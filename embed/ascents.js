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
  return `${list.length} ascents, ${sum(list, (a) => a.iterations)} iterations, ${sum(list, (a) => a.kept)} kept. Average score ${mean((a) => a.baseline.overall)} → ${mean((a) => a.best.overall)}.`;
};
const wantStyled = document.body.dataset.set === "style";
fetch(new URL("ascents.json", site)).then((r) => r.json()).then((list) => {
  const set = list.filter((a) => styled(a) === wantStyled);
  document.getElementById("rows").innerHTML = rows(set);
  document.getElementById("summary").textContent = summary(set);
}).catch(() => {
  document.getElementById("rows").innerHTML = '<tr><td colspan="7">Could not load ascents.json</td></tr>';
  document.getElementById("summary").textContent = "Could not load ascents.json";
});
