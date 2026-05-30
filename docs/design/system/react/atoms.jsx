/* Adivento DS — React atoms */
const cx = (...xs) => xs.filter(Boolean).join(" ");

const MECH = { fixed: "FIXED", fixed_odds: "FIXED", clob: "CLOB", lmsr: "LMSR", parimutuel: "PARI", pari: "PARI" };

export function Button({ variant, size, block, href, children, className, ...rest }) {
  const cls = cx("adv-btn", variant && `adv-btn--${variant}`, size && `adv-btn--${size}`, block && "adv-btn--block", className);
  if (href) return <a href={href} className={cls} {...rest}>{children}</a>;
  return <button className={cls} {...rest}>{children}</button>;
}

export function Chip({ active, accent, solid, mech, children, className, ...rest }) {
  return (
    <span className={cx("adv-chip", active && "is-active", accent && "adv-chip--accent", solid && "adv-chip--solid", className)} {...(mech ? { "data-mech": true } : {})} {...rest}>
      {children}
    </span>
  );
}

export function MechChip({ mechanism }) {
  return <Chip accent mech>{MECH[mechanism] || String(mechanism).toUpperCase()}</Chip>;
}

export function Badge({ status = "open", live, children }) {
  return <span className={cx("adv-badge", `adv-badge--${status}`, live && "adv-badge--live")}>{live ? "Live" : (children || status)}</span>;
}

export function Card({ flush, quiet, padSm, className, children, ...rest }) {
  return <div className={cx("adv-card", flush && "adv-card--flush", quiet && "adv-card--quiet", padSm && "adv-card--pad-sm", className)} {...rest}>{children}</div>;
}

export function Field({ label, suffix, help, className, ...rest }) {
  return (
    <div className="adv-field">
      {label && <label className="adv-label">{label}</label>}
      {suffix ? (
        <div className="adv-input-group">
          <input className={cx("adv-input", "adv-num", className)} {...rest} />
          <span className="adv-input-group__suffix">{suffix}</span>
        </div>
      ) : (
        <input className={cx("adv-input", className)} {...rest} />
      )}
      {help && <div className="adv-help">{help}</div>}
    </div>
  );
}

export function Segment({ options = [], value, onChange }) {
  return (
    <div className="adv-segment">
      {options.map((o) => (
        <button key={o} className={cx("adv-segment__item", o === value && "is-active")} onClick={() => onChange && onChange(o)}>{o}</button>
      ))}
    </div>
  );
}

export function Delta({ value, unit = "" }) {
  const up = value >= 0;
  return <span className={cx("adv-delta", up ? "adv-delta--up" : "adv-delta--down")}>{Math.abs(value)}{unit}</span>;
}

export function Avatar({ size, ...rest }) {
  return <span className={cx("adv-avatar", size && `adv-avatar--${size}`)} {...rest} />;
}
