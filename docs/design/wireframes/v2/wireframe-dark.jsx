// wireframe-dark.jsx — dark high-contrast scope + alt chrome for PR2.
// Re-skins the WF primitives by overriding their CSS vars inside .wf-dark.
// Exports window.WFD = { Dark, AltBar, AltSidebar, AltTabBar }.
(function () {
  if (typeof document !== 'undefined' && !document.getElementById('wf-dark-styles')) {
    const s = document.createElement('style');
    s.id = 'wf-dark-styles';
    s.textContent = `
    .wf-dark{
      --wf-ink:#eef2f9; --wf-line:#4a566f; --wf-soft:#93a0bd; --wf-faint:#2c3447;
      --wf-paper:#1b2130; --wf-fill:#232c3e; --wf-accent:#5b9dd9; --wf-accent-soft:#1f3147;
      --wf-warn:#e3aa54; --wf-warn-soft:#3a2f1c; --wf-pos:#5cc491; --wf-neg:#e58178;
      color:var(--wf-ink);
    }
    .wf-dark .wf-img{ background-color:#232c3e;
      background-image:repeating-linear-gradient(45deg, transparent, transparent 6px, rgba(255,255,255,.05) 6px, rgba(255,255,255,.05) 7px);
      border-color:#384358; color:#93a0bd; }
    .wf-dark .wf-line{ background:#384358; }
    `;
    document.head.appendChild(s);
  }

  const A = 'var(--wf-accent)';

  const Dark = ({ children, bg = '#11161f', style = {} }) => (
    <div className="wf wf-dark" style={{ width: '100%', height: '100%', background: bg, overflow: 'hidden', position: 'relative', ...style }}>{children}</div>
  );

  // top nav (dark) — supports a center segment + balance chip
  const AltBar = ({ active = 'Home', items = ['Home', 'Markets', 'Communities', 'Leaderboard'], style = {} }) => (
    <div className="wf-row" style={{ justifyContent: 'space-between', padding: '0 22px', height: 50, borderBottom: '1.5px solid var(--wf-faint)', background: '#10141d', ...style }}>
      <div className="wf-row" style={{ gap: 9 }}>
        <div style={{ width: 15, height: 15, borderRadius: 4, background: A }} />
        <span style={{ fontWeight: 800, fontSize: 15, letterSpacing: '-.02em', color: 'var(--wf-ink)' }}>Adivento</span>
      </div>
      <div className="wf-row" style={{ gap: 3 }}>
        {items.map((t) => (
          <span key={t} style={{ fontSize: 12.5, fontWeight: t === active ? 700 : 500, color: t === active ? 'var(--wf-accent)' : 'var(--wf-soft)', padding: '5px 10px', borderRadius: 6, background: t === active ? 'var(--wf-accent-soft)' : 'transparent' }}>{t}</span>
        ))}
        <span className="wf-pill" style={{ background: 'var(--wf-accent-soft)', borderColor: 'var(--wf-accent-soft)', color: 'var(--wf-accent)', fontWeight: 700, marginLeft: 6 }}>4,250 ADIV</span>
        <div style={{ width: 28, height: 28, borderRadius: '50%', border: '1.5px solid var(--wf-line)', marginLeft: 6 }} />
      </div>
    </div>
  );

  const AltSidebar = ({ active = 'Watchlist', style = {} }) => {
    const items = [['Home', '⌂'], ['Watchlist', '★'], ['Markets', '▦'], ['Portfolio', '◫'], ['Communities', '👥'], ['Leaderboard', '↟']];
    return (
      <div className="wf-col" style={{ width: 156, borderRight: '1.5px solid var(--wf-faint)', padding: '14px 10px', gap: 3, background: '#10141d', height: '100%', ...style }}>
        <div className="wf-row" style={{ gap: 8, padding: '2px 6px 12px' }}>
          <div style={{ width: 14, height: 14, borderRadius: 4, background: A }} />
          <span style={{ fontWeight: 800, fontSize: 13, color: 'var(--wf-ink)' }}>Adivento</span>
        </div>
        {items.map(([t, ic]) => (
          <span key={t} className="wf-row" style={{ gap: 9, fontSize: 12.5, fontWeight: t === active ? 700 : 500, color: t === active ? 'var(--wf-accent)' : 'var(--wf-soft)', padding: '8px 9px', borderRadius: 6, background: t === active ? 'var(--wf-accent-soft)' : 'transparent' }}><span style={{ width: 15, textAlign: 'center' }}>{ic}</span>{t}</span>
        ))}
      </div>
    );
  };

  const AltTabBar = ({ active = 'Markets', style = {} }) => {
    const tabs = [['Markets', '▦'], ['Watchlist', '★'], ['Trade', '⇄'], ['Portfolio', '◫']];
    return (
      <div className="wf-row" style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: 56, borderTop: '1.5px solid var(--wf-faint)', background: '#10141d', justifyContent: 'space-around', ...style }}>
        {tabs.map(([t, ic]) => (
          <div key={t} className="wf-col" style={{ alignItems: 'center', gap: 3, color: t === active ? 'var(--wf-accent)' : 'var(--wf-soft)' }}>
            <span style={{ fontSize: 16 }}>{ic}</span><span style={{ fontSize: 9.5, fontWeight: t === active ? 700 : 500 }}>{t}</span>
          </div>
        ))}
      </div>
    );
  };

  window.WFD = { Dark, AltBar, AltSidebar, AltTabBar };
})();
