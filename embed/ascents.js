const site = new URL("../", location.href);
const repo = "https://github.com/nextdoc/fflib-apex-common";
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const link = (href, text) => `<a href="${esc(href)}" target="_blank" rel="noopener">${text}</a>`;
const gainPct = (a) => (a.best.overall - a.baseline.overall) / a.baseline.overall * 100;
const rows = (list) => {
  const maxGain = Math.max(...list.map(gainPct));
  return list.length === 0 ? '<tr><td colspan="7" class="muted">None yet.</td></tr>' : list.map((a) => `
    <tr>
      <td>${esc(a.name)}<br><span class="muted">${esc(a.startedAt.slice(0, 10))}</span></td>
      <td>${a.app.map((p) => esc(p.split("/").pop().replace(/\.cls$/, ""))).join("<br>")}</td>
      <td class="num">${a.iterations} (${a.kept} kept)</td>
      <td class="num">${a.baseline.overall.toFixed(1)}</td>
      <td class="num gain"><div class="gain-bar" style="width: ${gainPct(a) / maxGain * 100}%">+${gainPct(a).toFixed(1)}%</div></td>
      <td class="num up">${a.best.overall.toFixed(1)}</td>
      <td>${link(new URL(a.report, site), "Report")} · ${link(`${repo}/tree/${a.branch}`, "Branch")}${a.retro ? ` · ${link(new URL(a.retro, site), "Retro JSON")}` : ""}</td>
    </tr>`).join("");
};
const styled = (a) => (a.excludedPmdRules ?? []).length > 0;
const sum = (list, f) => list.reduce((n, a) => n + f(a), 0);
const summary = (list) => {
  const mean = (f) => (sum(list, f) / list.length).toFixed(1);
  const stat = (value, label) => `<span class="stat"><span class="stat-value">${value}</span><span class="stat-label">${label}</span></span>`;
  return `<span class="stats">${stat(list.length, "ascents")}${stat(sum(list, (a) => a.iterations), "iterations")}${stat(sum(list, (a) => a.kept), "kept")}${stat(`${mean((a) => a.baseline.overall)} → ${mean((a) => a.best.overall)}`, "average score")}</span>`;
};
const groupNames = { "application": "Application factories", "objects": "Objects", "sobjects": "SObjects", "sobject-domain": "SObject domain", "sobject-selector": "SObject selector", "unit-of-work": "Unit of work", "query-factory": "Query factory", "sobject-describe": "SObject describe", "security-utils": "Security utils", "string-builder": "String builder" };
const groupName = (a) => groupNames[a.name.replace(/-(style-)?\d+$/, "")] ?? a.name;
const chart = (list) => {
  const sorted = [...list].sort((x, y) => gainPct(y) - gainPct(x));
  const cells = sorted.map((a, i) => `
    <div class="chart-row" data-i="${i}">
      <div class="chart-name" data-i="${i}">${esc(groupName(a))}</div>
      <div class="chart-track" data-i="${i}"><div class="seg-base" style="width: ${a.baseline.overall}%"></div><div class="seg-gain" style="width: ${a.best.overall - a.baseline.overall}%"></div></div>
    </div>`).join("");
  return { sorted, html: `<div class="chart-legend"><span style="--swatch: var(--base)">Start score</span><span style="--swatch: var(--gain)">Gain</span></div>
    <div class="chart-grid">${cells}<div class="chart-axis"><span>0</span><span class="minor">25</span><span>50</span><span class="minor">75</span><span>100</span></div></div>` };
};
const wireChart = (el, sorted) => {
  const tip = document.getElementById("tip");
  const hide = () => { tip.hidden = true; el.querySelector(".active")?.classList.remove("active"); };
  el.addEventListener("pointermove", (e) => {
    const i = e.target.closest("[data-i]")?.dataset.i;
    if (i === undefined) return hide();
    const a = sorted[i];
    el.querySelector(".active")?.classList.remove("active");
    el.querySelector(`.chart-row[data-i="${i}"]`).classList.add("active");
    tip.innerHTML = `<strong>${esc(groupName(a))}</strong><br>${esc(a.name)}<br>Score ${a.baseline.overall.toFixed(1)} → ${a.best.overall.toFixed(1)} (+${gainPct(a).toFixed(1)}%)<br>${a.iterations} iterations, ${a.kept} kept`;
    tip.hidden = false;
    tip.style.left = Math.max(8, Math.min(e.clientX + 12, innerWidth - tip.offsetWidth - 8)) + "px";
    tip.style.top = Math.max(8, Math.min(e.clientY + 12, innerHeight - tip.offsetHeight - 8)) + "px";
  });
  el.addEventListener("pointerleave", hide);
};
const details = document.querySelector("details.ascents"), chartEl = document.getElementById("chart");
details.addEventListener("toggle", () => { chartEl.hidden = details.open; document.getElementById("tip").hidden = true; });
const wantStyled = document.body.dataset.set === "style";
fetch(new URL("ascents.json", site)).then((r) => r.json()).then((list) => {
  const set = list.filter((a) => styled(a) === wantStyled);
  document.getElementById("rows").innerHTML = rows(set);
  document.getElementById("summary").innerHTML = summary(set);
  const { sorted, html } = chart(set);
  chartEl.innerHTML = html;
  wireChart(chartEl, sorted);
  if (typeof postHeight === "function") postHeight();
}).catch(() => {
  document.getElementById("rows").innerHTML = '<tr><td colspan="7">Could not load ascents.json</td></tr>';
  document.getElementById("summary").textContent = "Could not load ascents.json";
});
