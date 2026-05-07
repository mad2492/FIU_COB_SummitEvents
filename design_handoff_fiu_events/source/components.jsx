/* eslint-disable no-undef */
const { useState, useEffect } = React;

/* ============== ICONS ============== */
const I = {
  home:     "M3 11l9-8 9 8v9a1 1 0 0 1-1 1h-5v-7H10v7H5a1 1 0 0 1-1-1v-9z",
  event:    "M19 4h-1V2h-2v2H8V2H6v2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2zm0 16H5V10h14v10zM5 8V6h14v2H5z",
  instance: "M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2zm5 11h-6V6h2v5h4z",
  people:   "M16 11a4 4 0 1 0-4-4 4 4 0 0 0 4 4zm-8 0a4 4 0 1 0-4-4 4 4 0 0 0 4 4zm0 2c-2.7 0-8 1.3-8 4v3h16v-3c0-2.7-5.3-4-8-4zm8 0a8 8 0 0 0-1 .1A5.7 5.7 0 0 1 18 17v3h6v-3c0-2.7-5.3-4-8-4z",
  plus:     "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z",
  search:   "M15.5 14h-.79l-.28-.27a6.5 6.5 0 1 0-.7.7l.27.28v.79l5 4.99L20.49 19zm-6 0A4.5 4.5 0 1 1 14 9.5 4.5 4.5 0 0 1 9.5 14z",
  filter:   "M10 18h4v-2h-4zM3 6v2h18V6zm3 7h12v-2H6z",
  refresh:  "M17.65 6.35A8 8 0 1 0 19.73 14H17.5a6 6 0 1 1-1.5-7.07L13 10h7V3z",
  settings: "M19.4 13a7.5 7.5 0 0 0 0-2l2.1-1.6a.5.5 0 0 0 .12-.6l-2-3.46a.5.5 0 0 0-.6-.22l-2.5 1a7.3 7.3 0 0 0-1.7-1L14.5 2.5a.5.5 0 0 0-.5-.4h-4a.5.5 0 0 0-.5.4l-.4 2.6a7.3 7.3 0 0 0-1.7 1l-2.5-1a.5.5 0 0 0-.6.22l-2 3.46a.5.5 0 0 0 .12.6L4.6 11a7.5 7.5 0 0 0 0 2l-2.1 1.6a.5.5 0 0 0-.12.6l2 3.46a.5.5 0 0 0 .6.22l2.5-1a7.3 7.3 0 0 0 1.7 1l.4 2.6a.5.5 0 0 0 .5.4h4a.5.5 0 0 0 .5-.4l.4-2.6a7.3 7.3 0 0 0 1.7-1l2.5 1a.5.5 0 0 0 .6-.22l2-3.46a.5.5 0 0 0-.12-.6zM12 15.5A3.5 3.5 0 1 1 15.5 12 3.5 3.5 0 0 1 12 15.5z",
  close:    "M19 6.4L17.6 5 12 10.6 6.4 5 5 6.4 10.6 12 5 17.6 6.4 19 12 13.4 17.6 19 19 17.6 13.4 12z",
  check:    "M9 16.2L4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4z",
  warning:  "M1 21h22L12 2zm12-3h-2v-2h2zm0-4h-2v-4h2z",
  info:     "M11 17h2v-6h-2zm1-15A10 10 0 1 0 22 12 10 10 0 0 0 12 2zm0 18a8 8 0 1 1 8-8 8 8 0 0 1-8 8zm-1-13h2V9h-2z",
  arrow:    "M5 12h12m-4-4l4 4-4 4",
  eye:      "M12 4.5C7 4.5 2.7 7.6 1 12c1.7 4.4 6 7.5 11 7.5s9.3-3.1 11-7.5c-1.7-4.4-6-7.5-11-7.5zm0 12.5a5 5 0 1 1 5-5 5 5 0 0 1-5 5zm0-8a3 3 0 1 0 3 3 3 3 0 0 0-3-3z",
  edit:     "M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04a1 1 0 0 0 0-1.41l-2.34-2.34a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z",
  copy:     "M16 1H4a2 2 0 0 0-2 2v14h2V3h12zm3 4H8a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2zm0 16H8V7h11z",
  download: "M19 9h-4V3H9v6H5l7 7zm-14 9v2h14v-2z",
  upload:   "M9 16h6v-6h4l-7-7-7 7h4zm-4 2h14v2H5z",
  book:     "M21 5c-1.1-.4-2.3-.5-3.5-.5-2 0-4.2.4-5.5 1.5C10.7 4.9 8.5 4.5 6.5 4.5S2.3 4.9 1 5.7v14.7c0 .3.3.6.6.6.1 0 .2 0 .3-.1 1.2-.6 3-1 4.6-1 1.9 0 3.8.4 5 1.3.5.3 1.2.3 1.7 0 1.2-.8 3.1-1.3 5-1.3 1.4 0 3.1.3 4.3.9.4.2.9-.1.9-.6V5.7c-.5-.4-1-.5-1.4-.7zM21 18.5c-.9-.3-2-.5-3-.5-1.7 0-4.2.7-5.5 1.5v-12c1.3-.8 3.8-1.5 5.5-1.5 1 0 2 .1 3 .5z",
  sparkle:  "M12 2l1.5 5L18 8.5 13.5 10 12 15l-1.5-5L6 8.5 10.5 7zM4 17l.7 2.3L7 20l-2.3.7L4 23l-.7-2.3L1 20l2.3-.7zM20 16l1 3 3 1-3 1-1 3-1-3-3-1 3-1z"
};
function Icon({ name, size = 14, color = "currentColor" }) {
  return <svg width={size} height={size} viewBox="0 0 24 24" fill={color} style={{ flexShrink: 0 }}><path d={I[name] || I.info}/></svg>;
}

/* ============== ATOMS ============== */
function Btn({ children, variant, size, icon, onClick, disabled, title, style }) {
  const cls = ["btn", variant && `btn--${variant}`, size && `btn--${size}`].filter(Boolean).join(" ");
  return (
    <button className={cls} onClick={onClick} disabled={disabled} title={title} style={style}>
      {icon && <Icon name={icon} size={14}/>}
      {children}
    </button>
  );
}
function Badge({ children, variant = "neutral", icon }) {
  return <span className={`badge badge--${variant}`}>{icon && <Icon name={icon} size={10}/>}{children}</span>;
}
function Input(props) { return <input className="input" {...props}/>; }
function Textarea(props) { return <textarea className="textarea" {...props}/>; }
function Select({ options, value, onChange, ...rest }) {
  return (
    <select className="select" value={value} onChange={onChange} {...rest}>
      {(options || []).map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
    </select>
  );
}
function Field({ label, required, error, hint, children }) {
  return (
    <div className={`field${error ? " field--error" : ""}`}>
      {label && <label className="field__label">{label}{required && <span className="req">*</span>}</label>}
      {children}
      {error ? <div className="field__error"><Icon name="warning" size={11}/> {error}</div> : hint && <div className="field__hint">{hint}</div>}
    </div>
  );
}
function Toggle({ on, onChange, label }) {
  return (
    <div className={`toggle${on ? " is-on" : ""}`} onClick={() => onChange(!on)}>
      <div className="toggle__track"><div className="toggle__thumb"/></div>
      {label && <div style={{ fontSize: 12 }}>{label}</div>}
    </div>
  );
}
function LCard({ icon, iconClass, title, subtitle, actions, children }) {
  return (
    <div className="lcard">
      <div className="lcard__head">
        {icon && <div className={`circle-icon ${iconClass || ""}`}><Icon name={icon} color="#fff" size={16}/></div>}
        <div>
          <div className="lcard__title">{title}</div>
          {subtitle && <div className="lcard__subtitle">{subtitle}</div>}
        </div>
        <div className="lcard__actions">{actions}</div>
      </div>
      {children}
    </div>
  );
}
function Modal({ open, onClose, title, footer, children }) {
  if (!open) return null;
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <div className="modal__head">
          <div className="modal__title">{title}</div>
          <button onClick={onClose} style={{ background: "none", border: 0, cursor: "pointer" }}><Icon name="close"/></button>
        </div>
        <div className="modal__body">{children}</div>
        {footer && <div className="modal__foot">{footer}</div>}
      </div>
    </div>
  );
}
function Toast({ toast, onClose }) {
  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(onClose, 4000);
    return () => clearTimeout(t);
  }, [toast]);
  if (!toast) return null;
  return (
    <div className={`toast toast--${toast.variant || "info"}`}>
      <Icon name={toast.variant === "success" ? "check" : toast.variant === "error" ? "warning" : "info"} color="#fff"/>
      <div style={{ flex: 1 }}>{toast.message}</div>
      <button onClick={onClose} style={{ background: "none", border: 0, color: "#fff", cursor: "pointer" }}><Icon name="close" color="#fff"/></button>
    </div>
  );
}

Object.assign(window, { Icon, Btn, Badge, Input, Textarea, Select, Field, Toggle, LCard, Modal, Toast });
