// Random-length AXI-Stream packet generator (byte-wide).
// Generates frames in [MIN..MAX] bytes, with random inter-packet gaps and optional error injection.

module axi_stream_packet_gen #(
  parameter int MIN_BYTES = 64,
  parameter int MAX_BYTES = 512,
  parameter int SEED      = 32'h1234_5678
)(
  input  logic        clk,
  input  logic        rst_n,

  // AXI-S out
  output logic [7:0]  m_axis_tdata,
  output logic        m_axis_tvalid,
  input  logic        m_axis_tready,
  output logic        m_axis_tlast,

  // stats
  output int          frames_sent,
  input  int          total_frames,     // stop after this many frames

  // error injection (flip 1 random bit in 1/N frames)
  input  int          inj_every_n,      // e.g., 50 => flip in every 50th frame (approx)
  output logic        inj_this_frame    // 1 when this frame is injected
);

  typedef enum logic [1:0] {GAP, SEND} s_e;
  s_e state;

  int lfsr;
  int bytes_left;
  int cnt;

  function int rnd(int lo, int hi);
    lfsr = (lfsr * 1103515245 + 12345) & 32'h7FFFFFFF;
    return lo + (lfsr % (hi - lo + 1));
  endfunction

  initial begin
    lfsr = SEED;
    frames_sent = 0;
    inj_this_frame = 0;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= GAP;
      m_axis_tvalid <= 0;
      m_axis_tdata  <= 8'h00;
      m_axis_tlast  <= 0;
      bytes_left    <= 0;
      inj_this_frame<= 0;
    end else begin
      m_axis_tlast <= 0;

      unique case (state)
        GAP: begin
          m_axis_tvalid <= 0;
          if (frames_sent < total_frames) begin
            bytes_left     <= rnd(MIN_BYTES, MAX_BYTES);
            inj_this_frame <= (inj_every_n > 0) && ((frames_sent+1) % inj_every_n == 0);
            state          <= SEND;
          end
        end
        SEND: begin
          m_axis_tvalid <= 1;
          if (m_axis_tvalid && m_axis_tready) begin
            m_axis_tdata <= rnd(0,255);
            bytes_left   <= bytes_left - 1;
            if (bytes_left == 1) begin
              m_axis_tlast <= 1;
            end
            if (bytes_left == 1) begin
              frames_sent <= frames_sent + 1;
              state <= GAP;
            end
          end
        end
      endcase
    end
  end

endmodule
