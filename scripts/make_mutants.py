#!/usr/bin/env python3
"""Generate explicit RTL defects in a build directory, leaving the production RTL intact."""

import argparse
import hashlib
import json
import pathlib


ROOT = pathlib.Path(__file__).resolve().parents[1]
MUTATIONS = {
    "drop": ("out_valid[output_port] <= 1'b1;", "out_valid[output_port] <= 1'b0;"),
    "duplicate": ("end else if (out_ready[output_port]) begin\n          out_valid[output_port] <= 1'b0;",
                  "end else if (out_ready[output_port]) begin\n          out_valid[output_port] <= 1'b1;"),
    "corrupt": ("out_data[output_port] <= in_data[grant[output_port]];",
                "out_data[output_port] <= in_data[grant[output_port]] ^ DATA_W'(1);"),
    "route": ("in_dest[input_port] == 1'(output_port)",
              "in_dest[input_port] != 1'(output_port)"),
    "priority": ("priority_input[output_port] <= ~grant[output_port];",
                 "priority_input[output_port] <= 1'b0;"),
    "unstable": ("end else if (out_ready[output_port]) begin",
                 "end else if (out_valid[output_port] && !out_ready[output_port]) begin\n"
                 "          out_data[output_port] <= out_data[output_port] ^ DATA_W'(1);\n"
                 "        end else if (out_ready[output_port]) begin"),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=pathlib.Path, required=True)
    args = parser.parse_args()
    output = args.out_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    original = (ROOT / "rtl/packet_router.sv").read_text()
    sources = []
    manifest = {"production_sha256": hashlib.sha256(original.encode()).hexdigest(), "mutations": []}
    for index, (name, (before, after)) in enumerate(MUTATIONS.items(), 1):
        if original.count(before) != 1:
            raise SystemExit(f"Mutation anchor {name} no longer matches exactly once")
        changed = original.replace(before, after).replace("module packet_router #(", f"module packet_router_{name} #(")
        sources.append(changed)
        manifest["mutations"].append({"id": index, "name": name, "before": before, "after": after,
                                      "sha256": hashlib.sha256(changed.encode()).hexdigest()})
    header = original[:original.index(");") + 2].replace("module packet_router #(", "module packet_router_variants #(")
    count = len(MUTATIONS) + 1
    wrapper = [header, f"  logic [{count-1}:0][1:0] all_in_ready, all_out_valid;",
               f"  logic [{count-1}:0][1:0][DATA_W-1:0] all_out_data;", "  int selected = 0;",
               "  initial begin", "    void'($value$plusargs(\"MUTATION=%d\", selected));",
               f"    if (selected < 0 || selected >= {count}) $fatal(1, \"Invalid MUTATION\");", "  end",
               "  assign in_ready = all_in_ready[selected];", "  assign out_valid = all_out_valid[selected];",
               "  assign out_data = all_out_data[selected];"]
    for index, name in enumerate(["production", *MUTATIONS]):
        module = "packet_router" if index == 0 else f"packet_router_{name}"
        wrapper.extend([
            f"  {module} #(.DATA_W(DATA_W)) instance_{name} (",
            f"    .clk, .rst_n(rst_n && selected == {index}),",
            f"    .in_valid(selected == {index} ? in_valid : 2'b00), .in_ready(all_in_ready[{index}]),",
            "    .in_data, .in_dest, .out_ready,",
            f"    .out_valid(all_out_valid[{index}]), .out_data(all_out_data[{index}])", "  );",
        ])
    wrapper.append("endmodule\n")
    (output / "router_mutants.sv").write_text("\n".join(sources + wrapper))
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Generated {len(MUTATIONS)} RTL mutants in {output}")


if __name__ == "__main__":
    main()
