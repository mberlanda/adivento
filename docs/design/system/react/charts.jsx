/* Adivento DS — React charts (pure SVG, theme-aware via CSS vars)
   These read --adv-* at render; wrap in a key that changes on theme to recolor,
   or rely on currentColor. We use explicit vars for fill/stroke. */

function points2path(points, W, H) {
  const n = points.length;
  return points.map((v, i) => `${(i / (n - 1)) * W},${H - (Math.max(0, Math.min(100, v)) / 100) * H}`).join(" ");
}

export function Chart({ points = [], color = "var(--adv-accent)", height = 170, showAxis = true }) {
  const W = 300, H = 120;
  if (points.length < 2) return <div className="adv-chart" style={{ height }} />;
  const path = points2path(points, W, H);
  const area = `0,${H} ${path} ${W},${H}`;
  const last = path.split(" ").pop().split(",");
  return (
    <div className="adv-chart" style={{ height }}>
      <svg viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none">
        {[25, 50, 75].map((g) => (
          <line key={g} x1="0" x2={W} y1={H - (g / 100) * H} y2={H - (g / 100) * H} stroke="var(--adv-chart-grid)" strokeWidth="1" strokeDasharray="3 3" />
        ))}
        <polygon points={area} fill={color} opacity="0.12" />
        <polyline points={path} fill="none" stroke={color} strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />
        <circle cx={last[0]} cy={last[1]} r="3.5" fill={color} />
      </svg>
      {showAxis && <><span className="adv-chart__axis adv-chart__axis--top">100%</span><span className="adv-chart__axis adv-chart__axis--bottom">0%</span></>}
    </div>
  );
}

export function Sparkline({ points = [], color = "var(--adv-accent)", width = 72, height = 22 }) {
  if (points.length < 2) return null;
  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
      <polyline points={points.map((v, i) => `${(i / (points.length - 1)) * width},${height - (v / 100) * height}`).join(" ")} fill="none" stroke={color} strokeWidth="1.5" strokeLinejoin="round" />
    </svg>
  );
}
