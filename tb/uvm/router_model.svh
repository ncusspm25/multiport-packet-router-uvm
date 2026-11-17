class router_reference_model extends uvm_object;
  `uvm_object_utils(router_reference_model)
  data_t queue0[$];
  data_t queue1[$];
  bit [1:0] last_grant = '1;
  longint unsigned accepted = 0;
  longint unsigned delivered = 0;
  longint unsigned aborted = 0;
  function new(string name = "router_reference_model"); super.new(name); endfunction

  function int pending(); return queue0.size() + queue1.size(); endfunction
  function void reset_epoch();
    aborted += 64'(pending());
    queue0.delete();
    queue1.delete();
    last_grant = '1;
  endfunction
  function void accept(bit source, bit destination, data_t data);
    if (destination) queue1.push_back(data);
    else queue0.push_back(data);
    last_grant[destination] = source;
    accepted++;
  endfunction
  function string consume(bit destination, data_t data);
    data_t wanted;
    if ((destination == 0 && queue0.size() == 0) || (destination == 1 && queue1.size() == 0)) begin
      if ((destination == 0 && queue1.size() != 0 && queue1[0] == data)
          || (destination == 1 && queue0.size() != 0 && queue0[0] == data))
        return "SB_ROUTING";
      return "SB_DUPLICATE";
    end
    wanted = destination ? queue1[0] : queue0[0];
    if (wanted != data) begin
      if ((destination == 0 && queue1.size() != 0 && queue1[0] == data)
          || (destination == 1 && queue0.size() != 0 && queue0[0] == data))
        return "SB_ROUTING";
      return "SB_CORRUPTION_OR_ORDER";
    end
    if (destination) wanted = queue1.pop_front();
    else wanted = queue0.pop_front();
    delivered++;
    return "";
  endfunction
endclass

class router_coverage extends uvm_object;
  `uvm_object_utils(router_coverage)
  longint unsigned route_hits[4] = '{default:0};
  longint unsigned contention_hits[4] = '{default:0};
  longint unsigned stall_hits[2] = '{default:0};
  longint unsigned reset_busy_hits = 0;
  longint unsigned dual_hits = 0;
  bit [6:0] scenarios = '0;

  covergroup goals with function sample(int route, int contention_grant, int stalled_output,
                                       bit reset_busy, int payload_kind, int scenario);
    option.per_instance = 1;
    route_cp: coverpoint route {
      bins i0_o0 = {0}; bins i0_o1 = {1}; bins i1_o0 = {2}; bins i1_o1 = {3};
      ignore_bins idle = {-1};
    }
    contention_cp: coverpoint contention_grant {
      bins o0_i0 = {0}; bins o0_i1 = {1}; bins o1_i0 = {2}; bins o1_i1 = {3};
      ignore_bins idle = {-1};
    }
    stall_cp: coverpoint stalled_output {
      bins output0 = {0}; bins output1 = {1}; ignore_bins idle = {-1};
    }
    reset_cp: coverpoint reset_busy {
      bins pending_traffic = {1}; ignore_bins idle = {0};
    }
    data_cp: coverpoint payload_kind {
      bins zero = {0}; bins ones = {1}; bins mixed = {2}; ignore_bins idle = {-1};
    }
    scenario_cp: coverpoint scenario {
      bins single = {0}; bins simultaneous = {1}; bins contention = {2};
      bins backpressure = {3}; bins reset_traffic = {4}; bins random_traffic = {5};
      bins stress = {6}; ignore_bins idle = {-1};
    }
  endgroup

  function new(string name = "router_coverage");
    super.new(name);
    goals = new;
  endfunction
  function void accepted(int source, bit destination, data_t data, bit contention);
    int route = source * 2 + int'(destination);
    int grant_bin = contention ? int'(destination) * 2 + source : -1;
    int payload_kind = (data == '0) ? 0 : ((data == '1) ? 1 : 2);
    route_hits[route]++;
    if (contention) contention_hits[grant_bin]++;
    goals.sample(route, grant_bin, -1, 0, payload_kind, -1);
  endfunction
  function void stalled(int port_id);
    stall_hits[port_id]++;
    goals.sample(-1, -1, port_id, 0, -1, -1);
  endfunction
  function void reset_with_pending();
    reset_busy_hits++;
    goals.sample(-1, -1, -1, 1, -1, -1);
  endfunction
  function void completed(scenario_t scenario);
    scenarios[int'(scenario)] = 1;
    goals.sample(-1, -1, -1, 0, -1, int'(scenario));
  endfunction
endclass
