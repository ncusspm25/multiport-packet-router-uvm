interface router_if #(parameter int unsigned DATA_W = 32)(input logic clk);
  logic rst_n = 0;
  logic [1:0] in_valid = '0;
  logic [1:0] in_ready;
  logic [1:0][DATA_W-1:0] in_data = '0;
  logic [1:0] in_dest = '0;
  logic [1:0] out_valid;
  logic [1:0] out_ready = '0;
  logic [1:0][DATA_W-1:0] out_data;
endinterface
