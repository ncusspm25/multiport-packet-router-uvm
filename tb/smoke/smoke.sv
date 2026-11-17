`timescale 1ns/1ps

package smoke_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class router_uvm_smoke extends uvm_test;
    `uvm_component_utils(router_uvm_smoke)

    function new(string name = "router_uvm_smoke", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      #10ns;
      `uvm_info("SMOKE_PASS", "UVM factory, phases, objections and timing ran", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass
endpackage

module smoke_top;
  import uvm_pkg::*;
  import smoke_pkg::*;

  initial run_test("router_uvm_smoke");
  initial begin
    #1000ns;
    $fatal(1, "SMOKE_TIMEOUT");
  end
endmodule
