// wireframes-backoffice.jsx — operator console low-fi screens.
// Wireframes stay grayscale; the hi-fi backoffice is the dark+gold theme.
// Registered on window.WFBo.
(function () {
  const { Screen, Box, Line, Lines, Btn, Pill, Chip, Card, Field, Label, H, Text, Divider, Row, Col, Ann, BoSidebar } = window.WF;
  const A = '#356b8a', G = '#9a6a1e';
  const cap = { fontSize: 10.5, fontWeight: 600, letterSpacing: '.04em', textTransform: 'uppercase', color: 'var(--wf-soft)' };

  const Frame = ({ active, children }) => (
    <Screen>
      <div style={{ display: 'flex', height: '100%' }}>
        <BoSidebar active={active} />
        <div style={{ flex: 1, padding: '18px 22px', overflow: 'hidden' }}>{children}</div>
      </div>
    </Screen>
  );

  window.WFBo = {};

  // ── Dashboard ──────────────────────────────────────────────────────────────
  window.WFBo.Dashboard = () => (
    <Frame active="Dashboard">
      <H size={20} style={{ marginBottom: 4 }}>Operations dashboard</H>
      <Text soft style={{ marginBottom: 16 }}>House exposure, open markets &amp; pending actions</Text>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 12, marginBottom: 16 }}>
        {[['Open markets', '17'], ['House liability', '54,200'], ['Pending faucets', '5'], ['24h volume', '312k']].map(([l, v], i) => (
          <Box key={l} style={{ padding: '12px 14px', borderColor: i === 2 ? G : 'var(--wf-faint)' }}>
            <div style={cap}>{l}</div><div style={{ fontSize: 22, fontWeight: 800, marginTop: 3, color: i === 2 ? G : 'var(--wf-ink)' }}>{v}</div>
          </Box>
        ))}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 16 }}>
        <Card>
          <Row style={{ justifyContent: 'space-between', marginBottom: 10 }}><Label>Markets needing attention</Label><Btn primary style={{ background: G, borderColor: G }}>+ New market</Btn></Row>
          <Row style={{ justifyContent: 'space-between', padding: '7px 0', borderBottom: '1.5px solid var(--wf-faint)' }}>{['MARKET', 'MECH', 'STATUS', 'LIABILITY', ''].map((h) => <Text key={h} size={10.5} soft>{h}</Text>)}</Row>
          {[['Closed — settle now', 'closed', G], ['Open', 'open', A], ['Open', 'open', A], ['Draft — needs legs', 'draft', 'var(--wf-soft)']].map(([s, st, c], i) => (
            <Row key={i} style={{ justifyContent: 'space-between', padding: '9px 0', borderBottom: '1px solid var(--wf-faint)', alignItems: 'center' }}>
              <Line w="30%" /><Text size={11} soft>CLOB</Text>
              <span className="wf-chip" style={{ color: c, borderColor: 'currentColor' }}>{st}</span>
              <Text size={11} soft>8,200</Text><Text size={11} style={{ color: G }}>{i === 0 ? 'Settle ›' : 'View ›'}</Text>
            </Row>
          ))}
        </Card>
        <Col gap={14}>
          <Card style={{ borderColor: G }}>
            <Label style={{ marginBottom: 8 }}>Pending faucet requests · 5</Label>
            {[0, 1].map((i) => (
              <Row key={i} style={{ justifyContent: 'space-between', padding: '7px 0', borderBottom: '1px solid var(--wf-faint)', alignItems: 'center' }}>
                <Col gap={2}><Text size={11.5}><b>{`player_${i}`}</b></Text><Text size={10} soft>1,000 ADIV · 2h ago</Text></Col>
                <Row style={{ gap: 5 }}><Pill style={{ color: 'var(--wf-pos)', borderColor: 'var(--wf-pos)' }}>Approve</Pill><Pill>Reject</Pill></Row>
              </Row>
            ))}
            <Text size={11} style={{ color: G, marginTop: 8 }}>Review all ›</Text>
          </Card>
          <Card><Label style={{ marginBottom: 8 }}>Recent audit events</Label><Lines n={4} last="50%" /></Card>
        </Col>
      </div>
      <Ann n={1} style={{ marginTop: 12 }}>Dark + gold theme in hi-fi · this is the operator’s “mission control”</Ann>
    </Frame>
  );

  // ── Market create + mechanism config ─────────────────────────────────────────
  window.WFBo.Create = () => (
    <Frame active="Markets">
      <Row style={{ justifyContent: 'space-between', marginBottom: 14 }}><H size={20}>New market</H><Row style={{ gap: 6 }}><Field label="Template: Binary YES/NO ▾" style={{ width: 200 }} /></Row></Row>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 300px', gap: 18 }}>
        <Col gap={14}>
          <Card>
            <Label style={{ marginBottom: 10 }}>Question &amp; details</Label>
            <Field label="Market question" style={{ marginBottom: 8 }} />
            <Box className="wf-field" style={{ height: 56, alignItems: 'flex-start', paddingTop: 8 }}><Text size={12} soft>Description…</Text></Box>
            <Row style={{ gap: 8, marginTop: 8 }}><Field label="Category: Politics ▾" /><Field label="Tags: #senate #policy" /></Row>
          </Card>
          <Card>
            <Label style={{ marginBottom: 10 }}>Mechanism</Label>
            <Row style={{ gap: 7, marginBottom: 12 }}>
              <Box style={{ flex: 1, textAlign: 'center', padding: '9px 0', borderWidth: 2, borderColor: G, fontSize: 11.5 }}><b style={{ color: G }}>Fixed-odds</b></Box>
              <Box style={{ flex: 1, textAlign: 'center', padding: '9px 0', borderColor: 'var(--wf-faint)', fontSize: 11.5 }}>CLOB</Box>
              <Box style={{ flex: 1, textAlign: 'center', padding: '9px 0', borderColor: 'var(--wf-faint)', fontSize: 11.5 }}>LMSR</Box>
              <Box style={{ flex: 1, textAlign: 'center', padding: '9px 0', borderColor: 'var(--wf-faint)', fontSize: 11.5 }}>Parimutuel</Box>
            </Row>
            <Box dashed style={{ padding: 12, borderColor: G, background: 'var(--wf-warn-soft)' }}>
              <Text size={11} soft style={{ marginBottom: 8 }}>Conditional fields — fixed-odds (F-006):</Text>
              <Row style={{ gap: 8 }}><Field label="Liability cap: 50,000" /><Field label="Fee bps: 100" /></Row>
              <Ann style={{ marginTop: 8 }}>fields swap per mechanism (taker_fee / subsidy / takeout)</Ann>
            </Box>
          </Card>
          <Card>
            <Label style={{ marginBottom: 10 }}>Outcomes (exactly 2 — DB enforced)</Label>
            <Row style={{ gap: 8 }}><Field label="Leg A label: YES" /><Field label="Opening odds: 50%" /></Row>
            <Row style={{ gap: 8, marginTop: 8 }}><Field label="Leg B label: NO" /><Field label="Opening odds: 50%" /></Row>
          </Card>
          <Card>
            <Label style={{ marginBottom: 10 }}>Resolution</Label>
            <Row style={{ gap: 8 }}><Field label="Closes at: date/time" /><Field label="Source: Official register" /></Row>
            <Box className="wf-field" style={{ height: 44, marginTop: 8, alignItems: 'flex-start', paddingTop: 8 }}><Text size={12} soft>Resolution criteria…</Text></Box>
          </Card>
        </Col>
        <Col gap={12}>
          <Card style={{ position: 'sticky', top: 8 }}>
            <Label style={{ marginBottom: 8 }}>Live preview</Label>
            <Box style={{ padding: 11, borderColor: 'var(--wf-faint)' }}>
              <Row style={{ gap: 4, marginBottom: 7 }}><Chip>Draft</Chip><Chip style={{ color: A, borderColor: A }}>FIXED-ODDS</Chip></Row>
              <Lines n={2} last="60%" />
              <Row style={{ gap: 6, marginTop: 9 }}><Box style={{ flex: 1, textAlign: 'center', padding: '6px 0', borderColor: 'var(--wf-faint)', fontSize: 12 }}><b style={{ color: A }}>50%</b></Box><Box style={{ flex: 1, textAlign: 'center', padding: '6px 0', borderColor: 'var(--wf-faint)', fontSize: 12 }}><b style={{ color: G }}>50%</b></Box></Row>
            </Box>
            <Btn primary style={{ width: '100%', justifyContent: 'center', marginTop: 12, background: G, borderColor: G }}>Save draft</Btn>
            <Btn ghost style={{ width: '100%', justifyContent: 'center', marginTop: 8 }}>Save &amp; open</Btn>
            <Ann n={2} style={{ marginTop: 10 }}>preview updates as form changes (F-006)</Ann>
          </Card>
        </Col>
      </div>
    </Frame>
  );

  // ── Settle market ────────────────────────────────────────────────────────────
  window.WFBo.Settle = () => (
    <Frame active="Markets">
      <Text size={11.5} soft style={{ marginBottom: 8 }}>‹ Markets</Text>
      <Row style={{ gap: 5, marginBottom: 8 }}><Chip style={{ color: G, borderColor: G }}>Closed</Chip><Chip style={{ color: A, borderColor: A }}>FIXED-ODDS</Chip></Row>
      <H size={19} style={{ marginBottom: 12 }}>Will the proposal pass before Q3 2026?</H>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 320px', gap: 18 }}>
        <Col gap={14}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 10 }}>
            {[['Volume', '128k'], ['Bets', '342'], ['YES exposure', '40k'], ['NO exposure', '14k']].map(([l, v]) => (
              <Box key={l} style={{ padding: '9px 11px', borderColor: 'var(--wf-faint)' }}><div style={cap}>{l}</div><div style={{ fontSize: 15, fontWeight: 700, marginTop: 3 }}>{v}</div></Box>
            ))}
          </div>
          <Card>
            <Label style={{ marginBottom: 8 }}>Bets ledger (read-only)</Label>
            <Row style={{ justifyContent: 'space-between', padding: '6px 0', borderBottom: '1.5px solid var(--wf-faint)' }}>{['PLAYER', 'SIDE', 'STAKE', 'STATUS'].map((h) => <Text key={h} size={10.5} soft>{h}</Text>)}</Row>
            {Array.from({ length: 5 }).map((_, i) => (
              <Row key={i} style={{ justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid var(--wf-faint)' }}>
                <Line w="30%" /><Text size={11}>{i % 2 ? 'NO' : 'YES'}</Text><Text size={11}>500</Text><span className="wf-chip">open</span>
              </Row>
            ))}
          </Card>
          <Card><Label style={{ marginBottom: 8 }}>Edit details (metadata only once open — DD-007)</Label><Row style={{ gap: 8 }}><Field label="Close at" /><Field label="Source" /></Row></Card>
        </Col>
        <Col gap={12}>
          <Card style={{ borderColor: G }}>
            <Label style={{ marginBottom: 10 }}>Settle market</Label>
            <Text size={11.5} soft style={{ marginBottom: 10 }}>Declare the winning outcome. Payouts credit automatically. Irreversible.</Text>
            <Row style={{ gap: 8, marginBottom: 12 }}>
              <Box style={{ flex: 1, textAlign: 'center', padding: '12px 0', borderWidth: 2, borderColor: A }}><b style={{ color: A }}>YES wins</b></Box>
              <Box style={{ flex: 1, textAlign: 'center', padding: '12px 0', borderColor: 'var(--wf-faint)' }}><b>NO wins</b></Box>
            </Row>
            <Box style={{ padding: 10, background: 'var(--wf-warn-soft)', borderColor: 'var(--wf-faint)', marginBottom: 12 }}>
              <Text size={11} soft>Will pay <b style={{ color: 'var(--wf-ink)' }}>211 winning bets</b> · credit <b style={{ color: 'var(--wf-ink)' }}>64,400 ADIV</b></Text>
            </Box>
            <Btn primary style={{ width: '100%', justifyContent: 'center', background: G, borderColor: G }}>Confirm settlement</Btn>
            <Ann n={3} style={{ marginTop: 10 }}>two-step confirm — destructive action guard</Ann>
          </Card>
          <Card><Label style={{ marginBottom: 6 }}>Lifecycle</Label><Row style={{ gap: 4, alignItems: 'center', fontSize: 11 }}><span className="wf-chip">draft</span>›<span className="wf-chip">open</span>›<span className="wf-chip" style={{ color: G, borderColor: G }}>closed</span>›<span className="wf-chip">settled</span></Row></Card>
        </Col>
      </div>
    </Frame>
  );

  // ── Faucet review ──────────────────────────────────────────────────────────────
  window.WFBo.Faucet = () => (
    <Frame active="Faucet Requests">
      <H size={20} style={{ marginBottom: 4 }}>Faucet requests</H>
      <Text soft style={{ marginBottom: 14 }}>Approve or reject play-money top-ups</Text>
      <Row style={{ gap: 6, marginBottom: 14 }}><Pill active>Pending · 5</Pill><Pill>Approved</Pill><Pill>Rejected</Pill></Row>
      <Card style={{ padding: 0 }}>
        <Row style={{ justifyContent: 'space-between', padding: '11px 16px', borderBottom: '1.5px solid var(--wf-faint)' }}>{['PLAYER', 'AMOUNT', 'CURRENT BAL', 'REASON', 'REQUESTED', 'ACTION'].map((h) => <Text key={h} size={10.5} soft>{h}</Text>)}</Row>
        {Array.from({ length: 5 }).map((_, i) => (
          <Row key={i} style={{ justifyContent: 'space-between', padding: '12px 16px', borderBottom: '1px solid var(--wf-faint)', alignItems: 'center' }}>
            <Row style={{ gap: 8, width: 130 }}><div style={{ width: 22, height: 22, borderRadius: '50%', border: '1.5px solid var(--wf-line)', background: 'var(--wf-fill)' }} /><Text size={12}>{`player_${i}`}</Text></Row>
            <Text size={12}><b>1,000</b></Text><Text size={12} soft>{i * 250}</Text>
            <div style={{ width: 130 }}><Line w="80%" /></div><Text size={11} soft>{i + 1}h ago</Text>
            <Row style={{ gap: 6 }}><Btn primary style={{ background: 'var(--wf-pos)', borderColor: 'var(--wf-pos)', padding: '5px 12px', fontSize: 12 }}>Approve</Btn><Btn ghost style={{ padding: '5px 12px', fontSize: 12 }}>Reject</Btn></Row>
          </Row>
        ))}
      </Card>
      <Ann n={4} style={{ marginTop: 12 }}>Approve → ledger credit + audit event. Bulk approve optional.</Ann>
    </Frame>
  );
})();
