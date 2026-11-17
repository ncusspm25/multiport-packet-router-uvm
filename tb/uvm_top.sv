module uvm_top;
  import uvm_pkg::*;
  import router_types_pkg::*;
  import router_uvm_pkg::*;
  logic clk = 0;
  router_if #(DATA_W) bus(clk);
  always #5ns clk = ~clk;

  `ifdef ROUTER_MUTATIONS
    packet_router_variants #(.DATA_W(DATA_W)) dut (
  `else
    packet_router #(.DATA_W(DATA_W)) dut (
  `endif
    .clk, .rst_n(bus.rst_n), .in_valid(bus.in_valid), .in_ready(bus.in_ready),
    .in_data(bus.in_data), .in_dest(bus.in_dest), .out_valid(bus.out_valid),
    .out_ready(bus.out_ready), .out_data(bus.out_data)
  );
  router_assertions #(.DATA_W(DATA_W)) checks (
    .clk, .rst_n(bus.rst_n), .in_valid(bus.in_valid), .in_ready(bus.in_ready),
    .in_data(bus.in_data), .in_dest(bus.in_dest), .out_valid(bus.out_valid),
    .out_ready(bus.out_ready), .out_data(bus.out_data)
  );

  initial begin
    uvm_config_db#(router_vif_t)::set(null, "uvm_test_top", "vif", bus);
    run_test("router_test");
  end
  initial begin
    repeat (4) @(negedge clk);
    bus.rst_n = 1;
  end
  initial begin
    #10ms;
    $fatal(1, "GLOBAL_TIMEOUT");
  end
endmodule
