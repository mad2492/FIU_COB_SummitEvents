/* eslint-disable no-undef */
const { useState } = React;

function FiuGuide({ go }) {
  return (
    <div data-screen-label="06 Guide">
      <PageHeader crumbs={[{label:"Home",to:"home"},{label:"Guide"}]} title="FIU Events — How it works" go={go}/>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 280px", gap: 12, alignItems: "start" }}>
        <div style={{ background: "#fff", border: "1px solid var(--slds-border)", borderRadius: 6, padding: 24 }}>
          <h2 style={{ margin: 0, fontSize: 22, color: "#16325C" }}>The 30-second mental model</h2>
          <p style={{ color: "var(--slds-text-secondary)", fontSize: 14, lineHeight: 1.55 }}>
            FIU Events is built on three nested concepts. Get these and the rest is mostly forms.
          </p>

          <Concept num="1" color="#5867E8" title="Event" body="The parent. A reusable concept like 'MBA Spring Open House' or 'MS Finance Webinar Series'. Set up branding, audience, and location type once."/>
          <Concept num="2" color="#04844B" title="Instance" body="A specific date/time of an Event. People register for instances, not events. One Event can have many Instances — that's how you run the same Open House at three different dates."/>
          <Concept num="3" color="#16325C" title="Registration" body="A single contact signing up for one Instance. Status moves from Started → Registered → Attended (or Cancelled). 'Started' = they bailed mid-form; follow up."/>

          <h3 style={{ marginTop: 28, fontSize: 16 }}>Readiness — the most important concept</h3>
          <p style={{ fontSize: 13, color: "var(--slds-text-secondary)" }}>Every Event and Instance has a Readiness flag. <strong>Not Ready</strong> means a record can't go live yet. The system checks for required fields, payment gateway, banner image, etc. Your dashboard surfaces these — fix them before launch.</p>

          <h3 style={{ marginTop: 28, fontSize: 16 }}>Common pitfalls</h3>
          <ul style={{ fontSize: 13, color: "var(--slds-text-secondary)", lineHeight: 1.7 }}>
            <li><strong>"My event isn't visible publicly."</strong> It needs at least one Active, Ready Instance.</li>
            <li><strong>"Payment isn't working."</strong> Paid events need both a Payment Gateway and an Accounting Department set.</li>
            <li><strong>"I can't change the Record Type."</strong> Right — Record Type is locked after creation. Clone instead.</li>
            <li><strong>"Started registrations are piling up."</strong> Those are abandoned forms. Bulk-cancel or follow up.</li>
          </ul>

          <div style={{ marginTop: 24, display: "flex", gap: 8 }}>
            <Btn variant="brand" icon="plus" onClick={() => go("wizard")}>Create your first event</Btn>
            <Btn icon="event" onClick={() => go("events")}>Browse events</Btn>
          </div>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 12, position: "sticky", top: 12 }}>
          <div style={{ background: "var(--slds-brand-lightest)", border: "1px solid #B0DAFB", borderRadius: 6, padding: 14 }}>
            <div style={{ fontWeight: 700, fontSize: 13, marginBottom: 6, color: "var(--slds-brand-darker)" }}>Glossary</div>
            <dl style={{ margin: 0, fontSize: 12, color: "var(--slds-text-secondary)" }}>
              <Term k="Record Type" v="Layout & approval routing — Chapman / EPE / OGI."/>
              <Term k="Business Unit" v="Owning department. Auto-derived from Record Type."/>
              <Term k="Template" v="Visual style of the registration page."/>
              <Term k="Capacity" v="Max registrants per Instance."/>
              <Term k="Waitlist" v="Allow registration past capacity, in queue."/>
              <Term k="Started" v="Registration not completed (abandoned)."/>
            </dl>
          </div>

          <div style={{ background: "#fff", border: "1px solid var(--slds-border)", borderRadius: 6, padding: 14 }}>
            <div style={{ fontWeight: 700, fontSize: 13, marginBottom: 6 }}>Need help?</div>
            <div style={{ fontSize: 12, color: "var(--slds-text-secondary)" }}>
              Email <a href="#">eventsupport@fiu.edu</a> or check the full admin guide on the Chapman knowledge base.
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

const Concept = ({ num, color, title, body }) => (
  <div style={{ display: "flex", gap: 14, marginTop: 18, padding: 14, border: "1px solid var(--slds-border)", borderRadius: 6, borderLeft: `4px solid ${color}` }}>
    <div style={{ width: 32, height: 32, borderRadius: "50%", background: color, color: "#fff", display: "grid", placeItems: "center", fontWeight: 700, flexShrink: 0 }}>{num}</div>
    <div>
      <div style={{ fontWeight: 700, fontSize: 15 }}>{title}</div>
      <div style={{ fontSize: 13, color: "var(--slds-text-secondary)", marginTop: 4, lineHeight: 1.5 }}>{body}</div>
    </div>
  </div>
);
const Term = ({ k, v }) => (
  <div style={{ marginBottom: 8 }}>
    <dt style={{ fontWeight: 600, color: "var(--slds-text-primary)" }}>{k}</dt>
    <dd style={{ margin: 0 }}>{v}</dd>
  </div>
);

window.FiuGuide = FiuGuide;
