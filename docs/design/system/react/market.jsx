/* Adivento DS — React domain components */
import { useState, useMemo } from "react";
import { Card, Badge, MechChip, Chip, Button, Delta } from "./atoms.jsx";
import { Sparkline } from "./charts.jsx";

const cx = (...xs) => xs.filter(Boolean).join(" ");
const fmt = (n) => Number(n).toLocaleString();

export function MarketCard({ market, onOpen, suffix = "%" }) {
  const { question, status = "open", mechanism = "fixed", yesPct = 50, volumeLabel, closesLabel, spark, delta, live } = market;
  return (
    <Card className="ds-market" onClick={() => onOpen && onOpen(market)} style={{ cursor: "pointer" }}>
      <div className="ds-market__top">
        <Badge status={status} live={live ?? status === "open"} />
        <MechChip mechanism={mechanism} />
      </div>
      <div className="ds-market__q">{question}</div>
      <div className="ds-probar"><div className="ds-probar__fill" style={{ width: `${yesPct}%` }} /></div>
      <div className="ds-row ds-row--between">
        <span className="ds-market__pct ds-num">{yesPct}{suffix}</span>
        {spark ? <Sparkline points={spark} /> : delta != null ? <Delta value={delta} /> : null}
      </div>
      <div className="ds-market__foot"><span>{volumeLabel}</span><span>{closesLabel}</span></div>
    </Card>
  );
}

export function PriceBoxes({ yesPct, noPct, yesPayout, noPayout, selected, onSelect, suffix = "%" }) {
  return (
    <div className="ds-prices">
      {[["yes", yesPct, yesPayout], ["no", noPct, noPayout]].map(([side, pct, payout]) => (
        <div key={side} className={cx("ds-pricebox", `ds-pricebox--${side}`, selected === side && "is-selected")} data-price={pct} onClick={() => onSelect && onSelect(side)}>
          <div className="ds-pricebox__label">{side === "yes" ? "Yes" : "No"}</div>
          <div className="ds-pricebox__val ds-num">{pct}{suffix}</div>
          {payout && <div className="ds-pricebox__sub">pays {payout}</div>}
        </div>
      ))}
    </div>
  );
}

/* Controlled bet ticket — payout math lives here (cents → multiplier). */
export function BetTicket({ yesPct, noPct, balance, quick = [50, 100, 250], onSubmit }) {
  const [side, setSide] = useState("yes");
  const [stake, setStake] = useState(100);
  const price = side === "yes" ? yesPct : noPct;
  const payout = useMemo(() => (price > 0 ? Math.round(stake * (100 / price)) : 0), [price, stake]);
  return (
    <Card className="ds-ticket">
      <div className="ds-card__head"><span className="ds-h3">Your bet</span>{balance != null && <span className="ds-muted ds-xs">Balance {fmt(balance)} ADIV</span>}</div>
      <PriceBoxes yesPct={yesPct} noPct={noPct} selected={side} onSelect={setSide} suffix="¢" />
      <div style={{ marginTop: 14 }}>
        <label className="ds-label">Stake</label>
        <div className="ds-input-group">
          <input className="ds-input ds-num" type="number" value={stake} onChange={(e) => setStake(+e.target.value || 0)} />
          <span className="ds-input-group__suffix">ADIV</span>
        </div>
      </div>
      <div className="ds-chipset" style={{ margin: "12px 0" }}>
        {quick.map((q) => <button key={q} className="ds-chip" onClick={() => setStake(q)}>{q}</button>)}
        {balance != null && <button className="ds-chip" onClick={() => setStake(balance)}>Max</button>}
      </div>
      <div className="ds-ticket__summary"><span className="ds-muted">Potential profit</span><span className="ds-num">+{fmt(payout - stake)}</span></div>
      <div className="ds-ticket__summary ds-ticket__summary--total"><span>Payout if win</span><span className="ds-ticket__payout ds-num">{fmt(payout)}</span></div>
      <Button variant={side === "yes" ? "yes" : "no"} block size="lg" style={{ marginTop: 12 }} onClick={() => onSubmit && onSubmit({ side, stake, payout })}>
        Buy {side.toUpperCase()} · {fmt(stake)} ADIV
      </Button>
    </Card>
  );
}

export function OrderBook({ asks = [], bids = [], spread, last }) {
  const max = Math.max(1, ...asks.concat(bids).map((r) => r[1]));
  const Row = ({ px, sz, side }) => (
    <div className={`ds-orderbook__row ds-orderbook__row--${side}`}>
      <div className="ds-orderbook__bar" style={{ width: `${(sz / max) * 100}%` }} />
      <span className="ds-orderbook__px ds-num">{px}¢</span>
      <span className="ds-orderbook__sz ds-num">{sz}</span>
    </div>
  );
  return (
    <div className="ds-orderbook">
      {asks.slice().reverse().map(([px, sz], i) => <Row key={`a${i}`} px={px} sz={sz} side="ask" />)}
      <div className="ds-orderbook__spread">spread {spread}¢ · last {last}¢</div>
      {bids.map(([px, sz], i) => <Row key={`b${i}`} px={px} sz={sz} side="bid" />)}
    </div>
  );
}

export function PoolBar({ yesAmount, noAmount }) {
  const total = yesAmount + noAmount || 1;
  const yesW = Math.round((yesAmount / total) * 100);
  return (
    <div className="ds-pool">
      <div className="ds-pool__yes" style={{ width: `${yesW}%` }}>YES {yesW}% · {fmt(yesAmount)}</div>
      <div className="ds-pool__no" style={{ width: `${100 - yesW}%` }}>{100 - yesW}% · {fmt(noAmount)}</div>
    </div>
  );
}

export function StatStrip({ stats = [] }) {
  return (
    <div className="ds-stats">
      {stats.map(([k, v]) => <div className="ds-stat" key={k}><div className="ds-stat__k">{k}</div><div className="ds-stat__v ds-num">{v}</div></div>)}
    </div>
  );
}

export function SettlementSteps({ stage = "resolving" }) {
  const order = ["open", "closed", "resolving", "settled"];
  const idx = order.indexOf(stage);
  const steps = [["Open", "trading live"], ["Closes", "at deadline"], ["Resolves", "source checked"], ["Settles", "payouts sent"]];
  return (
    <div className="ds-steps">
      {steps.map(([label, sub], i) => (
        <div key={label} className={cx("ds-step", i < idx && "is-done", i === idx && "is-current")}>
          <div className="ds-step__label">{label}<br /><span className="ds-muted ds-xs">{sub}</span></div>
        </div>
      ))}
    </div>
  );
}

export function Callout({ variant, icon, title, children }) {
  return (
    <div className={cx("ds-callout", variant && `ds-callout--${variant}`)}>
      {icon && <span className="ds-callout__icon">{icon}</span>}
      <div>{title && <strong>{title}</strong>}<div className="ds-small ds-muted">{children}</div></div>
    </div>
  );
}
