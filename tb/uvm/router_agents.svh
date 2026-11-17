class router_monitor extends uvm_monitor;
  `uvm_component_utils(router_monitor)
  port_config cfg;
  uvm_analysis_port #(port_sample) ap;
  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(port_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("CONFIG", "Monitor configuration missing")
  endfunction
  task run_phase(uvm_phase phase);
    longint unsigned cycle = 0;
    forever begin
      port_sample sample;
      // All drivers use the falling edge. Read the rising edge before RTL NBA updates.
      @(posedge cfg.system_cfg.vif.clk);
      sample = port_sample::type_id::create("sample");
      sample.cycle = ++cycle;
      sample.rst_n = cfg.system_cfg.vif.rst_n;
      if (cfg.is_source) begin
        sample.valid = cfg.system_cfg.vif.in_valid[cfg.port_id];
        sample.ready = cfg.system_cfg.vif.in_ready[cfg.port_id];
        sample.data = cfg.system_cfg.vif.in_data[cfg.port_id];
        sample.dest = cfg.system_cfg.vif.in_dest[cfg.port_id];
      end else begin
        sample.valid = cfg.system_cfg.vif.out_valid[cfg.port_id];
        sample.ready = cfg.system_cfg.vif.out_ready[cfg.port_id];
        sample.data = cfg.system_cfg.vif.out_data[cfg.port_id];
        sample.dest = 1'(cfg.port_id);
      end
      ap.write(sample);
    end
  endtask
endclass

class source_driver extends uvm_driver #(packet);
  `uvm_component_utils(source_driver)
  port_config cfg;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(port_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("CONFIG", "Source configuration missing")
  endfunction
  task run_phase(uvm_phase phase);
    packet current = null;
    int unsigned gap_left = 0;
    int unsigned stalled = 0;
    bit violated = 0;
    forever begin
      @(negedge cfg.system_cfg.vif.clk);
      if (!cfg.system_cfg.vif.rst_n) begin
        cfg.system_cfg.vif.in_valid[cfg.port_id] = 0;
        stalled = 0;
      end else begin
        if (current == null) begin
          seq_item_port.try_next_item(current);
          if (current != null) gap_left = current.gap;
        end
        if (current != null && gap_left == 0) begin
          cfg.system_cfg.vif.in_valid[cfg.port_id] = 1;
          cfg.system_cfg.vif.in_data[cfg.port_id] = current.data;
          cfg.system_cfg.vif.in_dest[cfg.port_id] = current.dest;
          if (cfg.system_cfg.protocol_negative && !violated && stalled >= 2) begin
            current.data ^= data_t'(1);
            cfg.system_cfg.vif.in_data[cfg.port_id] = current.data;
            violated = 1;
          end
        end else begin
          cfg.system_cfg.vif.in_valid[cfg.port_id] = 0;
          if (gap_left != 0) gap_left--;
        end
      end
      @(posedge cfg.system_cfg.vif.clk);
      if (cfg.system_cfg.vif.rst_n && cfg.system_cfg.vif.in_valid[cfg.port_id]) begin
        if (cfg.system_cfg.vif.in_ready[cfg.port_id]) begin
          seq_item_port.item_done();
          current = null;
          stalled = 0;
        end else begin
          stalled++;
          if (stalled > 1024) `uvm_fatal("DRIVER_TIMEOUT", "Input has made no progress for 1024 cycles")
        end
      end
    end
  endtask
endclass

class sink_driver extends uvm_component;
  `uvm_component_utils(sink_driver)
  port_config cfg;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(port_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("CONFIG", "Sink configuration missing")
  endfunction
  task run_phase(uvm_phase phase);
    int unsigned cycle = 0;
    scenario_t previous = SINGLE_PORT;
    ready_pattern pattern = ready_pattern::type_id::create("pattern");
    pattern.srandom(cfg.system_cfg.seed ^ (32'h12340000 + 32'(cfg.port_id)));
    forever begin
      @(negedge cfg.system_cfg.vif.clk);
      if (cfg.system_cfg.scenario != previous) begin
        cycle = 0;
        previous = cfg.system_cfg.scenario;
      end
      cycle++;
      if (!cfg.system_cfg.vif.rst_n) cfg.system_cfg.vif.out_ready[cfg.port_id] = 0;
      else begin
        case (cfg.system_cfg.scenario)
          BACKPRESSURE:
            cfg.system_cfg.vif.out_ready[cfg.port_id] = cycle > 16 && (cycle % 9 >= 4);
          RESET_TRAFFIC:
            cfg.system_cfg.vif.out_ready[cfg.port_id] = cycle > 16;
          RANDOM_TRAFFIC, STRESS: begin
            if (cycle == 1 || cycle % 4 == 0) begin
              if (pattern.randomize() == 0) `uvm_fatal("RANDOMIZE", "Ready constraint solving failed")
            end
            cfg.system_cfg.vif.out_ready[cfg.port_id] = pattern.ready;
          end
          default: cfg.system_cfg.vif.out_ready[cfg.port_id] = 1;
        endcase
      end
    end
  endtask
endclass

class source_agent extends uvm_agent;
  `uvm_component_utils(source_agent)
  port_config cfg;
  uvm_sequencer #(packet) sequencer;
  source_driver driver;
  router_monitor monitor;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(port_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("CONFIG", "Source agent configuration missing")
    uvm_config_db#(port_config)::set(this, "*", "cfg", cfg);
    monitor = router_monitor::type_id::create("monitor", this);
    if (cfg.activity == UVM_ACTIVE) begin
      sequencer = uvm_sequencer#(packet)::type_id::create("sequencer", this);
      driver = source_driver::type_id::create("driver", this);
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.activity == UVM_ACTIVE) driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

class sink_agent extends uvm_agent;
  `uvm_component_utils(sink_agent)
  port_config cfg;
  sink_driver driver;
  router_monitor monitor;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(port_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("CONFIG", "Sink agent configuration missing")
    uvm_config_db#(port_config)::set(this, "*", "cfg", cfg);
    monitor = router_monitor::type_id::create("monitor", this);
    if (cfg.activity == UVM_ACTIVE) driver = sink_driver::type_id::create("driver", this);
  endfunction
endclass
