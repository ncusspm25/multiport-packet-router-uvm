`timescale 1ns/1ps

interface feature_if(input logic clk);
  logic valid = 0;
  logic ready = 1;
  logic [7:0] data = 0;
endinterface

class feature_item;
  rand bit [7:0] data;
  rand bit dest;
  constraint legal_data { data inside {[8'h10:8'hff]}; }

  covergroup destinations with function sample(bit destination);
    option.per_instance = 1;
    dest_cp: coverpoint destination {
      bins zero = {0};
      bins one = {1};
    }
  endgroup

  function new();
    destinations = new;
  endfunction
endclass

class feature_driver;
  virtual feature_if vif;
  function new(virtual feature_if vif);
    this.vif = vif;
  endfunction
  task send(bit [7:0] data);
    @(negedge vif.clk);
    vif.valid = 1;
    vif.data = data;
    @(posedge vif.clk);
    if (vif.data != data || !vif.ready) $fatal(1, "VIRTUAL_INTERFACE_PROBE");
  endtask
endclass

module feature_top;
  logic clk = 0;
  feature_if bus(clk);
  feature_item item;
  feature_driver driver;
  bit [1:0] seen = '0;
  always #5ns clk = ~clk;

  ap_stable: assert property (@(posedge clk)
    bus.valid && !bus.ready |=> bus.valid && $stable(bus.data))
    else $error("FEATURE_ASSERTION");

  initial begin
    item = new;
    driver = new(bus);
    for (int index = 0; index < 64; index++) begin
      if (item.randomize() == 0) $fatal(1, "RANDOMIZATION_FAILED");
      if (item.data < 8'h10) $fatal(1, "CONSTRAINT_NOT_ENFORCED");
      driver.send(item.data);
      seen[item.dest] = 1;
      item.destinations.sample(item.dest);
    end
    if (seen != '1) $fatal(1, "RANDOM_DESTINATION_BINS_MISSING");
    if (item.destinations.get_inst_coverage() != 100.0)
      $fatal(1, "NATIVE_COVERAGE_PROBE_FAILED");
    $display("FEATURE_PASS randomize=64 virtual_interface=64 native_coverage=%0.1f",
             item.destinations.get_inst_coverage());
    $finish;
  end
endmodule
