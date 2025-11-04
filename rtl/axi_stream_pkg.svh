// Simple AXI-Stream defs (byte-wide by default).
`ifndef AXI_STREAM_PKG_SVH
`define AXI_STREAM_PKG_SVH

parameter int DATA_W = 8;  // Keep byte-wide for now; extend later with tkeep.

typedef struct packed {
  logic [DATA_W-1:0] tdata;
  logic              tvalid;
  logic              tready;
  logic              tlast;
} axis_ifs_t;

`endif
