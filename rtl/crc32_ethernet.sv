// Ethernet CRC-32 (reflected) helpers.
// Poly (reflected) = 0xEDB88320; init=0xFFFFFFFF; final XOR=0xFFFFFFFF.
// LSB-first per byte; FCS bytes sent LSB-first.

module crc32_ethernet_byte #(
  parameter bit PIPELINED = 0  // 0 = combinational byte update
)(
  input  logic        clk,
  input  logic        en,            // pulse to update (one byte)
  input  logic [7:0]  data_byte,
  input  logic [31:0] crc_in,
  output logic [31:0] crc_out
);
  function automatic logic [31:0] upd (input logic [31:0] c, input logic [7:0] d);
    logic [31:0] crc;
    logic [7:0]  x;
    int i;
    crc = c;
    x   = d;
    for (i = 0; i < 8; i++) begin
      logic mix = crc[0] ^ x[0];
      crc = crc >> 1;                      // reflected => shift right
      if (mix) crc ^= 32'hEDB88320;       // reflected polynomial
      x = x >> 1;                          // next bit (LSB-first)
    end
    return crc;
  endfunction

  generate
    if (!PIPELINED) begin : g_comb
      always_comb begin
        if (en) crc_out = upd(crc_in, data_byte);
        else    crc_out = crc_in;
      end
    end else begin : g_seq
      logic [31:0] r;
      always_ff @(posedge clk) begin
        r <= (en) ? upd(crc_in, data_byte) : crc_in;
      end
      assign crc_out = r;
    end
  endgenerate
endmodule
