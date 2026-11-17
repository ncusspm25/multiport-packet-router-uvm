`timescale 1ns/1ps

module directed_top #(
  parameter int unsigned DATA_W = 32
);
  typedef logic [DATA_W-1:0] data_t;
  logic clk = 0;
  logic rst_n = 0;
  logic [1:0] in_valid = '0;
  logic [1:0] in_ready;
  logic [1:0][DATA_W-1:0] in_data = '0;
  logic [1:0] in_dest = '0;
  logic [1:0] out_valid;
  logic [1:0] out_ready = '1;
  logic [1:0][DATA_W-1:0] out_data;
  data_t expected0[$];
  data_t expected1[$];
  bit [1:0] next_winner = '0;
  int accepted = 0;
  int delivered = 0;
  int aborted = 0;
  int testcase = 0;

  always #5ns clk = ~clk;
  packet_router #(.DATA_W(DATA_W)) dut (.*);
  router_assertions #(.DATA_W(DATA_W)) checks (.*);

  always @(posedge clk) begin : independent_checker
    data_t wanted;
    if (!rst_n) begin
      aborted += expected0.size() + expected1.size();
      expected0.delete();
      expected1.delete();
      next_winner = '0;
    end else begin
      // Check the old output slots before recording new input acceptances.
      for (int port_id = 0; port_id < 2; port_id++) begin
        if (out_valid[port_id] && out_ready[port_id]) begin
          if (port_id == 0) begin
            if (expected0.size() == 0) $fatal(1, "DIRECTED_UNEXPECTED_OUTPUT");
            wanted = expected0.pop_front();
          end else begin
            if (expected1.size() == 0) $fatal(1, "DIRECTED_UNEXPECTED_OUTPUT");
            wanted = expected1.pop_front();
          end
          if (out_data[port_id] !== wanted) $fatal(1, "DIRECTED_DATA_MISMATCH");
          delivered++;
        end
      end
      if ((&in_valid) && (in_dest[0] == in_dest[1]) && (|in_ready)) begin
        if (!in_ready[next_winner[in_dest[0]]]) $fatal(1, "DIRECTED_ARBITRATION");
      end
      for (int port_id = 0; port_id < 2; port_id++) begin
        if (in_valid[port_id] && in_ready[port_id]) begin
          if (in_dest[port_id]) expected1.push_back(in_data[port_id]);
          else expected0.push_back(in_data[port_id]);
          next_winner[in_dest[port_id]] = ~1'(port_id);
          accepted++;
        end
      end
    end
  end

  task automatic send_stream(int port_id, bit destination, int count, int base);
    @(negedge clk);
    in_valid[port_id] = 1;
    in_dest[port_id] = destination;
    for (int index = 0; index < count; index++) begin
      in_data[port_id] = data_t'(base) + data_t'(index);
      do @(posedge clk); while (!rst_n || !in_ready[port_id]);
      @(negedge clk);
    end
    in_valid[port_id] = 0;
  endtask

  task automatic throttle_outputs();
    for (int cycle = 0; cycle < 100; cycle++) begin
      @(negedge clk);
      out_ready[0] = (cycle % 9) >= 4;
      out_ready[1] = (cycle % 7) >= 3;
    end
    @(negedge clk);
    out_ready = '1;
  endtask

  initial begin
    if (!$value$plusargs("CASE=%d", testcase)) testcase = 0;
    repeat (3) @(negedge clk);
    rst_n = 1;
    case (testcase)
      0: begin
        send_stream(0, 0, 8, 0);
        send_stream(0, 1, 8, 20);
        send_stream(1, 0, 8, 40);
        send_stream(1, 1, 8, 60);
      end
      1: fork
        send_stream(0, 0, 64, 100);
        send_stream(1, 1, 64, 200);
      join
      2: begin
        fork
          send_stream(0, 0, 32, 300);
          send_stream(1, 0, 32, 400);
        join
        fork
          send_stream(0, 1, 32, 500);
          send_stream(1, 1, 32, 600);
        join
      end
      3: fork
        send_stream(0, 0, 64, 700);
        send_stream(1, 1, 64, 800);
        throttle_outputs();
      join
      4: begin
        @(negedge clk);
        out_ready = '0;
        fork
          send_stream(0, 0, 16, 900);
          begin
            repeat (6) @(negedge clk);
            rst_n = 0;
            repeat (2) @(negedge clk);
            rst_n = 1;
            out_ready = '1;
          end
        join
      end
      default: $fatal(1, "Unknown directed case");
    endcase
    repeat (10) @(negedge clk);
    if (expected0.size() != 0 || expected1.size() != 0) $fatal(1, "DIRECTED_LOSS");
    if (accepted != delivered + aborted) $fatal(1, "DIRECTED_CONSERVATION");
    if (testcase == 4 && aborted == 0) $fatal(1, "Reset case did not abort pending traffic");
    $display("DIRECTED_PASS case=%0d width=%0d accepted=%0d delivered=%0d aborted=%0d",
             testcase, DATA_W, accepted, delivered, aborted);
    $finish;
  end

  initial begin
    #100us;
    $fatal(1, "DIRECTED_TIMEOUT");
  end
endmodule
