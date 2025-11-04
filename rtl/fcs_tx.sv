// AXI-Stream FCS appender (byte-wide).
// Passes payload through and then appends 4-byte FCS (LSB-first). TLAST asserted on final FCS byte.

`include "axi_stream_pkg.svh"

module fcs_tx #(
  parameter int DATA_W = 8
)(
  input  logic                 clk,
  input  logic                 rst_n,

  // AXI-S in (payload)
  input  logic [DATA_W-1:0]    s_axis_tdata,
  input  logic                 s_axis_tvalid,
  output logic                 s_axis_tready,
  input  logic                 s_axis_tlast,

  // AXI-S out (payload + FCS)
  output logic [DATA_W-1:0]    m_axis_tdata,
  output logic                 m_axis_tvalid,
  input  logic                 m_axis_tready,
  output logic                 m_axis_tlast
);

  // Only DATA_W=8 supported in this minimal drop.
  initial if (DATA_W != 8) $error("fcs_tx: only DATA_W=8 supported in this version.");

  typedef enum logic [1:0] {IDLE, RUN, APPEND} state_e;
  state_e state, nstate;

  logic [31:0] crc, crc_next;
  logic [1:0]  fcs_idx; // 0..3 which CRC byte we are sending
  logic        take_in, send_out;

  // byte-wide CRC helper (combinational)
  logic [31:0] crc_upd;
  logic        crc_en = take_in;
  crc32_ethernet_byte u_crc (
    .clk      (clk),
    .en       (crc_en),
    .data_byte(s_axis_tdata),
    .crc_in   (crc),
    .crc_out  (crc_upd)
  );

  // handshakes
  assign send_out = m_axis_tvalid && m_axis_tready;
  assign take_in  = s_axis_tvalid && s_axis_tready;

  // next state
  always_comb begin
    nstate = state;
    unique case (state)
      IDLE:  if (s_axis_tvalid) nstate = RUN;
      RUN:   if (take_in && s_axis_tlast) nstate = APPEND;
      APPEND: if (send_out && (fcs_idx == 2'd3)) nstate = IDLE;
    endcase
  end

  // outputs default
  always_comb begin
    s_axis_tready = 1'b0;
    m_axis_tvalid = 1'b0;
    m_axis_tdata  = '0;
    m_axis_tlast  = 1'b0;

    unique case (state)
      IDLE: begin
        s_axis_tready = 1'b1;
      end
      RUN: begin
        s_axis_tready = m_axis_tready;        // pass-through backpressure
        m_axis_tvalid = s_axis_tvalid;
        m_axis_tdata  = s_axis_tdata;
        m_axis_tlast  = 1'b0;                 // TLAST delayed until after FCS
      end
      APPEND: begin
        m_axis_tvalid = 1'b1;
        unique case (fcs_idx)
          2'd0: m_axis_tdata = (crc ^ 32'hFFFF_FFFF)[7:0];
          2'd1: m_axis_tdata = (crc ^ 32'hFFFF_FFFF)[15:8];
          2'd2: m_axis_tdata = (crc ^ 32'hFFFF_FFFF)[23:16];
          2'd3: m_axis_tdata = (crc ^ 32'hFFFF_FFFF)[31:24];
        endcase
        m_axis_tlast = (fcs_idx == 2'd3);
      end
    endcase
  end

  // sequential
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      crc     <= 32'hFFFF_FFFF;
      fcs_idx <= '0;
    end else begin
      state <= nstate;

      if (state == IDLE && s_axis_tvalid && s_axis_tready)
        crc <= 32'hFFFF_FFFF;          // start of frame (first byte)
      else if (state == RUN && take_in)
        crc <= crc_upd;

      if (state == RUN && take_in && s_axis_tlast) begin
        fcs_idx <= 2'd0;               // go to first FCS byte next
      end else if (state == APPEND && send_out) begin
        fcs_idx <= fcs_idx + 2'd1;
      end

      if (state == APPEND && send_out && (fcs_idx == 2'd3)) begin
        crc <= 32'hFFFF_FFFF;          // ready for next frame
      end
    end
  end

endmodule
