# Launch Prompt for Claude Code / Codex

Drop the `design_handoff_fiu_events/` folder at the root of your codebase, then paste the prompt below.

---

## Prompt

> I've added a folder called `design_handoff_fiu_events/` to the repo. It contains a redesign of our FIU Events management app on Salesforce:
>
> - `README.md` — the full spec: every screen, layout, design token, behavior, and state shape.
> - `screenshots/` — 10 PNGs of the rendered designs (Home, Events, Instances, Registrations, plus all six wizard steps and the Guide).
> - `source/` — the working HTML/CSS/JSX prototype that produced those screenshots. **Reference only — do not copy verbatim.** It uses inline React + Babel and is not how we ship.
>
> Please do this in order, stopping for review at each milestone:
>
> **1. Audit the current codebase.** Identify the framework (LWC + SLDS / something else), the component library, design tokens, and where Event / Instance / Registration / Program records and Site Templates currently live. Tell me what you found before writing any code. Pay special attention to:
>    - The existing Programs picklist or object (we have ~22 graduate programs).
>    - Existing Site Templates and how their logo/banner/page-copy customizations are wired today.
>    - The Status field on Registration — we use "Started" to mean abandoned, "Registered" to mean complete.
>    - Any existing readiness / validation rule on Event or Instance.
>
> **2. Map the design to our stack.** For each screen in the README, pick the right primitive in our component library. If we already have a `<DataTable>`, `<Card>`, `<Wizard>`, `<DualListbox>`, etc., use those — don't introduce new components for things we have. Flag genuinely missing pieces. The Programs picker should map to a Salesforce dual-listbox or equivalent multi-select with grouping; the Template picker should be a card-grid selector.
>
> **3. Reconcile design tokens.** Compare the README token list (Brand, Text, Borders, Surfaces, Success/Warning/Error, template gradients) with our existing tokens. Only introduce new tokens for values that don't already exist. No hardcoded hex values in components.
>
> **4. Implement screen by screen, stopping for review after each:**
>    1. Home command center
>    2. Shared list shell, then Events / Instances / Registrations browsers
>    3. Create Event Wizard — implement step-by-step, not all at once. The step order is **Basics → Programs → Branding → Logistics → Payment → Review**.
>    4. Guide page
>
> **5. Wire to real data.** Replace `mock-data.js` with our actual data layer (Apex / GraphQL / whatever we use). Keep the field semantics from the README. If our backend uses different names, write a thin adapter rather than renaming throughout the UI.
>
> **6. Preserve these design decisions — they are load-bearing, not decoration:**
>    - **Programs ≠ Audience tags.** Programs route registrations to recruiters. Audience tags are for marketing. Don't merge them.
>    - **Template comes first in Branding.** It's the only way to get a preview. Logo / Banner / page copy are layered on top. Color and type are locked to the template by design.
>    - **Readiness is surfaced everywhere.** Home dashboard, list views, side panels, wizard validation. "Not Ready" must show *why* — the specific blocker.
>    - **Three-pane wizard layout.** Step rail / form / live preview + validation. Don't collapse this on desktop.
>    - **Side-panel quick view.** Row click opens a 360px right panel; full record page is a separate route. Inline drill-down is a deliberate choice.
>
> **Constraints**:
> - Match designs pixel-for-pixel where the component library allows. Where it doesn't, prefer the library's idiom and tell me where you compromised.
> - No new dependencies without asking.
> - Leave `design_handoff_fiu_events/source/` untouched — it's the source of truth.
> - Write tests for: wizard validation logic, list-shell filter logic, Programs picker (search + level filter + bulk actions interact correctly).
>
> Start with step 1 (audit) and report back before writing any code.

---

## Tips

- **Claude Code**: run from the repo root so the README and screenshots are visible alongside source. Ask it to summarize the README before coding.
- **Codex**: paste the README inline if it starts inventing layouts. Drop in screenshots one at a time when reviewing each screen.
- **Push back on drift.** The Template-first Branding step, the Programs multiselect with level grouping, and the Not-Ready readiness surfacing are the parts users will notice. Layout shortcuts there will undo most of the redesign's value.
