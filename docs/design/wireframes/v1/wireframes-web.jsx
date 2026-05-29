// wireframes-web.jsx — customer web (desktop) low-fi screens.
// Each export is a function component; registered on window.WFWeb.
(function () {
  const {
    Screen, Box, Img, Line, Lines, Btn, Pill, Chip, Card, Field, Label, H, Text,
    Divider, Row, Col, Avatar, Ann, WebBar, Chart, Sparkline,
  } = window.WF;

  const A = '#356b8a';
  const cap = { fontSize: 11, fontWeight: 600, letterSpacing: '.04em', textTransform: 'uppercase', color: 'var(--wf-soft)' };

  // shared market card
  const MarketCard = ({ mech = 'FIXED-ODDS', yes = '62%', no = '38%' }) => (
    <Card style={{ padding: 13 }}>
      <Row style={{ gap: 5, marginBottom: 9 }}>
        <Chip>Open</Chip><Chip>Politics</Chip><Chip style={{ color: A, borderColor: A }}>{mech}</Chip>
      </Row>
      <div style={{ fontSize: 13.5, fontWeight: 700, lineHeight: 1.3, marginBottom: 10, height: 36, overflow: 'hidden' }}>Will the proposal pass before the end of Q3 2026?</div>
      <Row style={{ gap: 8, marginBottom: 11 }}>
        <Box style={{ flex: 1, textAlign: 'center', padding: '8px 0', borderColor: 'var(--wf-faint)' }}>
          <div style={{ fontSize: 10, color: 'var(--wf-soft)' }}>YES</div>
          <div style={{ fontSize: 19, fontWeight: 800, color: A }}>{yes}</div>
        </Box>
        <Box style={{ flex: 1, textAlign: 'center', padding: '8px 0', borderColor: 'var(--wf-faint)' }}>
          <div style={{ fontSize: 10, color: 'var(--wf-soft)' }}>NO</div>
          <div style={{ fontSize: 19, fontWeight: 800, color: 'var(--wf-warn)' }}>{no}</div>
        </Box>
      </Row>
      <Row style={{ justifyContent: 'space-between', alignItems: 'center' }}>
        <Text size={10.5} soft>Vol 128k</Text>
        <Sparkline points={[48, 50, 47, 52, 55, 53, 58, 62]} />
        <Text size={10.5} soft>Closes 6d</Text>
      </Row>
    </Card>
  );

  // ── 1. Discovery / browse ────────────────────────────────────────────────
  window.WFWeb = window.WFWeb || {};

  window.WFWeb.Browse = () => (
    <Screen>
      <WebBar active="Markets" />
      <div style={{ padding: '20px 26px' }}>
        <Row style={{ justifyContent: 'space-between', marginBottom: 4 }}>
          <H size={24}>Markets</H>
          <Ann n={1}>SSE “live” dot pulses on open markets</Ann>
        </Row>
        <Text soft style={{ marginBottom: 16 }}>Browse, search and filter prediction markets</Text>

        <Row style={{ gap: 10, marginBottom: 14 }}>
          <Field label="⌕  Search markets, tags…" style={{ flex: 1, maxWidth: 380 }} />
          <Field label="Category ▾" style={{ width: 130 }} />
          <Field label="Mechanism ▾" style={{ width: 130 }} />
          <Field label="Status ▾" style={{ width: 110 }} />
          <div style={{ flex: 1 }} />
          <Field label="Sort: Volume ▾" style={{ width: 150 }} />
        </Row>
        <Row style={{ gap: 6, marginBottom: 18 }}>
          <Pill active>All</Pill><Pill>Politics</Pill><Pill>Sports</Pill><Pill>Crypto</Pill><Pill>Macro</Pill><Pill>Culture</Pill>
          <Ann style={{ marginLeft: 8 }}>category quick-filter chips</Ann>
        </Row>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 14 }}>
          <MarketCard mech="FIXED-ODDS" />
          <MarketCard mech="CLOB" yes="54¢" no="46¢" />
          <MarketCard mech="LMSR" yes="71%" no="29%" />
          <MarketCard mech="PARIMUTUEL" yes="48%" no="52%" />
          <MarketCard mech="FIXED-ODDS" yes="33%" no="67%" />
          <MarketCard mech="CLOB" yes="60¢" no="40¢" />
          <MarketCard mech="LMSR" yes="22%" no="78%" />
          <MarketCard mech="PARIMUTUEL" yes="50%" no="50%" />
        </div>

        <Row style={{ justifyContent: 'center', gap: 8, marginTop: 18 }}>
          <Btn ghost>‹ Prev</Btn><Pill active>1</Pill><Pill>2</Pill><Pill>3</Pill><Btn ghost>Next ›</Btn>
          <Ann n={2} style={{ marginLeft: 10 }}>12 per page (F-017)</Ann>
        </Row>
      </div>
    </Screen>
  );

  // ── 2. Market detail (fixed-odds, full page) ──────────────────────────────
  window.WFWeb.MarketDetail = () => (
    <Screen>
      <WebBar active="Markets" />
      <div style={{ padding: '18px 26px', display: 'grid', gridTemplateColumns: '1fr 320px', gap: 22 }}>
        {/* main column */}
        <Col gap={14}>
          <Text size={11.5} soft>‹ All Markets</Text>
          <Row style={{ gap: 5 }}>
            <Chip>Open</Chip><Chip>Politics</Chip><Chip style={{ color: A, borderColor: A }}>FIXED-ODDS</Chip>
          </Row>
          <H size={22}>Will the proposal pass before the end of Q3 2026?</H>
          <Lines n={2} last="70%" />
          <Row style={{ gap: 5 }}><Chip style={{ textTransform: 'none', color: 'var(--wf-warn)', borderColor: 'var(--wf-warn-soft)' }}>#senate</Chip><Chip style={{ textTransform: 'none', color: 'var(--wf-warn)', borderColor: 'var(--wf-warn-soft)' }}>#policy</Chip></Row>

          <Row style={{ gap: 10 }}>
            {[['Volume', '128,400'], ['Open positions', '342'], ['Creator', 'mod_jane'], ['Closes in', '6d 4h']].map(([l, v]) => (
              <Box key={l} style={{ flex: 1, padding: '9px 11px', borderColor: 'var(--wf-faint)' }}>
                <div style={cap}>{l}</div><div style={{ fontSize: 15, fontWeight: 700, marginTop: 3 }}>{v}</div>
              </Box>
            ))}
          </Row>

          <Card>
            <Row style={{ justifyContent: 'space-between', marginBottom: 12 }}>
              <Row style={{ gap: 10, alignItems: 'baseline' }}>
                <span style={{ fontSize: 30, fontWeight: 800, color: A }}>62%</span>
                <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--wf-pos)' }}>▲ 4 pts today</span>
                <Text size={12} soft>YES chance</Text>
              </Row>
              <Pill style={{ fontSize: 10 }}>● live · SSE</Pill>
            </Row>
            <Chart points={[44, 47, 45, 50, 53, 51, 49, 55, 58, 56, 60, 62]} h={150} style={{ marginBottom: 12 }} />
            <Row style={{ gap: 10 }}>
              <Box style={{ flex: 1, textAlign: 'center', padding: '11px 0', borderWidth: 2, borderColor: A }}>
                <div style={{ fontSize: 11, color: 'var(--wf-soft)' }}>YES</div>
                <div style={{ fontSize: 26, fontWeight: 800, color: A }}>62%</div>
                <div style={{ fontSize: 10, color: 'var(--wf-soft)' }}>62.0¢ · pays 1.61×</div>
              </Box>
              <Box style={{ flex: 1, textAlign: 'center', padding: '11px 0', borderColor: 'var(--wf-faint)' }}>
                <div style={{ fontSize: 11, color: 'var(--wf-soft)' }}>NO</div>
                <div style={{ fontSize: 26, fontWeight: 800, color: 'var(--wf-warn)' }}>38%</div>
                <div style={{ fontSize: 10, color: 'var(--wf-soft)' }}>38.0¢ · pays 2.63×</div>
              </Box>
            </Row>
            <Row style={{ gap: 0, marginTop: 12, borderTop: '1.5px solid var(--wf-faint)', paddingTop: 10 }}>
              {[['24h volume', '24,180'], ['Liquidity', '88,400'], ['Holders', '146'], ['24h trades', '512']].map(([l, v], i) => (
                <Col key={l} gap={2} style={{ flex: 1, borderLeft: i ? '1px solid var(--wf-faint)' : 0, paddingLeft: i ? 12 : 0 }}>
                  <div style={{ ...cap, fontSize: 9.5 }}>{l}</div><div style={{ fontSize: 15, fontWeight: 700 }}>{v}</div>
                </Col>
              ))}
            </Row>
            <Ann n={2} style={{ marginTop: 10 }}>price-history chart + decision stats (Polymarket/Kalshi benchmark)</Ann>
          </Card>

          <Card>
            <Row style={{ justifyContent: 'space-between', marginBottom: 8 }}><Label>Activity &amp; top holders</Label><Row style={{ gap: 5 }}><Pill active>Trades</Pill><Pill>Holders</Pill></Row></Row>
            {[['bought YES', '+120 @ 60¢', 'var(--wf-pos)'], ['sold NO', '−80 @ 41¢', 'var(--wf-neg)'], ['bought YES', '+50 @ 61¢', 'var(--wf-pos)']].map(([a, d, c], i) => (
              <Row key={i} style={{ justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid var(--wf-faint)', alignItems: 'center' }}>
                <Row style={{ gap: 8 }}><Avatar size={22} /><Text size={12}>player_{i} <span style={{ color: 'var(--wf-soft)' }}>{a}</span></Text></Row>
                <Text size={12} style={{ color: c }}>{d}</Text><Text size={10.5} soft>{i + 1}m ago</Text>
              </Row>
            ))}
          </Card>

          <Card>
            <Label style={{ marginBottom: 8 }}>Resolution details</Label>
            <Lines n={2} last="80%" />
            <Row style={{ marginTop: 8, gap: 16 }}><Text size={11.5} soft>Source: <b style={{ color: 'var(--wf-ink)' }}>Official register</b></Text><Text size={11.5} soft>Closes: Sep 30, 2026 · 23:59 UTC</Text></Row>
          </Card>

          <Card>
            <Label style={{ marginBottom: 8 }}>Your bets</Label>
            <Row style={{ justifyContent: 'space-between', padding: '6px 0', borderBottom: '1.5px solid var(--wf-faint)' }}>
              <Text size={11} soft>OUTCOME</Text><Text size={11} soft>STAKE</Text><Text size={11} soft>PAYOUT</Text><Text size={11} soft>STATUS</Text>
            </Row>
            {['YES', 'NO'].map((s, i) => (
              <Row key={i} style={{ justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid var(--wf-faint)' }}>
                <Text size={12}><b>{s}</b></Text><Text size={12}>500</Text><Text size={12}>806</Text>
                <span className="wf-chip" style={{ color: i ? 'var(--wf-pos)' : A, borderColor: 'currentColor' }}>{i ? 'Won' : 'Open'}</span>
              </Row>
            ))}
          </Card>
        </Col>

        {/* sticky bet rail */}
        <Col gap={12}>
          <Card style={{ position: 'sticky', top: 12 }}>
            <H size={15} style={{ marginBottom: 12 }}>Place a bet</H>
            <Row style={{ gap: 8, marginBottom: 12 }}>
              <Box style={{ flex: 1, textAlign: 'center', padding: '12px 0', borderWidth: 2, borderColor: A }}><b style={{ color: A }}>YES</b><div style={{ fontSize: 10, color: 'var(--wf-soft)' }}>62%</div></Box>
              <Box style={{ flex: 1, textAlign: 'center', padding: '12px 0', borderColor: 'var(--wf-faint)' }}><b>NO</b><div style={{ fontSize: 10, color: 'var(--wf-soft)' }}>38%</div></Box>
            </Row>
            <Label style={{ marginBottom: 5 }}>Stake (ADIV)</Label>
            <Field label="100" style={{ marginBottom: 8 }} />
            <Row style={{ gap: 6, marginBottom: 12 }}>{['+50', '+100', '+500', 'Max'].map((q) => <Pill key={q}>{q}</Pill>)}</Row>
            <Box style={{ padding: 10, borderColor: 'var(--wf-faint)', background: 'var(--wf-fill)', marginBottom: 12 }}>
              <Row style={{ justifyContent: 'space-between' }}><Text size={11.5} soft>Potential payout</Text><Text size={13}><b>161 ADIV</b></Text></Row>
              <Row style={{ justifyContent: 'space-between' }}><Text size={11.5} soft>Fee (1%)</Text><Text size={11.5} soft>1 ADIV</Text></Row>
            </Box>
            <Btn primary style={{ width: '100%', justifyContent: 'center' }}>Place bet</Btn>
            <Ann n={3} style={{ marginTop: 10 }}>Guest → “Sign in to bet” here</Ann>
          </Card>
          <Card>
            <Label style={{ marginBottom: 6 }}>Outcomes</Label>
            <Row style={{ justifyContent: 'space-between', padding: '5px 0' }}><Text size={12}><b>YES</b></Text><Text size={11.5} soft>62% implied</Text></Row>
            <Row style={{ justifyContent: 'space-between', padding: '5px 0' }}><Text size={12}><b>NO</b></Text><Text size={11.5} soft>38% implied</Text></Row>
          </Card>
        </Col>
      </div>
    </Screen>
  );

  // ── 3. Profile / wallet / faucet ──────────────────────────────────────────
  window.WFWeb.Profile = () => (
    <Screen>
      <WebBar active="Profile" />
      <div style={{ padding: '20px 26px' }}>
        <Row style={{ gap: 14, marginBottom: 18 }}>
          <Avatar size={52} />
          <Col gap={3}><H size={20}>player_alex</H><Text soft>Member since Mar 2026 · Rank #14</Text></Col>
          <div style={{ flex: 1 }} />
          <Box style={{ padding: '12px 18px', textAlign: 'right', borderColor: A }}>
            <div style={cap}>Wallet balance</div><div style={{ fontSize: 26, fontWeight: 800, color: A }}>4,250 ADIV</div>
          </Box>
        </Row>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 12, marginBottom: 18 }}>
          {[['Net P&L', '+1,180', 'pos'], ['Total bets', '37', ''], ['Win rate', '57%', ''], ['Volume', '12,400', '']].map(([l, v, t]) => (
            <Box key={l} style={{ padding: '12px 14px', borderColor: 'var(--wf-faint)' }}>
              <div style={cap}>{l}</div><div style={{ fontSize: 21, fontWeight: 800, marginTop: 3, color: t === 'pos' ? 'var(--wf-pos)' : 'var(--wf-ink)' }}>{v}</div>
            </Box>
          ))}
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 300px', gap: 18 }}>
          <Card>
            <Row style={{ justifyContent: 'space-between', marginBottom: 8 }}><Label>Bet history</Label><Row style={{ gap: 5 }}><Pill active>All</Pill><Pill>Open</Pill><Pill>Settled</Pill></Row></Row>
            <Row style={{ justifyContent: 'space-between', padding: '6px 0', borderBottom: '1.5px solid var(--wf-faint)' }}>
              {['MARKET', 'SIDE', 'STAKE', 'P&L', 'STATUS'].map((h) => <Text key={h} size={10.5} soft>{h}</Text>)}
            </Row>
            {Array.from({ length: 6 }).map((_, i) => (
              <Row key={i} style={{ justifyContent: 'space-between', padding: '9px 0', borderBottom: '1px solid var(--wf-faint)', alignItems: 'center' }}>
                <Line w="34%" /><Text size={11}>YES</Text><Text size={11}>500</Text>
                <Text size={11} style={{ color: i % 2 ? 'var(--wf-pos)' : 'var(--wf-neg)' }}>{i % 2 ? '+306' : '−500'}</Text>
                <span className="wf-chip">{i % 2 ? 'Won' : 'Lost'}</span>
              </Row>
            ))}
          </Card>
          <Col gap={14}>
            <Card style={{ borderColor: A }}>
              <Label style={{ marginBottom: 8 }}>Request faucet top-up</Label>
              <Text size={11.5} soft style={{ marginBottom: 10 }}>Out of ADIV? Request play-money. A moderator approves it.</Text>
              <Field label="Amount: 1,000" style={{ marginBottom: 8 }} />
              <Field label="Reason (optional)" style={{ marginBottom: 10 }} />
              <Btn primary style={{ width: '100%', justifyContent: 'center' }}>Request top-up</Btn>
              <Ann n={1} style={{ marginTop: 10 }}>Pending request → status banner</Ann>
            </Card>
            <Card>
              <Label style={{ marginBottom: 8 }}>Open positions</Label>
              {['Fixed-odds · 2', 'CLOB contracts · 40', 'Pool stakes · 1'].map((p) => (
                <Row key={p} style={{ justifyContent: 'space-between', padding: '6px 0' }}><Text size={12}>{p}</Text><Text size={11.5} soft>›</Text></Row>
              ))}
            </Card>
          </Col>
        </div>
      </div>
    </Screen>
  );

  // ── 4. Leaderboard ────────────────────────────────────────────────────────
  window.WFWeb.Leaderboard = () => (
    <Screen>
      <WebBar active="Leaderboard" />
      <div style={{ padding: '20px 26px' }}>
        <H size={24} style={{ marginBottom: 4 }}>Leaderboard</H>
        <Text soft style={{ marginBottom: 18 }}>Ranked by net P&amp;L across all market mechanisms (F-015)</Text>

        <Row style={{ gap: 14, marginBottom: 20, alignItems: 'flex-end' }}>
          {[['2', 88, 'silver'], ['1', 108, 'gold'], ['3', 72, 'bronze']].map(([rank, h], i) => (
            <Col key={i} gap={6} style={{ alignItems: 'center', flex: 1 }}>
              <Avatar size={i === 1 ? 46 : 38} />
              <Text size={12}><b>player_{['','one','','three'][i] || 'two'}</b></Text>
              <Text size={11} style={{ color: 'var(--wf-pos)' }}>+{(4 - i) * 900} P&amp;L</Text>
              <Box style={{ width: '100%', height: h, background: 'var(--wf-fill)', borderColor: 'var(--wf-faint)', display: 'flex', alignItems: 'flex-start', justifyContent: 'center', paddingTop: 8, fontWeight: 800, fontSize: 18, color: A }}>{rank}</Box>
            </Col>
          ))}
          <Ann n={1} style={{ flex: '0 0 130px' }}>Top-3 podium feature row</Ann>
        </Row>

        <Card style={{ padding: 0 }}>
          <Row style={{ justifyContent: 'space-between', padding: '11px 16px', borderBottom: '1.5px solid var(--wf-faint)' }}>
            {['#', 'PLAYER', 'NET P&L', 'VOLUME', 'WIN RATE', 'BETS'].map((h) => <Text key={h} size={10.5} soft>{h}</Text>)}
          </Row>
          {Array.from({ length: 7 }).map((_, i) => (
            <Row key={i} style={{ justifyContent: 'space-between', padding: '11px 16px', borderBottom: '1px solid var(--wf-faint)', alignItems: 'center', background: i === 3 ? 'var(--wf-accent-soft)' : 'transparent' }}>
              <Text size={12.5}><b>{i + 4}</b></Text>
              <Row style={{ gap: 8, width: 160 }}><Avatar size={22} /><Text size={12}>player_{i}{i === 3 ? '  (you)' : ''}</Text></Row>
              <Text size={12} style={{ color: 'var(--wf-pos)' }}>+{1400 - i * 130}</Text>
              <Text size={12} soft>{12 - i}k</Text><Text size={12} soft>{60 - i * 2}%</Text><Text size={12} soft>{40 - i * 3}</Text>
            </Row>
          ))}
        </Card>
      </div>
    </Screen>
  );

  // ── 5. Auth (sign in + register) ──────────────────────────────────────────
  window.WFWeb.Auth = () => (
    <Screen bg="#faf9f6">
      <WebBar active="" signedIn={false} />
      <div style={{ display: 'flex', justifyContent: 'center', gap: 26, padding: '46px 26px' }}>
        <Card style={{ width: 320, padding: 22 }}>
          <H size={19} style={{ marginBottom: 4 }}>Welcome back</H>
          <Text soft style={{ marginBottom: 18 }}>Sign in to bet and track positions</Text>
          <Label style={{ marginBottom: 5 }}>Email</Label><Field label="you@email.com" style={{ marginBottom: 12 }} />
          <Label style={{ marginBottom: 5 }}>Password</Label><Field label="••••••••" style={{ marginBottom: 16 }} />
          <Btn primary style={{ width: '100%', justifyContent: 'center', marginBottom: 12 }}>Sign in</Btn>
          <Text size={11.5} soft style={{ textAlign: 'center' }}>No account? <b style={{ color: A }}>Register</b></Text>
        </Card>
        <Col gap={10} style={{ width: 250, paddingTop: 8 }}>
          <Ann n={1}>Session-cookie auth (web + backoffice)</Ann>
          <Box dashed style={{ padding: 14, borderColor: 'var(--wf-faint)' }}>
            <Label style={{ marginBottom: 8 }}>New here? You get</Label>
            <Lines n={3} last="50%" />
            <Row style={{ gap: 6, marginTop: 10 }}><Chip style={{ color: A, borderColor: A }}>Faucet ADIV</Chip><Chip>No real money</Chip></Row>
          </Box>
          <Ann n={2}>First-run: prompt faucet request after register</Ann>
        </Col>
      </div>
    </Screen>
  );
})();
