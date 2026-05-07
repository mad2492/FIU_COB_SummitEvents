/* eslint-disable no-undef */
const { useState, useMemo } = React;

/* ============== CREATE EVENT WIZARD (3-pane) ============== */
function FiuCreateEventWizard({ go, setToast }) {
  const STEPS = [
    { id: "basics",     label: "Basics",          icon: "event",    desc: "What and why" },
    { id: "audience",   label: "Programs",        icon: "people",   desc: "Programs offered" },
    { id: "branding",   label: "Branding",        icon: "settings", desc: "Look & feel" },
    { id: "logistics",  label: "Logistics",       icon: "instance", desc: "Location, capacity" },
    { id: "payment",    label: "Payment",         icon: "settings", desc: "Pricing & gateway" },
    { id: "review",     label: "Review & Create", icon: "check",    desc: "Confirm" }
  ];
  const [stepIdx, setStepIdx] = useState(0);
  const [form, setForm] = useState({
    name: "MBA Spring 2026 Open House",
    description: "An evening for prospective MBA students to meet faculty, tour the Chapman School, and learn about admissions.",
    recordType: "RT_CHAP",
    businessUnit: "BU_CHAP",
    template: "TPL_CHAPMAN",
    eventType: "GRAD_REC",
    category: "OPEN_HOUSE",
    programs: ["MBA"],
    audienceTags: ["Prospective Students", "Admitted Students"],
    isPaid: false,
    price: "",
    paymentGateway: "",
    accountingDept: "",
    locationType: "On-site",
    venue: "Modesto A. Maidique Campus, MANGO 100",
    capacity: 120,
    waitlist: true,
    startDate: "2026-03-12",
    endDate: "2026-03-12",
    primaryColor: "#081E3F",
    bannerImage: "uploaded.png",
    logoImage: "fiu-chapman-logo.png",
    pageCopy: {
      welcome: "Welcome to the FIU College of Business. We're excited you're considering Chapman.",
      registration: "Tell us about yourself. Required fields are marked with an asterisk.",
      confirmation: "You're registered! Watch for a confirmation email with calendar invite and venue details.",
      reminder: "See you soon! Reply to this email if you need to cancel or update your registration."
    }
  });
  const setF = patch => setForm(prev => ({ ...prev, ...patch }));

  const validation = useMemo(() => {
    const errors = {};
    const warnings = {};
    if (!form.name) errors.name = "Event name is required";
    if (!form.recordType) errors.recordType = "Pick a record type — this controls which fields you see";
    if (!form.template) errors.template = "Template required";
    if (form.programs.length === 0) errors.programs = "Select at least one program";
    if (form.isPaid && !form.paymentGateway) errors.paymentGateway = "Paid events need a payment gateway";
    if (form.isPaid && !form.price) errors.price = "Set a price for paid events";
    if (form.isPaid && !form.accountingDept) errors.accountingDept = "Pick an accounting department for paid events";
    if (!form.bannerImage) warnings.bannerImage = "Banner image not set — registration page will look generic";
    if (!form.endDate) warnings.endDate = "No end date — defaults to start date";
    return { errors, warnings, isValid: Object.keys(errors).length === 0 };
  }, [form]);

  const stepValidity = STEPS.map((s) => {
    if (s.id === "basics")    return form.name && form.recordType && form.template;
    if (s.id === "audience")  return form.programs.length > 0;
    if (s.id === "branding")  return true;
    if (s.id === "logistics") return form.locationType && form.capacity;
    if (s.id === "payment")   return !form.isPaid || (form.paymentGateway && form.price && form.accountingDept);
    if (s.id === "review")    return validation.isValid;
    return true;
  });

  const next = () => setStepIdx(Math.min(stepIdx + 1, STEPS.length - 1));
  const prev = () => setStepIdx(Math.max(stepIdx - 1, 0));

  return (
    <div data-screen-label="05 Create Event Wizard">
      <PageHeader crumbs={[{label:"Home",to:"home"},{label:"Events",to:"events"},{label:"New Event"}]} title="Create a new event" go={go}
        actions={<Btn onClick={() => go("home")}>Cancel</Btn>}
      />

      <div style={{ display: "grid", gridTemplateColumns: "240px 1fr 360px", gap: 12, alignItems: "start" }}>
        {/* LEFT: stepper */}
        <div style={{ background: "#fff", border: "1px solid var(--slds-border)", borderRadius: 6, overflow: "hidden", position: "sticky", top: 12 }}>
          <div style={{ padding: "10px 14px", borderBottom: "1px solid var(--slds-border)", background: "var(--slds-bg-alt)", fontWeight: 700, fontSize: 13 }}>Steps</div>
          <ol style={{ listStyle: "none", margin: 0, padding: 0 }}>
            {STEPS.map((s, i) => {
              const isActive = i === stepIdx;
              const isDone = i < stepIdx && stepValidity[i];
              const hasIssue = i < stepIdx && !stepValidity[i];
              return (
                <li key={s.id}>
                  <button onClick={() => setStepIdx(i)} style={{
                    display: "flex", alignItems: "center", gap: 10, width: "100%",
                    padding: "10px 14px", background: isActive ? "var(--slds-brand-lightest)" : "transparent",
                    border: 0, borderLeft: isActive ? "3px solid var(--slds-brand)" : "3px solid transparent",
                    cursor: "pointer", textAlign: "left", font: "inherit",
                    borderBottom: "1px solid var(--slds-border)"
                  }}>
                    <div style={{
                      width: 24, height: 24, borderRadius: "50%",
                      background: isDone ? "#04844B" : hasIssue ? "#BA0517" : isActive ? "var(--slds-brand)" : "#E5E5E5",
                      color: "#fff", display: "grid", placeItems: "center", fontSize: 11, fontWeight: 700, flexShrink: 0
                    }}>{isDone ? "✓" : hasIssue ? "!" : i+1}</div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ fontWeight: isActive ? 700 : 500, fontSize: 13 }}>{s.label}</div>
                      <div className="muted" style={{ fontSize: 11 }}>{s.desc}</div>
                    </div>
                  </button>
                </li>
              );
            })}
          </ol>
        </div>

        {/* CENTER: form */}
        <div style={{ background: "#fff", border: "1px solid var(--slds-border)", borderRadius: 6, overflow: "hidden" }}>
          <div style={{ padding: "12px 16px", borderBottom: "1px solid var(--slds-border)", display: "flex", alignItems: "center", gap: 10 }}>
            <div className={`circle-icon icn-event`} style={{ width: 28, height: 28 }}>
              <Icon name={STEPS[stepIdx].icon} color="#fff" size={16}/>
            </div>
            <div>
              <div style={{ fontSize: 16, fontWeight: 700 }}>Step {stepIdx+1} of {STEPS.length}: {STEPS[stepIdx].label}</div>
              <div className="muted" style={{ fontSize: 12 }}>{STEPS[stepIdx].desc}</div>
            </div>
            <div style={{ flex: 1 }}/>
            <div style={{ height: 4, width: 120, background: "#eee", borderRadius: 2 }}>
              <div style={{ width: `${((stepIdx+1)/STEPS.length)*100}%`, height: "100%", background: "var(--slds-brand)", borderRadius: 2 }}/>
            </div>
          </div>

          <div style={{ padding: 18 }}>
            {stepIdx === 0 && <BasicsStep form={form} setF={setF} errors={validation.errors}/>}
            {stepIdx === 1 && <AudienceStep form={form} setF={setF} errors={validation.errors}/>}
            {stepIdx === 2 && <BrandingStep form={form} setF={setF} errors={validation.errors}/>}
            {stepIdx === 3 && <LogisticsStep form={form} setF={setF} errors={validation.errors}/>}
            {stepIdx === 4 && <PaymentStep form={form} setF={setF} errors={validation.errors}/>}
            {stepIdx === 5 && <ReviewStep form={form} validation={validation} steps={STEPS} setStepIdx={setStepIdx}/>}
          </div>

          <div style={{ padding: 14, borderTop: "1px solid var(--slds-border)", background: "var(--slds-bg-alt)", display: "flex", justifyContent: "space-between" }}>
            <Btn onClick={() => go("home")}>Save as draft & exit</Btn>
            <div style={{ display: "flex", gap: 6 }}>
              <Btn onClick={prev} disabled={stepIdx === 0}>← Previous</Btn>
              {stepIdx < STEPS.length - 1
                ? <Btn variant="brand" onClick={next}>Next: {STEPS[stepIdx+1].label} →</Btn>
                : <Btn variant="brand" disabled={!validation.isValid} onClick={() => { setToast({ variant: "success", message: "Event created with 0 instances. Add an instance to make it live." }); go("events"); }}>Create Event</Btn>
              }
            </div>
          </div>
        </div>

        {/* RIGHT: Live Preview + Validation */}
        <div style={{ display: "flex", flexDirection: "column", gap: 12, position: "sticky", top: 12 }}>
          <PreviewCard form={form}/>
          <ValidationCard validation={validation}/>
          <ContextHelp step={STEPS[stepIdx].id}/>
        </div>
      </div>
    </div>
  );
}

/* ----- Step components ----- */
function BasicsStep({ form, setF, errors }) {
  return (
    <div>
      <SectionHeading title="What is this event?" subtitle="The name and description appear on registration pages."/>
      <div className="form-grid">
        <Field label="Event Name" required error={errors.name} hint="Use a name attendees will recognize. Year and term help.">
          <Input value={form.name} onChange={e => setF({ name: e.target.value })}/>
        </Field>
        <Field label="Description" hint="Plain text or rich-text. Shown on the public registration page.">
          <Textarea rows={3} value={form.description} onChange={e => setF({ description: e.target.value })}/>
        </Field>
      </div>

      <div className="spacer-md"/>
      <SectionHeading title="Classification" subtitle="These three fields control which fields you see — and which approvals are needed. They can't be changed later, so pick carefully."/>

      <div className="form-grid">
        <Field label="Record Type" required error={errors.recordType} hint="Determines layout, fields, and approval routing.">
          <Select value={form.recordType} onChange={e => setF({ recordType: e.target.value })} options={[{value:"",label:"Choose a record type..."}, ...MOCK.recordTypes]}/>
        </Field>
        <Field label="Business Unit" required hint="Auto-filled based on Record Type — change only if needed.">
          <Select value={form.businessUnit} onChange={e => setF({ businessUnit: e.target.value })} options={MOCK.businessUnits}/>
        </Field>
        <Field label="Template" required error={errors.template} hint="Visual layout for the registration page. Don't worry — you can preview before launch.">
          <Select value={form.template} onChange={e => setF({ template: e.target.value })} options={[{value:"",label:"Choose a template..."}, ...MOCK.templates]}/>
        </Field>
      </div>

      <div className="spacer-md"/>
      <SectionHeading title="Type & Category" subtitle="Used for reporting. Category options change based on Type."/>

      <div className="form-grid">
        <Field label="Event Type" required>
          <Select value={form.eventType} onChange={e => setF({ eventType: e.target.value, category: "" })} options={MOCK.eventTypes}/>
        </Field>
        <Field label="Category" hint="Filtered by Event Type">
          <Select value={form.category} onChange={e => setF({ category: e.target.value })} options={[{value:"",label:"Choose a category..."}, ...MOCK.categories.filter(c => c.controller === form.eventType)]}/>
        </Field>
      </div>
    </div>
  );
}

function AudienceStep({ form, setF, errors }) {
  const [query, setQuery] = useState("");
  const [levelFilter, setLevelFilter] = useState("");
  const allPrograms = MOCK.programs.filter(p => p.value);
  const toggleProgram = v => setF({ programs: form.programs.includes(v) ? form.programs.filter(p => p !== v) : [...form.programs, v] });
  const toggleTag = v => setF({ audienceTags: form.audienceTags.includes(v) ? form.audienceTags.filter(p => p !== v) : [...form.audienceTags, v] });

  const filtered = allPrograms.filter(p =>
    (!levelFilter || p.level === levelFilter) &&
    (!query || p.label.toLowerCase().includes(query.toLowerCase()) || p.value.toLowerCase().includes(query.toLowerCase()))
  );
  const grouped = filtered.reduce((acc, p) => { (acc[p.level] = acc[p.level] || []).push(p); return acc; }, {});
  const levelOrder = ["Masters", "Executive", "Doctoral", "Certificate", "Other"];

  const selectAllVisible = () => setF({ programs: Array.from(new Set([...form.programs, ...filtered.map(p => p.value)])) });
  const clearVisible = () => setF({ programs: form.programs.filter(v => !filtered.find(p => p.value === v)) });

  return (
    <div>
      <SectionHeading
        title="Which Graduate Programs is this event related to?"
        subtitle="Registrations are tagged with the program a registrant chooses, so recruiting can follow up. On the public registration site, the prospect picks one of the programs you select here from a dropdown."
      />
      {errors.programs && <Helper variant="error">{errors.programs}</Helper>}

      {/* Selected count + bulk */}
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 10, marginBottom: 8 }}>
        <Badge variant={form.programs.length > 0 ? "info" : "neutral"} icon="check">
          {form.programs.length} selected
        </Badge>
        <span style={{ flex: 1 }}/>
        <button onClick={selectAllVisible} style={{ background: "none", border: 0, color: "var(--slds-brand)", cursor: "pointer", fontSize: 12 }}>Select all visible</button>
        <span className="muted" style={{ fontSize: 12 }}>·</span>
        <button onClick={clearVisible} style={{ background: "none", border: 0, color: "var(--slds-brand)", cursor: "pointer", fontSize: 12 }}>Clear visible</button>
      </div>

      {/* Selected chips */}
      {form.programs.length > 0 && (
        <div style={{ display: "flex", gap: 6, flexWrap: "wrap", padding: 10, background: "var(--slds-brand-lightest)", border: "1px solid #B0DAFB", borderRadius: 4, marginBottom: 10 }}>
          {form.programs.map(v => {
            const p = allPrograms.find(x => x.value === v);
            if (!p) return null;
            return (
              <span key={v} className="pill">
                {p.label}
                <span className="x" onClick={() => toggleProgram(v)}><Icon name="close" size={10}/></span>
              </span>
            );
          })}
        </div>
      )}

      {/* Search + filter */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 200px", gap: 8, marginBottom: 8 }}>
        <div style={{ position: "relative" }}>
          <span style={{ position: "absolute", left: 10, top: "50%", transform: "translateY(-50%)", color: "#747474" }}><Icon name="search" size={14}/></span>
          <Input value={query} onChange={e => setQuery(e.target.value)} placeholder="Search programs by name or code..." style={{ paddingLeft: 30 }}/>
        </div>
        <Select
          value={levelFilter}
          onChange={e => setLevelFilter(e.target.value)}
          options={[{value:"",label:"All levels"}, ...levelOrder.map(l => ({value:l,label:l}))]}
        />
      </div>

      {/* Scrollable list */}
      <div style={{ border: "1px solid var(--slds-border)", borderRadius: 4, maxHeight: 320, overflow: "auto", background: "#fff" }}>
        {filtered.length === 0 && (
          <div style={{ padding: 20, textAlign: "center", color: "var(--slds-text-tertiary)", fontSize: 12 }}>
            No programs match. Try clearing search or filter.
          </div>
        )}
        {levelOrder.filter(l => grouped[l]).map(level => (
          <div key={level}>
            <div style={{ padding: "6px 12px", background: "var(--slds-bg-alt)", fontSize: 11, fontWeight: 700, color: "var(--slds-text-tertiary)", textTransform: "uppercase", letterSpacing: ".04em", borderBottom: "1px solid var(--slds-border)", position: "sticky", top: 0 }}>
              {level} <span style={{ fontWeight: 400 }}>· {grouped[level].length}</span>
            </div>
            {grouped[level].map(p => {
              const on = form.programs.includes(p.value);
              return (
                <label key={p.value} style={{
                  display: "flex", alignItems: "center", gap: 10, padding: "8px 12px",
                  borderBottom: "1px solid var(--slds-border)", cursor: "pointer",
                  background: on ? "var(--slds-brand-lightest)" : "#fff"
                }}>
                  <input type="checkbox" checked={on} onChange={() => toggleProgram(p.value)}/>
                  <div style={{ flex: 1 }}>
                    <div className="bold" style={{ fontSize: 13 }}>{p.label}</div>
                    <div className="muted" style={{ fontSize: 11 }}>{p.value} · {p.dept}</div>
                  </div>
                </label>
              );
            })}
          </div>
        ))}
      </div>
      <div className="muted" style={{ fontSize: 11, marginTop: 6 }}>
        Showing {filtered.length} of {allPrograms.length} programs
      </div>

      <div className="spacer-md"/>
      <SectionHeading title="Audience tags" subtitle="Used for marketing segmentation and reporting — separate from program selection above."/>
      <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
        {["Prospective Students","Admitted Students","Current Students","Alumni","Faculty","Corporate Partners","General Public"].map(t => {
          const on = form.audienceTags.includes(t);
          return (
            <button key={t} onClick={() => toggleTag(t)} style={{
              border: `1px solid ${on ? "var(--slds-brand)" : "var(--slds-border)"}`,
              background: on ? "var(--slds-brand)" : "#fff",
              color: on ? "#fff" : "var(--slds-text-primary)",
              padding: "6px 12px", borderRadius: 100, cursor: "pointer", fontSize: 12, font: "inherit"
            }}>{t}</button>
          );
        })}
      </div>
    </div>
  );
}

function BrandingStep({ form, setF }) {
  const tpl = MOCK.templates.find(t => t.value === form.template);
  const setCopy = (k, v) => setF({ pageCopy: { ...form.pageCopy, [k]: v } });
  const PAGES = [
    { key: "welcome",      label: "Welcome page",      hint: "First page prospects land on. Sets the tone." },
    { key: "registration", label: "Registration form", hint: "Shown above the form fields." },
    { key: "confirmation", label: "Confirmation page", hint: "After submitting registration." },
    { key: "reminder",     label: "Reminder email",    hint: "Body copy sent 24 hours before the event." }
  ];

  return (
    <div>
      <SectionHeading
        title="Pick the Template"
        subtitle="The Template is the HTML backbone of the public registration site for this event. It's how the page gets rendered — there's no preview without one. You can swap it later, but pick the one that best matches the audience now."
      />
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginBottom: 4 }}>
        {MOCK.templates.map(t => {
          const on = form.template === t.value;
          return (
            <button key={t.value} onClick={() => setF({ template: t.value })} style={{
              border: `2px solid ${on ? "var(--slds-brand)" : "var(--slds-border)"}`,
              background: "#fff", borderRadius: 6, cursor: "pointer", textAlign: "left",
              padding: 0, font: "inherit", overflow: "hidden", position: "relative"
            }}>
              <div style={{ height: 70, background: t.preview.bg, position: "relative" }}>
                <div style={{ position: "absolute", left: 10, top: 10, width: 28, height: 28, borderRadius: 4, background: "rgba(255,255,255,.95)", display: "grid", placeItems: "center", fontSize: 10, fontWeight: 700, color: "#081E3F" }}>FIU</div>
                <div style={{ position: "absolute", right: 10, bottom: 10, padding: "4px 10px", background: t.preview.accent, color: "#0a0a0a", fontSize: 10, fontWeight: 700, borderRadius: 3 }}>Register</div>
              </div>
              <div style={{ padding: 10 }}>
                <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                  <div className="bold" style={{ fontSize: 13 }}>{t.label}</div>
                  {on && <Badge variant="success" icon="check">Selected</Badge>}
                </div>
                <div className="muted" style={{ fontSize: 11, marginTop: 4 }}>{t.desc}</div>
              </div>
            </button>
          );
        })}
      </div>

      <div className="spacer-md"/>
      <SectionHeading
        title="Customize the template"
        subtitle={tpl ? `These are the only pieces of "${tpl.label}" you can override per event. Everything else (colors, type, footer, layout) is locked to the template.` : "Pick a template above to unlock customization."}
      />

      <div className="form-grid">
        <Field label="Logo (header)" hint="Replaces the template's default school/department logo. PNG with transparent bg, 200×60px recommended.">
          {form.logoImage
            ? <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <div style={{ height: 50, width: 160, background: "#fff", border: "1px solid var(--slds-border)", borderRadius: 4, display: "grid", placeItems: "center", fontSize: 11, fontWeight: 600, color: "#081E3F" }}>
                  {form.logoImage}
                </div>
                <Btn icon="close" size="sm" onClick={() => setF({ logoImage: "" })}>Replace</Btn>
              </div>
            : <button style={{ border: "1.5px dashed var(--slds-border-strong)", padding: 14, borderRadius: 4, width: "100%", background: "var(--slds-bg-alt)", cursor: "pointer", textAlign: "center" }}
                onClick={() => setF({ logoImage: "fiu-chapman-logo.png" })}>
                <Icon name="upload" color="#0176D3"/>
                <div style={{ fontSize: 12, marginTop: 6 }}>Upload logo (or use template default)</div>
              </button>
          }
        </Field>
        <Field label="Banner image" hint="Hero image at the top of the registration page. 1200×400px, JPEG/PNG.">
          {form.bannerImage
            ? <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <div style={{ height: 50, width: 160, background: tpl?.preview.bg || "linear-gradient(135deg,#081E3F,#B6862C)", borderRadius: 4, display: "grid", placeItems: "center", color: "#fff", fontSize: 10, fontWeight: 600 }}>
                  {form.bannerImage}
                </div>
                <Btn icon="close" size="sm" onClick={() => setF({ bannerImage: "" })}>Replace</Btn>
              </div>
            : <button style={{ border: "1.5px dashed var(--slds-border-strong)", padding: 14, borderRadius: 4, width: "100%", background: "var(--slds-bg-alt)", cursor: "pointer", textAlign: "center" }}
                onClick={() => setF({ bannerImage: "banner.png" })}>
                <Icon name="upload" color="#0176D3"/>
                <div style={{ fontSize: 12, marginTop: 6 }}>Upload banner</div>
              </button>
          }
        </Field>
      </div>

      <div className="spacer-md"/>
      <div style={{ fontWeight: 700, fontSize: 13, marginBottom: 4 }}>Page copy</div>
      <div className="muted" style={{ fontSize: 12, marginBottom: 10 }}>Each page in the registration flow has a customizable copy block. The template provides defaults — override only what you want different.</div>

      <div style={{ display: "grid", gap: 10 }}>
        {PAGES.map(pg => (
          <div key={pg.key} style={{ border: "1px solid var(--slds-border)", borderRadius: 6, padding: 12, background: "#fff" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 6 }}>
              <Badge variant="info">{pg.label}</Badge>
              <span className="muted" style={{ fontSize: 11 }}>{pg.hint}</span>
              <span style={{ flex: 1 }}/>
              <button onClick={() => setCopy(pg.key, "")} style={{ background: "none", border: 0, color: "var(--slds-brand)", cursor: "pointer", fontSize: 11 }}>Reset to template default</button>
            </div>
            <Textarea rows={2} value={form.pageCopy[pg.key]} onChange={e => setCopy(pg.key, e.target.value)} placeholder={`Use template default copy for ${pg.label.toLowerCase()}...`}/>
          </div>
        ))}
      </div>
    </div>
  );
}

function LogisticsStep({ form, setF }) {
  return (
    <div>
      <SectionHeading title="Where & how" subtitle="These settings apply to the Event by default — individual Instances can override them."/>
      <div className="form-grid">
        <Field label="Location Type" required>
          <Select value={form.locationType} onChange={e => setF({ locationType: e.target.value })} options={MOCK.locationTypes}/>
        </Field>
        {(form.locationType === "On-site" || form.locationType === "Hybrid" || form.locationType === "Off-campus") && (
          <Field label="Venue / Address" hint="Building & room, or full address for off-campus.">
            <Input value={form.venue} onChange={e => setF({ venue: e.target.value })}/>
          </Field>
        )}
        <Field label="Default Capacity" hint="Maximum registrants per instance. Override on each instance if needed.">
          <Input type="number" value={form.capacity} onChange={e => setF({ capacity: e.target.value })}/>
        </Field>
        <Field label="Waitlist">
          <Toggle on={form.waitlist} onChange={v => setF({ waitlist: v })} label={form.waitlist ? "Enabled — extra registrants join the waitlist" : "Disabled — registration closes when full"}/>
        </Field>
        <Field label="Start Date">
          <Input type="date" value={form.startDate} onChange={e => setF({ startDate: e.target.value })}/>
        </Field>
        <Field label="End Date">
          <Input type="date" value={form.endDate} onChange={e => setF({ endDate: e.target.value })}/>
        </Field>
      </div>
    </div>
  );
}

function PaymentStep({ form, setF, errors }) {
  return (
    <div>
      <SectionHeading title="Is this a paid event?" subtitle="If you're not sure, leave it free — you can change this before going live."/>
      <Toggle on={form.isPaid} onChange={v => setF({ isPaid: v })} label={form.isPaid ? "Yes — attendees pay to register" : "No — free event"}/>
      {form.isPaid && (
        <>
          <div className="spacer-md"/>
          <Helper variant="info">Paid events require a payment gateway and an accounting department. Both are validated before the event can go live.</Helper>
          <div className="form-grid" style={{ marginTop: 12 }}>
            <Field label="Price (USD)" required error={errors.price}>
              <Input type="number" value={form.price} onChange={e => setF({ price: e.target.value })} placeholder="0.00"/>
            </Field>
            <Field label="Payment Gateway" required error={errors.paymentGateway} hint="TouchNet is the FIU-standard option.">
              <Select value={form.paymentGateway} onChange={e => setF({ paymentGateway: e.target.value })} options={[{value:"",label:"Choose a payment gateway..."}, ...MOCK.paymentGateways]}/>
            </Field>
            <Field label="Accounting Department" required error={errors.accountingDept} hint="Funds are routed here. Ask your finance contact if unsure.">
              <Select value={form.accountingDept} onChange={e => setF({ accountingDept: e.target.value })} options={[{value:"",label:"Choose a department..."}, ...MOCK.accountingDepts]}/>
            </Field>
          </div>
        </>
      )}
    </div>
  );
}

function ReviewStep({ form, validation, steps, setStepIdx }) {
  const fields = [
    { step: 0, label: "Event Name", value: form.name },
    { step: 0, label: "Record Type", value: MOCK.recordTypes.find(r => r.value === form.recordType)?.label },
    { step: 0, label: "Business Unit", value: MOCK.businessUnits.find(r => r.value === form.businessUnit)?.label },
    { step: 0, label: "Template", value: MOCK.templates.find(r => r.value === form.template)?.label },
    { step: 0, label: "Event Type / Category", value: `${MOCK.eventTypes.find(r => r.value === form.eventType)?.label} / ${MOCK.categories.find(r => r.value === form.category)?.label || "—"}` },
    { step: 1, label: "Programs", value: form.programs.map(p => MOCK.programs.find(x => x.value === p)?.label).join(", ") },
    { step: 1, label: "Audience", value: form.audienceTags.join(", ") },
    { step: 3, label: "Location", value: `${form.locationType}${form.venue ? " — " + form.venue : ""}` },
    { step: 3, label: "Default Capacity", value: form.capacity },
    { step: 3, label: "Waitlist", value: form.waitlist ? "Enabled" : "Disabled" },
    { step: 4, label: "Pricing", value: form.isPaid ? `Paid — $${form.price || "?"} via ${MOCK.paymentGateways.find(g => g.value === form.paymentGateway)?.label || "—"}` : "Free" }
  ];
  return (
    <div>
      <SectionHeading title="Review your event" subtitle="Everything looks good? Click Create. The event will be created with 0 instances — you can add a date next."/>
      {!validation.isValid && (
        <Helper variant="error">There are {Object.keys(validation.errors).length} required field(s) missing. Click any row below to fix.</Helper>
      )}
      {Object.keys(validation.warnings).length > 0 && (
        <Helper variant="warning">{Object.keys(validation.warnings).length} warning(s) — won't block creation, but worth reviewing.</Helper>
      )}
      <div style={{ border: "1px solid var(--slds-border)", borderRadius: 4, marginTop: 12, overflow: "hidden" }}>
        {fields.map((f, i) => (
          <div key={i} style={{ display: "flex", padding: "10px 14px", borderBottom: i < fields.length - 1 ? "1px solid var(--slds-border)" : 0, alignItems: "center", gap: 10 }}>
            <div style={{ width: 180, color: "var(--slds-text-tertiary)", fontSize: 12 }}>{f.label}</div>
            <div style={{ flex: 1, fontSize: 13 }}>{f.value || <span className="muted">(empty)</span>}</div>
            <button onClick={() => setStepIdx(f.step)} style={{ background: "none", border: 0, color: "var(--slds-brand)", cursor: "pointer", fontSize: 12 }}>Edit</button>
          </div>
        ))}
      </div>

      <div className="spacer-md"/>
      <Helper variant="info">After creation: you'll need to <strong>add at least one Instance</strong> (a specific date/time) before people can register. We'll prompt you on the next screen.</Helper>
    </div>
  );
}

/* ----- Right rail components ----- */
function PreviewCard({ form }) {
  return (
    <div style={{ background: "#fff", border: "1px solid var(--slds-border)", borderRadius: 6, overflow: "hidden" }}>
      <div style={{ padding: "8px 12px", background: "var(--slds-bg-alt)", borderBottom: "1px solid var(--slds-border)", fontSize: 12, fontWeight: 700, display: "flex", alignItems: "center", gap: 6 }}>
        <Icon name="eye" size={12}/> Live Preview
        <span className="muted" style={{ fontWeight: 400, fontSize: 11 }}>· What attendees will see</span>
      </div>
      <div style={{ padding: 0 }}>
        <div style={{ height: 80, background: form.bannerImage ? `linear-gradient(135deg, ${form.primaryColor || "#081E3F"} 0%, #B6862C 100%)` : "#E5E5E5", display: "grid", placeItems: "center", color: "#fff", fontSize: 11, fontWeight: 600 }}>
          {form.bannerImage ? "EVENT BANNER" : <span style={{ color: "#777" }}>No banner</span>}
        </div>
        <div style={{ padding: 14 }}>
          <div style={{ fontSize: 16, fontWeight: 700, color: "#16325C" }}>{form.name || "Event name"}</div>
          <div className="muted" style={{ fontSize: 11, marginTop: 4 }}>
            {form.startDate} {form.endDate && form.endDate !== form.startDate && `– ${form.endDate}`}
            {" · "}{form.venue || form.locationType}
          </div>
          <div style={{ fontSize: 12, marginTop: 8, color: "var(--slds-text-secondary)" }}>{form.description || "(no description)"}</div>
          {form.isPaid && form.price && (
            <div style={{ fontSize: 13, marginTop: 8 }}><strong>Price:</strong> ${form.price}</div>
          )}
          <button style={{
            marginTop: 12, padding: "8px 16px", background: form.primaryColor || "var(--slds-brand)",
            color: "#fff", border: 0, borderRadius: 4, cursor: "pointer", fontSize: 13, fontWeight: 600, width: "100%"
          }}>Register</button>
        </div>
      </div>
    </div>
  );
}

function ValidationCard({ validation }) {
  const errs = Object.entries(validation.errors);
  const warns = Object.entries(validation.warnings);
  if (errs.length === 0 && warns.length === 0) {
    return (
      <div style={{ background: "var(--slds-success-bg)", border: "1px solid #B5E1B0", borderRadius: 6, padding: 12, fontSize: 12, color: "#03612F", display: "flex", gap: 8 }}>
        <Icon name="check" color="#04844B"/>
        <div><strong>Ready to create.</strong> All required fields are filled.</div>
      </div>
    );
  }
  return (
    <div style={{ background: "#fff", border: "1px solid var(--slds-border)", borderRadius: 6, overflow: "hidden" }}>
      <div style={{ padding: "8px 12px", background: "var(--slds-bg-alt)", borderBottom: "1px solid var(--slds-border)", fontSize: 12, fontWeight: 700 }}>
        Validation
      </div>
      <div>
        {errs.map(([k, v]) => (
          <div key={k} style={{ padding: "8px 12px", borderBottom: "1px solid var(--slds-border)", fontSize: 12, display: "flex", gap: 8, color: "#8E030F" }}>
            <Icon name="warning" color="#BA0517"/> {v}
          </div>
        ))}
        {warns.map(([k, v]) => (
          <div key={k} style={{ padding: "8px 12px", borderBottom: "1px solid var(--slds-border)", fontSize: 12, display: "flex", gap: 8, color: "#8C4A00" }}>
            <Icon name="warning" color="#FE9339"/> {v}
          </div>
        ))}
      </div>
    </div>
  );
}

function ContextHelp({ step }) {
  const help = {
    basics: { title: "Why these matter", body: "Record Type and Template control what fields appear on the Event and the look of its registration page. They can't be changed easily later — pick deliberately." },
    audience: { title: "Programs drive recruiting", body: "Each registration is tagged with the program the prospect chose, so the right recruiter can follow up. Pick every program this event is relevant for — the public registration page renders these as a single dropdown." },
    branding: { title: "Why Template comes first", body: "The Template is the HTML scaffold of the public site — the only way to render a preview at all. Logo, banner, and page copy are the customization surfaces; everything else is locked to the template so events stay on-brand." },
    logistics: { title: "Event vs. Instance settings", body: "Settings here are defaults. Each Instance (specific date) can override the venue, capacity, and waitlist." },
    payment: { title: "Why are these required?", body: "Paid events must route money correctly. The payment gateway processes the card; the accounting department books the revenue. Both are validated before the event can go live." },
    review: { title: "Almost there", body: "After clicking Create, you'll be asked to add the first Instance. The event won't appear publicly until it has at least one active instance." }
  }[step];
  return (
    <div style={{ background: "var(--slds-brand-lightest)", border: "1px solid #B0DAFB", borderRadius: 6, padding: 12, fontSize: 12, color: "var(--slds-brand-darker)" }}>
      <div style={{ fontWeight: 700, marginBottom: 4, display: "flex", alignItems: "center", gap: 6 }}>
        <Icon name="info" color="#0176D3" size={14}/> {help.title}
      </div>
      <div>{help.body}</div>
    </div>
  );
}

const SectionHeading = ({ title, subtitle }) => (
  <div style={{ marginBottom: 12 }}>
    <div style={{ fontSize: 14, fontWeight: 700, color: "var(--slds-text-primary)" }}>{title}</div>
    {subtitle && <div className="muted" style={{ fontSize: 12, marginTop: 2 }}>{subtitle}</div>}
  </div>
);

const Helper = ({ variant, children }) => {
  const styles = {
    info:    { bg: "#EAF5FE", border: "#B0DAFB", color: "#014486", icon: "#0176D3" },
    warning: { bg: "var(--slds-warning-bg)", border: "#FCC58D", color: "#8C4A00", icon: "#FE9339" },
    error:   { bg: "var(--slds-error-bg)", border: "#F39191", color: "#8E030F", icon: "#BA0517" }
  }[variant];
  return (
    <div style={{ background: styles.bg, border: `1px solid ${styles.border}`, color: styles.color, padding: "8px 12px", borderRadius: 4, fontSize: 12, display: "flex", gap: 8, alignItems: "flex-start" }}>
      <Icon name="info" color={styles.icon}/>
      <div>{children}</div>
    </div>
  );
};

window.FiuCreateEventWizard = FiuCreateEventWizard;
