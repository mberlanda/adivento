/* Adivento DS — React atoms */
const cx = (...xs) => xs.filter(Boolean).join(" ");

const MECH = { fixed: "FIXED", fixed_odds: "FIXED", clob: "CLOB", lmsr: "LMSR", parimutuel: "PARI", pari: "PARI" };

export function Button({ variant, size, block, href, children, className, ...rest }) {
  const cls = cx("ds-btn", variant && `ds-btn--${variant}`, size && `ds-btn--${size}`, block && "ds-btn--block", className);
  if (href) return <a href={href} className={cls} {...rest}>{children}</a>;
  return <button className={cls} {...rest}>{children}</button>;
}

export function Chip({ active, accent, solid, mech, children, className, ...rest }) {
  return (
    <span className={cx("ds-chip", active && "is-active", accent && "ds-chip--accent", solid && "ds-chip--solid", className)} {...(mech ? { "data-mech": true } : {})} {...rest}>
      {children}
    </span>
  );
}

export function MechChip({ mechanism }) {
  return <Chip accent mech>{MECH[mechanism] || String(mechanism).toUpperCase()}</Chip>;
}

export function Badge({ status = "open", live, children }) {
  return <span className={cx("ds-badge", `ds-badge--${status}`, live && "ds-badge--live")}>{live ? "Live" : (children || status)}</span>;
}

export function Card({ flush, quiet, padSm, className, children, ...rest }) {
  return <div className={cx("ds-card", flush && "ds-card--flush", quiet && "ds-card--quiet", padSm && "ds-card--pad-sm", className)} {...rest}>{children}</div>;
}

export function Field({ label, suffix, help, className, ...rest }) {
  return (
    <div className="ds-field">
      {label && <label className="ds-label">{label}</label>}
      {suffix ? (
        <div className="ds-input-group">
          <input className={cx("ds-input", "ds-num", className)} {...rest} />
          <span className="ds-input-group__suffix">{suffix}</span>
        </div>
      ) : (
        <input className={cx("ds-input", className)} {...rest} />
      )}
      {help && <div className="ds-help">{help}</div>}
    </div>
  );
}

export function Segment({ options = [], value, onChange }) {
  return (
    <div className="ds-segment">
      {options.map((o) => (
        <button key={o} className={cx("ds-segment__item", o === value && "is-active")} onClick={() => onChange && onChange(o)}>{o}</button>
      ))}
    </div>
  );
}

export function Delta({ value, unit = "" }) {
  const up = value >= 0;
  return <span className={cx("ds-delta", up ? "ds-delta--up" : "ds-delta--down")}>{Math.abs(value)}{unit}</span>;
}

export function Avatar({ size, ...rest }) {
  return <span className={cx("ds-avatar", size && `ds-avatar--${size}`)} {...rest} />;
}
