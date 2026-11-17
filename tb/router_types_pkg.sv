package router_types_pkg;
  `ifndef ROUTER_DATA_W
    `define ROUTER_DATA_W 32
  `endif
  parameter int unsigned DATA_W = `ROUTER_DATA_W;
  typedef bit [DATA_W-1:0] data_t;
  typedef enum int {
    SINGLE_PORT, SIMULTANEOUS, CONTENTION, BACKPRESSURE,
    RESET_TRAFFIC, RANDOM_TRAFFIC, STRESS
  } scenario_t;
endpackage
