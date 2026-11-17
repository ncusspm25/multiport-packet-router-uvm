`timescale 1ns/1ps

module router_assertions #(
  parameter int unsigned DATA_W = 32
) (
  input logic clk,
  input logic rst_n,
  input logic [1:0] in_valid,
  input logic [1:0] in_ready,
  input logic [1:0][DATA_W-1:0] in_data,
  input logic [1:0] in_dest,
  input logic [1:0] out_valid,
  input logic [1:0] out_ready,
  input logic [1:0][DATA_W-1:0] out_data
);
  for (genvar port_id = 0; port_id < 2; port_id++) begin : protocol
    ap_input_stable: assert property (@(posedge clk) disable iff (!rst_n)
      in_valid[port_id] && !in_ready[port_id] |=>
      in_valid[port_id] && $stable({in_data[port_id], in_dest[port_id]}))
      else $error("SVA_INPUT_STABLE port=%0d", port_id);

    ap_output_stable: assert property (@(posedge clk) disable iff (!rst_n)
      out_valid[port_id] && !out_ready[port_id] |=>
      out_valid[port_id] && $stable(out_data[port_id]))
      else $error("SVA_OUTPUT_STABLE port=%0d", port_id);
  end

  ap_reset_clears: assert property (@(posedge clk)
    !rst_n |=> out_valid == '0)
    else $error("SVA_RESET_CLEARS");

  ap_reset_blocks_inputs: assert property (@(posedge clk)
    !rst_n |-> in_ready == '0)
    else $error("SVA_RESET_INPUTS");

  ap_no_double_grant: assert property (@(posedge clk) disable iff (!rst_n)
    (&in_valid) && (in_dest[0] == in_dest[1]) |-> !(&in_ready))
    else $error("SVA_DOUBLE_GRANT");
endmodule
