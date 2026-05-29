// wireframes-mechanisms.jsx — the four betting mechanisms, side by side.
// Registered on window.WFMech.
(function () {
  const { Screen, Box, Line, Lines, Btn, Pill, Chip, Card, Field, Label, H, Text, Divider, Row, Col, Ann } = window.WF;
  const A = '#356b8a', W = '#9a6a1e';
  const cap = { fontSize: 10.5, fontWeight: 600, letterSpacing: '.04em', textTransform: 'uppercase', color: 'var(--wf-soft)' };

  const Head = ({ tag, title }) => (
    <Col gap={4} style={{ marginBottom: 12 }}>
      <Chip style={{ color: A, borderColor: A, alignSelf: 'flex-start' }}>{tag}</Chip>
      <H size={15}>{title}</H>
    </Col>
  );

  window.WFMech = {};

  // ── Fixed-odds ────────────────────────────────────────────────────────────
  window.WFMech.FixedOdds = () => (
    <Screen pad={16}>
      <Head tag="FIXED-ODDS" title="Place a bet" />
      <Text size={11.5} soft style={{ marginBottom: 12 }}>House sets the price. Payout = stake ÷ implied probability.</Text>
      <Row style={{ gap: 8, marginBottom: 12 }}>
        <Box style={{ flex: 1, textAlign: 'center', padding: '13px 0', borderWidth: 2, borderColor: A }}><b style={{ color: A }}>YES</b><div style={{ fontSize: 18, fontWeight: 800, color: A }}>62%</div></Box>
        <Box style={{ flex: 1, textAlign: 'center', padding: '13px 0', borderColor: 'var(--wf-faint)' }}><b>NO</b><div style={{ fontSize: 18, fontWeight: 800, color: W }}>38%</div></Box>
      </Row>
      <Label style={{ marginBottom: 5 }}>Stake (ADIV)</Label>
      <Field label="100" style={{ marginBottom: 8 }} />
      <Row style={{ gap: 6, marginBottom: 14 }}>{['+50', '+100', '+500', 'Max'].map((q) => <Pill key={q}>{q}</Pill>)}</Row>
      <Box style={{ padding: 11, background: 'var(--wf-fill)', borderColor: 'var(--wf-faint)', marginBottom: 14 }}>
        <Row style={{ justifyContent: 'space-between', marginBottom: 4 }}><Text size={11.5} soft>Potential payout</Text><Text size={13}><b>161 ADIV</b></Text></Row>
        <Row style={{ justifyContent: 'space-between' }}><Text size={11.5} soft>Fee 1% · House liability ok</Text><Text size={11.5} soft>−1</Text></Row>
      </Box>
      <Btn primary style={{ width: '100%', justifyContent: 'center' }}>Place bet</Btn>
      <Ann n={1} style={{ marginTop: 12 }}>Simplest — single stake, instant payout preview</Ann>
    </Screen>
  );

  // ── CLOB order book ─────────────────────────────────────────────────────────
  window.WFMech.Clob = () => (
    <Screen pad={16}>
      <Head tag="CLOB" title="Order book" />
      <Row style={{ gap: 8, marginBottom: 10 }}>
        <Box style={{ flex: 1, textAlign: 'center', padding: '9px 0', borderColor: 'var(--wf-faint)' }}><div style={cap}>Bid</div><div style={{ fontSize: 16, fontWeight: 800, color: A }}>54¢</div></Box>
        <Box style={{ flex: 1, textAlign: 'center', padding: '9px 0', borderColor: 'var(--wf-faint)' }}><div style={cap}>Ask</div><div style={{ fontSize: 16, fontWeight: 800, color: W }}>57¢</div></Box>
        <Box style={{ flex: 1, textAlign: 'center', padding: '9px 0', borderColor: 'var(--wf-faint)' }}><div style={cap}>Last</div><div style={{ fontSize: 16, fontWeight: 800 }}>55¢</div></Box>
      </Row>
      <Box style={{ padding: 8, marginBottom: 12, borderColor: 'var(--wf-faint)' }}>
        <Text size={10.5} soft style={{ marginBottom: 5 }}>DEPTH (price × qty)</Text>
        {[['57', 30, W], ['56', 55, W], ['55', 80, W]].map(([p, w, c], i) => (
          <Row key={'a' + i} style={{ justifyContent: 'space-between', position: 'relative', padding: '2px 0' }}>
            <div style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: w + '%', background: 'var(--wf-warn-soft)', opacity: .6 }} />
            <Text size={11} style={{ color: c, zIndex: 1 }}>{p}¢</Text><Text size={11} soft style={{ zIndex: 1 }}>{w * 4}</Text>
          </Row>
        ))}
        <Divider style={{ margin: '5px 0' }} />
        {[['54', 70, A], ['53', 45, A], ['52', 25, A]].map(([p, w, c], i) => (
          <Row key={'b' + i} style={{ justifyContent: 'space-between', position: 'relative', padding: '2px 0' }}>
            <div style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: w + '%', background: 'var(--wf-accent-soft)', opacity: .7 }} />
            <Text size={11} style={{ color: c, zIndex: 1 }}>{p}¢</Text><Text size={11} soft style={{ zIndex: 1 }}>{w * 4}</Text>
          </Row>
        ))}
      </Box>
      <Row style={{ gap: 6, marginBottom: 8 }}>
        <Box style={{ flex: 1, textAlign: 'center', padding: '7px 0', borderWidth: 2, borderColor: A, fontSize: 12 }}><b style={{ color: A }}>Buy YES</b></Box>
        <Box style={{ flex: 1, textAlign: 'center', padding: '7px 0', borderColor: 'var(--wf-faint)', fontSize: 12 }}><b>Sell / NO</b></Box>
      </Row>
      <Row style={{ gap: 6, marginBottom: 8 }}><Field label="Price 54¢" /><Field label="Qty 10" /></Row>
      <Row style={{ gap: 6, marginBottom: 12 }}><Pill active>GTC</Pill><Pill>IOC</Pill><Pill>FOK</Pill><Ann style={{ marginLeft: 4 }}>order type</Ann></Row>
      <Btn primary style={{ width: '100%', justifyContent: 'center', marginBottom: 10 }}>Place limit order</Btn>
      <Ann n={2}>Open orders list + cancel below (TD-004: cashout = post sell order)</Ann>
    </Screen>
  );

  // ── LMSR ────────────────────────────────────────────────────────────────────
  window.WFMech.Lmsr = () => (
    <Screen pad={16}>
      <Head tag="LMSR · AMM" title="Buy shares" />
      <Text size={11.5} soft style={{ marginBottom: 12 }}>Automated maker. Price moves as you buy — bigger buys cost more.</Text>
      <Row style={{ gap: 8, marginBottom: 12 }}>
        <Box style={{ flex: 1, textAlign: 'center', padding: '11px 0', borderWidth: 2, borderColor: A }}><b style={{ color: A }}>YES</b><div style={{ fontSize: 18, fontWeight: 800, color: A }}>71%</div></Box>
        <Box style={{ flex: 1, textAlign: 'center', padding: '11px 0', borderColor: 'var(--wf-faint)' }}><b>NO</b><div style={{ fontSize: 18, fontWeight: 800, color: W }}>29%</div></Box>
      </Row>
      <Label style={{ marginBottom: 6 }}>Shares to buy</Label>
      <Box style={{ height: 30, borderColor: 'var(--wf-faint)', marginBottom: 4, position: 'relative', display: 'flex', alignItems: 'center', padding: '0 6px' }}>
        <div style={{ height: 4, background: 'var(--wf-faint)', flex: 1, borderRadius: 2 }} />
        <div style={{ position: 'absolute', left: '40%', width: 16, height: 16, borderRadius: '50%', background: A }} />
      </Box>
      <Row style={{ justifyContent: 'space-between', marginBottom: 12 }}><Text size={10.5} soft>1</Text><Field label="50" style={{ height: 28, width: 70 }} /><Text size={10.5} soft>max</Text></Row>
      <Box style={{ padding: 11, background: 'var(--wf-fill)', borderColor: 'var(--wf-faint)', marginBottom: 14 }}>
        <Row style={{ justifyContent: 'space-between', marginBottom: 4 }}><Text size={11.5} soft>Avg cost / share</Text><Text size={12}><b>0.73 ADIV</b></Text></Row>
        <Row style={{ justifyContent: 'space-between', marginBottom: 4 }}><Text size={11.5} soft>Total cost</Text><Text size={12}><b>36.5 ADIV</b></Text></Row>
        <Row style={{ justifyContent: 'space-between' }}><Text size={11.5} soft>New YES price</Text><Text size={11.5} style={{ color: A }}>71% → 74% ↑</Text></Row>
      </Box>
      <Btn primary style={{ width: '100%', justifyContent: 'center' }}>Buy YES shares</Btn>
      <Ann n={3} style={{ marginTop: 12 }}>Show subsidy depth + “price impact” bar (TD-001 settlement payouts pending)</Ann>
    </Screen>
  );

  // ── Parimutuel ──────────────────────────────────────────────────────────────
  window.WFMech.Parimutuel = () => (
    <Screen pad={16}>
      <Head tag="PARIMUTUEL" title="Join a pool" />
      <Text size={11.5} soft style={{ marginBottom: 12 }}>All stakes pool together. Final odds set at close. Takeout 15%.</Text>
      <Col gap={9} style={{ marginBottom: 14 }}>
        <Box style={{ padding: 10, borderColor: A }}>
          <Row style={{ justifyContent: 'space-between', marginBottom: 6 }}><b style={{ color: A }}>YES pool</b><Text size={12}><b>48%</b> · 96k</Text></Row>
          <div style={{ height: 8, background: 'var(--wf-fill)', borderRadius: 4 }}><div style={{ width: '48%', height: '100%', background: A, borderRadius: 4 }} /></div>
        </Box>
        <Box style={{ padding: 10, borderColor: 'var(--wf-faint)' }}>
          <Row style={{ justifyContent: 'space-between', marginBottom: 6 }}><b>NO pool</b><Text size={12}><b>52%</b> · 104k</Text></Row>
          <div style={{ height: 8, background: 'var(--wf-fill)', borderRadius: 4 }}><div style={{ width: '52%', height: '100%', background: W, borderRadius: 4 }} /></div>
        </Box>
      </Col>
      <Label style={{ marginBottom: 5 }}>Stake (ADIV)</Label>
      <Field label="100" style={{ marginBottom: 12 }} />
      <Box style={{ padding: 11, background: 'var(--wf-warn-soft)', borderColor: 'var(--wf-faint)', marginBottom: 14 }}>
        <Text size={11} soft>Est. payout if YES wins: <b style={{ color: 'var(--wf-ink)' }}>~177 ADIV</b></Text>
        <Text size={10.5} soft style={{ marginTop: 3 }}>⚠ Final odds shift as the pool fills — estimate only.</Text>
      </Box>
      <Btn primary style={{ width: '100%', justifyContent: 'center' }}>Add to YES pool</Btn>
      <Ann n={4} style={{ marginTop: 12 }}>No fixed odds — emphasise “estimate” + live pool movement</Ann>
    </Screen>
  );
})();
