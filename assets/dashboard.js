const data = window.INDIA_TRIALS_DATA;
const trials = data.trials || [];
const sites = data.sites || [];
const contacts = data.contacts || [];
const colors = ["#0b0d10", "#a36b16", "#225f7f", "#86a83e", "#9c3f32", "#6e5b8d", "#41766a", "#b78c47", "#5f6872", "#c4562e", "#2d4858", "#7f8d52"];

const pageSize = 25;
let filteredTrials = trials.slice();
let page = 1;

const els = {
  sourceStrip: document.getElementById("sourceStrip"),
  heroTrials: document.getElementById("heroTrials"),
  heroSites: document.getElementById("heroSites"),
  heroContacts: document.getElementById("heroContacts"),
  kpis: document.getElementById("kpis"),
  insights: document.getElementById("insights"),
  activeFilters: document.getElementById("activeFilters"),
  search: document.getElementById("searchInput"),
  area: document.getElementById("areaFilter"),
  phase: document.getElementById("phaseFilter"),
  status: document.getElementById("statusFilter"),
  state: document.getElementById("stateFilter"),
  sponsorClass: document.getElementById("sponsorClassFilter"),
  contactForm: document.getElementById("contactForm"),
  contactStatus: document.getElementById("contactStatus"),
  reset: document.getElementById("resetFilters"),
  rows: document.getElementById("trialRows"),
  resultCount: document.getElementById("resultCount"),
  pageLabel: document.getElementById("pageLabel"),
  prev: document.getElementById("prevPage"),
  next: document.getElementById("nextPage"),
  drawer: document.getElementById("drawer"),
  drawerContent: document.getElementById("drawerContent")
};

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function formatNumber(value) {
  return Number(value || 0).toLocaleString("en-IN");
}

function pct(count, total) {
  return total ? `${((count / total) * 100).toFixed(1)}%` : "0%";
}

function unique(values) {
  return [...new Set(values.filter(Boolean))].sort((a, b) => a.localeCompare(b));
}

function notProvided(value) {
  if (Array.isArray(value)) return value.length ? value.join("; ") : "Not Provided";
  return value || "Not Provided";
}

function buildSearchIndex(trial) {
  const siteText = (trial.indiaLocations || []).map(site => [
    site.facility, site.city, site.state,
    ...(site.contacts || []).flatMap(contact => [contact.name, contact.role, contact.phone, contact.email])
  ].join(" ")).join(" ");
  const contactText = (trial.centralContacts || []).map(contact => [contact.name, contact.role, contact.phone, contact.email].join(" ")).join(" ");
  return [
    trial.nctId, trial.briefTitle, trial.officialTitle, trial.leadSponsor, trial.leadSponsorClass,
    trial.therapeuticArea, trial.phase, trial.overallStatus, trial.primaryPurpose,
    ...(trial.conditions || []), ...(trial.keywords || []), ...(trial.interventionNames || []),
    ...(trial.indiaStates || []), ...(trial.indiaCities || []), siteText, contactText
  ].join(" ").toLowerCase();
}

for (const trial of trials) {
  trial._search = buildSearchIndex(trial);
}

function countBy(items, getter) {
  const map = new Map();
  for (const item of items) {
    const key = getter(item) || "Not Provided";
    map.set(key, (map.get(key) || 0) + 1);
  }
  return [...map.entries()]
    .map(([label, count]) => ({ label, count }))
    .sort((a, b) => b.count - a.count || a.label.localeCompare(b.label));
}

function countMulti(items, getter) {
  const map = new Map();
  for (const item of items) {
    const values = getter(item);
    if (!values || !values.length) {
      map.set("Not Provided", (map.get("Not Provided") || 0) + 1);
      continue;
    }
    for (const value of values) {
      const key = value || "Not Provided";
      map.set(key, (map.get(key) || 0) + 1);
    }
  }
  return [...map.entries()]
    .map(([label, count]) => ({ label, count }))
    .sort((a, b) => b.count - a.count || a.label.localeCompare(b.label));
}

function filteredSites(items) {
  const ids = new Set(items.map(trial => trial.nctId));
  return sites.filter(site => ids.has(site.nctId));
}

function filteredContacts(items) {
  const ids = new Set(items.map(trial => trial.nctId));
  return contacts.filter(contact => ids.has(contact.nctId));
}

function countLocations(items, field) {
  const rows = filteredSites(items);
  const map = new Map();
  for (const site of rows) {
    const key = site[field] || "Not Provided";
    if (!map.has(key)) {
      map.set(key, { label: key, siteCount: 0, trialIds: new Set(), contactCount: 0 });
    }
    const row = map.get(key);
    row.siteCount += 1;
    row.trialIds.add(site.nctId);
    row.contactCount += Number(site.contactCount || 0);
  }
  return [...map.values()]
    .map(row => ({
      label: row.label,
      siteCount: row.siteCount,
      trialCount: row.trialIds.size,
      contactCount: row.contactCount
    }))
    .sort((a, b) => b.trialCount - a.trialCount || b.siteCount - a.siteCount || a.label.localeCompare(b.label));
}

function setOptions(select, values, label = "All") {
  select.innerHTML = [`<option value="">${label}</option>`]
    .concat(values.map(value => `<option value="${escapeHtml(value)}">${escapeHtml(value)}</option>`))
    .join("");
}

function init() {
  setOptions(els.area, unique(trials.map(t => t.therapeuticArea)));
  setOptions(els.phase, unique(trials.map(t => t.phase)));
  setOptions(els.status, unique(trials.map(t => t.overallStatus)));
  setOptions(els.state, unique(sites.map(s => s.state)));
  setOptions(els.sponsorClass, unique(trials.map(t => t.leadSponsorClass)));

  const summary = data.summary || {};
  els.heroTrials.textContent = formatNumber(summary.totalIndiaTrials || trials.length);
  els.heroSites.textContent = formatNumber(summary.indiaSiteCount || sites.length);
  els.heroContacts.textContent = formatNumber(summary.contactRecordCount || contacts.length);
  renderSourceStrip();
  bindEvents();
  applyFilters();
}

function renderSourceStrip() {
  const method = data.methodology || {};
  const summary = data.summary || {};
  els.sourceStrip.innerHTML = `
    <strong>Audit trail</strong><br>
    Supplied JSON only. Generated ${escapeHtml(summary.generatedAt || "Not Provided")}.<br>
    SHA-256 ${escapeHtml(summary.sourceSha256 || "Not Provided")}.<br>
    ${escapeHtml(method.scope || "")}
  `;
}

function currentFilterValues() {
  return {
    query: els.search.value.trim().toLowerCase(),
    area: els.area.value,
    phase: els.phase.value,
    status: els.status.value,
    state: els.state.value,
    sponsorClass: els.sponsorClass.value
  };
}

function applyFilters() {
  const f = currentFilterValues();
  filteredTrials = trials.filter(trial => {
    if (f.query && !trial._search.includes(f.query)) return false;
    if (f.area && trial.therapeuticArea !== f.area) return false;
    if (f.phase && trial.phase !== f.phase) return false;
    if (f.status && trial.overallStatus !== f.status) return false;
    if (f.sponsorClass && trial.leadSponsorClass !== f.sponsorClass) return false;
    if (f.state && !(trial.indiaStates || []).includes(f.state)) return false;
    return true;
  }).sort((a, b) =>
    a.therapeuticArea.localeCompare(b.therapeuticArea) ||
    a.phase.localeCompare(b.phase) ||
    a.briefTitle.localeCompare(b.briefTitle)
  );
  page = 1;
  renderAll();
}

function setFilter(filterName, value) {
  const map = {
    area: els.area,
    phase: els.phase,
    status: els.status,
    state: els.state,
    sponsorClass: els.sponsorClass
  };
  if (!map[filterName]) return;
  map[filterName].value = map[filterName].value === value ? "" : value;
  applyFilters();
}

function renderActiveFilters() {
  const chips = [
    ["search", els.search.value.trim()],
    ["area", els.area.value],
    ["phase", els.phase.value],
    ["status", els.status.value],
    ["state", els.state.value],
    ["sponsorClass", els.sponsorClass.value]
  ].filter(([, value]) => value);

  els.activeFilters.innerHTML = chips.length
    ? chips.map(([key, value]) => `<span class="filter-chip">${escapeHtml(value)} <button type="button" data-clear="${key}" aria-label="Clear ${escapeHtml(value)}">x</button></span>`).join("")
    : `<span class="filter-chip">No active slicers</span>`;
}

function renderKpis(items) {
  const itemSites = filteredSites(items);
  const itemContacts = filteredContacts(items);
  const kpis = [
    [items.length, "filtered active trials"],
    [items.filter(t => t.overallStatus === "RECRUITING").length, "recruiting"],
    [items.filter(t => t.overallStatus === "NOT_YET_RECRUITING").length, "not yet recruiting"],
    [itemSites.length, "India site records"],
    [unique(itemSites.map(site => site.city)).length, "cities represented"],
    [itemContacts.filter(contact => contact.email).length, "email contact records"]
  ];
  els.kpis.innerHTML = kpis.map(([value, label]) => `
    <div class="kpi"><b>${formatNumber(value)}</b><span>${escapeHtml(label)}</span></div>
  `).join("");
}

function renderInsights(items) {
  const area = countBy(items, t => t.therapeuticArea)[0];
  const phase = countBy(items, t => t.phase)[0];
  const state = countLocations(items, "state")[0];
  const sponsor = countBy(items, t => t.leadSponsorClass)[0];
  const email = items.filter(t => t.hasContactEmail).length;
  const insights = [
    area && `<strong>${escapeHtml(area.label)}</strong> leads the therapeutic mix with ${formatNumber(area.count)} trials (${pct(area.count, items.length)}).`,
    phase && `<strong>${escapeHtml(phase.label)}</strong> is the largest phase grouping with ${formatNumber(phase.count)} trials.`,
    state && `<strong>${escapeHtml(state.label)}</strong> is the largest state/region field by unique trial footprint (${formatNumber(state.trialCount)} trials).`,
    sponsor && `<strong>${escapeHtml(sponsor.label)}</strong> is the dominant sponsor class in this view (${formatNumber(sponsor.count)} trials).`,
    `${formatNumber(email)} of ${formatNumber(items.length)} filtered trials include at least one email contact.`
  ].filter(Boolean);
  els.insights.innerHTML = insights.map(text => `<div class="insight">${text}</div>`).join("");
}

function polarToCartesian(cx, cy, r, angle) {
  const radians = (angle - 90) * Math.PI / 180;
  return { x: cx + r * Math.cos(radians), y: cy + r * Math.sin(radians) };
}

function arcPath(cx, cy, r, startAngle, endAngle) {
  const start = polarToCartesian(cx, cy, r, endAngle);
  const end = polarToCartesian(cx, cy, r, startAngle);
  const largeArc = endAngle - startAngle <= 180 ? "0" : "1";
  return [`M ${cx} ${cy}`, `L ${start.x} ${start.y}`, `A ${r} ${r} 0 ${largeArc} 0 ${end.x} ${end.y}`, "Z"].join(" ");
}

function renderPie(svgId, legendId, rows, totalLabelId, filterName, limit = 9) {
  const svg = document.getElementById(svgId);
  const legend = document.getElementById(legendId);
  const totalLabel = document.getElementById(totalLabelId);
  if (!svg || !legend || !totalLabel) return;

  const total = rows.reduce((sum, row) => sum + row.count, 0);
  totalLabel.textContent = `${formatNumber(total)} trials`;
  const topRows = rows.slice(0, limit);
  const remaining = rows.slice(limit).reduce((sum, row) => sum + row.count, 0);
  const chartRows = remaining > 0 ? topRows.concat([{ label: "Other visible categories", count: remaining, noFilter: true }]) : topRows;
  svg.innerHTML = "";
  if (!total) {
    legend.innerHTML = "";
    return;
  }
  let angle = 0;
  svg.innerHTML = chartRows.map((row, index) => {
    const next = angle + (row.count / total) * 360;
    const fill = colors[index % colors.length];
    const shape = chartRows.length === 1
      ? `<circle cx="110" cy="110" r="96" fill="${fill}" data-filter="${filterName}" data-value="${escapeHtml(row.label)}"></circle>`
      : `<path d="${arcPath(110, 110, 96, angle, next)}" fill="${fill}" data-filter="${filterName}" data-value="${escapeHtml(row.label)}"><title>${escapeHtml(row.label)}: ${formatNumber(row.count)}</title></path>`;
    angle = next;
    return row.noFilter ? shape.replace(/data-filter="[^"]+" data-value="[^"]+"/, "") : shape;
  }).join("") + `<circle cx="110" cy="110" r="54" fill="#fff"></circle><text x="110" y="104" text-anchor="middle" font-size="20" font-weight="800" fill="#0b0d10">${formatNumber(total)}</text><text x="110" y="124" text-anchor="middle" font-size="11" fill="#626a73">trials</text>`;

  legend.innerHTML = chartRows.map((row, index) => `
    <div class="legend-row" ${row.noFilter ? "" : `data-filter="${filterName}" data-value="${escapeHtml(row.label)}"`}>
      <i style="background:${colors[index % colors.length]}"></i>
      <strong title="${escapeHtml(row.label)}">${escapeHtml(row.label)}</strong>
      <span>${formatNumber(row.count)}</span>
    </div>
  `).join("");
}

function renderBars(id, rows, valueKey = "count", limit = 12, filterName = "") {
  const el = document.getElementById(id);
  if (!el) return;
  const visible = rows.slice(0, limit);
  const max = Math.max(1, ...visible.map(row => Number(row[valueKey] || 0)));
  el.innerHTML = visible.map(row => {
    const value = Number(row[valueKey] || 0);
    const width = Math.max(3, (value / max) * 100);
    const sub = row.siteCount !== undefined ? `${formatNumber(row.siteCount)} sites | ${formatNumber(row.contactCount || 0)} contacts` : `${formatNumber(value)} trials`;
    return `
      <div class="bar-row" ${filterName ? `data-filter="${filterName}" data-value="${escapeHtml(row.label)}"` : ""}>
        <div><strong title="${escapeHtml(row.label)}">${escapeHtml(row.label)}</strong><span>${formatNumber(value)}</span></div>
        <div class="bar-track"><i class="bar-fill" style="width:${width}%"></i></div>
        <div><span>${escapeHtml(sub)}</span></div>
      </div>
    `;
  }).join("");
}

function renderCharts(items) {
  const skipJunk = (rows) => rows.filter(r => {
    const label = (r.label || "").toLowerCase();
    return !label.includes("not applicable") && !label.includes("not provided") && label !== "na" && label !== "n/a";
  });

  renderPie("areaPie", "areaLegend", skipJunk(countBy(items, t => t.therapeuticArea)), "areaChartTotal", "area", 9);
  renderPie("phasePie", "phaseLegend", skipJunk(countBy(items, t => t.phase)), "phaseChartTotal", "phase", 8);
  renderPie("statusPie", "statusLegend", skipJunk(countBy(items, t => t.overallStatus)), "statusChartTotal", "status", 6);
  renderPie("sponsorPie", "sponsorLegend", skipJunk(countBy(items, t => t.leadSponsorClass)), "sponsorChartTotal", "sponsorClass", 6);
  renderBars("stateBars", skipJunk(countLocations(items, "state")), "trialCount", 14, "state");
  renderBars("cityBars", skipJunk(countLocations(items, "city")), "trialCount", 14, "");
  renderBars("interventionBars", skipJunk(countMulti(items, t => t.interventionTypes)), "count", 14, "");
  renderBars("sponsorBars", skipJunk(countBy(items, t => t.leadSponsor)), "count", 14, "");
  renderContactBars(items);
  renderMatrix(items);
}

function renderContactBars(items) {
  const readiness = [
    { label: "Trials with email", count: items.filter(t => t.hasContactEmail).length },
    { label: "Trials with phone", count: items.filter(t => t.hasContactPhone).length },
    { label: "Trials with any contact", count: items.filter(t => t.hasAnyContact).length },
    { label: "Trials missing contact", count: items.filter(t => !t.hasAnyContact).length }
  ];
  renderBars("contactBars", readiness, "count", 6, "");
  renderBars("contactCityBars", countLocations(items, "city"), "contactCount", 14, "");
}

function renderMatrix(items) {
  const el = document.getElementById("phaseMatrix");
  if (!el) return;
  const skipJunk = (label) => {
    const l = (label || "").toLowerCase();
    return !l.includes("not applicable") && !l.includes("not provided") && l !== "na" && l !== "n/a";
  };
  const areas = countBy(items, t => t.therapeuticArea).filter(row => skipJunk(row.label)).slice(0, 16).map(row => row.label);
  const phases = unique(items.map(t => t.phase)).filter(skipJunk);
  const max = Math.max(1, ...areas.flatMap(area => phases.map(phase => items.filter(t => t.therapeuticArea === area && t.phase === phase).length)));
  el.innerHTML = `
    <table class="matrix">
      <thead><tr><th>Therapeutic Area</th>${phases.map(phase => `<th>${escapeHtml(phase)}</th>`).join("")}</tr></thead>
      <tbody>
        ${areas.map(area => `
          <tr>
            <td>${escapeHtml(area)}</td>
            ${phases.map(phase => {
              const value = items.filter(t => t.therapeuticArea === area && t.phase === phase).length;
              const intensity = value ? Math.max(0.12, value / max).toFixed(2) : "0";
              return `<td class="matrix-cell" style="--intensity:${intensity}" data-filter="area" data-value="${escapeHtml(area)}">${value ? formatNumber(value) : ""}</td>`;
            }).join("")}
          </tr>
        `).join("")}
      </tbody>
    </table>
  `;
}

function contactPill(trial) {
  if (trial.hasContactEmail) return `<span class="pill good">Email</span>`;
  if (trial.hasContactPhone) return `<span class="pill good">Phone</span>`;
  if (trial.hasAnyContact) return `<span class="pill warn">Listed</span>`;
  return `<span class="pill">Not Provided</span>`;
}

function renderTable() {
  const totalPages = Math.max(1, Math.ceil(filteredTrials.length / pageSize));
  page = Math.min(page, totalPages);
  const start = (page - 1) * pageSize;
  const rows = filteredTrials.slice(start, start + pageSize);
  els.resultCount.textContent = `${formatNumber(filteredTrials.length)} matching trials`;
  els.pageLabel.textContent = `Page ${page} of ${totalPages}`;
  els.prev.disabled = page <= 1;
  els.next.disabled = page >= totalPages;
  els.rows.innerHTML = rows.map(trial => `
    <tr>
      <td><button class="details-btn" data-nct="${escapeHtml(trial.nctId)}">${escapeHtml(trial.nctId)}</button></td>
      <td class="trial-title">
        <span class="row-title">${escapeHtml(trial.briefTitle)}</span>
        <span class="row-sub">${escapeHtml((trial.conditions || []).slice(0, 3).join("; ") || "Conditions not provided")}</span>
      </td>
      <td>${escapeHtml(trial.therapeuticArea)}<br><span class="row-sub">Basis: ${escapeHtml(trial.therapeuticAreaBasis)}</span></td>
      <td><span class="pill">${escapeHtml(trial.phase)}</span></td>
      <td>${escapeHtml(trial.overallStatus)}</td>
      <td>${escapeHtml(trial.leadSponsor || "Not Provided")}<br><span class="row-sub">${escapeHtml(trial.leadSponsorClass || "")}</span></td>
      <td>${formatNumber(trial.indiaSiteCount)}<br><span class="row-sub">${escapeHtml((trial.indiaCities || []).slice(0, 3).join(", ") || "Cities not provided")}</span></td>
      <td>${contactPill(trial)}</td>
    </tr>
  `).join("");
}

function renderAll() {
  renderActiveFilters();
  renderKpis(filteredTrials);
  renderInsights(filteredTrials);
  renderCharts(filteredTrials);
  renderTable();
}

function renderContact(contact) {
  const bits = [
    contact.name ? `<strong>${escapeHtml(contact.name)}</strong>` : "",
    contact.role ? `Role: ${escapeHtml(contact.role)}` : "",
    contact.phone ? `Phone: <a href="tel:${escapeHtml(contact.phone)}">${escapeHtml(contact.phone)}</a>` : "",
    contact.email ? `Email: <a href="mailto:${escapeHtml(contact.email)}">${escapeHtml(contact.email)}</a>` : ""
  ].filter(Boolean);
  return bits.join("; ") || "Not Provided";
}

function openDrawer(nctId) {
  const trial = trials.find(item => item.nctId === nctId);
  if (!trial) return;
  const central = (trial.centralContacts || []).map(renderContact);
  const officials = (trial.overallOfficials || []).map(official =>
    [official.name, official.role, official.affiliation].filter(Boolean).map(escapeHtml).join("; ")
  );
  const sitesHtml = (trial.indiaLocations || []).length
    ? `<div class="table-scroll"><table><thead><tr><th>Facility</th><th>City</th><th>State/Region</th><th>Status</th><th>Contacts</th></tr></thead><tbody>${
      trial.indiaLocations.map(site => `
        <tr>
          <td>${escapeHtml(site.facility || "Not Provided")}</td>
          <td>${escapeHtml(site.city || "Not Provided")}</td>
          <td>${escapeHtml(site.state || "Not Provided")}</td>
          <td>${escapeHtml(site.status || "Not Provided")}</td>
          <td>${(site.contacts || []).map(renderContact).join("<br>") || "Not Provided"}</td>
        </tr>
      `).join("")
    }</tbody></table></div>`
    : "<p>India site details not provided.</p>";

  els.drawerContent.innerHTML = `
    <p class="eyebrow">${escapeHtml(trial.nctId)} | ${escapeHtml(trial.overallStatus)}</p>
    <h2>${escapeHtml(trial.briefTitle)}</h2>
    <p><a href="${escapeHtml(trial.trialUrl)}" target="_blank" rel="noreferrer">Open on ClinicalTrials.gov</a></p>
    <div class="meta-grid">
      <div class="meta"><strong>Therapeutic area</strong>${escapeHtml(trial.therapeuticArea)}<br><span class="row-sub">Basis: ${escapeHtml(trial.therapeuticAreaBasis)}</span></div>
      <div class="meta"><strong>Phase</strong>${escapeHtml(trial.phase)} | ${escapeHtml(trial.phaseBucket)}</div>
      <div class="meta"><strong>Lead sponsor</strong>${escapeHtml(trial.leadSponsor || "Not Provided")}<br><span class="row-sub">${escapeHtml(trial.leadSponsorClass || "")}</span></div>
      <div class="meta"><strong>India footprint</strong>${formatNumber(trial.indiaSiteCount)} sites | ${escapeHtml((trial.indiaCities || []).join(", ") || "Cities not provided")}</div>
      <div class="meta"><strong>Enrollment</strong>${escapeHtml(trial.enrollmentCount ?? "Not Provided")} ${escapeHtml(trial.enrollmentType || "")}</div>
      <div class="meta"><strong>Dates</strong>Start: ${escapeHtml(trial.startDate || "Not Provided")}<br>Completion: ${escapeHtml(trial.completionDate || "Not Provided")}</div>
    </div>
    <section class="drawer-section"><h3>Official Title</h3><p>${escapeHtml(trial.officialTitle || "Not Provided")}</p></section>
    <section class="drawer-section"><h3>Conditions and Interventions</h3><ul class="compact-list">
      <li><strong>Conditions:</strong> ${escapeHtml(notProvided(trial.conditions))}</li>
      <li><strong>Intervention types:</strong> ${escapeHtml(notProvided(trial.interventionTypes))}</li>
      <li><strong>Interventions:</strong> ${escapeHtml(notProvided(trial.interventionNames))}</li>
    </ul></section>
    <section class="drawer-section"><h3>Design</h3><ul class="compact-list">
      <li><strong>Study type:</strong> ${escapeHtml(trial.studyType || "Not Provided")}</li>
      <li><strong>Purpose:</strong> ${escapeHtml(trial.primaryPurpose || "Not Provided")}</li>
      <li><strong>Allocation / model / masking:</strong> ${escapeHtml([trial.allocation, trial.interventionModel, trial.masking].filter(Boolean).join(" / ") || "Not Provided")}</li>
      <li><strong>Eligibility:</strong> Sex ${escapeHtml(trial.sex || "Not Provided")}; age ${escapeHtml(trial.minimumAge || "Not Provided")} to ${escapeHtml(trial.maximumAge || "Not Provided")}; healthy volunteers ${escapeHtml(String(trial.healthyVolunteers ?? "Not Provided"))}</li>
    </ul></section>
    <section class="drawer-section"><h3>Summary</h3><p>${escapeHtml(trial.briefSummary || "Not Provided")}</p></section>
    <section class="drawer-section"><h3>Primary Outcomes</h3><ul class="compact-list">${(trial.primaryOutcomes || []).map(outcome => `<li><strong>${escapeHtml(outcome.measure || "Not Provided")}</strong><br>${escapeHtml(outcome.timeFrame || "")}</li>`).join("") || "<li>Not Provided</li>"}</ul></section>
    <section class="drawer-section"><h3>Central Contacts</h3><ul class="compact-list">${central.map(item => `<li>${item}</li>`).join("") || "<li>Not Provided</li>"}</ul></section>
    <section class="drawer-section"><h3>Overall Officials</h3><ul class="compact-list">${officials.map(item => `<li>${item}</li>`).join("") || "<li>Not Provided</li>"}</ul></section>
    <section class="drawer-section"><h3>India Sites and Contacts</h3>${sitesHtml}</section>
  `;
  els.drawer.classList.add("open");
  els.drawer.setAttribute("aria-hidden", "false");
}

function closeDrawer() {
  els.drawer.classList.remove("open");
  els.drawer.setAttribute("aria-hidden", "true");
}

function bindEvents() {
  for (const input of [els.search, els.area, els.phase, els.status, els.state, els.sponsorClass]) {
    input.addEventListener("input", applyFilters);
  }
  els.reset.addEventListener("click", () => {
    els.search.value = "";
    els.area.value = "";
    els.phase.value = "";
    els.status.value = "";
    els.state.value = "";
    els.sponsorClass.value = "";
    applyFilters();
  });
  els.prev.addEventListener("click", () => {
    page = Math.max(1, page - 1);
    renderTable();
  });
  els.next.addEventListener("click", () => {
    page += 1;
    renderTable();
  });
  document.addEventListener("click", event => {
    const tab = event.target.closest("[data-view]");
    if (tab) {
      const view = tab.dataset.view;
      document.querySelectorAll(".tab").forEach(item => item.classList.toggle("active", item === tab));
      document.querySelectorAll("[data-view-panel]").forEach(panel => panel.classList.toggle("active", panel.dataset.viewPanel === view));
    }
    const filterTarget = event.target.closest("[data-filter][data-value]");
    if (filterTarget) setFilter(filterTarget.dataset.filter, filterTarget.dataset.value);
    const clear = event.target.closest("[data-clear]");
    if (clear) {
      const key = clear.dataset.clear;
      if (key === "search") els.search.value = "";
      if (key === "area") els.area.value = "";
      if (key === "phase") els.phase.value = "";
      if (key === "status") els.status.value = "";
      if (key === "state") els.state.value = "";
      if (key === "sponsorClass") els.sponsorClass.value = "";
      applyFilters();
    }
    const details = event.target.closest("[data-nct]");
    if (details) openDrawer(details.dataset.nct);
    if (event.target.closest("[data-close]")) closeDrawer();
  });
  document.addEventListener("keydown", event => {
    if (event.key === "Escape") closeDrawer();
  });
  if (els.contactForm) {
    els.contactForm.addEventListener("submit", submitContactForm);
  }
}

init();

async function submitContactForm(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const button = form.querySelector("button[type='submit']");
  const payload = Object.fromEntries(new FormData(form).entries());
  els.contactStatus.textContent = "Sending inquiry...";
  button.disabled = true;
  try {
    const response = await fetch("/api/contact", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
    const result = await response.json();
    if (!response.ok || !result.ok) {
      throw new Error(result.error || "Unable to submit inquiry.");
    }
    form.reset();
    els.contactStatus.textContent = result.emailed
      ? "Inquiry sent. We will follow up shortly."
      : "Inquiry saved locally. Add email credentials on the server to enable direct email delivery.";
  } catch (error) {
    els.contactStatus.textContent = error.message || "Unable to submit inquiry. Please try again.";
  } finally {
    button.disabled = false;
  }
}
