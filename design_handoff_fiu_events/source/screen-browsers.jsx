/* eslint-disable no-undef */
const { useState, useMemo } = React;

/* Shared list-view shell with side-panel drill down */
function ListShell({ screenLabel, icon, iconClass, title, subtitle, scope, columns, rows, primaryAction, secondaryActions, filterDef, defaultFilters, sideRender, rowActions, setToast, hint }) {
  const [search, setSearch] = useState("");
  const [filters, setFilters] = useState(defaultFilters || {});
  const [sel, setSel] = useState([]);
  const [activeRow, setActiveRow] = useState(null);
  const [showFilter, setShowFilter] = useState(false);

  const visible = useMemo(() => {
    let out = rows;
    if (search) {
      const q = search.toLowerCase();
      out = out.filter(r => Object.values(r).some(v => String(v ?? "").toLowerCase().includes(q)));
    }
    Object.entries(filters).forEach(([k, v]) => {
      if (v) out = out.filter(r => r[k] === v);
    });
    return out;
  }, [rows, search, filters]);

  const pills = Object.entries(filters).filter(([_, v]) => v).map(([k, v]) => {
    const def = (filterDef || []).find(f => f.key === k);
    const opt = def?.options.find(o => o.value === v);
    return { k, label: `${def?.label || k}: ${opt?.label || v}` };
  });
  if (search) pills.unshift({ k: "__search", label: `Search: "${search}"` });

  return (
    <div data-screen-label={screenLabel} style={{ display: "grid", gridTemplateColumns: activeRow ? "1fr 360px" : "1fr", gap: 12 }}>
      <LCard
        icon={icon} iconClass={iconClass}
        title={title} subtitle={subtitle}
        actions={(
          <>
            {primaryAction}
            {secondaryActions}
          </>
        )}
      >
        {hint && (
          <div style={{ padding: "8px 14px", background: "var(--slds-brand-lightest)", borderBottom: "1px solid #B0DAFB", fontSize: 12, color: "var(--slds-brand-darker)", display: "flex", gap: 8, alignItems: "center" }}>
            <Icon name="info" color="#0176D3"/> {hint}
          </div>
        )}
        <div className="toolbar">
          {scope && <Badge variant="info" icon="filter">{scope}</Badge>}
          <div className="search">
            <Input placeholder="Search this list..." value={search} onChange={e => setSearch(e.target.value)} />
          </div>
          <div className="grow"/>
          <Btn icon="refresh" title="Refresh" onClick={() => setToast?.({ variant: "info", message: "Refreshed" })}/>
          <Btn icon="filter" onClick={() => setShowFilter(true)}>Filters</Btn>
          <Btn icon="settings" title="View settings"/>
        </div>

        {pills.length > 0 && (
          <div style={{ padding: "8px 14px", display: "flex", gap: 6, flexWrap: "wrap", borderBottom: "1px solid var(--slds-border)" }}>
            {pills.map(p => (
              <span key={p.k} className="pill">
                {p.label}
                <span className="x" onClick={() => {
                  if (p.k === "__search") setSearch("");
                  else setFilters(f => ({ ...f, [p.k]: "" }));
                }}><Icon name="close" size={10}/></span>
              </span>
            ))}
            <button onClick={() => { setSearch(""); setFilters(defaultFilters || {}); }} style={{ background: "none", border: 0, color: "var(--slds-brand)", cursor: "pointer", fontSize: 12 }}>Clear all</button>
          </div>
        )}

        <div className="ldt-wrap" style={{ borderRadius: 0, border: 0, borderTop: "1px solid var(--slds-border)" }}>
          <table className="ldt">
            <thead>
              <tr>
                <th style={{ width: 32 }}>
                  <input type="checkbox" checked={sel.length === visible.length && visible.length > 0} onChange={e => setSel(e.target.checked ? visible.map(r => r.id) : [])}/>
                </th>
                {columns.map(c => <th key={c.key}>{c.label}</th>)}
                <th style={{ width: 40 }}></th>
              </tr>
            </thead>
            <tbody>
              {visible.map(r => (
                <tr key={r.id} className={sel.includes(r.id) ? "is-selected" : ""}>
                  <td><input type="checkbox" checked={sel.includes(r.id)} onChange={e => setSel(s => e.target.checked ? [...s, r.id] : s.filter(id => id !== r.id))}/></td>
                  {columns.map(c => <td key={c.key}>{c.render ? c.render(r, () => setActiveRow(r)) : r[c.key]}</td>)}
                  <td>
                    <button onClick={() => setActiveRow(r)} title="Quick view" style={{ background: "none", border: 0, cursor: "pointer", color: "var(--slds-brand)" }}><Icon name="eye"/></button>
                  </td>
                </tr>
              ))}
              {visible.length === 0 && (
                <tr><td colSpan={columns.length + 2}>
                  <div style={{ padding: 30, textAlign: "center" }}>
                    <div className="bold">No records match these filters.</div>
                    <div className="muted" style={{ fontSize: 12, marginTop: 4 }}>Try clearing filters or adjusting search.</div>
                    <div style={{ marginTop: 10 }}><Btn onClick={() => { setSearch(""); setFilters(defaultFilters || {}); }}>Clear filters</Btn></div>
                  </div>
                </td></tr>
              )}
            </tbody>
          </table>
        </div>
        <div style={{ padding: "8px 14px", display: "flex", justifyContent: "space-between", alignItems: "center", fontSize: 12, color: "var(--slds-text-tertiary)" }}>
          <span>Selected: {sel.length} · Showing {visible.length} of {rows.length}</span>
          <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
            <Select value="25" options={[{label:"25",value:"25"},{label:"50",value:"50"}]} onChange={()=>{}}/>
            <Btn size="sm" disabled>Previous</Btn>
            <Btn size="sm">Next</Btn>
          </div>
        </div>
      </LCard>

      {activeRow && (
        <div style={{ background: "#fff", border: "1px solid var(--slds-border)", borderRadius: 6, padding: 0, height: "fit-content", boxShadow: "var(--slds-shadow-2)" }}>
          <div style={{ padding: "10px 14px", borderBottom: "1px solid var(--slds-border)", display: "flex", alignItems: "center", gap: 8, background: "var(--slds-bg-alt)" }}>
            <div className="bold" style={{ flex: 1 }}>Quick view</div>
            <button onClick={() => setActiveRow(null)} style={{ background: "none", border: 0, cursor: "pointer" }}><Icon name="close"/></button>
          </div>
          <div style={{ padding: 14 }}>
            {sideRender ? sideRender(activeRow) : <pre style={{ fontSize: 11, whiteSpace: "pre-wrap" }}>{JSON.stringify(activeRow, null, 2)}</pre>}
          </div>
          {rowActions && <div style={{ padding: 12, borderTop: "1px solid var(--slds-border)", display: "flex", gap: 6, flexWrap: "wrap" }}>{rowActions(activeRow)}</div>}
        </div>
      )}

      <Modal open={showFilter} onClose={() => setShowFilter(false)} title="Filters"
        footer={<>
          <Btn onClick={() => setShowFilter(false)}>Cancel</Btn>
          <Btn variant="brand" onClick={() => setShowFilter(false)}>Apply</Btn>
        </>}>
        {(filterDef || []).map(f => (
          <Field key={f.key} label={f.label}>
            <Select value={filters[f.key] || ""} onChange={e => setFilters(prev => ({ ...prev, [f.key]: e.target.value }))} options={f.options}/>
          </Field>
        ))}
      </Modal>
    </div>
  );
}

/* ============== EVENTS BROWSER ============== */
function FiuEventBrowser({ go, setToast }) {
  return (
    <div>
      <PageHeader crumbs={[{label:"Home",to:"home"},{label:"Events"}]} title="Events" go={go}
        actions={<>
          <Btn icon="download">Export</Btn>
          <Btn variant="brand" icon="plus" onClick={() => go("wizard")}>Create New Event</Btn>
        </>}
      />
      <ListShell
        screenLabel="02 Events"
        icon="event" iconClass="icn-event"
        title="Events" subtitle={`${MOCK.events.length} records`}
        hint="Events are the parent concept. Each Event has one or more Instances (specific dates/times) for people to register for."
        rows={MOCK.events}
        defaultFilters={{ readiness: "", status: "", program: "" }}
        filterDef={[
          { key: "status", label: "Status", options: [{value:"",label:"All"},{value:"Active",label:"Active"},{value:"Draft",label:"Draft"},{value:"Closed",label:"Closed"}] },
          { key: "readiness", label: "Readiness", options: [{value:"",label:"All"},{value:"Ready",label:"Ready"},{value:"Not Ready",label:"Not Ready"}] },
          { key: "program", label: "Program", options: MOCK.programs }
        ]}
        columns={[
          { key: "name", label: "Event Name", render: (r, open) => <a href="#" onClick={(e)=>{e.preventDefault();open();}}>{r.name}</a> },
          { key: "recordType", label: "Record Type" },
          { key: "status", label: "Status", render: r => <Badge variant={r.status==="Active"?"success":r.status==="Draft"?"warning":"neutral"}>{r.status}</Badge> },
          { key: "readiness", label: "Readiness", render: r => <Badge variant={r.readiness==="Ready"?"success":"error"}>{r.readiness==="Ready"?"✓ Ready":"⚠ Not Ready"}</Badge> },
          { key: "issue", label: "Issues", render: r => r.issue ? <span style={{ color:"#BA0517" }}>{r.issue}</span> : <span className="muted">—</span> },
          { key: "instances", label: "Instances", render: r => <span className="bold">{r.instances}</span> },
          { key: "startDate", label: "Start Date" }
        ]}
        sideRender={r => (
          <div>
            <div className="bold" style={{ fontSize: 15 }}>{r.name}</div>
            <div className="muted" style={{ fontSize: 12, marginBottom: 10 }}>{r.recordType} · {r.program}</div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginBottom: 10 }}>
              <div><div className="muted" style={{fontSize:11}}>Status</div><Badge variant={r.status==="Active"?"success":"warning"}>{r.status}</Badge></div>
              <div><div className="muted" style={{fontSize:11}}>Readiness</div><Badge variant={r.readiness==="Ready"?"success":"error"}>{r.readiness}</Badge></div>
              <div><div className="muted" style={{fontSize:11}}>Start</div><div>{r.startDate}</div></div>
              <div><div className="muted" style={{fontSize:11}}>End</div><div>{r.endDate}</div></div>
              <div><div className="muted" style={{fontSize:11}}>Instances</div><div className="bold">{r.instances}</div></div>
              <div><div className="muted" style={{fontSize:11}}>Registrations</div><div className="bold">{r.registrations}</div></div>
            </div>
            {r.issue && (
              <div style={{ background: "var(--slds-error-bg)", border: "1px solid #F39191", borderRadius: 4, padding: 10, fontSize: 12, color: "#8E030F", display:"flex", gap: 8 }}>
                <Icon name="warning" color="#BA0517"/>{r.issue}
              </div>
            )}
          </div>
        )}
        rowActions={() => (
          <>
            <Btn icon="event" size="sm">Open</Btn>
            <Btn icon="instance" size="sm" onClick={() => go("instances")}>View Instances</Btn>
            <Btn icon="plus" size="sm" variant="brand">Add Instance</Btn>
          </>
        )}
        setToast={setToast}
      />
    </div>
  );
}

/* ============== INSTANCES BROWSER ============== */
function FiuInstanceBrowser({ go, setToast }) {
  return (
    <div>
      <PageHeader crumbs={[{label:"Home",to:"home"},{label:"Instances"}]} title="Instances" go={go}
        actions={<>
          <Btn icon="download">Export</Btn>
          <Btn icon="plus">Add Instance to existing event</Btn>
        </>}
      />
      <ListShell
        screenLabel="03 Instances"
        icon="instance" iconClass="icn-instance"
        title="Instances" subtitle={`${MOCK.instances.length} records`}
        hint="An Instance is a specific date and time of an Event. This is what people actually register for."
        rows={MOCK.instances}
        defaultFilters={{ readiness: "", status: "", program: "" }}
        filterDef={[
          { key: "status", label: "Status", options: [{value:"",label:"All"},{value:"Active",label:"Active"},{value:"Inactive",label:"Inactive"}] },
          { key: "readiness", label: "Readiness", options: [{value:"",label:"All"},{value:"Ready",label:"Ready"},{value:"Not Ready",label:"Not Ready"}] },
          { key: "program", label: "Program", options: MOCK.programs }
        ]}
        columns={[
          { key: "title", label: "Instance", render: (r, open) => <a href="#" onClick={(e)=>{e.preventDefault();open();}}>{r.title}</a> },
          { key: "eventName", label: "Event" },
          { key: "startDate", label: "Start", render: r => new Date(r.startDate).toLocaleString("en-US",{month:"short",day:"numeric",year:"numeric",hour:"numeric",minute:"2-digit"}) },
          { key: "status", label: "Status", render: r => <Badge variant={r.status==="Active"?"success":"neutral"}>{r.status}</Badge> },
          { key: "readiness", label: "Readiness", render: r => <Badge variant={r.readiness==="Ready"?"success":"error"}>{r.readiness}</Badge> },
          { key: "registered", label: "Registered", render: r => {
            const pct = Math.round((r.registered/r.capacity)*100);
            return <div style={{ minWidth: 110 }}>
              <div style={{ fontSize: 12 }}>{r.registered}/{r.capacity} ({pct}%)</div>
              <div style={{ height: 4, background: "#eee", borderRadius: 2, marginTop: 2 }}>
                <div style={{ width: `${pct}%`, height: "100%", background: pct>=90?"#BA0517":pct>=70?"#FE9339":"#04844B", borderRadius: 2 }}/>
              </div>
            </div>;
          }},
          { key: "reason", label: "Reason (if Not Ready)", render: r => r.reason ? <span style={{ color: "#BA0517" }}>{r.reason}</span> : <span className="muted">—</span> }
        ]}
        sideRender={r => (
          <div>
            <div className="bold" style={{ fontSize: 15 }}>{r.title}</div>
            <div className="muted" style={{ fontSize: 12, marginBottom: 10 }}>{r.eventName}</div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginBottom: 10 }}>
              <div><div className="muted" style={{fontSize:11}}>Start</div><div>{new Date(r.startDate).toLocaleString()}</div></div>
              <div><div className="muted" style={{fontSize:11}}>Status</div><Badge variant={r.status==="Active"?"success":"neutral"}>{r.status}</Badge></div>
              <div><div className="muted" style={{fontSize:11}}>Capacity</div><div>{r.capacity}</div></div>
              <div><div className="muted" style={{fontSize:11}}>Registered</div><div className="bold">{r.registered}</div></div>
            </div>
            {r.reason && (
              <div style={{ background: "var(--slds-error-bg)", border: "1px solid #F39191", borderRadius: 4, padding: 10, fontSize: 12, color: "#8E030F", display:"flex", gap: 8 }}>
                <Icon name="warning" color="#BA0517"/>{r.reason}
              </div>
            )}
          </div>
        )}
        rowActions={() => (
          <>
            <Btn icon="instance" size="sm">Open</Btn>
            <Btn icon="copy" size="sm">Clone</Btn>
            <Btn icon="people" size="sm" onClick={() => go("registrations")}>Registrations</Btn>
          </>
        )}
        setToast={setToast}
      />
    </div>
  );
}

/* ============== REGISTRATIONS BROWSER ============== */
function FiuRegistrationBrowser({ go, setToast }) {
  return (
    <div>
      <PageHeader crumbs={[{label:"Home",to:"home"},{label:"Registrations"}]} title="Registrations" go={go}
        actions={<>
          <Btn icon="download">Export</Btn>
          <Btn icon="people">Mass Update</Btn>
          <Btn variant="brand" icon="plus">Import</Btn>
        </>}
      />
      <ListShell
        screenLabel="04 Registrations"
        icon="people" iconClass="icn-people"
        title="Registrations" subtitle={`${MOCK.registrations.length} records`}
        hint="Each registration is one person signing up for one Instance. 'Started' status means they began but didn't finish — follow up on these."
        rows={MOCK.registrations}
        defaultFilters={{ status: "", program: "" }}
        filterDef={[
          { key: "status", label: "Status", options: [{value:"",label:"All"},{value:"Registered",label:"Registered"},{value:"Started",label:"Started (Review)"},{value:"Cancelled",label:"Cancelled"}] },
          { key: "program", label: "Program", options: MOCK.programs },
          { key: "locationType", label: "Location Type", options: [{value:"",label:"All"},{value:"On-site",label:"On-site"},{value:"Online",label:"Online"},{value:"Off-campus",label:"Off-campus"}] }
        ]}
        columns={[
          { key: "name", label: "Registration", render: (r, open) => <a href="#" onClick={(e)=>{e.preventDefault();open();}}>{r.name}</a> },
          { key: "contactName", label: "Contact", render: r => r.issue ? <span style={{ color:"#BA0517" }}>⚠ {r.contactName}</span> : r.contactName },
          { key: "email", label: "Email" },
          { key: "event", label: "Event" },
          { key: "instance", label: "Instance" },
          { key: "instanceStart", label: "Instance Start", render: r => new Date(r.instanceStart).toLocaleDateString() },
          { key: "status", label: "Status", render: r => <Badge variant={r.status==="Registered"?"success":r.status==="Started"?"warning":"neutral"}>{r.status}</Badge> }
        ]}
        sideRender={r => (
          <div>
            <div className="bold" style={{ fontSize: 15 }}>{r.contactName}</div>
            <div className="muted" style={{ fontSize: 12, marginBottom: 10 }}>{r.email} · {r.name}</div>
            <div style={{ marginBottom: 10 }}>
              <div className="muted" style={{ fontSize: 11 }}>Event</div>
              <div>{r.event}</div>
              <div className="muted" style={{ fontSize: 11, marginTop: 6 }}>Instance</div>
              <div>{r.instance}</div>
              <div className="muted" style={{ fontSize: 11, marginTop: 6 }}>Status</div>
              <Badge variant={r.status==="Registered"?"success":r.status==="Started"?"warning":"neutral"}>{r.status}</Badge>
            </div>
            {r.status === "Started" && (
              <div style={{ background: "var(--slds-warning-bg)", border: "1px solid #FCC58D", borderRadius: 4, padding: 10, fontSize: 12, color: "#8C4A00" }}>
                <Icon name="warning" color="#FE9339"/> This person started but hasn't completed registration. Consider reaching out.
              </div>
            )}
          </div>
        )}
        rowActions={() => (
          <>
            <Btn icon="people" size="sm">View Record</Btn>
            <Btn icon="edit" size="sm">Edit Status</Btn>
          </>
        )}
        setToast={setToast}
      />
    </div>
  );
}

const PageHeader = ({ crumbs, title, actions, go }) => (
  <div className="page-header">
    <div>
      <div className="page-header__crumbs">
        {crumbs.map((c, i) => (
          <span key={i}>
            {c.to ? <a href="#" onClick={e => { e.preventDefault(); go(c.to); }}>{c.label}</a> : c.label}
            {i < crumbs.length - 1 && <span style={{ margin: "0 6px" }}>›</span>}
          </span>
        ))}
      </div>
      <div className="page-header__title">{title}</div>
    </div>
    <div className="page-header__actions">{actions}</div>
  </div>
);

window.FiuEventBrowser = FiuEventBrowser;
window.FiuInstanceBrowser = FiuInstanceBrowser;
window.FiuRegistrationBrowser = FiuRegistrationBrowser;
window.PageHeader = PageHeader;
