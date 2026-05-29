// wireframe-kit.jsx — low-fi wireframe primitives for Adivento.
// Grayscale "sketch" vocabulary + one muted accent. Exports WF.* to window.
// All components accept a `style` prop override and most accept children.

(function () {
  // ---- one-time style injection -------------------------------------------
  if (typeof document !== 'undefined' && !document.getElementById('wf-styles')) {
    const s = document.createElement('style');
    s.id = 'wf-styles';
    s.textContent = `
    :root{
      --wf-ink:#2c2c2c; --wf-line:#3a3a3a; --wf-soft:#8d8d8d; --wf-faint:#c7c7c2;
      --wf-paper:#ffffff; --wf-fill:#f4f3ef; --wf-accent:#356b8a; --wf-accent-soft:#dce8ee;
      --wf-warn:#9a6a1e; --wf-warn-soft:#f1e6d0; --wf-pos:#3c7a52; --wf-neg:#9a4038;
    }
    .wf{ font-family:'Inter',system-ui,sans-serif; color:var(--wf-ink); box-sizing:border-box; }
    .wf *{ box-sizing:border-box; }
    .wf-hand{ font-family:'Caveat',cursive; }
    .wf-box{ border:1.5px solid var(--wf-line); border-radius:5px; background:var(--wf-paper); }
    .wf-dashed{ border-style:dashed; }
    .wf-img{
      background-color:var(--wf-fill);
      background-image:repeating-linear-gradient(45deg, transparent, transparent 6px, rgba(0,0,0,.05) 6px, rgba(0,0,0,.05) 7px);
      border:1.5px solid var(--wf-faint); border-radius:5px;
      display:flex; align-items:center; justify-content:center;
      color:var(--wf-soft); font-family:'Inter',monospace; font-size:11px; letter-spacing:.03em; text-align:center;
    }
    .wf-line{ height:9px; border-radius:4px; background:var(--wf-faint); }
    .wf-btn{ display:inline-flex; align-items:center; justify-content:center; gap:6px;
      border:1.5px solid var(--wf-line); border-radius:6px; background:var(--wf-paper);
      padding:8px 14px; font-size:13px; font-weight:600; color:var(--wf-ink); white-space:nowrap; }
    .wf-btn-primary{ background:var(--wf-accent); border-color:var(--wf-accent); color:#fff; }
    .wf-btn-ghost{ border-color:var(--wf-faint); color:var(--wf-soft); font-weight:500; }
    .wf-pill{ display:inline-flex; align-items:center; gap:5px; border:1.5px solid var(--wf-faint);
      border-radius:999px; padding:5px 12px; font-size:12px; color:var(--wf-soft); white-space:nowrap; }
    .wf-pill-active{ background:var(--wf-accent); border-color:var(--wf-accent); color:#fff; font-weight:600; }
    .wf-chip{ display:inline-flex; align-items:center; border:1.2px solid var(--wf-faint); border-radius:999px;
      padding:2px 9px; font-size:10.5px; font-weight:600; letter-spacing:.04em; text-transform:uppercase; color:var(--wf-soft); }
    .wf-card{ border:1.5px solid var(--wf-line); border-radius:9px; background:var(--wf-paper); padding:14px; }
    .wf-field{ border:1.5px solid var(--wf-faint); border-radius:6px; background:var(--wf-paper);
      height:36px; display:flex; align-items:center; padding:0 11px; font-size:12.5px; color:var(--wf-soft); }
    .wf-ann{ font-family:'Caveat',cursive; color:var(--wf-accent); font-size:17px; line-height:1.15; font-weight:600; }
    .wf-num{ display:inline-flex; align-items:center; justify-content:center; width:18px; height:18px; flex:0 0 18px;
      border-radius:999px; background:var(--wf-accent); color:#fff; font-family:'Inter',sans-serif; font-size:11px; font-weight:700; }
    .wf-divider{ height:1.5px; background:var(--wf-faint); border:0; }
    .wf-row{ display:flex; align-items:center; }
    .wf-col{ display:flex; flex-direction:column; }
    `;
    document.head.appendChild(s);
  }

  const A = '#356b8a';

  // ---- primitives ----------------------------------------------------------
  const Screen = ({ children, style = {}, pad = 0, bg = '#fff' }) => (
    <div className="wf" style={{ width: '100%', height: '100%', background: bg, padding: pad, overflow: 'hidden', position: 'relative', ...style }}>{children}</div>
  );

  const Box = ({ children, dashed, style = {}, ...p }) => (
    <div className={'wf-box' + (dashed ? ' wf-dashed' : '')} style={style} {...p}>{children}</div>
  );

  const Img = ({ label = 'image', style = {} }) => (
    <div className="wf-img" style={style}>{label}</div>
  );

  const Line = ({ w = '100%', style = {} }) => (
    <div className="wf-line" style={{ width: w, ...style }} />
  );

  const Lines = ({ n = 3, gap = 7, last = '60%', w = '100%', style = {} }) => (
    <div className="wf-col" style={{ gap, ...style }}>
      {Array.from({ length: n }).map((_, i) => (
        <div key={i} className="wf-line" style={{ width: i === n - 1 ? last : w }} />
      ))}
    </div>
  );

  const Btn = ({ children, primary, ghost, style = {} }) => (
    <span className={'wf-btn' + (primary ? ' wf-btn-primary' : '') + (ghost ? ' wf-btn-ghost' : '')} style={style}>{children}</span>
  );

  const Pill = ({ children, active, style = {} }) => (
    <span className={'wf-pill' + (active ? ' wf-pill-active' : '')} style={style}>{children}</span>
  );

  const Chip = ({ children, style = {} }) => (
    <span className="wf-chip" style={style}>{children}</span>
  );

  const Card = ({ children, style = {} }) => (
    <div className="wf-card" style={style}>{children}</div>
  );

  const Field = ({ label = '', style = {} }) => (
    <div className="wf-field" style={style}>{label}</div>
  );

  const Label = ({ children, style = {} }) => (
    <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: '.04em', textTransform: 'uppercase', color: 'var(--wf-soft)', ...style }}>{children}</div>
  );

  const H = ({ children, size = 20, style = {} }) => (
    <div style={{ fontSize: size, fontWeight: 700, color: 'var(--wf-ink)', lineHeight: 1.2, ...style }}>{children}</div>
  );

  const Text = ({ children, size = 12.5, soft, style = {} }) => (
    <div style={{ fontSize: size, color: soft ? 'var(--wf-soft)' : 'var(--wf-ink)', lineHeight: 1.4, ...style }}>{children}</div>
  );

  const Divider = ({ style = {} }) => <div className="wf-divider" style={style} />;

  const Row = ({ children, gap = 8, style = {} }) => (
    <div className="wf-row" style={{ gap, ...style }}>{children}</div>
  );

  const Col = ({ children, gap = 8, style = {} }) => (
    <div className="wf-col" style={{ gap, ...style }}>{children}</div>
  );

  const Avatar = ({ size = 30, style = {} }) => (
    <div style={{ width: size, height: size, borderRadius: '50%', border: '1.5px solid var(--wf-line)', background: 'var(--wf-fill)', flex: `0 0 ${size}px`, ...style }} />
  );

  // numbered annotation marker (for callouts referenced in the guide)
  const Ann = ({ n, children, style = {} }) => (
    <div className="wf-row" style={{ gap: 6, alignItems: 'flex-start', ...style }}>
      {n != null && <span className="wf-num" style={{ marginTop: 1 }}>{n}</span>}
      <span className="wf-ann">{children}</span>
    </div>
  );

  // ---- web chrome ----------------------------------------------------------
  const WebBar = ({ active = 'Markets', balance = '4,250', signedIn = true, style = {} }) => (
    <div className="wf-row" style={{ justifyContent: 'space-between', padding: '0 22px', height: 52, borderBottom: '1.5px solid var(--wf-faint)', background: '#fff', ...style }}>
      <div className="wf-row" style={{ gap: 8 }}>
        <div style={{ width: 16, height: 16, borderRadius: 4, background: A }} />
        <span style={{ fontWeight: 800, fontSize: 15, letterSpacing: '-.02em' }}>Adivento</span>
      </div>
      <div className="wf-row" style={{ gap: 4 }}>
        {['Markets', 'Leaderboard', 'Positions', 'Profile'].map((t) => (
          <span key={t} style={{ fontSize: 12.5, fontWeight: t === active ? 700 : 500, color: t === active ? A : 'var(--wf-soft)', padding: '5px 9px', borderRadius: 6, background: t === active ? 'var(--wf-accent-soft)' : 'transparent' }}>{t}</span>
        ))}
        {signedIn
          ? <span className="wf-pill" style={{ background: 'var(--wf-accent-soft)', borderColor: 'var(--wf-accent-soft)', color: A, fontWeight: 700 }}>{balance} ADIV</span>
          : <span className="wf-btn wf-btn-primary" style={{ padding: '5px 12px', fontSize: 12 }}>Sign in</span>}
      </div>
    </div>
  );

  // ---- mobile chrome -------------------------------------------------------
  const PhoneStatus = ({ style = {} }) => (
    <div className="wf-row" style={{ justifyContent: 'space-between', padding: '0 18px', height: 30, fontSize: 11, fontWeight: 700, color: 'var(--wf-ink)', ...style }}>
      <span>9:41</span>
      <div className="wf-row" style={{ gap: 4 }}>
        <span style={{ fontSize: 10 }}>●●●</span>
        <span style={{ fontSize: 10 }}>▮▮▮</span>
        <span style={{ width: 16, height: 9, border: '1.2px solid var(--wf-ink)', borderRadius: 2, display: 'inline-block' }} />
      </div>
    </div>
  );

  const TabBar = ({ active = 'Markets', style = {} }) => {
    const tabs = [['Markets', '▦'], ['Search', '⌕'], ['Positions', '▣'], ['Profile', '◉']];
    return (
      <div className="wf-row" style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: 58, borderTop: '1.5px solid var(--wf-faint)', background: '#fff', justifyContent: 'space-around', ...style }}>
        {tabs.map(([t, icon]) => (
          <div key={t} className="wf-col" style={{ alignItems: 'center', gap: 3, color: t === active ? A : 'var(--wf-soft)' }}>
            <span style={{ fontSize: 17 }}>{icon}</span>
            <span style={{ fontSize: 9.5, fontWeight: t === active ? 700 : 500 }}>{t}</span>
          </div>
        ))}
      </div>
    );
  };

  // ---- backoffice chrome (wireframe stays grayscale; theme noted in guide) -
  const BoSidebar = ({ active = 'Markets', style = {} }) => {
    const items = ['Dashboard', 'Markets', 'Templates', 'Faucet Requests', 'Permissions', 'Ad-hoc Grants'];
    return (
      <div className="wf-col" style={{ width: 168, borderRight: '1.5px solid var(--wf-faint)', padding: '16px 12px', gap: 4, background: '#fafaf8', height: '100%', ...style }}>
        <div className="wf-row" style={{ gap: 7, padding: '0 6px 12px' }}>
          <div style={{ width: 14, height: 14, borderRadius: 4, background: 'var(--wf-warn)' }} />
          <span style={{ fontWeight: 800, fontSize: 13 }}>Backoffice</span>
        </div>
        {items.map((t) => (
          <span key={t} style={{ fontSize: 12.5, fontWeight: t === active ? 700 : 500, color: t === active ? 'var(--wf-warn)' : 'var(--wf-soft)', padding: '7px 8px', borderRadius: 6, background: t === active ? 'var(--wf-warn-soft)' : 'transparent' }}>{t}</span>
        ))}
      </div>
    );
  };

  // ---- data viz (legit chart drawing, not illustration) -------------------
  // probability line chart over time, 0..100. points: array of numbers.
  const Chart = ({ points = [50, 48, 54, 52, 60, 57, 63, 61, 66, 62], h = 150, color = A, frames = ['1H', '6H', '1D', '1W', 'ALL'], style = {} }) => {
    const W = 300, H = 120, n = points.length;
    const pts = points.map((v, i) => `${(i / (n - 1)) * W},${H - (v / 100) * H}`).join(' ');
    const area = `0,${H} ${pts} ${W},${H}`;
    return (
      <div style={style}>
        <div style={{ position: 'relative', width: '100%', height: h, border: '1.5px solid var(--wf-faint)', borderRadius: 6, overflow: 'hidden', background: 'var(--wf-paper)' }}>
          <svg viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" style={{ width: '100%', height: '100%', display: 'block' }}>
            {[25, 50, 75].map((g) => (
              <line key={g} x1="0" x2={W} y1={H - (g / 100) * H} y2={H - (g / 100) * H} stroke="#e6e4de" strokeWidth="1" strokeDasharray="3 3" />
            ))}
            <polygon points={area} fill={color} opacity="0.08" />
            <polyline points={pts} fill="none" stroke={color} strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />
            <circle cx={W} cy={H - (points[n - 1] / 100) * H} r="3.5" fill={color} />
          </svg>
          <div style={{ position: 'absolute', top: 4, right: 6, fontSize: 9, color: 'var(--wf-soft)' }}>100%</div>
          <div style={{ position: 'absolute', bottom: 4, right: 6, fontSize: 9, color: 'var(--wf-soft)' }}>0%</div>
        </div>
        <div className="wf-row" style={{ gap: 5, marginTop: 8, justifyContent: 'center' }}>
          {frames.map((f, i) => <span key={f} className={'wf-pill' + (i === 2 ? ' wf-pill-active' : '')} style={{ padding: '3px 10px', fontSize: 11 }}>{f}</span>)}
        </div>
      </div>
    );
  };

  const Sparkline = ({ points = [50, 52, 49, 55, 58, 56, 62], color = A, w = 70, h = 22, style = {} }) => {
    const n = points.length, pts = points.map((v, i) => `${(i / (n - 1)) * w},${h - (v / 100) * h}`).join(' ');
    return <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={style}><polyline points={pts} fill="none" stroke={color} strokeWidth="1.5" strokeLinejoin="round" /></svg>;
  };

  window.WF = {
    Screen, Box, Img, Line, Lines, Btn, Pill, Chip, Card, Field, Label, H, Text,
    Divider, Row, Col, Avatar, Ann, WebBar, PhoneStatus, TabBar, BoSidebar, Chart, Sparkline,
  };
})();
