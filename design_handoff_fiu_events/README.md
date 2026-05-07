# Handoff: FIU Events — Salesforce Console Redesign

## Overview
A redesign of the FIU College of Business "Events" management app, built on Salesforce. It restructures the experience around the actual data model — **Event → Instance → Registration** — and replaces a flat list of UI surfaces with a guided command center, polished list browsers, and a hero "Create Event" wizard that prevents the most common configuration mistakes (paid event with no payment gateway, event with no instances, wrong template, wrong programs).

## About the Design Files
The HTML/CSS/JSX files in this bundle are **design references**. They are interactive prototypes built with React + inline Babel, intended to communicate intended look, layout, and behavior — **not** production code to copy directly.

Recreate the designs in the target codebase's existing environment. For an FIU Salesforce org that means Lightning Web Components (LWC) + SLDS using the org's existing record types, business units, validation rules, and Site templates. In any other React codebase, use the established component library and design tokens — adapt the patterns, don't lift the JSX verbatim.

## Fidelity
**High-fidelity.** Pixel-perfect mockups with final colors, typography, spacing, and interactions. Visual language is Salesforce Lightning Design System (SLDS) with a light FIU navy/gold accent.

## Screens / Views

### 1. Home (Command Center) — `01-home.png`
Single landing page that surfaces what needs attention, shows scope-filtered KPIs, teaches the Event/Instance/Registration mental model, and provides four "what do you want to do?" entry points. Welcome banner is dismissable. KPI tiles use a 3px left amber border for any "Not Ready" metric. Needs Attention and Upcoming panels live side-by-side.

### 2. Events Browser — `02-events.png`
List shell with breadcrumbs, info hint banner, search, filter pills, SLDS data table, and a 360px right-side quick-view panel that opens when a row is selected. Status and Readiness render as Badges; "Issues" column shows the readiness blocker inline.

### 3. Instances Browser — `03-instances.png`
Same list shell. Capacity column renders a labeled progress bar (green → orange → red as it fills). Reason column shows the specific blocker for any "Not Ready" instance.

### 4. Registrations Browser — `04-registrations.png`
Same list shell. "Started" status (abandoned forms) is highlighted as warning. Side panel surfaces a callout when a registration was started but never completed, prompting follow-up.

### 5. Create Event Wizard — Step 1 of 6: Basics — `05-wizard-basics.png`
3-pane layout, `240px 1fr 360px`, both rails sticky.
- **Left**: Step rail (Basics, Programs, Branding, Logistics, Payment, Review). Numbered circles. Active step = brand left border + brand-lightest bg. Done = green check; failed = red `!`.
- **Center**: Form. Name, Description, Record Type / Business Unit / Template (locked after creation), Event Type / Category (cascading).
- **Right**: Live preview of the registration page + Validation card + Context help.

### 6. Wizard Step 2: Programs — `06-wizard-programs.png` *(updated this round)*
**This step is about Graduate Programs, not generic audience.** Each registration is tagged with the program a prospect chooses, so the right recruiter can follow up. The picker:
- 22 programs across **Masters / Executive / Doctoral / Certificate / Other**
- Search by name or program code
- Level filter dropdown
- Scrollable list (max-height 320px) with sticky group headers and checkboxes
- "Selected" chip bar at the top with one-click remove
- Bulk actions: "Select all visible" / "Clear visible" — respects current search/filter
- Audience tags (Prospective / Admitted / Current / Alumni / Faculty / Corporate / Public) live below as a separate concept for marketing segmentation, not for routing.

### 7. Wizard Step 3: Branding — `07-wizard-branding.png` *(updated this round)*
**The Template is the centerpiece — it's the HTML scaffold of the public registration site, and the only way to get a preview at all.** Layout:
- 4-card visual Template picker, 2-up grid. Each card: 70px gradient banner (matches the template's identity), white "FIU" mark top-left, accent-colored "Register" pill bottom-right, label + description below. Selected card gets a 2px brand border + green "Selected" badge.
- **Customization surfaces** (only what the template actually exposes):
  - **Logo** (header) — upload or use template default
  - **Banner image** — hero image
  - **Page copy** for four pages: Welcome, Registration form, Confirmation, Reminder email. Each is a textarea with a "Reset to template default" link. Templates supply defaults; the user only overrides what they want different.
- Everything else (colors, type, footer, layout) is locked to the template by design — events stay on-brand.

### 8. Wizard Step 5: Payment — `08-wizard-payment.png`
Toggle gates the rest. When "Paid" = on: Price, Payment Gateway (TouchNet default), Accounting Department all become required. Inline validation. Helper banner explains why the validation matters.

### 9. Wizard Step 6: Review & Create — `09-wizard-review.png`
Field summary table. Each row has an "Edit" link that jumps back to the relevant step. Errors and warnings surface above. Create button stays disabled until validation passes. After creation, a toast prompts the user to add the first Instance.

### 10. Guide — `10-guide.png`
Static educational page. Two-column: long-form mental model + glossary side rail. Numbered concept cards with colored left borders matching the home screen.

## Interactions & Behavior
- **Wizard validation**: Live (`useMemo` over the form). Step-rail icons reflect per-step validity. Final "Create Event" disabled until all required fields pass.
- **Programs picker**: Filter+search are independent. "Select all visible" only adds programs in the current filtered view. Selected chips persist regardless of filter.
- **Template picker**: Selecting a template swaps the right-rail Live Preview's banner gradient and accent. Branding customizations layer on top.
- **List filters**: Active filters render as removable pills above the table. Search runs against all string fields.
- **Side panel**: Opens on row click or eye icon. Closes via X. Layout switches between `1fr` and `1fr 360px`.
- **Toasts**: 4-second auto-dismiss, color-coded by variant.

## State Management
- Top-level: `view`, `toast`.
- Wizard form shape:
  ```ts
  {
    name, description, recordType, businessUnit, template, eventType, category,
    programs: string[],          // program codes, e.g. ["MBA-FT", "MS-FIN"]
    audienceTags: string[],
    isPaid, price, paymentGateway, accountingDept,
    locationType, venue, capacity, waitlist,
    startDate, endDate,
    primaryColor,                // legacy, not exposed in UI anymore
    bannerImage, logoImage,
    pageCopy: { welcome, registration, confirmation, reminder }
  }
  ```
- Programs step has its own local `query` and `levelFilter`.
- All interactions client-side. In production, every Save/Update maps to a Salesforce DML call (LWC `@wire` / Apex).

## Design Tokens

### Colors
- Brand: `#0176D3` / `#014486` / `#032D60` / `#1B96FF` / `#EAF5FE`
- FIU accents: `#081E3F` (navy), `#B6862C` (gold) — logo mark, welcome banner, Chapman template
- Text: `#181818` / `#444444` / `#747474` / `#939393`
- Borders: `#E5E5E5` / `#C9C9C9`
- Surfaces: `#F3F3F3` (app), `#FAFAFA` (alt)
- Success: `#2E844A` text on `#CDEFC4`
- Warning: `#DD7A01` / `#FE9339` icon on `#FEF1EE`
- Error: `#BA0517` on `#FEDED7`
- Concept-card icons: Event `#5867E8`, Instance `#04844B`, Registration `#16325C`

### Template preview gradients
- **Standard**: `linear-gradient(135deg, #1a3865, #0f2647)` — accent `#FFC845`
- **Chapman**: `linear-gradient(135deg, #081E3F, #B6862C)` — accent `#B6862C`
- **Executive**: `linear-gradient(135deg, #1f1f1f, #3a3a3a)` — accent `#C8A45A`
- **Global**: `linear-gradient(135deg, #0a5d6e, #13909e)` — accent `#FFB347`

### Typography
- Family: `"SF Pro Text", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`
- Body 13px / Section heading 14px bold / Page title 18px bold / KPI value 28px bold
- Mono: `"SF Mono", "Roboto Mono", Menlo, Consolas`

### Spacing & Radius
- 4 / 6 / 8 / 10 / 12 / 14 / 16 / 18 / 20 / 24
- Radii: 4 (controls), 6 (cards/panels), 8 (modal/banner), 100 (pills/badges)

### Shadows
- `0 1px 2px rgba(0,0,0,.08)` — cards
- `0 2px 6px rgba(0,0,0,.12)` — popovers, banner
- `0 8px 24px rgba(0,0,0,.18)` — modals, toasts

## Assets
- All icons are inline SVGs in `components.jsx` (`I` map). In LWC, swap for `<lightning-icon>` (utility set).
- No raster assets; all gradients are CSS.
- Real implementation needs: school/department logos, Site banner images, the actual template HTML scaffolds (these already exist in the org).

## Files
Inside `source/`:
- `FIU Events Redesign.html` — entry point
- `styles.css` — all design tokens + component CSS
- `components.jsx` — atoms (Btn, Badge, Field, Toggle, Modal, Toast, Icon, LCard)
- `mock-data.js` — picklists (incl. 22 Graduate Programs and 4 Templates with preview metadata) and sample records
- `screen-home.jsx`, `screen-browsers.jsx`, `screen-wizard.jsx`, `screen-guide.jsx`, `app.jsx`

## Implementation Notes for Salesforce
- Replace picklists with the org's actual `Event_Type__c`, `Category__c`, `Record_Type`, `Program__c`, and Template metadata.
- The 22 program list is illustrative — pull the live list from the Programs object. Group by `Level__c` (or your equivalent).
- Templates correspond to actual Site templates in the org. The "Customize" surfaces (logo, banner, four page-copy blocks) should map to template-level Custom Metadata fields and per-event override fields.
- The "Readiness" model maps to a formula or validation-rule field on the Event/Instance object.
- "Started vs Registered" on registrations is the existing Status picklist — keep those values.
- Icons → SLDS utility icons. Layouts → SLDS grid + `<lightning-card>`. Forms → `<lightning-input>` / `<lightning-combobox>` / `<lightning-dual-listbox>` (a strong fit for the Programs picker). Modals → `<lightning-modal>`.
