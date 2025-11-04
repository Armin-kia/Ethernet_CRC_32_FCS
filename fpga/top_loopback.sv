// Minimal loopback: generator -> fcs_tx -> fcs_rx -> checker
// Expose a few counters for ILA/Signal Tap.

module top_loopback (
  input  logic        clk,     // e.g., 100 MHz board clock
  input  logic        rst_n,

  output logic [31:0] frames_ok,
  output logic [31:0] frames_bad
);

  // Stream wires
  logic [7:0]  gen_tdata, tx_tdata, rx_tdata;
  logic        gen_tvalid, gen_tready, gen_tlast;
  logic        tx_tvalid,  tx_tready,  tx_tlast;
  logic        rx_tvalid,  rx_tready,  rx_tlast;
  logic        bad_fcs;
  int          frames_sent;

  // Simple on-chip traffic (shorter & deterministic)
  axi_stream_packet_gen #(.MIN_BYTES(64), .MAX_BYTES(128), .SEED(32'hBEEF_BABE)) u_gen (
    .clk            (clk),
    .rst_n          (rst_n),
    .m_axis_tdata   (gen_tdata),
    .m_axis_tvalid  (gen_tvalid),
    .m_axis_tready  (gen_tready),
    .m_axis_tlast   (gen_tlast),
    .frames_sent    (frames_sent),
    .total_frames   (32'h7FFF_FFFF),      // run forever
    .inj_every_n    (0),                  // no error injection in hardware
    .inj_this_frame ()
  );

  fcs_tx u_tx (
    .clk(clk), .rst_n(rst_n),
    .s_axis_tdata (gen_tdata),
    .s_axis_tvalid(gen_tvalid),
    .s_axis_tready(gen_tready),
    .s_axis_tlast (gen_tlast),
    .m_axis_tdata (tx_tdata),
    .m_axis_tvalid(tx_tvalid),
    .m_axis_tready(tx_tready),
    .m_axis_tlast (tx_tlast)
  );

  assign tx_tready = 1'b1;

  fcs_rx u_rx (
    .clk(clk), .rst_n(rst_n),
    .s_axis_tdata (tx_tdata),
    .s_axis_tvalid(tx_tvalid),
    .s_axis_tready(),
    .s_axis_tlast (tx_tlast),
    .m_axis_tdata (rx_tdata),
    .m_axis_tvalid(rx_tvalid),
    .m_axis_tready(rx_tready),
    .m_axis_tlast (rx_tlast),
    .bad_fcs      (bad_fcs)
  );

  assign rx_tready = 1'b1;

  // counters
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      frames_ok  <= 0;
      frames_bad <= 0;
    end else begin
      if (rx_tvalid && rx_tready && rx_tlast) frames_ok  <= frames_ok + 1;
      if (bad_fcs)                            frames_bad <= frames_bad + 1;
    end
  end

endmodule
