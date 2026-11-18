"use strict";

const steps = [
  {
    title: "Drive the input",
    description: "The sequencer hands the driver a packet. On the falling edge the driver presents data, destination and valid, then holds them until acceptance.",
    nodes: ["driver", "dut"], edges: [0], queue: "empty", actual: "—",
  },
  {
    title: "Build the expected queue",
    description: "At the rising edge, the input monitor records valid and ready high. The reference model uses the sampled destination to enqueue 0xA5 for output 1.",
    nodes: ["in", "score"], edges: [1, 3], queue: "[0xA5]", actual: "—",
  },
  {
    title: "Observe the output",
    description: "At the next rising edge in this example, output 1 handshakes. The output monitor samples 0xA5 and sends it through its analysis FIFO.",
    nodes: ["dut", "out"], edges: [2], queue: "[0xA5]", actual: "0xA5",
  },
  {
    title: "Compare and pop",
    description: "The scoreboard aligns all four monitor samples by cycle. For this output handshake the model compares the sampled payload with the head of the output 1 queue, then pops the matched packet.",
    nodes: ["score"], edges: [3, 4], queue: "empty", actual: "0xA5 · match",
  },
];

const buttons = [...document.querySelectorAll("[data-step]")];
const advance = document.querySelector("#advance");
const play = document.querySelector("#play");
const reset = document.querySelector("#reset");
const packet = document.querySelector("#packet");
let current = 0;
let timer = null;
let travel;
const tracks = [...document.querySelectorAll("[data-edge]")];
const reduced = matchMedia("(prefers-reduced-motion: reduce)");

function movePacket(path) {
  travel?.cancel();
  packet.removeAttribute("transform");
  packet.style.offsetPath = 'path("' + path.getAttribute("d") + '")';
  packet.style.offsetDistance = "88%";
  if (!reduced.matches) {
    const duration = parseFloat(getComputedStyle(packet).getPropertyValue("--travel"));
    travel = packet.animate({ offsetDistance: ["8%", "88%"] }, { duration, easing: "ease-in-out" });
  }
}


function pause() {
  clearInterval(timer);
  timer = null;
  play.textContent = "Play demo";
}

function show(index) {
  current = index;
  const step = steps[index];
  document.querySelector("#phase").textContent = "Step " + (index + 1) + " of " + steps.length;
  document.querySelector("#step-title").textContent = step.title;
  document.querySelector("#describe").textContent = step.description;
  document.querySelector("#queue").textContent = step.queue;
  document.querySelector("#actual").textContent = step.actual;
  buttons.forEach((button, i) => {
    if (i === index) button.setAttribute("aria-current", "step");
    else button.removeAttribute("aria-current");
  });
  document.querySelectorAll("[data-node]").forEach((node) => {
    node.classList.toggle("live", step.nodes.includes(node.dataset.node));
  });
  tracks.forEach((edge) => {
    edge.classList.toggle("live", step.edges.includes(Number(edge.dataset.edge)));
  });
  movePacket(tracks[step.edges.at(-1)]);
  advance.textContent = index === steps.length - 1 ? "Start over" : "Next step";
  reset.disabled = index === 0 && timer === null;
}

function go(index) {
  pause();
  show(index);
}

buttons.forEach((button, index) => button.addEventListener("click", () => go(index)));
advance.addEventListener("click", () => go((current + 1) % steps.length));
reset.addEventListener("click", () => go(0));
play.addEventListener("click", () => {
  if (timer !== null) {
    go(current);
    return;
  }
  play.textContent = "Pause";
  timer = setInterval(() => {
    const next = current + 1;
    if (next === steps.length - 1) pause();
    show(next);
  }, 3200);
  show(current === steps.length - 1 ? 0 : current);
});
advance.disabled = false;
play.disabled = false;
document.addEventListener("visibilitychange", () => {
  if (document.hidden && timer !== null) go(current);
});
show(0);
