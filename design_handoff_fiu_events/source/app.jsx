/* eslint-disable no-undef */
const { useState } = React;

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "showOnboarding": true,
  "density": "comfortable",
  "accentColor": "#0176D3"
}/*EDITMODE-END*/;

function App() {
  const [view, setView] = useState("home");
  const [toast, setToast] = useState(null);
  const go = v => setView(v);

  const navItems = [
    { id: "home",          label: "Home",          icon: "home" },
    { id: "events",        label: "Events",        icon: "event" },
    { id: "instances",     label: "Instances",     icon: "instance" },
    { id: "registrations", label: "Registrations", icon: "people" }
  ];

  return (
    <div>
      {/* Top app header */}
      <div className="app-header">
        <div className="app-header__top">
          <div className="app-header__app-launcher" title="App Launcher">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="#fff"><path d="M4 4h6v6H4zm10 0h6v6h-6zM4 14h6v6H4zm10 0h6v6h-6z"/></svg>
          </div>
          <div className="app-header__logo">
            <div className="app-header__logo-mark">FIU</div>
            <div>
              <div style={{ fontSize: 13, opacity: .8, fontWeight: 500 }}>College of Business · Salesforce</div>
              <div style={{ fontSize: 15, fontWeight: 700 }}>FIU Events</div>
            </div>
          </div>
          <div style={{ flex: 1 }}/>
          <div className="app-header__search">
            <span className="app-header__search-icon"><Icon name="search" size={14} color="#747474"/></span>
            <input placeholder="Search events, instances, contacts..."/>
          </div>
          <button className="app-header__icon-btn" title="Help" onClick={() => go("guide")}><Icon name="info" size={18} color="#fff"/></button>
          <button className="app-header__icon-btn" title="Settings"><Icon name="settings" size={18} color="#fff"/></button>
          <div className="app-header__avatar">DR</div>
        </div>

        {/* Tab strip — Salesforce console style */}
        <div className="app-tabs">
          <div className="app-tab is-active">
            <Icon name="event" size={12} color="#0176D3"/>
            FIU Events
          </div>
          <div className="app-tab">
            <Icon name="home" size={12} color="#747474"/>
            Recently Viewed
            <button className="app-tab__close" style={{ background: "none", border: 0, cursor: "pointer" }}><Icon name="close" size={10}/></button>
          </div>
        </div>
      </div>

      {/* Sub navigation */}
      <div className="subnav">
        {navItems.map(n => (
          <div key={n.id} className={`subnav__item${view === n.id ? " is-active" : ""}`} onClick={() => go(n.id)}>
            <Icon name={n.icon} size={14} color={view === n.id ? "#0176D3" : "#747474"}/>
            {n.label}
          </div>
        ))}
        <span className="subnav__sep">|</span>
        <div className={`subnav__item${view === "wizard" ? " is-active" : ""}`} onClick={() => go("wizard")}>
          <Icon name="plus" size={14} color={view === "wizard" ? "#0176D3" : "#747474"}/>
          Create Event
        </div>
        <div className={`subnav__item${view === "guide" ? " is-active" : ""}`} onClick={() => go("guide")}>
          <Icon name="book" size={14} color={view === "guide" ? "#0176D3" : "#747474"}/>
          Guide
        </div>
        <div style={{ marginLeft: "auto", fontSize: 11, color: "var(--slds-text-tertiary)", paddingRight: 8 }}>
          v2 · {new Date().toLocaleDateString()}
        </div>
      </div>

      {/* Content */}
      <div style={{ padding: 16, maxWidth: 1500, margin: "0 auto" }}>
        {view === "home"          && <FiuEventsHome go={go} setToast={setToast}/>}
        {view === "events"        && <FiuEventBrowser go={go} setToast={setToast}/>}
        {view === "instances"     && <FiuInstanceBrowser go={go} setToast={setToast}/>}
        {view === "registrations" && <FiuRegistrationBrowser go={go} setToast={setToast}/>}
        {view === "wizard"        && <FiuCreateEventWizard go={go} setToast={setToast}/>}
        {view === "guide"         && <FiuGuide go={go} setToast={setToast}/>}
      </div>

      <Toast toast={toast} onClose={() => setToast(null)}/>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App/>);
