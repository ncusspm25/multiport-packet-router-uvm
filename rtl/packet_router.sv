`timescale 1ns/1ps

module packet_router #(
  parameter int unsigned DATA_W = 32
) (
  input  logic                        clk,
  input  logic                        rst_n,
  input  logic [1:0]                   in_valid,
  output logic [1:0]                   in_ready,
  input  logic [1:0][DATA_W-1:0]       in_data,
  input  logic [1:0]                   in_dest,
  output logic [1:0]                   out_valid,
  input  logic [1:0]                   out_ready,
  output logic [1:0][DATA_W-1:0]      out_data
);
  logic [1:0] priority_input;
  logic [1:0] grant_valid;
  logic [1:0] grant;

  always_comb begin
    in_ready = '0;
    grant_valid = '0;
    grant = '0;
    for (int output_port = 0; output_port < 2; output_port++) begin
      logic [1:0] requests;
      requests = '0;
      for (int input_port = 0; input_port < 2; input_port++) begin
        requests[input_port] = in_valid[input_port]
                             && (in_dest[input_port] == 1'(output_port));
      end
      if (rst_n && (!out_valid[output_port] || out_ready[output_port])) begin
        if (&requests) begin
          grant_valid[output_port] = 1'b1;
          grant[output_port] = priority_input[output_port];
        end else if (|requests) begin
          grant_valid[output_port] = 1'b1;
          grant[output_port] = requests[1];
        end
        if (grant_valid[output_port]) begin
          in_ready[grant[output_port]] = 1'b1;
        end
      end
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      out_valid <= '0;
      out_data <= '0;
      priority_input <= '0;
    end else begin
      for (int output_port = 0; output_port < 2; output_port++) begin
        if (grant_valid[output_port]) begin
          out_valid[output_port] <= 1'b1;
          out_data[output_port] <= in_data[grant[output_port]];
          priority_input[output_port] <= ~grant[output_port];
        end else if (out_ready[output_port]) begin
          out_valid[output_port] <= 1'b0;
        end
      end
    end
  end
endmodule
