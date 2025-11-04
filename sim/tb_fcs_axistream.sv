`timescale 1ns/1ps
`include "../rtl/axi_stream_pkg.svh"

module tb_fcs_axistream;

  // Clock/Reset
  logic clk = 0; always #5 clk = ~clk; // 100 MHz
  logic rst_n = 0;

  // Wires
  logic [7:0]  gen_tdata, tx_tdata, rx_tdata;
  logic        gen_tvalid, gen_tready, gen_tlast;
  logic        tx_tvalid,  tx_tready,  tx_tlast;
  logic        rx_tvalid,  rx_tready,  rx_tlast;
  logic        bad_fcs;

  int          frames_sent, frames_rcvd, bad_count;
  int          TOTAL = 2000;
  logic        inj_this;

  // Generator
  axi_stream_packet_gen #(.MIN_BYTES(64), .MAX_BYTES(256), .SEED(32'hC0DE_1234)) u_gen (
    .clk            (clk),
    .rst_n          (rst_n),
    .m_axis_tdata   (gen_tdata),
    .m_axis_tvalid  (gen_tvalid),
    .m_axis_tready  (gen_tready),
    .m_axis_tlast   (gen_tlast),
    .frames_sent    (frames_sent),
    .total_frames   (TOTAL),
    .inj_every_n    (50),           // flip roughly every 50th frame (TB will flip one bit)
    .inj_this_frame (inj_this)
  );

  // DUTs
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

  // In-TB error injection: flip a bit on one byte when inj_this is high
  logic [7:0] tx_tdata_err;
  assign tx_tready = 1;
  assign tx_tdata_err = (inj_this && tx_tvalid) ? (tx_tdata ^ 8'h01) : tx_tdata;

  fcs_rx u_rx (
    .clk(clk), .rst_n(rst_n),
    .s_axis_tdata (tx_tdata_err),
    .s_axis_tvalid(tx_tvalid),
    .s_axis_tready(),
    .s_axis_tlast (tx_tlast),
    .m_axis_tdata (rx_tdata),
    .m_axis_tvalid(rx_tvalid),
    .m_axis_tready(rx_tready),
    .m_axis_tlast (rx_tlast),
    .bad_fcs      (bad_fcs)
  );

  // Checker
  assign rx_tready = 1;
  axi_stream_packet_chk u_chk (
    .clk(clk), .rst_n(rst_n),
    .s_axis_tdata (rx_tdata),
    .s_axis_tvalid(rx_tvalid),
    .s_axis_tready(),
    .s_axis_tlast (rx_tlast),
    .bad_fcs      (bad_fcs),
    .frames_rcvd  (frames_rcvd),
    .bad_count    (bad_count)
  );

  initial begin
    $display("== TB start ==");
    repeat (10) @(posedge clk);
    rst_n = 1;
    wait (frames_sent == TOTAL);
    repeat (5000) @(posedge clk);
    $display("Frames sent   = %0d", frames_sent);
    $display("Frames rcvd   = %0d", frames_rcvd);
    $display("Bad FCS count = %0d", bad_count);
    $finish;
  end

endmodule
