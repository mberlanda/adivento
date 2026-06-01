/* ============================================================================
   Adivento Design System — adivento.js
   Zero-dependency vanilla interactions for the static demo and the Rails app.
   Everything is namespaced under window.Adivento and auto-inits on
   [data-adv] attributes, so ERB partials stay declarative.
   ============================================================================ */
(function () {
  "use strict";

  const Adivento = {};

  /* ---- theme ------------------------------------------------------------- */
  const THEME_KEY = "ds-theme";
  function syncThemeControls(name) {
    document.querySelectorAll("[data-ds-theme-toggle]").forEach((el) => {
      el.setAttribute("aria-pressed", String(name === "dark"));
    });
    document.querySelectorAll("[data-ds-theme-label]").forEach((el) => {
      el.textContent = name === "dark" ? "Dark" : "Light";
    });
  }
  Adivento.theme = {
    get() { return document.documentElement.getAttribute("data-theme") || "light"; },
    set(name) {
      const root = document.documentElement;
      root.classList.add("ds-theming");
      root.setAttribute("data-theme", name);
      try { localStorage.setItem(THEME_KEY, name); } catch (e) {}
      syncThemeControls(name);
      window.dispatchEvent(new CustomEvent("ds:theme", { detail: { theme: name } }));
      requestAnimationFrame(() => requestAnimationFrame(() => root.classList.remove("ds-theming")));
    },
    toggle() { this.set(this.get() === "dark" ? "light" : "dark"); },
    init() {
      let saved;
      try { saved = localStorage.getItem(THEME_KEY); } catch (e) {}
      if (saved) {
        this.set(saved);
      } else {
        syncThemeControls(this.get());
      }
      document.addEventListener("click", (e) => {
        const t = e.target.closest("[data-ds-theme-toggle], [data-ds-theme-label]");
        if (t) { e.preventDefault(); this.toggle(); }
      });
    },
  };

  /* ---- segmented controls / tabs ---------------------------------------- */
  // <div class="ds-segment" data-ds-segment>
  //   <button class="ds-segment__item is-active" data-target="#a">A</button> ...
  Adivento.segments = {
    init() {
      document.addEventListener("click", (e) => {
        const item = e.target.closest("[data-ds-segment] .ds-segment__item, [data-ds-tabs] .ds-chip, [data-ds-tabs] [data-tab]");
        if (!item) return;
        const group = item.closest("[data-ds-segment], [data-ds-tabs]");
        group.querySelectorAll(".ds-segment__item, .ds-chip, [data-tab]").forEach((b) => b.classList.remove("is-active"));
        item.classList.add("is-active");
        const sel = item.getAttribute("data-target");
        if (sel) {
          const panel = group.getAttribute("data-ds-tabs");
          const scope = panel ? document.querySelector(panel) || document : document;
          scope.querySelectorAll("[data-panel]").forEach((p) => { p.hidden = ("#" + p.getAttribute("data-panel")) !== sel; });
        }
        group.dispatchEvent(new CustomEvent("ds:segment", { detail: { value: item.textContent.trim(), target: sel } }));
      });
    },
  };

  /* ---- bottom sheet ------------------------------------------------------ */
  Adivento.sheet = {
    open(id) { this._toggle(id, true); },
    close(id) { this._toggle(id, false); },
    _toggle(id, show) {
      const sheet = typeof id === "string" ? document.getElementById(id) : id;
      if (!sheet) return;
      sheet.hidden = !show;
      let scrim = sheet._scrim;
      if (show && !scrim) {
        scrim = document.createElement("div");
        scrim.className = "ds-scrim";
        scrim.addEventListener("click", () => this._toggle(sheet, false));
        document.body.appendChild(scrim);
        sheet._scrim = scrim;
      } else if (!show && scrim) {
        scrim.hidden = true;
        setTimeout(() => { scrim.remove(); sheet._scrim = null; }, 250);
      }
    },
    init() {
      document.addEventListener("click", (e) => {
        const o = e.target.closest("[data-ds-sheet-open]");
        if (o) { e.preventDefault(); this.open(o.getAttribute("data-ds-sheet-open")); }
        const c = e.target.closest("[data-ds-sheet-close]");
        if (c) { e.preventDefault(); const s = c.closest(".ds-sheet"); if (s) this.close(s); }
      });
    },
  };

  /* ---- charts: probability line + sparkline ----------------------------- */
  // Adivento.chart.line(svgEl, [..0-100..]); reads colors from CSS vars.
  function cssVar(el, name, fallback) {
    const v = getComputedStyle(el).getPropertyValue(name).trim();
    return v || fallback;
  }
  Adivento.chart = {
    line(el, points, opts) {
      opts = opts || {};
      const W = 300, H = 120, n = points.length;
      if (n < 2) return;
      const color = opts.color || cssVar(el, "--ds-accent", "#0e7c66");
      const grid = cssVar(el, "--ds-chart-grid", "#e7e3d6");
      const areaOp = cssVar(el, "--ds-chart-area", "0.1");
      const xy = points.map((v, i) => [(i / (n - 1)) * W, H - (Math.max(0, Math.min(100, v)) / 100) * H]);
      const path = xy.map((p) => p.join(",")).join(" ");
      const area = `0,${H} ${path} ${W},${H}`;
      const gl = [25, 50, 75].map((g) => `<line x1="0" x2="${W}" y1="${H - (g / 100) * H}" y2="${H - (g / 100) * H}" stroke="${grid}" stroke-width="1" stroke-dasharray="3 3"/>`).join("");
      const last = xy[xy.length - 1];
      el.setAttribute("viewBox", `0 0 ${W} ${H}`);
      el.setAttribute("preserveAspectRatio", "none");
      el.innerHTML = `${gl}<polygon points="${area}" fill="${color}" opacity="${areaOp}"/>` +
        `<polyline points="${path}" fill="none" stroke="${color}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>` +
        `<circle cx="${last[0]}" cy="${last[1]}" r="3.5" fill="${color}"/>`;
    },
    spark(el, points, opts) {
      opts = opts || {};
      const W = 72, H = 22, n = points.length;
      const color = opts.color || cssVar(el, "--ds-accent", "#0e7c66");
      const path = points.map((v, i) => `${(i / (n - 1)) * W},${H - (v / 100) * H}`).join(" ");
      el.setAttribute("viewBox", `0 0 ${W} ${H}`);
      el.innerHTML = `<polyline points="${path}" fill="none" stroke="${color}" stroke-width="1.5" stroke-linejoin="round"/>`;
      el.style.width = W + "px"; el.style.height = H + "px";
    },
    init() {
      document.querySelectorAll("svg[data-ds-chart]").forEach((el) => {
        const pts = (el.getAttribute("data-ds-chart") || "").split(",").map(Number).filter((x) => !isNaN(x));
        if (pts.length) this.line(el, pts, { color: el.getAttribute("data-color") || undefined });
      });
      document.querySelectorAll("svg[data-ds-spark]").forEach((el) => {
        const pts = (el.getAttribute("data-ds-spark") || "").split(",").map(Number).filter((x) => !isNaN(x));
        if (pts.length) this.spark(el, pts, { color: el.getAttribute("data-color") || undefined });
      });
      window.addEventListener("ds:theme", () => this.init());
    },
  };

  /* ---- order book rendering ---------------------------------------------- */
  // Adivento.orderbook.render(el, {asks:[[px,sz]...], bids:[[px,sz]...], last})
  Adivento.orderbook = {
    render(el, book) {
      const all = book.asks.concat(book.bids).map((r) => r[1]);
      const max = Math.max.apply(null, all) || 1;
      const row = (r, side) => {
        const w = (r[1] / max) * 100;
        return `<div class="ds-orderbook__row ds-orderbook__row--${side}">` +
          `<div class="ds-orderbook__bar" style="width:${w}%"></div>` +
          `<span class="ds-orderbook__px ds-num">${r[0]}¢</span>` +
          `<span class="ds-orderbook__sz ds-num">${r[1]}</span></div>`;
      };
      el.innerHTML =
        book.asks.slice().reverse().map((r) => row(r, "ask")).join("") +
        `<div class="ds-orderbook__spread">spread ${book.spread || "—"}¢ · last ${book.last}¢</div>` +
        book.bids.map((r) => row(r, "bid")).join("");
    },
  };

  /* ---- bet ticket calculator -------------------------------------------- */
  // Wraps a [data-ds-ticket] block. Reads stake input + selected price box,
  // writes payout/profit to [data-ticket-payout]/[data-ticket-profit].
  Adivento.ticket = {
    init() {
      document.querySelectorAll("[data-ds-ticket]").forEach((root) => {
        const stake = root.querySelector("[data-ticket-stake]");
        const recalc = () => {
          const sel = root.querySelector(".ds-pricebox.is-selected") || root.querySelector(".ds-pricebox");
          const price = sel ? parseFloat(sel.getAttribute("data-price")) : NaN;     // cents
          const s = parseFloat(stake && stake.value) || 0;
          const payout = price > 0 ? s * (100 / price) : 0;
          const set = (k, v) => { const n = root.querySelector(k); if (n) n.textContent = v; };
          set("[data-ticket-payout]", Math.round(payout).toLocaleString());
          set("[data-ticket-profit]", "+" + Math.round(payout - s).toLocaleString());
        };
        root.addEventListener("input", recalc);
        root.addEventListener("click", (e) => {
          const box = e.target.closest(".ds-pricebox");
          if (box) {
            root.querySelectorAll(".ds-pricebox").forEach((b) => b.classList.remove("is-selected"));
            box.classList.add("is-selected");
            recalc();
          }
          const quick = e.target.closest("[data-ticket-add]");
          if (quick && stake) { stake.value = quick.getAttribute("data-ticket-add"); recalc(); }
        });
        recalc();
      });
    },
  };

  /* ---- live price tick (demo simulation) -------------------------------- */
  // Adds gentle random walk to [data-ds-live] elements; emits ds:tick.
  // Real app should replace this with the SSE snapshot handler.
  Adivento.live = {
    _timer: null,
    start(intervalMs) {
      this.stop();
      this._timer = setInterval(() => {
        document.querySelectorAll("[data-ds-live]").forEach((el) => {
          let v = parseFloat(el.getAttribute("data-value")) || 50;
          v = Math.max(2, Math.min(98, v + (Math.random() - 0.5) * 3));
          el.setAttribute("data-value", v.toFixed(1));
          const pctEl = el.querySelector("[data-live-pct]") || el;
          if (pctEl.hasAttribute && pctEl.hasAttribute("data-live-pct")) pctEl.textContent = Math.round(v) + "%";
          el.dispatchEvent(new CustomEvent("ds:tick", { bubbles: true, detail: { value: v } }));
        });
      }, intervalMs || 2200);
    },
    stop() { if (this._timer) clearInterval(this._timer); this._timer = null; },
  };

  /* ---- boot -------------------------------------------------------------- */
  Adivento.init = function () {
    Adivento.theme.init();
    Adivento.segments.init();
    Adivento.sheet.init();
    Adivento.chart.init();
    Adivento.ticket.init();
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", Adivento.init);
  else Adivento.init();

  window.Adivento = Adivento;
})();
