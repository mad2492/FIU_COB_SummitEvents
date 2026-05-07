/* eslint-disable no-undef */
const { useState, useEffect, useMemo } = React;

/* ============== HOME ============== */
function FiuEventsHome({ go, setToast }) {
  const [program, setProgram] = useState("");
  const [showWelcome, setShowWelcome] = useState(true);

  const filtered = useMemo(() => {
    return MOCK.events.filter(e => !program || e.program === program);
  }, [program]);

  const kpi = useMemo(() => {
    const insts = MOCK.instances.filter(i => !program || i.program === program);
    const regs = MOCK.registrations.filter(r => !program || r.program === program);
    return {
      activeEvents: filtered.filter(e => e.status === "Active").length,
      notReadyEvents: filtered.filter(e => e.readiness === "Not Ready").length,
      upcomingInstances: insts.filter(i => new Date(i.startDate) > new Date("2026-05-06")).length,
      notReadyInstances: insts.filter(i => i.readiness === "Not Ready").length,
      openRegs: regs.filter(r => r.status === "Registered").length,
      startedRegs: regs.filter(r => r.status === "Started").length
    };
  }, [filtered, program]);

  const attentionItems = MOCK.instances.filter(i => i.readiness === "Not Ready" && (!program || i.program === program));
  const upcomingItems = MOCK.instances.filter(i => i.readiness === "Ready" && (!program || i.program === program)).slice(0, 4);

  return (
    <div data-screen-label="01 Home">
      {showWelcome && (
        <div style={{
          background: "linear-gradient(135deg, #032D60 0%, #0176D3 60%, #1B96FF 100%)",
          borderRadius: 8, padding: "20px 24px", color: "#fff", marginBottom: 14,
          display: "flex", alignItems: "center", gap: 16, boxShadow: "var(--slds-shadow-2)"
        }}>
          <div style={{
            width: 48, height: 48, borderRadius: 8, background: "rgba(255,255,255,.2)",
            display: "grid", placeItems: "center"
          }}><Icon name="sparkle" size={24} color="#fff"/></div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 18, fontWeight: 700 }}>Welcome back, Diana</div>
            <div style={{ fontSize: 13, opacity: .9, marginTop: 2 }}>
              You have <strong>{kpi.notReadyInstances}</strong> instances that need attention before they can go live, and{" "}
              <strong>{kpi.startedRegs}</strong> in-progress registrations to follow up on.
            </div>
          </div>
          <Btn variant="ghost" onClick={() => go("guide")} icon="book">
            <span style={{ color: "#fff" }}>New here? Read the guide</span>
          </Btn>
          <button
            onClick={() => setShowWelcome(false)}
            style={{ background: "none", border: 0, color: "#fff", cursor: "pointer", padding: 4 }}
          ><Icon name="close" color="#fff"/></button>
        </div>
      )}

      <LCard
        icon="home" iconClass="icn-home"
        title="FIU Events Command Center"
        actions={(
          <>
            <Select
              value={program}
              onChange={e => setProgram(e.target.value)}
              options={MOCK.programs}
              style={{ minWidth: 220 }}
            />
            <Btn icon="refresh" title="Refresh" onClick={() => setToast({ variant:"info", message:"Dashboard refreshed" })}/>
          </>
        )}
      >
        <div style={{ padding: 14 }}>
          <div className="muted" style={{ fontSize: 12, marginBottom: 10 }}>
            Scope: <strong style={{ color: "var(--slds-text-primary)" }}>
              {MOCK.programs.find(p => p.value === program)?.label || "All Programs"}
            </strong>
          </div>

          {/* KPI grid */}
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: 10, marginBottom: 16 }}>
            <KpiTile tone="warning"  label="Not Ready Instances" value={kpi.notReadyInstances} cta="Resolve issues"   onClick={() => go("instances")} />
            <KpiTile tone="warning"  label="Not Ready Events"    value={kpi.notReadyEvents}    cta="Review events"     onClick={() => go("events")}    />
            <KpiTile tone="warning"  label="Started Registrations" value={kpi.startedRegs}     cta="Review started"    onClick={() => go("registrations")} />
            <KpiTile tone="neutral"  label="Upcoming Instances"  value={kpi.upcomingInstances} cta="View instances"    onClick={() => go("instances")} />
            <KpiTile tone="neutral"  label="Open Registrations"  value={kpi.openRegs}          cta="View registrations" onClick={() => go("registrations")} />
            <KpiTile tone="neutral"  label="Active Events"       value={kpi.activeEvents}      cta="Browse events"     onClick={() => go("events")}    />
          </div>

          {/* Layout */}
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, marginBottom: 16 }}>
            <Panel title="Needs Attention" badge={attentionItems.length}>
              {attentionItems.length === 0
                ? <div className="muted" style={{ padding: 12 }}>No readiness issues. 🎉</div>
                : attentionItems.map(i => (
                    <div key={i.id} style={{ padding: "10px 12px", borderBottom: "1px solid var(--slds-border)", display: "flex", gap: 10 }}>
                      <Icon name="warning" color="#FE9339"/>
                      <div style={{ flex: 1 }}>
                        <div className="bold">{i.title}</div>
                        <div className="muted" style={{ fontSize: 12 }}>{i.eventName} · <span style={{ color: "#BA0517" }}>{i.reason}</span></div>
                      </div>
                      <Btn size="sm" onClick={() => go("instances")}>Fix</Btn>
                    </div>
                  ))
              }
            </Panel>

            <Panel title="Upcoming This Week" badge={upcomingItems.length}>
              {upcomingItems.map(i => (
                <div key={i.id} style={{ padding: "10px 12px", borderBottom: "1px solid var(--slds-border)" }}>
                  <div className="bold">{i.title}</div>
                  <div className="muted" style={{ fontSize: 12, marginTop: 2 }}>
                    {new Date(i.startDate).toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" })}
                    {" · "}
                    {i.registered}/{i.capacity} registered
                  </div>
                </div>
              ))}
            </Panel>
          </div>

          {/* Mental model card */}
          <Panel title="How FIU Events fit together" subtitle="The mental model in 30 seconds">
            <div style={{ padding: 14, display: "grid", gridTemplateColumns: "1fr auto 1fr auto 1fr", alignItems: "stretch", gap: 12 }}>
              <ConceptCard icon="event" iconBg="#5867E8" title="Event"
                desc="The parent concept — name, branding, location type, programs it's for. Set up once."
                example="e.g. MBA Spring 2026 Open House"
              />
              <Arrow/>
              <ConceptCard icon="instance" iconBg="#04844B" title="Instance"
                desc="A specific date/time people register for. One Event can have many Instances."
                example="e.g. May 12, 6:30pm at Coral Gables"
              />
              <Arrow/>
              <ConceptCard icon="people" iconBg="#16325C" title="Registration"
                desc="A single person signing up for one Instance. This is what a contact submits."
                example="e.g. Maria Alvarez, registered"
              />
            </div>
          </Panel>

          {/* Guided actions */}
          <div className="spacer-md"/>
          <Panel title="What do you want to do?" subtitle="Pick a workflow — we'll walk you through it">
            <div style={{ padding: 14, display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(260px, 1fr))", gap: 12 }}>
              <ActionCard title="Create a new event" desc="Brand-new event concept. We'll guide you through every field." icon="plus" onClick={() => go("wizard")} primary/>
              <ActionCard title="Clone an existing event" desc="Copy an event you've used before. Review risky settings." icon="copy" onClick={() => setToast({ variant:"info", message:"Clone wizard would open here" })}/>
              <ActionCard title="Add a date to an existing event" desc="Just need a new instance for an event that already exists." icon="event" onClick={() => setToast({ variant:"info", message:"Instance wizard would open here" })}/>
              <ActionCard title="Bulk update registrations" desc="Mass-update statuses, reassign instances, etc." icon="people" onClick={() => go("registrations")}/>
            </div>
          </Panel>
        </div>
      </LCard>
    </div>
  );
}

const KpiTile = ({ tone, label, value, cta, onClick }) => (
  <div style={{
    background: "#fff", border: "1px solid var(--slds-border)", borderRadius: 6,
    borderLeft: tone === "warning" ? "3px solid #FE9339" : "1px solid var(--slds-border)",
    padding: 12, display: "flex", flexDirection: "column", gap: 4
  }}>
    <div style={{ fontSize: 11, color: "var(--slds-text-tertiary)", textTransform: "uppercase", letterSpacing: ".04em", fontWeight: 600 }}>
      {label}
    </div>
    <div style={{ fontSize: 28, fontWeight: 700, color: "var(--slds-brand-darker)" }}>{value}</div>
    <button onClick={onClick} style={{
      background: "none", border: 0, color: "var(--slds-brand)", padding: 0,
      cursor: "pointer", fontSize: 12, textAlign: "left", marginTop: 2, fontWeight: 500
    }}>{cta} →</button>
  </div>
);

const Panel = ({ title, subtitle, badge, children }) => (
  <div style={{ background: "#fff", border: "1px solid var(--slds-border)", borderRadius: 6, overflow: "hidden" }}>
    <div style={{ padding: "10px 14px", borderBottom: "1px solid var(--slds-border)", background: "var(--slds-bg-alt)", display: "flex", alignItems: "center", gap: 8 }}>
      <div style={{ fontWeight: 700, fontSize: 13 }}>{title}</div>
      {subtitle && <div className="muted" style={{ fontSize: 12 }}>· {subtitle}</div>}
      {badge !== undefined && <Badge variant="info">{badge}</Badge>}
    </div>
    <div>{children}</div>
  </div>
);

const ConceptCard = ({ icon, iconBg, title, desc, example }) => (
  <div style={{ border: "1px solid var(--slds-border)", borderRadius: 6, padding: 12, background: "#fff" }}>
    <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 8 }}>
      <div style={{ width: 28, height: 28, borderRadius: 6, background: iconBg, color: "#fff", display: "grid", placeItems: "center" }}>
        <Icon name={icon} color="#fff" size={16}/>
      </div>
      <div style={{ fontWeight: 700 }}>{title}</div>
    </div>
    <div style={{ fontSize: 12, color: "var(--slds-text-secondary)", marginBottom: 6 }}>{desc}</div>
    <div className="mono" style={{ background: "var(--slds-bg-alt)", padding: "4px 6px", borderRadius: 3, fontSize: 11, color: "var(--slds-text-tertiary)" }}>{example}</div>
  </div>
);
const Arrow = () => (
  <div style={{ display: "grid", placeItems: "center", color: "var(--slds-text-weak)" }}>
    <Icon name="arrow" color="#939393" size={20}/>
  </div>
);

const ActionCard = ({ title, desc, icon, onClick, primary }) => (
  <button onClick={onClick} style={{
    textAlign: "left", border: "1px solid var(--slds-border)",
    borderColor: primary ? "var(--slds-brand)" : "var(--slds-border)",
    background: primary ? "var(--slds-brand-lightest)" : "#fff",
    borderRadius: 6, padding: 14, cursor: "pointer", font: "inherit"
  }}>
    <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 6 }}>
      <Icon name={icon} color={primary ? "#0176D3" : "#444"} size={18}/>
      <div style={{ fontWeight: 700, color: primary ? "var(--slds-brand-darker)" : "var(--slds-text-primary)" }}>{title}</div>
    </div>
    <div style={{ fontSize: 12, color: "var(--slds-text-secondary)" }}>{desc}</div>
  </button>
);

window.FiuEventsHome = FiuEventsHome;
