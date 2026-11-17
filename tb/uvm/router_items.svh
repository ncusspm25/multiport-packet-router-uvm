typedef virtual router_if #(DATA_W) router_vif_t;

class packet extends uvm_sequence_item;
  `uvm_object_utils(packet)
  rand data_t data;
  rand bit dest;
  rand int unsigned gap;
  constraint bounded_gap { gap inside {[0:3]}; }
  function new(string name = "packet"); super.new(name); endfunction
endclass

class ready_pattern extends uvm_object;
  `uvm_object_utils(ready_pattern)
  rand bit ready;
  constraint weighted_ready { ready dist {0 := 30, 1 := 70}; }
  function new(string name = "ready_pattern"); super.new(name); endfunction
endclass

class port_sample extends uvm_object;
  `uvm_object_utils(port_sample)
  longint unsigned cycle;
  bit rst_n;
  bit valid;
  bit ready;
  bit dest;
  data_t data;
  function new(string name = "port_sample"); super.new(name); endfunction
endclass

class router_config extends uvm_object;
  `uvm_object_utils(router_config)
  router_vif_t vif;
  scenario_t scenario = SINGLE_PORT;
  int unsigned seed = 1;
  int unsigned packets_per_source = 32;
  int passive_source = -1;
  bit protocol_negative = 0;
  function new(string name = "router_config"); super.new(name); endfunction
endclass

class port_config extends uvm_object;
  `uvm_object_utils(port_config)
  router_config system_cfg;
  int port_id;
  bit is_source;
  uvm_active_passive_enum activity = UVM_ACTIVE;
  function new(string name = "port_config"); super.new(name); endfunction
endclass

class traffic_sequence extends uvm_sequence #(packet);
  `uvm_object_utils(traffic_sequence)
  int port_id;
  int unsigned count = 32;
  int unsigned seed = 1;
  scenario_t scenario = SINGLE_PORT;
  function new(string name = "traffic_sequence"); super.new(name); endfunction

  task body();
    packet item = packet::type_id::create("packet");
    item.srandom(seed ^ (32'h9e3779b9 + (32'(port_id) << 16)));
    for (int unsigned index = 0; index < count; index++) begin
      start_item(item);
      if (item.randomize() == 0) `uvm_fatal("RANDOMIZE", "Packet constraint solving failed")
      if (scenario != RANDOM_TRAFFIC && scenario != STRESS) item.gap = 0;
      case (scenario)
        SIMULTANEOUS, BACKPRESSURE: item.dest = 1'(port_id);
        CONTENTION: item.dest = 1'(index >= count / 2);
        RESET_TRAFFIC: item.dest = 0;
        SINGLE_PORT: item.dest = 1'(index);
        default: ;
      endcase
      if (index == 0) item.data = '0;
      if (index == 1) item.data = '1;
      finish_item(item);
    end
  endtask
endclass
