// wireframes-additions.jsx — PR1 additions: stats/settlement/community.
// Registered on window.WFExtra.
(function () {
  const { Screen, Box, Line, Lines, Btn, Pill, Chip, Card, Field, Label, H, Text, Divider, Row, Col, Avatar, Ann, WebBar, Chart } = window.WF;
  const A = '#356b8a', W = '#9a6a1e', POS = '#3c7a52';
  const cap = { fontSize: 10.5, fontWeight: 600, letterSpacing: '.04em', textTransform: 'uppercase', color: 'var(--wf-soft)' };

  window.WFExtra = {};

  // ── How settlement works (explainer) ─────────────────────────────────────
  window.WFExtra.Settlement = () => {
    const steps = [['Open', 'Accepting bets · prices live', A], ['Closes', 'close_at passes → no new bets', W], ['Resolution', 'Moderator declares outcome + evidence', A], ['Dispute', 'Optional window to contest', W], ['Settled', 'Payouts credited · ledger entries', POS]];
    const mechs = [
      ['Fixed-odds', 'Winning bets paid stake ÷ implied probability. House covered the other side.'],
      ['CLOB', 'Each winning contract redeems for 1 ADIV; losing contracts expire at 0. Open orders cancelled & released.'],
      ['LMSR', 'Outcome marked; winning shares pay out from the maker. (v1: settlement payout in progress — TD-001.)'],
      ['Parimutuel', 'Winning pool splits the total pool minus takeout, pro-rata to stake. Zero winners → refund.'],
    ];
    return (
      <Screen>
        <WebBar active="" />
        <div style={{ padding: '22px 26px', maxWidth: 980, margin: '0 auto' }}>
          <H size={24} style={{ marginBottom: 4 }}>How markets settle</H>
          <Text soft style={{ marginBottom: 20 }}>Every payout is recorded as an append-only ledger entry — settlement is idempotent and fully audited.</Text>

          <Label style={{ marginBottom: 12 }}>Market lifecycle</Label>
          <Row style={{ gap: 0, marginBottom: 24, alignItems: 'stretch' }}>
            {steps.map(([t, d, c], i) => (
              <React.Fragment key={t}>
                <Col gap={6} style={{ flex: 1 }}>
                  <Row style={{ gap: 7 }}><span style={{ width: 22, height: 22, borderRadius: 999, background: c, color: '#fff', fontSize: 11, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{i + 1}</span><Text size={13}><b>{t}</b></Text></Row>
                  <Text size={10.5} soft style={{ paddingRight: 10 }}>{d}</Text>
                </Col>
                {i < steps.length - 1 && <div style={{ alignSelf: 'center', color: 'var(--wf-faint)', fontSize: 18, padding: '0 2px' }}>→</div>}
              </React.Fragment>
            ))}
          </Row>

          <Label style={{ marginBottom: 12 }}>Payout by mechanism</Label>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 24 }}>
            {mechs.map(([m, d]) => (
              <Card key={m}>
                <Chip style={{ color: A, borderColor: A, marginBottom: 8 }}>{m}</Chip>
                <Text size={12.5} style={{ lineHeight: 1.5 }}>{d}</Text>
              </Card>
            ))}
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Card style={{ borderColor: W }}>
              <Label style={{ marginBottom: 8 }}>Disputes</Label>
              <Text size={12.5} style={{ lineHeight: 1.5, marginBottom: 8 }}>During the dispute window any participant can contest the result with a reason. A resolver reviews evidence and finalizes or reverses.</Text>
              <Row style={{ gap: 5 }}><Chip>Open</Chip><Chip>Accepted</Chip><Chip>Rejected</Chip><Chip>Reversed</Chip></Row>
            </Card>
            <Card>
              <Label style={{ marginBottom: 8 }}>Why you can trust it</Label>
              {['Append-only ledger — no silent balance edits', 'Settlement runs once (idempotent)', 'Resolver ≠ market creator (configurable)', 'Every step writes an audit event'].map((t) => (
                <Row key={t} style={{ gap: 7, padding: '4px 0', alignItems: 'flex-start' }}><span style={{ color: POS, fontWeight: 800 }}>✓</span><Text size={12}>{t}</Text></Row>
              ))}
            </Card>
          </div>
          <Ann n={1} style={{ marginTop: 14 }}>Link this from every market’s “Resolution details” + settled banner</Ann>
        </div>
      </Screen>
    );
  };

  // ── Browse with visibility scope (public vs community) ────────────────────
  window.WFExtra.Scope = () => (
    <Screen>
      <WebBar active="Markets" />
      <div style={{ padding: '20px 26px' }}>
        <Row style={{ justifyContent: 'space-between', marginBottom: 14 }}>
          <H size={24}>Markets</H>
          <Btn primary>+ Create market</Btn>
        </Row>
        <Row style={{ gap: 8, marginBottom: 16 }}>
          <Pill active>All</Pill><Pill>🌐 Public</Pill><Pill>👥 My communities</Pill>
          <div style={{ flex: 1 }} />
          <Field label="Community: Office League ▾" style={{ width: 200 }} />
          <Ann style={{ marginLeft: 6 }}>scope = visibility filter</Ann>
        </Row>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 14 }}>
          {[['🌐 Public', A, false], ['👥 Office League', W, false], ['👥 Family Pool', W, true], ['🌐 Public', A, false], ['👥 Crypto Club', W, false], ['🔒 Invite-only', 'var(--wf-soft)', true]].map(([scope, c, locked], i) => (
            <Card key={i} style={{ padding: 13, opacity: locked ? 0.96 : 1 }}>
              <Row style={{ gap: 5, marginBottom: 9 }}><Chip style={{ color: c, borderColor: c, textTransform: 'none' }}>{scope}</Chip><Chip>Open</Chip></Row>
              <Text size={13} style={{ fontWeight: 700, lineHeight: 1.3, marginBottom: 10 }}>{locked ? 'Members-only market — join to view details' : 'Will the proposal pass before Q3 2026?'}</Text>
              {locked
                ? <Box dashed style={{ padding: '14px 0', textAlign: 'center', borderColor: 'var(--wf-faint)' }}><Text size={11} soft>🔒 Restricted</Text><div style={{ marginTop: 6 }}><Pill>Request invite</Pill></div></Box>
                : <Row style={{ gap: 8 }}><Box style={{ flex: 1, textAlign: 'center', padding: '7px 0', borderColor: 'var(--wf-faint)' }}><div style={{ fontSize: 9, color: 'var(--wf-soft)' }}>YES</div><div style={{ fontSize: 16, fontWeight: 800, color: A }}>62%</div></Box><Box style={{ flex: 1, textAlign: 'center', padding: '7px 0', borderColor: 'var(--wf-faint)' }}><div style={{ fontSize: 9, color: 'var(--wf-soft)' }}>NO</div><div style={{ fontSize: 16, fontWeight: 800, color: W }}>38%</div></Box></Row>}
            </Card>
          ))}
        </div>
        <Ann n={2} style={{ marginTop: 14 }}>Public = anyone · Community = group members only (groups/memberships)</Ann>
      </div>
    </Screen>
  );

  // ── Community hub (group page) ────────────────────────────────────────────
  window.WFExtra.Community = () => (
    <Screen>
      <WebBar active="Markets" />
      <div style={{ padding: '20px 26px' }}>
        <Row style={{ gap: 14, marginBottom: 8 }}>
          <div style={{ width: 52, height: 52, borderRadius: 12, background: 'var(--wf-fill)', border: '1.5px solid var(--wf-line)' }} />
          <Col gap={3}>
            <Row style={{ gap: 8 }}><H size={21}>Office League</H><Chip style={{ color: W, borderColor: W, textTransform: 'none' }}>👥 Private community</Chip></Row>
            <Text size={12} soft>32 members · 14 open markets · you are an Admin</Text>
          </Col>
          <div style={{ flex: 1 }} />
          <Btn ghost>Invite members</Btn><Btn primary>+ Create market</Btn>
        </Row>
        <Divider style={{ margin: '14px 0' }} />
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 280px', gap: 20 }}>
          <Col gap={12}>
            <Row style={{ gap: 6 }}><Pill active>Open</Pill><Pill>Closed</Pill><Pill>Settled</Pill><Pill>Mine</Pill></Row>
            {[0, 1, 2].map((i) => (
              <Card key={i} style={{ padding: 13 }}>
                <Row style={{ gap: 5, marginBottom: 8 }}><Chip>Open</Chip><Chip style={{ color: A, borderColor: A }}>CLOB</Chip><span style={{ marginLeft: 'auto', fontSize: 10, color: 'var(--wf-soft)' }}>by mod_jane</span></Row>
                <Row style={{ justifyContent: 'space-between', alignItems: 'center' }}>
                  <Text size={13} style={{ fontWeight: 700, width: '60%' }}>Will we hit the Q3 target?</Text>
                  <Row style={{ gap: 8 }}><Box style={{ textAlign: 'center', padding: '6px 14px', borderColor: 'var(--wf-faint)' }}><div style={{ fontSize: 9, color: 'var(--wf-soft)' }}>YES</div><div style={{ fontSize: 15, fontWeight: 800, color: A }}>5{i}¢</div></Box></Row>
                </Row>
              </Card>
            ))}
          </Col>
          <Col gap={14}>
            <Card>
              <Label style={{ marginBottom: 8 }}>Members · 32</Label>
              {['mod_jane · Owner', 'player_alex · Admin', 'player_sam · Member', 'player_lee · Member'].map((m, i) => (
                <Row key={i} style={{ gap: 8, padding: '5px 0', alignItems: 'center' }}><Avatar size={24} /><Text size={12}>{m}</Text></Row>
              ))}
              <Text size={11.5} style={{ color: A, marginTop: 6 }}>View all ›</Text>
            </Card>
            <Card style={{ borderColor: W }}>
              <Label style={{ marginBottom: 8 }}>Pending invites · 3</Label>
              <Lines n={2} last="60%" />
              <Btn ghost style={{ width: '100%', justifyContent: 'center', marginTop: 10 }}>Manage invites</Btn>
            </Card>
            <Card><Label style={{ marginBottom: 6 }}>Community leaderboard</Label><Lines n={3} last="50%" /></Card>
          </Col>
        </div>
        <Ann n={3} style={{ marginTop: 12 }}>Roles: Owner · Admin · Resolver · Member · Read-only (per group)</Ann>
      </div>
    </Screen>
  );

  // ── Create-market visibility selector (focused panel) ─────────────────────
  window.WFExtra.Visibility = () => (
    <Screen pad={18}>
      <H size={16} style={{ marginBottom: 4 }}>Visibility &amp; access</H>
      <Text size={11.5} soft style={{ marginBottom: 14 }}>Who can see and bet on this market?</Text>
      <Col gap={10}>
        <Box style={{ padding: 12, borderWidth: 2, borderColor: A }}>
          <Row style={{ gap: 8, alignItems: 'flex-start' }}><span style={{ marginTop: 1 }}>🌐</span><Col gap={3}><Text size={13}><b style={{ color: A }}>Public</b></Text><Text size={11} soft>Anyone on Adivento can view and bet. Appears in the global market list.</Text></Col></Row>
        </Box>
        <Box style={{ padding: 12, borderColor: 'var(--wf-faint)' }}>
          <Row style={{ gap: 8, alignItems: 'flex-start' }}><span style={{ marginTop: 1 }}>👥</span><Col gap={3}><Text size={13}><b>Community</b></Text><Text size={11} soft>Only members of a chosen community can participate.</Text>
            <Field label="Choose community: Office League ▾" style={{ marginTop: 6 }} /></Col></Row>
        </Box>
        <Box style={{ padding: 12, borderColor: 'var(--wf-faint)' }}>
          <Row style={{ gap: 8, alignItems: 'flex-start' }}><span style={{ marginTop: 1 }}>🔒</span><Col gap={3}><Text size={13}><b>Invite-only</b></Text><Text size={11} soft>Hidden. Only people you invite by link/email can join this single market.</Text></Col></Row>
        </Box>
      </Col>
      <Box style={{ padding: 10, background: 'var(--wf-warn-soft)', borderColor: 'var(--wf-faint)', marginTop: 14 }}>
        <Text size={10.5} soft>⚠ Visibility is locked once the market opens. Community markets enforce membership at bet time.</Text>
      </Box>
      <Ann n={4} style={{ marginTop: 12 }}>Maps to markets.group_id + RBAC (PRIVATE_PREDICTION_MARKETS.md)</Ann>
    </Screen>
  );
})();
