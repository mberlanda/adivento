// wireframes-alt.jsx — PR2 alternative directions (dark, high-contrast).
// Diverges on (A) IA/navigation, (B) market-detail & betting, (C) visual structure.
// Registered on window.WFAlt.
(function () {
  const { Box, Line, Lines, Btn, Pill, Chip, Card, Field, Label, H, Text, Divider, Row, Col, Avatar, Ann, Chart, Sparkline } = window.WF;
  const { Dark, AltBar, AltSidebar, AltTabBar } = window.WFD;
  const AC = '#5b9dd9', WC = '#e3aa54', POS = '#5cc491', NEG = '#e58178';
  const cap = { fontSize: 10, fontWeight: 600, letterSpacing: '.05em', textTransform: 'uppercase', color: 'var(--wf-soft)' };
  const chg = (v) => <span style={{ color: v >= 0 ? POS : NEG, fontWeight: 700, fontSize: 11.5 }}>{v >= 0 ? '▲' : '▼'} {Math.abs(v)}</span>;

  window.WFAlt = {};

  // ── Intro ─────────────────────────────────────────────────────────────────
  window.WFAlt.Intro = () => (
    <Dark bg="#11161f" style={{ padding: '30px 34px' }}>
      <div style={{ fontFamily: "'Caveat',cursive", fontSize: 30, fontWeight: 700, color: AC, marginBottom: 2 }}>Alternative direction — Dark “Terminal”</div>
      <Text soft style={{ marginBottom: 20, fontSize: 13 }}>PR2 · diverges on all three axes vs PR1’s light card-stack. High-contrast slate, data-forward, power-user leaning.</Text>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 24 }}>
        {[['A · Navigation / IA', 'Three home models: a live activity feed, a category hub, and a watchlist terminal dashboard — instead of one filter-grid.'], ['B · Detail & betting', 'A trading-terminal layout (chart + order book + ticket rail), a chart-dominant compact view, and a mobile bottom-sheet terminal.'], ['C · Visual structure', 'Dark high-contrast (not black), dense tabular data, big tickers, sparklines everywhere, mono-ish numerals.']].map(([t, d]) => (
          <Col key={t} gap={8}><div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.05em', textTransform: 'uppercase', color: AC }}>{t}</div><Text style={{ fontSize: 12.5, lineHeight: 1.5 }}>{d}</Text></Col>
        ))}
      </div>
      <Box style={{ marginTop: 20, padding: 14, borderColor: 'var(--wf-faint)', background: 'var(--wf-fill)' }}>
        <Text style={{ fontSize: 12.5 }}>Pick-and-mix: any single direction here can be combined with PR1. In PR3 both become a theme toggle with shared component classes.</Text>
      </Box>
    </Dark>
  );

  // ════════════════ A · NAVIGATION / IA ════════════════
  // A1 — Feed-first home
  window.WFAlt.Feed = () => (
    <Dark>
      <AltBar active="Home" />
      <div style={{ padding: '18px 24px', display: 'grid', gridTemplateColumns: '1fr 300px', gap: 20 }}>
        <Col gap={14}>
          <Label>🔥 Trending now</Label>
          <Row style={{ gap: 12 }}>
            {[['62%', 4], ['54¢', -2], ['71%', 9]].map(([v, d], i) => (
              <Card key={i} style={{ flex: 1, padding: 12 }}>
                <Text size={11.5} style={{ fontWeight: 600, marginBottom: 8, height: 32, overflow: 'hidden' }}>Will the proposal pass before Q3?</Text>
                <Row style={{ justifyContent: 'space-between', alignItems: 'flex-end' }}><span style={{ fontSize: 22, fontWeight: 800, color: AC }}>{v}</span>{chg(d)}</Row>
                <Sparkline points={[48, 50, 47, 53, 55, 58, 62]} color={AC} w={250} h={26} style={{ marginTop: 6, width: '100%' }} />
              </Card>
            ))}
          </Row>
          <Label style={{ marginTop: 6 }}>Activity feed</Label>
          {[['player_alex', 'bought YES', '+120 @ 60¢', 'trade'], ['Market resolved', 'YES — “Rate cut in June”', 'paid 1,240 ADIV', 'resolve'], ['player_sam', 'opened a community market', 'Office League', 'market'], ['player_lee', 'bought NO', '−80 @ 41¢', 'trade']].map(([a, b, c, t], i) => (
            <Card key={i} style={{ padding: 12 }}>
              <Row style={{ gap: 10, alignItems: 'center' }}>
                <Avatar size={28} />
                <Col gap={2} style={{ flex: 1 }}><Text size={12.5}><b>{a}</b> <span style={{ color: 'var(--wf-soft)' }}>{b}</span></Text><Text size={11} soft>{c} · {i + 1}m ago</Text></Col>
                <Chip style={{ color: t === 'resolve' ? POS : AC, borderColor: 'currentColor' }}>{t}</Chip>
              </Row>
            </Card>
          ))}
          <Ann n={1}>IA: home = a live feed; discover via trending + who you follow</Ann>
        </Col>
        <Col gap={14}>
          <Card><Label style={{ marginBottom: 8 }}>Your portfolio</Label><Row style={{ justifyContent: 'space-between' }}><Text size={11.5} soft>Value</Text><Text size={13}><b>5,430</b></Text></Row><Row style={{ justifyContent: 'space-between' }}><Text size={11.5} soft>Today</Text>{chg(180)}</Row><Sparkline points={[40, 45, 43, 50, 55, 52, 60]} color={POS} w={250} h={28} style={{ marginTop: 8, width: '100%' }} /></Card>
          <Card><Label style={{ marginBottom: 8 }}>Watchlist</Label>{[['Senate vote', '62%', 4], ['BTC > 100k', '54¢', -2], ['Cup final', '48%', 1]].map(([m, v, d], i) => (<Row key={i} style={{ justifyContent: 'space-between', padding: '6px 0', borderBottom: i < 2 ? '1px solid var(--wf-faint)' : 0 }}><Text size={11.5}>{m}</Text><Row style={{ gap: 8 }}><Text size={12}><b>{v}</b></Text>{chg(d)}</Row></Row>))}</Card>
        </Col>
      </div>
    </Dark>
  );

  // A2 — Category hub
  window.WFAlt.Hub = () => (
    <Dark>
      <AltBar active="Markets" />
      <div style={{ display: 'flex', height: 'calc(100% - 50px)' }}>
        <div className="wf-col" style={{ width: 150, borderRight: '1.5px solid var(--wf-faint)', padding: '16px 10px', gap: 3, background: '#10141d' }}>
          <Text size={10} soft style={{ padding: '0 8px 6px', textTransform: 'uppercase', letterSpacing: '.05em' }}>Categories</Text>
          {['All markets', 'Politics', 'Sports', 'Crypto', 'Macro', 'Culture'].map((t, i) => (
            <span key={t} style={{ fontSize: 12.5, fontWeight: i === 1 ? 700 : 500, color: i === 1 ? AC : 'var(--wf-soft)', padding: '8px 9px', borderRadius: 6, background: i === 1 ? 'var(--wf-accent-soft)' : 'transparent' }}>{t}</span>
          ))}
          <Divider style={{ margin: '10px 4px' }} />
          <Text size={10} soft style={{ padding: '0 8px 6px', textTransform: 'uppercase', letterSpacing: '.05em' }}>Communities</Text>
          {['Office League', 'Crypto Club'].map((t) => <span key={t} style={{ fontSize: 12.5, color: 'var(--wf-soft)', padding: '7px 9px' }}>👥 {t}</span>)}
        </div>
        <div style={{ flex: 1, padding: '18px 22px', overflow: 'hidden' }}>
          <Row style={{ justifyContent: 'space-between', marginBottom: 6 }}><H size={20} style={{ color: 'var(--wf-ink)' }}>Politics</H><Field label="Sort: Volume ▾" style={{ width: 150 }} /></Row>
          <Text soft style={{ marginBottom: 16, fontSize: 12 }}>34 open markets</Text>
          {[['Featured', 2], ['Closing soon', 2]].map(([sec, n], si) => (
            <div key={sec} style={{ marginBottom: 18 }}>
              <Label style={{ marginBottom: 10 }}>{sec}</Label>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 12 }}>
                {Array.from({ length: 3 }).map((_, i) => (
                  <Card key={i} style={{ padding: 12 }}>
                    <Row style={{ gap: 4, marginBottom: 7 }}><Chip>Open</Chip><Chip style={{ color: AC, borderColor: AC }}>{['FIXED', 'CLOB', 'LMSR'][i]}</Chip></Row>
                    <Text size={12} style={{ fontWeight: 600, marginBottom: 9, height: 30, overflow: 'hidden' }}>Will the bill pass committee?</Text>
                    <Row style={{ justifyContent: 'space-between', alignItems: 'center' }}><span style={{ fontSize: 18, fontWeight: 800, color: AC }}>6{i}%</span><Sparkline points={[50, 52, 49, 55, 58, 62]} color={AC} /></Row>
                  </Card>
                ))}
              </div>
            </div>
          ))}
          <Ann n={2}>IA: browse-by-topic; categories + communities as first-class nav</Ann>
        </div>
      </div>
    </Dark>
  );

  // A3 — Terminal dashboard
  window.WFAlt.Terminal = () => (
    <Dark>
      <div style={{ display: 'flex', height: '100%' }}>
        <AltSidebar active="Markets" />
        <div style={{ flex: 1, padding: '16px 20px', overflow: 'hidden' }}>
          <Row style={{ gap: 12, marginBottom: 14 }}>
            {[['Portfolio', '5,430', 180], ['Available', '4,250', 0], ['Open positions', '12', 0], ['Today P&L', '+180', 180]].map(([l, v, d], i) => (
              <Box key={l} style={{ flex: 1, padding: '10px 13px', borderColor: 'var(--wf-faint)' }}><div style={cap}>{l}</div><Row style={{ justifyContent: 'space-between', alignItems: 'baseline', marginTop: 3 }}><span style={{ fontSize: 18, fontWeight: 800 }}>{v}</span>{d ? chg(d) : null}</Row></Box>
            ))}
          </Row>
          <Card style={{ padding: 0 }}>
            <Row style={{ justifyContent: 'space-between', padding: '10px 14px', borderBottom: '1.5px solid var(--wf-faint)' }}>
              {['MARKET', 'MECH', 'CHANCE', '24H', 'VOLUME', 'CLOSES', ''].map((h) => <Text key={h} size={10} soft style={{ flex: h === 'MARKET' ? 2 : 1 }}>{h}</Text>)}
            </Row>
            {[[62, 4], [54, -2], [71, 9], [48, 1], [33, -5], [60, 3]].map(([v, d], i) => (
              <Row key={i} style={{ padding: '11px 14px', borderBottom: '1px solid var(--wf-faint)', alignItems: 'center' }}>
                <Text size={12} style={{ flex: 2 }}>Will the proposal pass before Q{i}?</Text>
                <div style={{ flex: 1 }}><Chip style={{ color: AC, borderColor: AC }}>{['FIXED', 'CLOB', 'LMSR', 'PARI'][i % 4]}</Chip></div>
                <div style={{ flex: 1 }}><span style={{ fontSize: 14, fontWeight: 800, color: AC }}>{v}%</span></div>
                <div style={{ flex: 1 }}>{chg(d)}</div>
                <Text size={11.5} soft style={{ flex: 1 }}>{120 - i * 8}k</Text>
                <Text size={11.5} soft style={{ flex: 1 }}>{i + 2}d</Text>
                <div style={{ flex: 1 }}><Pill style={{ color: AC, borderColor: AC }}>Trade</Pill></div>
              </Row>
            ))}
          </Card>
          <Ann n={3} style={{ marginTop: 12 }}>IA: power-user dashboard — watchlist + sortable table + portfolio strip</Ann>
        </div>
      </div>
    </Dark>
  );

  // ════════════════ B · DETAIL & BETTING ════════════════
  // B1 — Trading terminal
  window.WFAlt.TradeTerminal = () => (
    <Dark>
      <AltBar active="Markets" />
      <div style={{ padding: '14px 20px' }}>
        <Row style={{ gap: 6, marginBottom: 8 }}><Chip>Open</Chip><Chip style={{ color: AC, borderColor: AC }}>CLOB</Chip><Text size={11} soft>· Politics · closes 6d</Text></Row>
        <Row style={{ justifyContent: 'space-between', marginBottom: 12 }}>
          <H size={18} style={{ color: 'var(--wf-ink)' }}>Will the proposal pass before Q3 2026?</H>
          <Row style={{ gap: 10, alignItems: 'baseline' }}><span style={{ fontSize: 26, fontWeight: 800, color: AC }}>54¢</span>{chg(2)}</Row>
        </Row>
        <div style={{ display: 'grid', gridTemplateColumns: '1.6fr 0.8fr 0.9fr', gap: 14 }}>
          {/* chart */}
          <Col gap={10}>
            <Chart points={[40, 44, 42, 48, 46, 52, 50, 55, 53, 58, 56, 54]} color={AC} h={210} />
            <Row style={{ gap: 0 }}>{[['24h vol', '24k'], ['Liquidity', '88k'], ['Holders', '146'], ['Spread', '3¢']].map(([l, v], i) => (<Col key={l} gap={2} style={{ flex: 1, borderLeft: i ? '1px solid var(--wf-faint)' : 0, paddingLeft: i ? 12 : 0 }}><div style={cap}>{l}</div><Text size={14}><b>{v}</b></Text></Col>))}</Row>
          </Col>
          {/* order book */}
          <Card style={{ padding: 12 }}>
            <Label style={{ marginBottom: 8 }}>Order book</Label>
            {[['57', 30], ['56', 55], ['55', 80]].map(([p, w], i) => (
              <Row key={'a' + i} style={{ justifyContent: 'space-between', position: 'relative', padding: '3px 0' }}><div style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: w + '%', background: 'var(--wf-warn-soft)' }} /><Text size={11.5} style={{ color: WC, zIndex: 1 }}>{p}¢</Text><Text size={11.5} soft style={{ zIndex: 1 }}>{w * 4}</Text></Row>
            ))}
            <Row style={{ justifyContent: 'center', padding: '5px 0' }}><Text size={11} soft>spread 3¢ · last 55¢</Text></Row>
            {[['54', 70], ['53', 45], ['52', 25]].map(([p, w], i) => (
              <Row key={'b' + i} style={{ justifyContent: 'space-between', position: 'relative', padding: '3px 0' }}><div style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: w + '%', background: 'var(--wf-accent-soft)' }} /><Text size={11.5} style={{ color: AC, zIndex: 1 }}>{p}¢</Text><Text size={11.5} soft style={{ zIndex: 1 }}>{w * 4}</Text></Row>
            ))}
          </Card>
          {/* ticket */}
          <Card style={{ padding: 12 }}>
            <Row style={{ gap: 6, marginBottom: 10 }}><Box style={{ flex: 1, textAlign: 'center', padding: '7px 0', borderWidth: 2, borderColor: POS, fontSize: 12 }}><b style={{ color: POS }}>Buy</b></Box><Box style={{ flex: 1, textAlign: 'center', padding: '7px 0', borderColor: 'var(--wf-faint)', fontSize: 12 }}><b style={{ color: 'var(--wf-soft)' }}>Sell</b></Box></Row>
            <Label style={{ marginBottom: 5 }}>Price ¢</Label><Field label="54" style={{ marginBottom: 8 }} />
            <Label style={{ marginBottom: 5 }}>Quantity</Label><Field label="10" style={{ marginBottom: 8 }} />
            <Row style={{ gap: 5, marginBottom: 10 }}><Pill active>GTC</Pill><Pill>IOC</Pill><Pill>FOK</Pill></Row>
            <Box style={{ padding: 9, background: 'var(--wf-fill)', borderColor: 'var(--wf-faint)', marginBottom: 10 }}><Row style={{ justifyContent: 'space-between' }}><Text size={11} soft>Cost</Text><Text size={12}><b>540</b></Text></Row><Row style={{ justifyContent: 'space-between' }}><Text size={11} soft>Max payout</Text><Text size={12}><b>1,000</b></Text></Row></Box>
            <Btn primary style={{ width: '100%', justifyContent: 'center', background: POS, borderColor: POS, color: '#06140d' }}>Buy 10 @ 54¢</Btn>
          </Card>
        </div>
        <Ann n={1} style={{ marginTop: 10 }}>B1: full trading terminal — chart · order book · ticket (best for CLOB)</Ann>
      </div>
    </Dark>
  );

  // B2 — Chart-dominant compact
  window.WFAlt.ChartCompact = () => (
    <Dark style={{ padding: 0 }}>
      <AltBar active="Markets" />
      <div style={{ padding: '20px 26px', maxWidth: 760, margin: '0 auto' }}>
        <Row style={{ gap: 6, marginBottom: 8 }}><Chip>Open</Chip><Chip style={{ color: AC, borderColor: AC }}>FIXED-ODDS</Chip></Row>
        <H size={20} style={{ color: 'var(--wf-ink)', marginBottom: 14 }}>Will the proposal pass before Q3 2026?</H>
        <Row style={{ gap: 12, alignItems: 'baseline', marginBottom: 12 }}><span style={{ fontSize: 40, fontWeight: 800, color: AC }}>62%</span>{chg(4)}<Text size={12} soft>YES chance · live</Text></Row>
        <Chart points={[44, 47, 45, 50, 53, 51, 49, 55, 58, 56, 60, 62]} color={AC} h={200} style={{ marginBottom: 16 }} />
        <Row style={{ gap: 10, marginBottom: 16 }}>{[['24h vol', '24k'], ['Liquidity', '88k'], ['Holders', '146']].map(([l, v], i) => (<Box key={l} style={{ flex: 1, padding: '10px 12px', borderColor: 'var(--wf-faint)' }}><div style={cap}>{l}</div><Text size={15}><b>{v}</b></Text></Box>))}</Row>
        <Card>
          <Row style={{ gap: 10 }}>
            <Box style={{ flex: 1, textAlign: 'center', padding: '12px 0', borderWidth: 2, borderColor: AC }}><b style={{ color: AC }}>YES 62%</b><div style={{ fontSize: 10, color: 'var(--wf-soft)' }}>pays 1.61×</div></Box>
            <Box style={{ flex: 1, textAlign: 'center', padding: '12px 0', borderColor: 'var(--wf-faint)' }}><b style={{ color: WC }}>NO 38%</b><div style={{ fontSize: 10, color: 'var(--wf-soft)' }}>pays 2.63×</div></Box>
          </Row>
          <Row style={{ gap: 10, marginTop: 12, alignItems: 'center' }}><Field label="Stake 100" style={{ flex: 1 }} /><Btn primary style={{ background: AC, borderColor: AC, color: '#06121d' }}>Place bet · win 161</Btn></Row>
        </Card>
        <Row style={{ gap: 8, marginTop: 12 }}><Pill>Details ▾</Pill><Pill>Resolution ▾</Pill><Pill>Activity ▾</Pill></Row>
        <Ann n={2} style={{ marginTop: 12 }}>B2: chart-dominant, calm; details collapse (best for fixed-odds/casual)</Ann>
      </div>
    </Dark>
  );

  // B3 — Mobile terminal
  window.WFAlt.MobileTrade = () => (
    <Dark>
      <div className="wf-row" style={{ justifyContent: 'space-between', padding: '10px 16px', height: 30, fontSize: 11, fontWeight: 700 }}><span>9:41</span><span style={{ fontSize: 10 }}>▮▮▮ ◗</span></div>
      <div style={{ padding: '4px 16px 150px' }}>
        <Row style={{ justifyContent: 'space-between', marginBottom: 8 }}><Text size={12} soft>‹ Back</Text><Text size={13}>★ ⋯</Text></Row>
        <Row style={{ gap: 5, marginBottom: 8 }}><Chip>Open</Chip><Chip style={{ color: AC, borderColor: AC }}>CLOB</Chip></Row>
        <Text size={15} style={{ fontWeight: 700, marginBottom: 10, color: 'var(--wf-ink)' }}>Will the proposal pass before Q3?</Text>
        <Row style={{ gap: 10, alignItems: 'baseline', marginBottom: 10 }}><span style={{ fontSize: 30, fontWeight: 800, color: AC }}>54¢</span>{chg(2)}</Row>
        <Chart points={[42, 46, 44, 50, 48, 53, 51, 55, 54]} color={AC} h={150} frames={['1H', '1D', '1W', 'ALL']} style={{ marginBottom: 12 }} />
        <Row style={{ gap: 8 }}>{[['Vol', '24k'], ['Spread', '3¢'], ['Holders', '146']].map(([l, v]) => (<Box key={l} style={{ flex: 1, padding: '8px 0', textAlign: 'center', borderColor: 'var(--wf-faint)' }}><div style={{ ...cap, fontSize: 9 }}>{l}</div><Text size={12}><b>{v}</b></Text></Box>))}</Row>
      </div>
      <div style={{ position: 'absolute', bottom: 56, left: 0, right: 0, background: '#161c28', borderTop: '1.5px solid var(--wf-line)', borderRadius: '14px 14px 0 0', padding: '12px 16px' }}>
        <div style={{ display: 'flex', justifyContent: 'center', paddingBottom: 8 }}><div style={{ width: 90, height: 5, borderRadius: 3, background: 'var(--wf-faint)' }} /></div>
        <Row style={{ gap: 8, marginBottom: 8 }}><Box style={{ flex: 1, textAlign: 'center', padding: '8px 0', borderWidth: 2, borderColor: POS, fontSize: 12 }}><b style={{ color: POS }}>Buy YES</b></Box><Box style={{ flex: 1, textAlign: 'center', padding: '8px 0', borderColor: 'var(--wf-faint)', fontSize: 12 }}><b style={{ color: 'var(--wf-soft)' }}>Buy NO</b></Box></Row>
        <Row style={{ gap: 8 }}><Field label="54¢" style={{ width: 70 }} /><Field label="Qty 10" style={{ flex: 1 }} /><Btn primary style={{ background: POS, borderColor: POS, color: '#06140d' }}>Buy</Btn></Row>
      </div>
      <AltTabBar active="Trade" />
      <Ann n={3} style={{ position: 'absolute', left: -2, bottom: 210, transform: 'rotate(-3deg)' }}>B3: mobile terminal — chart + sheet</Ann>
    </Dark>
  );

  // ════════════════ C · SUPPORTING (structure holds) ════════════════
  window.WFAlt.Portfolio = () => (
    <Dark>
      <AltBar active="Home" items={['Home', 'Markets', 'Portfolio', 'Leaderboard']} />
      <div style={{ padding: '20px 26px' }}>
        <Row style={{ justifyContent: 'space-between', marginBottom: 14, alignItems: 'flex-end' }}>
          <Col gap={4}><Text soft size={12}>Portfolio value</Text><Row style={{ gap: 12, alignItems: 'baseline' }}><span style={{ fontSize: 34, fontWeight: 800, color: 'var(--wf-ink)' }}>5,430</span>{chg(180)}<Text size={12} soft>today</Text></Row></Col>
          <Btn primary style={{ background: AC, borderColor: AC, color: '#06121d' }}>Request faucet</Btn>
        </Row>
        <Chart points={[30, 35, 33, 40, 44, 42, 48, 52, 50, 56, 54, 60]} color={POS} h={160} style={{ marginBottom: 18 }} />
        <Label style={{ marginBottom: 10 }}>Open positions</Label>
        <Card style={{ padding: 0 }}>
          <Row style={{ padding: '10px 14px', borderBottom: '1.5px solid var(--wf-faint)' }}>{['MARKET', 'SIDE', 'QTY', 'AVG', 'NOW', 'P&L'].map((h) => <Text key={h} size={10} soft style={{ flex: h === 'MARKET' ? 2 : 1 }}>{h}</Text>)}</Row>
          {[[10, -1], [40, 2], [25, -1]].map(([q, d], i) => (
            <Row key={i} style={{ padding: '11px 14px', borderBottom: '1px solid var(--wf-faint)', alignItems: 'center' }}>
              <Text size={12} style={{ flex: 2 }}>Will the proposal pass before Q{i}?</Text>
              <Text size={11.5} style={{ flex: 1, color: i % 2 ? WC : AC }}>{i % 2 ? 'NO' : 'YES'}</Text>
              <Text size={11.5} soft style={{ flex: 1 }}>{q * 10}</Text><Text size={11.5} soft style={{ flex: 1 }}>5{i}¢</Text><Text size={11.5} soft style={{ flex: 1 }}>6{i}¢</Text>
              <div style={{ flex: 1 }}>{chg(d * 90)}</div>
            </Row>
          ))}
        </Card>
        <Ann n={1} style={{ marginTop: 12 }}>C: same dark system → portfolio with equity curve</Ann>
      </div>
    </Dark>
  );

  window.WFAlt.Leaderboard = () => (
    <Dark>
      <AltBar active="Leaderboard" items={['Home', 'Markets', 'Portfolio', 'Leaderboard']} />
      <div style={{ padding: '20px 26px' }}>
        <H size={22} style={{ color: 'var(--wf-ink)', marginBottom: 4 }}>Leaderboard</H>
        <Text soft style={{ marginBottom: 16, fontSize: 12 }}>Net P&L across all mechanisms · this week</Text>
        <Row style={{ gap: 6, marginBottom: 14 }}><Pill active>All time</Pill><Pill>This week</Pill><Pill>By community</Pill></Row>
        <Card style={{ padding: 0 }}>
          <Row style={{ padding: '10px 16px', borderBottom: '1.5px solid var(--wf-faint)' }}>{['#', 'PLAYER', 'NET P&L', 'VOLUME', 'WIN', 'TREND'].map((h) => <Text key={h} size={10} soft style={{ flex: h === 'PLAYER' ? 2 : 1 }}>{h}</Text>)}</Row>
          {Array.from({ length: 8 }).map((_, i) => (
            <Row key={i} style={{ padding: '11px 16px', borderBottom: '1px solid var(--wf-faint)', alignItems: 'center', background: i === 3 ? 'var(--wf-accent-soft)' : 'transparent' }}>
              <Text size={12.5} style={{ flex: 1, fontWeight: 700, color: i < 3 ? WC : 'var(--wf-ink)' }}>{i + 1}</Text>
              <Row style={{ flex: 2, gap: 8 }}><Avatar size={22} /><Text size={12}>player_{i}{i === 3 ? ' (you)' : ''}</Text></Row>
              <Text size={12} style={{ flex: 1, color: POS }}>+{2200 - i * 180}</Text>
              <Text size={11.5} soft style={{ flex: 1 }}>{20 - i}k</Text><Text size={11.5} soft style={{ flex: 1 }}>{64 - i * 2}%</Text>
              <div style={{ flex: 1 }}><Sparkline points={[40, 44, 42, 50, 48, 55].map((x) => x + i)} color={POS} w={56} h={18} /></div>
            </Row>
          ))}
        </Card>
      </div>
    </Dark>
  );
})();
