// Simple sink/counter for AXI-Stream payload, with bad_fcs tracker.

module axi_stream_packet_chk (
  input  logic       clk,
  input  logic       rst_n,

  // AXI-S in (payload only)
  input  logic [7:0] s_axis_tdata,
  input  logic       s_axis_tvalid,
  output logic       s_axis_tready,
  input  logic       s_axis_tlast,

  // bad_fcs from RX
  input  logic       bad_fcs,

  // stats
  output int         frames_rcvd,
  output int         bad_count
);
  assign s_axis_tready = 1;

  initial begin
    frames_rcvd = 0;
    bad_count   = 0;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      frames_rcvd <= 0;
      bad_count   <= 0;
    end else begin
      if (s_axis_tvalid && s_axis_tready && s_axis_tlast)
        frames_rcvd <= frames_rcvd + 1;
      if (bad_fcs)
        bad_count   <= bad_count + 1;
    end
  end

endmodule
