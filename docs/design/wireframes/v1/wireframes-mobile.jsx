// wireframes-mobile.jsx — native mobile app low-fi screens (375-wide feel).
// Registered on window.WFMob.
(function () {
  const { Screen, Box, Img, Line, Lines, Btn, Pill, Chip, Card, Field, Label, H, Text, Divider, Row, Col, Avatar, Ann, PhoneStatus, TabBar } = window.WF;
  const A = '#356b8a', W = '#9a6a1e';
  const cap = { fontSize: 10, fontWeight: 600, letterSpacing: '.04em', textTransform: 'uppercase', color: 'var(--wf-soft)' };

  const Notch = () => (
    <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 6 }}>
      <div style={{ width: 90, height: 5, borderRadius: 3, background: 'var(--wf-faint)' }} />
    </div>
  );

  window.WFMob = {};

  // ── Markets list ────────────────────────────────────────────────────────────
  window.WFMob.Markets = () => (
    <Screen>
      <PhoneStatus />
      <div style={{ padding: '6px 16px 0' }}>
        <Row style={{ justifyContent: 'space-between', marginBottom: 10 }}>
          <H size={21}>Markets</H>
          <Pill style={{ background: 'var(--wf-accent-soft)', borderColor: 'var(--wf-accent-soft)', color: A, fontWeight: 700 }}>4,250 ADIV</Pill>
        </Row>
        <Field label="⌕  Search markets…" style={{ marginBottom: 10 }} />
        <Row style={{ gap: 6, marginBottom: 12, overflow: 'hidden' }}>
          <Pill active>All</Pill><Pill>Politics</Pill><Pill>Sports</Pill><Pill>Crypto</Pill>
        </Row>
        <Col gap={11}>
          {[['FIXED-ODDS', '62%', '38%'], ['CLOB', '54¢', '46¢'], ['LMSR', '71%', '29%']].map(([m, y, n], i) => (
            <Card key={i} style={{ padding: 12 }}>
              <Row style={{ gap: 4, marginBottom: 7 }}><Chip>Open</Chip><Chip style={{ color: A, borderColor: A }}>{m}</Chip><span style={{ marginLeft: 'auto', fontSize: 9.5, color: 'var(--wf-soft)' }}>6d</span></Row>
              <Text size={13} style={{ fontWeight: 700, lineHeight: 1.3, marginBottom: 9 }}>Will the proposal pass before Q3 2026?</Text>
              <Row style={{ gap: 7 }}>
                <Box style={{ flex: 1, textAlign: 'center', padding: '7px 0', borderColor: 'var(--wf-faint)' }}><div style={{ fontSize: 9, color: 'var(--wf-soft)' }}>YES</div><div style={{ fontSize: 15, fontWeight: 800, color: A }}>{y}</div></Box>
                <Box style={{ flex: 1, textAlign: 'center', padding: '7px 0', borderColor: 'var(--wf-faint)' }}><div style={{ fontSize: 9, color: 'var(--wf-soft)' }}>NO</div><div style={{ fontSize: 15, fontWeight: 800, color: W }}>{n}</div></Box>
              </Row>
            </Card>
          ))}
        </Col>
      </div>
      <TabBar active="Markets" />
      <Ann n={1} style={{ position: 'absolute', right: -8, top: 120, transform: 'rotate(4deg)' }}>tap card → detail</Ann>
    </Screen>
  );

  // ── Market detail + bottom bet sheet ─────────────────────────────────────────
  window.WFMob.Detail = () => (
    <Screen>
      <PhoneStatus />
      <div style={{ padding: '6px 16px 150px', overflow: 'hidden' }}>
        <Row style={{ justifyContent: 'space-between', marginBottom: 10 }}><Text size={12} soft>‹ Back</Text><Text size={14}>⋯</Text></Row>
        <Row style={{ gap: 4, marginBottom: 9 }}><Chip>Open</Chip><Chip>Politics</Chip><Chip style={{ color: A, borderColor: A }}>FIXED-ODDS</Chip></Row>
        <H size={17} style={{ marginBottom: 8 }}>Will the proposal pass before Q3 2026?</H>
        <Lines n={2} last="65%" style={{ marginBottom: 14 }} />
        <Row style={{ gap: 9, marginBottom: 14 }}>
          <Box style={{ flex: 1, textAlign: 'center', padding: '15px 0', borderColor: 'var(--wf-faint)' }}><div style={{ fontSize: 10, color: 'var(--wf-soft)' }}>YES</div><div style={{ fontSize: 28, fontWeight: 800, color: A }}>62%</div></Box>
          <Box style={{ flex: 1, textAlign: 'center', padding: '15px 0', borderColor: 'var(--wf-faint)' }}><div style={{ fontSize: 10, color: 'var(--wf-soft)' }}>NO</div><div style={{ fontSize: 28, fontWeight: 800, color: W }}>38%</div></Box>
        </Row>
        <Row style={{ gap: 8, marginBottom: 14 }}>
          {[['Vol', '128k'], ['Positions', '342'], ['Closes', '6d']].map(([l, v]) => (
            <Box key={l} style={{ flex: 1, padding: '8px 0', textAlign: 'center', borderColor: 'var(--wf-faint)' }}><div style={cap}>{l}</div><div style={{ fontSize: 13, fontWeight: 700, marginTop: 2 }}>{v}</div></Box>
          ))}
        </Row>
        <Box dashed style={{ height: 60, borderColor: 'var(--wf-faint)', marginBottom: 14 }}><div className="wf-img" style={{ border: 0, background: 'transparent', height: '100%' }}>price sparkline</div></Box>
        <Label style={{ marginBottom: 6 }}>Resolution</Label><Lines n={2} last="70%" />
      </div>
      {/* sticky bet sheet */}
      <div style={{ position: 'absolute', bottom: 58, left: 0, right: 0, background: '#fff', borderTop: '1.5px solid var(--wf-line)', borderRadius: '14px 14px 0 0', padding: '12px 16px', boxShadow: '0 -6px 18px rgba(0,0,0,.06)' }}>
        <Notch />
        <Row style={{ gap: 8, margin: '8px 0' }}>
          <Box style={{ flex: 1, textAlign: 'center', padding: '9px 0', borderWidth: 2, borderColor: A, fontSize: 12 }}><b style={{ color: A }}>YES 62%</b></Box>
          <Box style={{ flex: 1, textAlign: 'center', padding: '9px 0', borderColor: 'var(--wf-faint)', fontSize: 12 }}><b>NO 38%</b></Box>
        </Row>
        <Row style={{ gap: 8 }}><Field label="Stake 100" style={{ flex: 1 }} /><Btn primary style={{ flex: '0 0 auto' }}>Place bet</Btn></Row>
      </div>
      <TabBar active="Markets" />
      <Ann n={2} style={{ position: 'absolute', left: -4, bottom: 200, transform: 'rotate(-3deg)' }}>persistent bet sheet — thumb reachable</Ann>
    </Screen>
  );

  // ── Profile / wallet ──────────────────────────────────────────────────────────
  window.WFMob.Profile = () => (
    <Screen>
      <PhoneStatus />
      <div style={{ padding: '6px 16px 0' }}>
        <Col gap={4} style={{ alignItems: 'center', marginBottom: 14 }}>
          <Avatar size={56} />
          <H size={17}>player_alex</H><Text size={11.5} soft>Rank #14 · since Mar 2026</Text>
        </Col>
        <Box style={{ padding: '14px 0', textAlign: 'center', borderColor: A, marginBottom: 12 }}>
          <div style={cap}>Wallet balance</div><div style={{ fontSize: 28, fontWeight: 800, color: A, margin: '2px 0' }}>4,250 ADIV</div>
          <Btn primary style={{ marginTop: 6 }}>Request faucet top-up</Btn>
        </Box>
        <Row style={{ gap: 8, marginBottom: 14 }}>
          {[['P&L', '+1,180', 'pos'], ['Win', '57%', ''], ['Bets', '37', '']].map(([l, v, t]) => (
            <Box key={l} style={{ flex: 1, padding: '10px 0', textAlign: 'center', borderColor: 'var(--wf-faint)' }}><div style={cap}>{l}</div><div style={{ fontSize: 16, fontWeight: 800, marginTop: 2, color: t ? 'var(--wf-pos)' : 'var(--wf-ink)' }}>{v}</div></Box>
          ))}
        </Row>
        <Row style={{ gap: 5, marginBottom: 10 }}><Pill active>Open</Pill><Pill>Settled</Pill><Pill>All</Pill></Row>
        <Col gap={9}>
          {[0, 1, 2].map((i) => (
            <Card key={i} style={{ padding: 11 }}>
              <Row style={{ justifyContent: 'space-between', marginBottom: 6 }}><Line w="55%" /><span className="wf-chip" style={{ color: i ? 'var(--wf-pos)' : A, borderColor: 'currentColor' }}>{i ? 'Won' : 'Open'}</span></Row>
              <Row style={{ justifyContent: 'space-between' }}><Text size={11} soft>YES · 500 ADIV</Text><Text size={11.5} style={{ color: i ? 'var(--wf-pos)' : 'var(--wf-soft)' }}>{i ? '+306' : '→ 806'}</Text></Row>
            </Card>
          ))}
        </Col>
      </div>
      <TabBar active="Profile" />
    </Screen>
  );

  // ── Leaderboard ────────────────────────────────────────────────────────────────
  window.WFMob.Leaderboard = () => (
    <Screen>
      <PhoneStatus />
      <div style={{ padding: '6px 16px 0' }}>
        <H size={21} style={{ marginBottom: 12 }}>Leaderboard</H>
        <Row style={{ gap: 8, marginBottom: 16, alignItems: 'flex-end' }}>
          {[['2', 60], ['1', 78], ['3', 48]].map(([r, h], i) => (
            <Col key={i} gap={4} style={{ alignItems: 'center', flex: 1 }}>
              <Avatar size={i === 1 ? 40 : 32} /><Text size={10.5}><b>p_{['', 'one', '', 'three'][i] || 'two'}</b></Text>
              <Text size={9.5} style={{ color: 'var(--wf-pos)' }}>+{(4 - i) * 900}</Text>
              <Box style={{ width: '100%', height: h, background: 'var(--wf-fill)', borderColor: 'var(--wf-faint)', textAlign: 'center', paddingTop: 7, fontWeight: 800, color: A }}>{r}</Box>
            </Col>
          ))}
        </Row>
        <Col gap={0}>
          <Row style={{ justifyContent: 'space-between', padding: '7px 4px', borderBottom: '1.5px solid var(--wf-faint)' }}><Text size={10} soft>#</Text><Text size={10} soft>PLAYER</Text><Text size={10} soft>NET P&L</Text></Row>
          {Array.from({ length: 6 }).map((_, i) => (
            <Row key={i} style={{ justifyContent: 'space-between', padding: '9px 4px', borderBottom: '1px solid var(--wf-faint)', alignItems: 'center', background: i === 2 ? 'var(--wf-accent-soft)' : 'transparent' }}>
              <Text size={11.5}><b>{i + 4}</b></Text>
              <Row style={{ gap: 7, width: 110 }}><Avatar size={20} /><Text size={11}>{`player_${i}`}{i === 2 ? ' (you)' : ''}</Text></Row>
              <Text size={11.5} style={{ color: 'var(--wf-pos)' }}>+{1400 - i * 130}</Text>
            </Row>
          ))}
        </Col>
      </div>
      <TabBar active="Positions" />
    </Screen>
  );
})();
