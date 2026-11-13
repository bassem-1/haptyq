let page = #"""
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Haptic Lab</title>
<style>
:root { --bg:#f6f6f4; --card:#fff; --ink:#1c1c1e; --mute:#6b6b70; --line:#e2e2de; --acc:#2f6fed;
        --s0:#c9c9c4; --s1:#9cc3f5; --s2:#5b9bf0; --s3:#2f6fed; --s4:#163f9e; }
@media (prefers-color-scheme: dark) { :root { --bg:#141416; --card:#1d1d20; --ink:#ececee; --mute:#9a9aa2;
        --line:#2e2e33; --acc:#6c9cff; --s0:#3a3a40; --s1:#2b4a7a; --s2:#3c68b4; --s3:#5b8cf0; --s4:#9dbcff; } }
* { box-sizing:border-box; }
body { margin:0; background:var(--bg); color:var(--ink); font:14px/1.45 -apple-system, system-ui, sans-serif; }
main { max-width:980px; margin:0 auto; padding:24px 16px 64px; }
h1 { font-size:20px; margin:0 0 4px; }
h2 { font-size:13px; text-transform:uppercase; letter-spacing:.06em; color:var(--mute); margin:0 0 12px; }
p.sub { color:var(--mute); margin:0 0 20px; }
section { background:var(--card); border:1px solid var(--line); border-radius:12px; padding:16px; margin-bottom:16px; }
.grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(84px, 1fr)); gap:8px; }
button { font:inherit; color:inherit; background:var(--card); border:1px solid var(--line); border-radius:8px;
         padding:10px 8px; cursor:pointer; }
button:hover { border-color:var(--acc); }
button:active { transform:scale(.97); }
.idbtn { display:flex; flex-direction:column; align-items:center; gap:4px; padding:10px 4px 8px; }
.idbtn b { font-size:18px; font-variant-numeric:tabular-nums; }
.idbtn .bar { width:60%; height:4px; border-radius:2px; background:var(--s0); }
.idbtn.flash { border-color:var(--acc); box-shadow:0 0 0 2px var(--acc) inset; }
.controls { display:flex; flex-wrap:wrap; gap:16px; align-items:center; margin-bottom:12px; color:var(--mute); }
.controls label { display:flex; gap:8px; align-items:center; }
.controls input[type=number] { width:70px; }
input, select { font:inherit; color:inherit; background:var(--bg); border:1px solid var(--line); border-radius:6px; padding:4px 6px; }
.rate { display:none; margin-top:12px; padding:12px; border:1px dashed var(--line); border-radius:8px; }
.rate.show { display:block; }
.rate .opts { display:flex; flex-wrap:wrap; gap:6px; margin-top:8px; }
.rate .opts button { padding:6px 10px; }
.pats { display:flex; flex-wrap:wrap; gap:8px; }
.pats button { padding:10px 16px; }
.pats small { color:var(--mute); display:block; font-size:11px; }
table { width:100%; border-collapse:collapse; font-variant-numeric:tabular-nums; }
td, th { text-align:left; padding:6px 8px; border-bottom:1px solid var(--line); }
th { color:var(--mute); font-weight:500; font-size:12px; }
#log { max-height:240px; overflow:auto; font:12px ui-monospace, Menlo, monospace; color:var(--mute); }
.row { display:flex; gap:8px; flex-wrap:wrap; align-items:center; }
.pill { display:inline-block; padding:1px 8px; border-radius:999px; font-size:12px; color:#fff; }
#status { font-size:12px; }
.err { color:#d33; }
#pg { display:flex; gap:16px; flex-wrap:wrap; align-items:stretch; }
#win { position:relative; flex:1; min-width:260px; height:300px; border:1px solid var(--line); border-radius:10px;
       background:var(--bg); overflow:hidden; cursor:default; }
#titlebar { height:28px; display:flex; gap:8px; align-items:center; padding-left:12px; border-bottom:1px solid var(--line); }
.tl { width:12px; height:12px; border-radius:50%; display:inline-block; }
#closeBtn { cursor:pointer; position:relative; z-index:2; }
#ring { position:absolute; border:1px dashed #ff5f57; border-radius:50%; pointer-events:none; opacity:.5; }
#meter { width:180px; display:flex; flex-direction:column; gap:6px; font-variant-numeric:tabular-nums; color:var(--mute); font-size:13px; }
#meter span::before { color:var(--ink); }
#mBar { height:8px; border-radius:4px; background:var(--s0); overflow:hidden; margin-top:6px; }
#mBar i { display:block; height:100%; width:0; background:#ff5f57; transition:width .05s; }
.sliders { display:grid; grid-template-columns:repeat(auto-fill, minmax(260px, 1fr)); gap:8px 20px; margin-top:14px; color:var(--mute); }
.sliders label { display:flex; gap:8px; align-items:center; }
.sliders input[type=range] { flex:1; }
.sliders output { min-width:34px; text-align:right; color:var(--ink); font-variant-numeric:tabular-nums; }
</style>
</head>
<body>
<main>
  <h1>Haptic Lab</h1>
  <p class="sub">Click a button and feel the trackpad. Rate each ID so you can see which ones are worth using. <span id="status"></span></p>

  <section>
    <h2>Raw actuator IDs</h2>
    <div class="controls">
      <label>f1 <input id="f1" type="number" step="0.1" value="0"></label>
      <label>f2 <input id="f2" type="number" step="0.1" value="0"></label>
      <label><input id="askRate" type="checkbox" checked> ask how it felt</label>
      <label>Range <input id="lo" type="number" value="0"> to <input id="hi" type="number" value="20"></label>
      <button id="sweep">Sweep range</button>
    </div>
    <div class="grid" id="ids"></div>
    <div class="rate" id="rate">
      <div>How did <b id="rateId"></b> feel?</div>
      <div class="opts" id="rateOpts"></div>
    </div>
  </section>

  <section>
    <h2>Proximity playground</h2>
    <p style="margin:0 0 12px;color:var(--mute)">Move the cursor toward the red button. Taps get faster and stronger as you get closer, and stop when you stop moving. Changes are saved for <code>haptic-daemon</code>, which picks them up live.</p>
    <div id="pg">
      <div id="win">
        <div id="titlebar"><span class="tl" id="closeBtn" style="background:#ff5f57"></span><span class="tl" style="background:#febc2e"></span><span class="tl" style="background:#28c840"></span></div>
        <div id="ring"></div>
      </div>
      <div id="meter"><span id="mDist">–</span><span id="mRate">–</span><span id="mId">–</span><div id="mBar"><i></i></div></div>
    </div>
    <div class="sliders">
      <label>Radius <input type="range" data-k="radius" min="30" max="400" step="5"><output></output> pt</label>
      <label>Slowest <input type="range" data-k="slowestMs" min="60" max="600" step="5"><output></output> ms</label>
      <label>Fastest <input type="range" data-k="fastestMs" min="10" max="200" step="1"><output></output> ms</label>
      <label>Curve <input type="range" data-k="curve" min="0.3" max="4" step="0.1"><output></output></label>
      <label>Idle cutoff <input type="range" data-k="idleMs" min="50" max="1500" step="25"><output></output> ms</label>
      <label>IDs weak→strong <input type="text" data-k="ids" style="width:120px"></label>
      <label><input type="checkbox" data-k="hoverTick"> tick when entering any button (daemon)</label>
    </div>
  </section>

  <section>
    <h2>Patterns</h2>
    <div class="pats" id="pats"></div>
  </section>

  <section>
    <h2>Build a pattern</h2>
    <div class="row" style="margin-bottom:8px">
      <input id="seq" style="flex:1;min-width:240px" value="6@0, 3@45" title="id@delayMs, comma separated">
      <button id="playSeq">Play</button>
      <button id="copySeq">Copy JSON</button>
    </div>
    <div style="color:var(--mute);font-size:12px">Format: <code>id@delayMs</code>, comma separated. The delay counts from the previous pulse.</div>
  </section>

  <section>
    <h2>Your ratings</h2>
    <table><thead><tr><th>ID</th><th>Feel</th><th>Fires</th><th>Note</th></tr></thead><tbody id="ratings"></tbody></table>
    <div class="row" style="margin-top:12px">
      <button id="export">Copy ratings JSON</button>
      <button id="reset">Clear ratings</button>
    </div>
  </section>

  <section>
    <h2>Log</h2>
    <div id="log"></div>
  </section>
</main>
<script>
const FEELS = ["nothing", "faint", "soft", "medium", "strong"];
const $ = s => document.querySelector(s);
let store = {};
try { store = JSON.parse(localStorage.getItem("hapticRatings") || "{}"); } catch {}
const save = () => { try { localStorage.setItem("hapticRatings", JSON.stringify(store)); } catch {} };
const rec = id => (store[id] ||= { feel: null, fires: 0, note: "" });

function log(msg, cls) {
  const d = document.createElement("div");
  d.textContent = new Date().toLocaleTimeString() + "  " + msg;
  if (cls) d.className = cls;
  $("#log").prepend(d);
}

async function api(path, opts = {}) {
  try {
    const r = await fetch(path, { method: "POST", ...opts });
    const j = await r.json();
    if (!r.ok) throw new Error(j.error || r.status);
    $("#status").textContent = "connected"; $("#status").className = "";
    return j;
  } catch (e) {
    $("#status").textContent = "server not reachable: is haptic-web running?"; $("#status").className = "err";
    log("error: " + e.message, "err");
    return null;
  }
}

let rateTarget = null;
async function fire(id, { ask = true } = {}) {
  const f1 = $("#f1").value || 0, f2 = $("#f2").value || 0;
  const j = await api(`/api/fire?id=${id}&f1=${f1}&f2=${f2}`);
  if (!j) return;
  rec(id).fires++; save(); render();
  const b = document.querySelector(`[data-id="${id}"]`);
  if (b) { b.classList.add("flash"); setTimeout(() => b.classList.remove("flash"), 250); }
  log(`fire id=${id} f1=${f1} f2=${f2}` + (j.fallback ? "  (private API failed, used generic fallback)" : ""));
  if (ask && $("#askRate").checked) { rateTarget = id; $("#rateId").textContent = "ID " + id; $("#rate").classList.add("show"); }
}

function renderIds() {
  const g = $("#ids"); g.innerHTML = "";
  const lo = +$("#lo").value, hi = +$("#hi").value;
  for (let id = lo; id <= hi; id++) {
    const b = document.createElement("button");
    b.className = "idbtn"; b.dataset.id = id;
    b.innerHTML = `<b>${id}</b><span class="bar"></span>`;
    b.onclick = () => fire(id);
    g.append(b);
  }
  render();
}

function render() {
  document.querySelectorAll(".idbtn").forEach(b => {
    const r = store[b.dataset.id];
    const lvl = r && r.feel != null ? r.feel : null;
    b.querySelector(".bar").style.background = lvl == null ? "var(--s0)" : `var(--s${lvl})`;
    b.title = lvl == null ? "not rated" : FEELS[lvl];
  });
  const tb = $("#ratings"); tb.innerHTML = "";
  Object.keys(store).map(Number).sort((a, b) => a - b).forEach(id => {
    const r = store[id];
    const tr = document.createElement("tr");
    const feel = r.feel == null ? "–" : `<span class="pill" style="background:var(--s${r.feel});color:${r.feel>=2?'#fff':'var(--ink)'}">${FEELS[r.feel]}</span>`;
    tr.innerHTML = `<td><button style="padding:2px 10px">${id}</button></td><td>${feel}</td><td>${r.fires}</td><td><input style="width:100%" value=""></td>`;
    tr.querySelector("button").onclick = () => fire(id, { ask: false });
    const inp = tr.querySelector("input"); inp.value = r.note || "";
    inp.onchange = () => { r.note = inp.value; save(); };
    tb.append(tr);
  });
}

FEELS.forEach((f, i) => {
  const b = document.createElement("button"); b.textContent = f;
  b.onclick = () => { if (rateTarget == null) return; rec(rateTarget).feel = i; save(); render();
    log(`rated id=${rateTarget}: ${f}`); $("#rate").classList.remove("show"); rateTarget = null; };
  $("#rateOpts").append(b);
});
const again = document.createElement("button"); again.textContent = "fire again";
again.onclick = () => rateTarget != null && fire(rateTarget);
$("#rateOpts").append(again);

$("#lo").onchange = $("#hi").onchange = renderIds;
let sweeping = false;
$("#sweep").onclick = async () => {
  if (sweeping) { sweeping = false; return; }
  sweeping = true; $("#sweep").textContent = "Stop";
  for (let id = +$("#lo").value; id <= +$("#hi").value && sweeping; id++) {
    await fire(id, { ask: false });
    await new Promise(r => setTimeout(r, 800));
  }
  sweeping = false; $("#sweep").textContent = "Sweep range";
};

async function loadPatterns() {
  try {
    const list = await (await fetch("/api/patterns")).json();
    const box = $("#pats"); box.innerHTML = "";
    list.forEach(p => {
      const b = document.createElement("button");
      b.innerHTML = `${p.name}<small>${p.pulses.map(x => x.id + "@" + x.delayMs).join(", ")}</small>`;
      b.onclick = async () => { if (await api(`/api/play?name=${encodeURIComponent(p.name)}`)) log("play " + p.name); };
      box.append(b);
    });
  } catch { $("#status").textContent = "server not reachable: is haptic-web running?"; $("#status").className = "err"; }
}

function parseSeq() {
  return $("#seq").value.split(",").map(s => s.trim()).filter(Boolean).map(s => {
    const [id, d] = s.split("@");
    return { id: parseInt(id), f1: +$("#f1").value || 0, f2: +$("#f2").value || 0, delayMs: parseInt(d || "0") };
  }).filter(p => !isNaN(p.id) && !isNaN(p.delayMs));
}
$("#playSeq").onclick = async () => {
  const pulses = parseSeq(); if (!pulses.length) return;
  if (await api("/api/play", { body: JSON.stringify({ name: "custom", pulses }) })) log("play custom " + $("#seq").value);
};
$("#copySeq").onclick = () => {
  const json = JSON.stringify({ name: "custom", pulses: parseSeq() });
  navigator.clipboard.writeText(json).then(() => log("copied: " + json));
};
$("#export").onclick = () => navigator.clipboard.writeText(JSON.stringify(store, null, 2)).then(() => log("ratings copied to clipboard"));
$("#reset").onclick = () => { if (confirm("Clear all ratings?")) { store = {}; save(); render(); } };

// --- Proximity playground (the server runs the same engine the daemon uses) ---
let pcfg = null, saveT = null, lastSend = 0;
const closeBtn = $("#closeBtn"), win = $("#win"), ring = $("#ring");

function output(cfg, d) { // display mirror of ProximityEngine.output
  if (d >= cfg.radius || !cfg.ids.length) return null;
  const c = Math.min(1, Math.max(0, 1 - Math.max(0, d) / cfg.radius));
  const interval = cfg.slowestMs - (cfg.slowestMs - cfg.fastestMs) * Math.pow(c, cfg.curve);
  return { c, interval, id: cfg.ids[Math.min(cfg.ids.length - 1, Math.floor(c * cfg.ids.length))] };
}
function drawRing() {
  if (!pcfg) return;
  const w = win.getBoundingClientRect(), b = closeBtn.getBoundingClientRect();
  const cx = b.left - w.left + b.width / 2, cy = b.top - w.top + b.height / 2, r = pcfg.radius + b.width / 2;
  Object.assign(ring.style, { left: cx - r + "px", top: cy - r + "px", width: 2 * r + "px", height: 2 * r + "px" });
}
function showMeter(d) {
  const o = d == null || !pcfg ? null : output(pcfg, d);
  $("#mDist").textContent = d == null ? "distance –" : `distance ${Math.round(d)} pt`;
  $("#mRate").textContent = o ? `every ${Math.round(o.interval)} ms (${(1000 / o.interval).toFixed(1)}/s)` : "silent";
  $("#mId").textContent = o ? `actuator id ${o.id}` : "–";
  $("#mBar i").style.width = o ? (o.c * 100).toFixed(0) + "%" : "0";
}
win.addEventListener("mousemove", e => {
  const b = closeBtn.getBoundingClientRect();
  const d = Math.max(0, Math.hypot(e.clientX - (b.left + b.width / 2), e.clientY - (b.top + b.height / 2)) - b.width / 2);
  showMeter(d);
  const now = performance.now();
  if (now - lastSend < 25) return;
  lastSend = now;
  fetch(`/api/prox?d=${d.toFixed(1)}`, { method: "POST" }).catch(() => {});
});
win.addEventListener("mouseleave", () => { showMeter(null); fetch("/api/prox?d=-1", { method: "POST" }).catch(() => {}); });
closeBtn.onclick = async () => { if (await api("/api/play?name=latch")) log("clicked close: play latch"); };

function bindSliders() {
  document.querySelectorAll(".sliders [data-k]").forEach(el => {
    const k = el.dataset.k, out = el.parentElement.querySelector("output");
    if (el.type === "checkbox") el.checked = !!pcfg[k];
    else el.value = k === "ids" ? pcfg.ids.join(", ") : pcfg[k];
    if (out) out.textContent = el.value;
    el.oninput = () => {
      if (el.type === "checkbox") pcfg[k] = el.checked;
      else if (k === "ids") { const ids = el.value.split(",").map(s => parseInt(s)).filter(n => !isNaN(n)); if (!ids.length) return; pcfg.ids = ids; }
      else pcfg[k] = +el.value;
      if (out) out.textContent = el.value;
      drawRing();
      clearTimeout(saveT);
      saveT = setTimeout(async () => { const j = await api("/api/proximity", { body: JSON.stringify(pcfg) }); if (j) log("proximity settings saved: " + j.path); }, 300);
    };
  });
}
fetch("/api/proximity").then(r => r.json()).then(c => { pcfg = c; bindSliders(); drawRing(); }).catch(() => {});
addEventListener("resize", drawRing);

renderIds(); loadPatterns();
</script>
</body>
</html>
"""#
