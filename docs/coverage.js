"use strict";

const source = "https://raw.githubusercontent.com/ncusspm25/multiport-packet-router-uvm/c941632fdfbdf4d50c21a4e1c13458451f4f6d18/reports/coverage.json";
const group = document.querySelector("#group");
const status = document.querySelector("#status");
const bins = document.querySelector("#bins");
const body = bins.tBodies[0];
const fmt = new Intl.NumberFormat("en");

function cell(row, value, className) {
  const td = row.insertCell();
  td.textContent = value;
  if (className) td.className = className;
  return td;
}

function render(report) {
  const rows = report.native_functional_bins;
  const maximum = Math.max(1, ...rows.map(({ hits }) => hits));
  document.querySelector("#total").textContent = report.functional_covered + " / " + report.functional_total;
  const counters = document.querySelector("#counters tbody");
  for (const [kind, count] of Object.entries(report.rtl_counters)) {
    const row = counters.insertRow();
    cell(row, kind);
    cell(row, fmt.format(count.covered) + " / " + fmt.format(count.total), "num number");
  }

  function fill() {
    const shown = rows.filter(({ bin }) => group.value === "all" || bin.split(".")[0] === group.value);
    body.replaceChildren();
    for (const { bin, hits } of shown) {
      const row = body.insertRow();
      cell(row, bin, "bin");
      const bar = document.createElement("meter");
      bar.max = Math.log1p(maximum);
      bar.value = Math.log1p(hits);
      bar.setAttribute("aria-hidden", "true");
      cell(row, "", "plot").append(bar);
      cell(row, fmt.format(hits), "num number");
    }
    status.textContent = shown.length + " of " + rows.length + " bins shown";
  }

  fill();
  bins.hidden = false;
  group.disabled = false;
  group.addEventListener("change", fill);
}

fetch(source, { signal: AbortSignal.timeout(12000) })
  .then((response) => {
    if (!response.ok) throw new Error("Coverage request failed");
    return response.json();
  })
  .then(render)
  .catch(() => {
    status.textContent = "The coverage data could not be loaded. Open the source report below or reload to try again.";
  });
