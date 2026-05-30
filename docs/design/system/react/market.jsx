/* Adivento DS — React domain components */
import { useState, useMemo } from "react";
import { Card, Badge, MechChip, Chip, Button, Delta } from "./atoms.jsx";
import { Sparkline } from "./charts.jsx";

const cx = (...xs) => xs.filter(Boolean).join(" ");
const fmt = (n) => Number(n).toLocaleString();

export function MarketCard({ market, onOpen, suffix = "%" }) {
  const { question, status = "open", mechanism = "fixed", yesPct = 50, volumeLabel, closesLabel, spark, delta, live } = market;
  return (
    <Card className="adv-market" onClick={() => onOpen && onOpen(market)} style={{ cursor: "pointer" }}>
      <div className="adv-market__top">
        <Badge status={status} live={live ?? status === "open"} />
        <MechChip mechanism={mechanism} />
      </div>
      <div className="adv-market__q">{question}</div>
      <div className="adv-probar"><div className="adv-probar__fill" style={{ width: `${yesPct}%` }} /></div>
      <div className="adv-row adv-row--between">
        <span className="adv-market__pct adv-num">{yesPct}{suffix}</span>
        {spark ? <Sparkline points={spark} /> : delta != null ? <Delta value={delta} /> : null}
      </div>
      <div className="adv-market__foot"><span>{volumeLabel}</span><span>{closesLabel}</span></div>
    </Card>
  );
}

export function PriceBoxes({ yesPct, noPct, yesPayout, noPayout, selected, onSelect, suffix = "%" }) {
  return (
    <div className="adv-prices">
      {[["yes", yesPct, yesPayout], ["no", noPct, noPayout]].map(([side, pct, payout]) => (
        <div key={side} className={cx("adv-pricebox", `adv-pricebox--${side}`, selected === side && "is-selected")} data-price={pct} onClick={() => onSelect && onSelect(side)}>
          <div className="adv-pricebox__label">{side === "yes" ? "Yes" : "No"}</div>
          <div className="adv-pricebox__val adv-num">{pct}{suffix}</div>
          {payout && <div className="adv-pricebox__sub">pays {payout}</div>}
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
    <Card className="adv-ticket">
      <div className="adv-card__head"><span className="adv-h3">Your bet</span>{balance != null && <span className="adv-muted adv-xs">Balance {fmt(balance)} ADIV</span>}</div>
      <PriceBoxes yesPct={yesPct} noPct={noPct} selected={side} onSelect={setSide} suffix="¢" />
      <div style={{ marginTop: 14 }}>
        <label className="adv-label">Stake</label>
        <div className="adv-input-group">
          <input className="adv-input adv-num" type="number" value={stake} onChange={(e) => setStake(+e.target.value || 0)} />
          <span className="adv-input-group__suffix">ADIV</span>
        </div>
      </div>
      <div className="adv-chipset" style={{ margin: "12px 0" }}>
        {quick.map((q) => <button key={q} className="adv-chip" onClick={() => setStake(q)}>{q}</button>)}
        {balance != null && <button className="adv-chip" onClick={() => setStake(balance)}>Max</button>}
      </div>
      <div className="adv-ticket__summary"><span className="adv-muted">Potential profit</span><span className="adv-num">+{fmt(payout - stake)}</span></div>
      <div className="adv-ticket__summary adv-ticket__summary--total"><span>Payout if win</span><span className="adv-ticket__payout adv-num">{fmt(payout)}</span></div>
      <Button variant={side === "yes" ? "yes" : "no"} block size="lg" style={{ marginTop: 12 }} onClick={() => onSubmit && onSubmit({ side, stake, payout })}>
        Buy {side.toUpperCase()} · {fmt(stake)} ADIV
      </Button>
    </Card>
  );
}

export function OrderBook({ asks = [], bids = [], spread, last }) {
  const max = Math.max(1, ...asks.concat(bids).map((r) => r[1]));
  const Row = ({ px, sz, side }) => (
    <div className={`adv-orderbook__row adv-orderbook__row--${side}`}>
      <div className="adv-orderbook__bar" style={{ width: `${(sz / max) * 100}%` }} />
      <span className="adv-orderbook__px adv-num">{px}¢</span>
      <span className="adv-orderbook__sz adv-num">{sz}</span>
    </div>
  );
  return (
    <div className="adv-orderbook">
      {asks.slice().reverse().map(([px, sz], i) => <Row key={`a${i}`} px={px} sz={sz} side="ask" />)}
      <div className="adv-orderbook__spread">spread {spread}¢ · last {last}¢</div>
      {bids.map(([px, sz], i) => <Row key={`b${i}`} px={px} sz={sz} side="bid" />)}
    </div>
  );
}

export function PoolBar({ yesAmount, noAmount }) {
  const total = yesAmount + noAmount || 1;
  const yesW = Math.round((yesAmount / total) * 100);
  return (
    <div className="adv-pool">
      <div className="adv-pool__yes" style={{ width: `${yesW}%` }}>YES {yesW}% · {fmt(yesAmount)}</div>
      <div className="adv-pool__no" style={{ width: `${100 - yesW}%` }}>{100 - yesW}% · {fmt(noAmount)}</div>
    </div>
  );
}

export function StatStrip({ stats = [] }) {
  return (
    <div className="adv-stats">
      {stats.map(([k, v]) => <div className="adv-stat" key={k}><div className="adv-stat__k">{k}</div><div className="adv-stat__v adv-num">{v}</div></div>)}
    </div>
  );
}

export function SettlementSteps({ stage = "resolving" }) {
  const order = ["open", "closed", "resolving", "settled"];
  const idx = order.indexOf(stage);
  const steps = [["Open", "trading live"], ["Closes", "at deadline"], ["Resolves", "source checked"], ["Settles", "payouts sent"]];
  return (
    <div className="adv-steps">
      {steps.map(([label, sub], i) => (
        <div key={label} className={cx("adv-step", i < idx && "is-done", i === idx && "is-current")}>
          <div className="adv-step__label">{label}<br /><span className="adv-muted adv-xs">{sub}</span></div>
        </div>
      ))}
    </div>
  );
}

export function Callout({ variant, icon, title, children }) {
  return (
    <div className={cx("adv-callout", variant && `adv-callout--${variant}`)}>
      {icon && <span className="adv-callout__icon">{icon}</span>}
      <div>{title && <strong>{title}</strong>}<div className="adv-small adv-muted">{children}</div></div>
    </div>
  );
}
