// AXI-Stream FCS checker (byte-wide).
// Accepts payload+FCS; outputs payload only and raises bad_fcs for frames with CRC mismatch.

`include "axi_stream_pkg.svh"

module fcs_rx #(
  parameter int DATA_W = 8
)(
  input  logic                 clk,
  input  logic                 rst_n,

  // AXI-S in (payload + 4-byte FCS)
  input  logic [DATA_W-1:0]    s_axis_tdata,
  input  logic                 s_axis_tvalid,
  output logic                 s_axis_tready,
  input  logic                 s_axis_tlast,

  // AXI-S out (payload only)
  output logic [DATA_W-1:0]    m_axis_tdata,
  output logic                 m_axis_tvalid,
  input  logic                 m_axis_tready,
  output logic                 m_axis_tlast,

  // status
  output logic                 bad_fcs    // pulses 1 on last beat of a bad frame
);

  initial if (DATA_W != 8) $error("fcs_rx: only DATA_W=8 supported in this version.");

  logic [7:0]  q0,q1,q2,q3;    // q3=oldest to forward
  logic [2:0]  depth;
  logic        in_hs = s_axis_tvalid && s_axis_tready;
  logic        out_hs= m_axis_tvalid && m_axis_tready;

  logic [31:0] crc, crc_upd;
  logic        crc_en;

  logic [31:0] fcs_recv;
  logic [1:0]  fcs_idx_cnt;

  crc32_ethernet_byte u_crc (
    .clk      (clk),
    .en       (crc_en),
    .data_byte(q3),
    .crc_in   (crc),
    .crc_out  (crc_upd)
  );

  assign s_axis_tready = 1'b1;
  assign m_axis_tvalid = (depth >= 3) ? s_axis_tvalid : 1'b0;
  assign m_axis_tdata  = q3;
  assign m_axis_tlast  = (depth >= 3) && s_axis_tvalid && s_axis_tlast;

  assign crc_en = out_hs;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      q0 <= '0; q1 <= '0; q2 <= '0; q3 <= '0;
      depth <= '0;
      crc   <= 32'hFFFF_FFFF;
      fcs_recv <= '0;
      fcs_idx_cnt <= '0;
      bad_fcs <= 1'b0;
    end else begin
      bad_fcs <= 1'b0;

      if (in_hs) begin
        q3 <= q2;
        q2 <= q1;
        q1 <= q0;
        q0 <= s_axis_tdata;

        if (depth != 3'd7) depth <= depth + 3'd1;

        if (s_axis_tlast) begin
          fcs_recv <= { q3, q2, q1, q0 };  // assemble LSB->MSB order
          fcs_idx_cnt <= 2'd3;
        end
      end

      if (out_hs) begin
        if ( (depth == 3) && s_axis_tvalid ) begin
          crc <= 32'hFFFF_FFFF;
        end else begin
          crc <= crc_upd;
        end
      end

      if (m_axis_tlast && out_hs) begin
        logic [31:0] crc_final = crc ^ 32'hFFFF_FFFF;
        if (crc_final != fcs_recv) bad_fcs <= 1'b1;
        crc   <= 32'hFFFF_FFFF;
        depth <= '0;
      end
    end
  end

endmodule
