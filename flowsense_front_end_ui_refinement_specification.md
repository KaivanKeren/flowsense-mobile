# FlowSENSE Front-End UI Refinement Specification

## Source

This refinement specification is derived from the current **Front-End Checklist** project by David Dias / thedaviddias.

The checklist currently contains 385 English rules across 11 active categories:

- HTML
- CSS
- JavaScript
- Performance
- Accessibility
- SEO
- Security
- Images
- Testing
- Privacy
- Internationalization

The purpose of this document is to translate those front-end quality principles into a concrete UI/UX refinement specification for the **FlowSENSE AI Predictive Traffic Light Control Management System**.

This document is intended to be used as a **Google Stitch refinement prompt**.

---

# 1. PROJECT CONTEXT

Product name:

**FlowSENSE**

Product type:

**Adaptive Predictive AI Traffic Light Control Management System**

Primary users:

- Dinas Perhubungan operators
- Traffic management officers
- Transportation administrators
- Emergency-response coordinators
- Authorized infrastructure operators

Primary platform:

**Mobile application**

Maximum primary content width:

**448 px**

Primary interface language:

**Bahasa Indonesia**

Product purpose:

FlowSENSE monitors traffic conditions, analyzes computer-vision detections, predicts traffic queues, identifies gridlock risk, generates adaptive signal timing recommendations, prioritizes emergency vehicles, monitors pedestrian accessibility events, visualizes traffic through GIS, and provides historical analytics.

The application is an **operational intelligence and recommendation interface**.

It must NOT present itself as a direct physical traffic-light controller.

The interface must clearly distinguish:

- observed data
- predicted data
- AI recommendations
- historical data
- simulation data
- system status
- stale/offline data

---

# 2. REFINEMENT OBJECTIVE

Refine the existing FlowSENSE UI without destroying its information architecture.

Do not redesign the product into a generic dashboard.

Improve it through:

- semantic structure
- responsive behavior
- accessibility
- visual hierarchy
- typography
- interaction quality
- performance-aware components
- loading states
- error states
- offline states
- security-conscious UX
- localization readiness
- consistent component architecture

The final result must feel like:

**a serious intelligent transportation operations platform**

rather than:

- a generic admin dashboard
- a consumer navigation application
- a cryptocurrency dashboard
- a smart-home interface
- an AI marketing landing page

---

# 3. DESIGN PRIORITY

Use this priority order when refining the UI:

## Priority 1

Safety-critical information

Examples:

- emergency vehicle
- gridlock risk
- intersection failure
- AI service failure
- pedestrian safety
- accessibility event

## Priority 2

Real-time operational information

Examples:

- current queue
- vehicle count
- traffic occupancy
- current signal phase
- data freshness

## Priority 3

Predictive intelligence

Examples:

- congestion prediction
- queue forecast
- AI confidence
- adaptive timing recommendation
- predicted impact

## Priority 4

Historical analytics

Examples:

- traffic trends
- baseline comparison
- historical congestion
- intervention effectiveness

## Priority 5

System metadata

Examples:

- API health
- model status
- synchronization time
- service status

Never allow decorative UI elements to compete visually with Priority 1 information.

---

# 4. MOBILE-FIRST FOUNDATION

Design for a narrow mobile viewport first.

Target range:

320–448 px

The interface must remain usable at:

- 320 px
- 360 px
- 375 px
- 390 px
- 414 px
- 428 px
- 448 px

Do not design only for a 390 px mockup.

All components must be fluid.

Avoid fixed-width cards that overflow narrow screens.

Avoid horizontal page scrolling.

Horizontal scrolling is allowed only for intentional UI patterns such as:

- KPI carousel
- time filters
- category chips
- chart ranges

The main document itself must never horizontally scroll.

The current Front-End Checklist explicitly treats prevention of horizontal scrolling as a responsive and accessibility requirement.

---

# 5. RESPONSIVE CONTAINER

Use a responsive page container.

Conceptual structure:

```text
Viewport
└── App Shell
    ├── Safe Area
    ├── Header
    ├── Main Content
    │   └── max-width: 448px
    └── Bottom Navigation
```

Use:

- fluid width
- responsive padding
- safe-area awareness
- flexible cards
- content-driven height

Do not force all content into fixed pixel dimensions.

Use relative units and responsive sizing where appropriate.

The checklist specifically recommends relative units and responsive layouts rather than relying exclusively on fixed pixel dimensions.

---

# 6. SAFE AREA

Support mobile safe areas.

Important areas:

- top status area
- bottom navigation
- device gesture area
- modal bottom sheets

Do not place critical buttons directly against the device edge.

Bottom navigation must have enough bottom padding for gesture-navigation devices.

---

# 7. APP SHELL

Create a consistent application shell.

Structure:

```text
┌───────────────────────────┐
│ Status / Header           │
├───────────────────────────┤
│                           │
│ Main operational content  │
│                           │
│                           │
├───────────────────────────┤
│ Bottom navigation         │
└───────────────────────────┘
```

Primary navigation:

- Overview
- Intersections
- Map
- Alerts
- Analytics

The navigation should remain consistent across screens.

Do not move navigation controls unpredictably between pages.

---

# 8. SEMANTIC INFORMATION HIERARCHY

Every page must have a clear hierarchy:

```text
Page
├── Page title
├── Current operational status
├── Primary information
├── Secondary information
├── Supporting information
└── Actions
```

Use exactly one primary page heading.

Do not create multiple visually competing page titles.

The Front-End Checklist specifically includes semantic HTML, a single main landmark, logical heading hierarchy, and descriptive navigation as accessibility requirements.

---

# 9. CARD HIERARCHY

Do not make every card visually identical.

Create three levels.

## Level 1: Critical card

Used for:

- emergency vehicle
- critical gridlock
- intersection failure

Visual:

- strongest contrast
- prominent icon
- status label
- timestamp
- immediate context

## Level 2: Operational card

Used for:

- traffic condition
- queue
- signal status
- AI prediction

Visual:

- medium elevation
- clear KPI
- supporting metadata

## Level 3: Supporting card

Used for:

- historical statistics
- model metadata
- secondary analytics

Visual:

- subtle surface
- less visual weight

---

# 10. VISUAL HIERARCHY

The eye should move approximately like this:

```text
CRITICAL EVENT
      ↓
CURRENT TRAFFIC
      ↓
AI PREDICTION
      ↓
RECOMMENDATION
      ↓
EXPLANATION
      ↓
HISTORICAL CONTEXT
```

Do not place analytics charts above an active emergency warning.

Do not let decorative maps overpower critical status information.

---

# 11. COLOR SYSTEM

Create semantic design tokens.

Use categories:

```text
--color-background
--color-surface
--color-surface-elevated
--color-text-primary
--color-text-secondary
--color-border

--color-success
--color-warning
--color-critical
--color-info
--color-prediction
--color-emergency
```

Recommended semantic meaning:

### Green

Normal / operational / healthy

### Amber

Warning / elevated traffic / degraded service

### Red

Critical / emergency / failure

### Cyan / Blue

AI / information / system intelligence

### Purple

Prediction / forecast / analytical state

Do not rely on color alone.

Every semantic status must combine:

**color + icon + text**

Example:

```text
● Normal
```

```text
▲ Warning
```

```text
! Critical
```

```text
AI Prediction
```

---

# 12. DARK MODE

The primary FlowSENSE interface should use a dark operational theme.

However, implement the design system using semantic tokens so light mode can be introduced without rebuilding components.

Support system preference where appropriate.

The current checklist explicitly includes dark-mode support through `prefers-color-scheme` and reusable CSS custom properties.

Dark mode should use:

- deep navy background
- elevated slate surfaces
- high-contrast text
- restrained accent colors

Avoid pure black everywhere.

Avoid excessive neon.

---

# 13. COLOR CONTRAST

All important text must have sufficient contrast against its background.

Particularly:

- KPI numbers
- alert text
- chart labels
- navigation labels
- timestamps
- button labels
- status chips

Do not use low-opacity gray text for essential information.

Do not place red text on dark gray if contrast is insufficient.

Never communicate traffic severity using color alone.

---

# 14. TYPOGRAPHY

Use a highly readable modern sans-serif.

Prioritize:

- legibility
- numerical clarity
- compact hierarchy
- mobile readability

Recommended hierarchy:

```text
Display KPI
28–32 px

Page title
22–24 px

Section title
16–18 px

Card title
14–16 px

Body
14–16 px

Metadata
12–13 px
```

Do not shrink body text excessively to fit more data.

The Front-End Checklist specifically recommends readable mobile font sizes and responsive units.

---

# 15. NUMERICAL TYPOGRAPHY

Traffic applications contain many numerical values.

Use consistent numerical presentation for:

- vehicle count
- queue length
- speed
- occupancy
- prediction confidence
- signal timing
- percentages
- timestamps

Examples:

```text
127
vehicles
```

```text
68%
occupancy
```

```text
31
vehicles queued
```

```text
00:32
green remaining
```

Numbers should visually dominate their units without separating them so far that interpretation becomes difficult.

---

# 16. TOUCH TARGETS

All interactive elements must be comfortable to touch.

Use generous hit areas for:

- bottom navigation
- buttons
- filter chips
- map markers
- alerts
- expandable sections
- segmented controls

Do not make tiny icon-only controls difficult to tap.

If an icon visually appears 20 px, the interactive hit area can still be substantially larger.

---

# 17. FOCUS STATES

Every interactive element must have a visible focus state.

Required for:

- buttons
- links
- inputs
- tabs
- navigation
- filters
- expandable components

Never remove focus outlines without providing an equivalent visible focus indicator.

The checklist explicitly requires visible custom focus indicators.

---

# 18. BUTTON DESIGN

Use clear semantic button hierarchy.

## Primary

Used for:

- View Intersection
- View Alert
- View Timing Plan
- View AI Reasoning

## Secondary

Used for:

- View Details
- Compare
- Filter

## Tertiary

Used for:

- Expand
- More information
- Metadata

Do not create a primary button for every action.

---

# 19. AI RECOMMENDATION DESIGN

Every AI recommendation must visually identify itself.

Structure:

```text
AI RECOMMENDATION

Recommended timing
51 sec

Confidence
91%

Reason
North queue growth detected

Expected impact
Queue −18%
Delay −11 sec
```

Never display:

```text
AI says do this
```

Prefer:

```text
AI recommendation
```

The AI must be presented as a decision-support system.

---

# 20. AI EXPLAINABILITY

Every significant recommendation should provide:

- reason
- confidence
- contributing factors
- predicted outcome
- data freshness

Example:

```text
Why this recommendation?

1. North queue increasing
2. East traffic demand decreasing
3. Pedestrian demand detected
4. Downstream capacity available
```

Use progressive disclosure.

Do not expose a giant AI explanation by default.

---

# 21. DATA FRESHNESS

Real-time data must always show freshness.

Examples:

```text
Updated 8 sec ago
```

```text
Live
```

```text
2 min old
```

```text
Cached data
```

Never display stale data as if it were live.

For critical information, freshness should become more visually prominent as the data ages.

---

# 22. LOADING STATES

Every asynchronous section needs a loading state.

Use skeletons instead of blank cards.

Examples:

```text
┌─────────────────────┐
│ █████████           │
│                     │
│ ███████ ████        │
└─────────────────────┘
```

Loading states must preserve approximate final layout dimensions.

Avoid layout jumps.

The checklist explicitly includes minimizing cumulative layout shift and showing loading indicators.

---

# 23. ERROR STATES

Never show raw technical errors.

Bad:

```text
500 Internal Server Error
TypeError...
```

Better:

```text
Traffic data unavailable

The latest intersection data could not be loaded.

Last successful update:
08:42:16

Retry
```

Technical details belong in diagnostics, not the primary operator interface.

---

# 24. OFFLINE STATE

Create a deliberate offline experience.

Display:

```text
Connection lost

Showing cached information

Last synchronized:
2 min 14 sec ago
```

Clearly differentiate:

- live
- cached
- unavailable

The checklist specifically recommends an offline fallback rather than leaving users with a generic browser error page.

---

# 25. DEGRADED AI STATE

If the AI engine fails:

```text
AI prediction unavailable

Real-time traffic monitoring remains operational.

Fallback:
Fixed timing reference

Last prediction:
08:42
```

Do not make the entire application appear broken if only the AI service has failed.

Separate subsystem health.

---

# 26. SYSTEM HEALTH UI

Represent services individually.

```text
AI Engine             ● Operational
Computer Vision       ● Operational
Traffic Data          ● Operational
GIS Service            ● Operational
API Connector         ● Operational
Database               ● Operational
```

Avoid a single generic:

```text
System OK
```

because it hides subsystem failure.

---

# 27. ALERT DESIGN

Alerts require clear severity.

## Critical

Large visual prominence.

Example:

```text
CRITICAL

Emergency vehicle detected

Simpang Ahmad Yani
East approach

Detected 24 sec ago
```

## Warning

```text
WARNING

Gridlock risk increasing

Risk 72%
```

## Information

```text
INFO

Pedestrian extension activated
```

Do not use identical styling for all three.

---

# 28. ALERT PERSISTENCE

Critical alerts should remain visible until acknowledged or resolved.

Do not make critical alerts disappear automatically after a few seconds.

Do not use aggressive full-screen popups unless the information genuinely requires immediate attention.

The checklist warns against intrusive interstitials that block content on mobile.

---

# 29. MAP UI

The GIS map should be functional rather than decorative.

Show:

- intersections
- traffic state
- congestion
- emergency events
- green-wave corridors
- selected intersection

Map markers should not contain excessive information.

Use:

```text
● Normal
▲ Warning
! Critical
◆ Prediction hotspot
```

Selecting a marker should open a bottom sheet.

---

# 30. MAP BOTTOM SHEET

Example:

```text
Simpang Ahmad Yani

Operational

Queue
31 vehicles

Congestion
54%

Prediction
78% in 15 min

Updated 8 sec ago

View intersection
```

The map remains visible behind the sheet.

Do not navigate to a new page for every tiny map interaction.

---

# 31. CHART DESIGN

Charts must be understandable without relying on color alone.

Every chart requires:

- title
- unit
- axis context
- legend where necessary
- accessible text interpretation

Example:

```text
Queue Forecast

Current ─────────
Predicted - - - -
Threshold ───────

Next 15 minutes
```

Provide a textual summary:

```text
Prediction:
Queue expected to increase by approximately 16%.
```

---

# 32. CHART PERFORMANCE

Do not render unnecessary high-frequency chart points.

For long historical datasets:

- aggregate where appropriate
- virtualize large lists
- lazy-load analytics
- render only visible information

The checklist explicitly recommends virtualizing long lists and tables and reducing DOM size and complexity.

---

# 33. INTERSECTION DIGITAL TWIN

The intersection visualization must prioritize clarity.

Display:

- four approaches
- traffic direction
- signal states
- pedestrian crossing
- detected vehicles
- emergency vehicle
- queue visualization

Do not turn the digital twin into a visually complicated 3D scene.

Use a lightweight 2D representation.

---

# 34. SIGNAL STATE

Make signal states visually obvious.

Example:

```text
NORTH ↕ SOUTH

● GREEN
00:32

EAST ↔ WEST

● RED
00:18
```

Include text labels.

Do not rely solely on red/yellow/green circles.

---

# 35. ACCESSIBILITY EVENT DESIGN

Use neutral terminology.

Preferred:

```text
Mobility assistance detected
```

Categories:

```text
Wheelchair
Cane
Crutch
```

Avoid stigmatizing or ambiguous labels.

Display:

```text
Pedestrian safety

5 mobility-assistance detections

Crossing extension
+8 sec
```

---

# 36. EMERGENCY VEHICLE UI

Emergency states must override ordinary informational hierarchy.

Display:

```text
EMERGENCY PRIORITY

Ambulance detected

Approach
East

Estimated arrival
48 sec

AI recommendation
Clear East-West corridor
```

Keep the visual treatment urgent but controlled.

Avoid flashing animations.

Avoid excessive motion.

---

# 37. MOTION DESIGN

Use animation sparingly.

Allowed:

- subtle loading animation
- signal transition
- map marker pulse
- page transition
- chart reveal
- status update

Avoid:

- constant blinking
- rapidly flashing alerts
- excessive parallax
- animated backgrounds
- unnecessary particle effects

Use transform and opacity for animation when possible.

The checklist specifically recommends transform/opacity-based animation for performance.

---

# 38. REDUCE LAYOUT SHIFT

Components must reserve space before asynchronous content arrives.

Examples:

- chart containers have fixed aspect ratios
- image containers reserve dimensions
- cards preserve their height
- skeletons approximate final content

Do not allow the entire dashboard to move when one chart loads.

The checklist sets CLS below 0.1 as a performance target.

---

# 39. IMAGE STRATEGY

FlowSENSE should minimize unnecessary raster images.

Prefer:

- SVG icons
- CSS shapes
- vector illustrations
- lightweight map assets

When raster imagery is required:

- use modern formats
- compress
- provide responsive sizes
- lazy-load below-the-fold assets
- define width and height
- provide meaningful alt text

The checklist includes responsive images, compression, lazy loading, explicit dimensions, modern formats, and meaningful alt text.

---

# 40. ICON SYSTEM

Use one consistent icon family.

Icons must:

- have consistent stroke weight
- have consistent visual size
- communicate meaning clearly
- not be decorative clutter

Important icons:

- traffic
- warning
- emergency
- pedestrian
- accessibility
- AI
- map
- analytics
- settings
- system health

Icon-only controls require accessible names.

---

# 41. SEARCH

Intersection search should have:

- visible label
- clear placeholder
- autocomplete
- keyboard accessibility
- predictable result behavior

Example:

```text
Search intersection

⌕ Ahmad Yani
```

Do not make search dependent only on an icon with no accessible name.

The checklist explicitly includes accessible search inputs.

---

# 42. FILTERS

Use compact filters.

Example:

```text
All   Healthy   Warning   Critical
```

Selected filter must be obvious through:

- background
- border
- text
- icon where useful

Do not depend only on color.

---

# 43. FORMS

For login and settings:

Every input needs:

- visible label
- appropriate input type
- error state
- helper text where needed
- accessible name
- clear focus state

Do not use placeholder text as the only label.

The checklist explicitly requires associated labels and accessible form validation.

---

# 44. LOGIN SECURITY UX

Password input should provide:

- password visibility toggle
- secure autocomplete behavior
- clear validation
- no password exposure

Do not visually expose tokens, API keys, or internal credentials.

The checklist includes secure password inputs, HTTPS, secure authentication tokens, CSP, and protection against leaked environment variables.

---

# 45. PWA BEHAVIOR

Treat FlowSENSE as a PWA-capable operational application.

Design for:

- installability
- standalone mode
- splash screen
- offline fallback
- service worker caching
- mobile viewport

The checklist explicitly includes web app manifest, PWA installability, service worker support, and offline behavior.

---

# 46. PERFORMANCE TARGETS

Design and implement with performance budgets in mind.

Targets derived from the checklist include:

```text
FCP < 1.8s
LCP < 2.5s
INP < 200ms
CLS < 0.1
Page load < 3s
Page weight < 1500KB
```

These are implementation targets, not visual design claims.

The current checklist explicitly contains rules for FCP, LCP, INP, CLS, page-load time, page weight, and performance budgets.

---

# 47. LAZY LOADING

Do not load everything immediately.

Priority order:

## Immediate

- app shell
- navigation
- current status
- critical alerts
- primary KPI

## Deferred

- historical analytics
- secondary charts
- detailed AI explanations
- large map layers
- secondary intersection data

The checklist explicitly recommends lazy-loading offscreen content and loading non-critical code only when needed.

---

# 48. DOM COMPLEXITY

Keep the interface structurally simple.

Avoid:

- deeply nested cards
- unnecessary wrappers
- duplicated components
- giant dashboard DOM trees
- unnecessary hidden elements

Prefer reusable components.

For large lists:

- pagination
- virtualization
- incremental loading

---

# 49. CSS DESIGN SYSTEM

Use design tokens.

Example conceptual structure:

```text
tokens/
├── colors
├── typography
├── spacing
├── radius
├── shadows
├── motion
└── breakpoints
```

CSS custom properties should control:

- colors
- spacing
- typography
- radii
- semantic states

The checklist explicitly recommends CSS custom properties for design tokens.

---

# 50. COMPONENT RESPONSIVENESS

Components must adapt based on available space.

Examples:

A KPI card:

```text
Wide:
[ KPI ][ KPI ]

Narrow:
[ KPI ]
[ KPI ]
```

Intersection information:

```text
Wide:
Queue | Speed | Occupancy

Narrow:
Queue
Speed
Occupancy
```

Prefer component-level responsiveness rather than assuming one viewport.

The checklist includes container queries as a component-level responsive strategy.

---

# 51. INTERNATIONALIZATION READINESS

Primary language:

**Indonesian**

But design the UI so text can expand.

English translations may be longer or shorter.

Avoid:

```text
fixed-width text containers
```

Prefer:

```text
content-driven containers
```

Do not truncate important operational labels.

The checklist specifically recommends designing components to accommodate translation expansion.

---

# 52. NUMBER AND DATE FORMATTING

Use locale-aware formatting.

Examples:

```text
08:42:16
```

```text
9 Agustus 2026
```

```text
1.245 kendaraan
```

Use localized number/date formatting rather than manually concatenating strings.

The checklist explicitly recommends `Intl` APIs for number and date formatting.

---

# 53. ACCESSIBILITY FOUNDATION

FlowSENSE must support:

- keyboard navigation
- screen readers
- logical focus order
- visible focus
- semantic landmarks
- accessible labels
- descriptive links
- accessible dynamic content
- appropriate ARIA
- plain language

The current checklist contains 95 accessibility rules covering keyboard, screen-reader, ARIA, semantics, inclusive language, heading hierarchy, and plain language.

---

# 54. DYNAMIC CONTENT

Traffic data changes continuously.

When a metric changes:

Do not unexpectedly move the user.

For important updates, announce changes appropriately to assistive technologies.

Example:

```text
Traffic update:
North queue increased to 34 vehicles.
```

Use live-region semantics in the implementation where appropriate.

The checklist explicitly includes announcing dynamic content with ARIA live regions.

---

# 55. PLAIN LANGUAGE

Use concise operational Indonesian.

Prefer:

```text
Risiko gridlock meningkat
```

instead of:

```text
Sistem kecerdasan buatan mendeteksi kemungkinan terjadinya fenomena ketidakseimbangan arus kendaraan
```

Prefer:

```text
Prediksi antrean meningkat 16%
```

instead of:

```text
Berdasarkan inferensi model prediktif, terdapat kecenderungan peningkatan akumulasi kendaraan
```

The checklist explicitly recommends plain language and inclusive language.

---

# 56. SEMANTIC NAVIGATION

Navigation should be identifiable.

Primary navigation:

```text
Overview
Intersections
Map
Alerts
Analytics
```

Each item must have:

- icon
- visible label
- accessible name
- selected state

Do not use ambiguous icons without labels.

---

# 57. EMPTY STATES

Create meaningful empty states.

Example:

```text
Tidak ada peringatan aktif

Semua persimpangan berada dalam kondisi normal.
```

Avoid:

```text
No data
```

without explanation.

---

# 58. NO DATA VS ERROR

These are different.

## No data

```text
Belum ada data historis
```

## Error

```text
Data historis gagal dimuat
```

## Offline

```text
Koneksi tidak tersedia
```

## Not applicable

```text
Tidak tersedia untuk persimpangan ini
```

Never collapse all four into one generic error.

---

# 59. TABLES

Avoid desktop-style tables on the primary mobile UI.

Use:

- cards
- stacked metrics
- expandable rows

If a table is genuinely required:

- horizontally scroll only the table container
- provide headers
- preserve row/column relationships
- maintain accessible table semantics

The checklist explicitly includes semantic table markup for screen readers.

---

# 60. LIST PERFORMANCE

For long intersection lists:

```text
virtualized list
```

rather than rendering hundreds of cards simultaneously.

Show:

```text
12 of 48 intersections
```

where useful.

Load additional records progressively.

---

# 61. SECURITY-AWARE UI

The interface must not expose:

- API keys
- authentication tokens
- environment variables
- internal stack traces
- database credentials
- internal infrastructure paths

Production errors must remain user-friendly.

The current checklist explicitly includes prevention of leaked environment variables, secure authentication tokens, CSP, HTTPS, safe cookies, and prevention of stack-trace exposure.

---

# 62. HTTPS / SECURE TRANSPORT

Production FlowSENSE must assume HTTPS.

Never design API endpoints or resources around insecure HTTP.

Avoid mixed-content resources.

The checklist explicitly requires HTTPS and avoidance of mixed content.

---

# 63. PRIVACY

Collect only information necessary for the operator experience.

Potential user data:

- operator identity
- role
- preferences
- notification settings

Do not introduce unnecessary personal-data collection.

The checklist recommends data minimization and clear privacy-policy access.

---

# 64. CAMERA / COMPUTER VISION PRIVACY

The UI should communicate computer vision as an infrastructure monitoring capability.

Avoid presenting raw personal identification.

Use aggregate detection:

```text
127 vehicles
18 pedestrians
5 mobility-assistance detections
1 emergency vehicle
```

rather than unnecessary personal profiles.

---

# 65. SEO

SEO is relevant primarily if FlowSENSE has a public website or public product documentation.

It is less important for the authenticated operator application.

For the public-facing FlowSENSE website, implement:

- descriptive title
- meta description
- canonical URL
- sitemap
- semantic headings
- Organization structured data
- descriptive links
- valid structured data
- proper robots directives

The current checklist contains 94 SEO rules covering metadata, crawlability, canonical URLs, structured data, internal linking, titles, descriptions, and indexability.

Do NOT distort the authenticated dashboard UI merely to satisfy SEO.

---

# 66. ERROR PAGE

Create a custom 404.

Example:

```text
404

Halaman tidak ditemukan.

Data lalu lintas tetap aman.

Kembali ke Overview
```

The checklist specifically recommends custom 404 pages with helpful navigation.

---

# 67. TESTING-READY UI

Design components so they can be tested independently.

Every major component should have predictable states:

```text
default
loading
success
warning
critical
error
empty
offline
disabled
```

The checklist includes unit, integration, E2E, accessibility, visual regression, real-device testing, and major-browser testing.

---

# 68. VISUAL REGRESSION

The design system should maintain stable visual baselines.

Important screens:

- Overview
- Intersection Detail
- Map
- Alerts
- Analytics
- Login
- Offline
- Emergency state

Avoid random visual changes between states.

---

# 69. REAL DEVICE TESTING

Validate the design on actual mobile devices.

Minimum conceptual targets:

```text
320 px
360 px
375 px
390 px
414 px
428 px
448 px
```

Test:

- touch
- scrolling
- keyboard
- safe area
- bottom navigation
- map gestures
- chart interaction
- modal sheets

The checklist explicitly calls for real-device/mobile viewport testing.

---

# 70. BROWSER COMPATIBILITY

The implementation should be tested across major browsers.

Target:

- Chrome
- Firefox
- Safari
- Edge

The checklist explicitly includes major-browser testing.

---

# 71. PERFORMANCE-AWARE MAP

Maps can become expensive.

Do not load every possible layer simultaneously.

Prioritize:

1. selected intersection
2. active alerts
3. traffic status
4. congestion layer
5. green-wave layer
6. historical layers

Load secondary GIS information only when requested.

---

# 72. PERFORMANCE-AWARE ANALYTICS

Analytics should not block the operational dashboard.

The Overview screen should render:

```text
System status
Critical alerts
Traffic KPIs
Current prediction
```

before:

```text
Historical analytics
```

Historical analytics can load progressively.

---

# 73. PERFORMANCE-AWARE AI

AI prediction visualization should not freeze the interface.

Use:

```text
Prediction loading...
```

rather than blocking the entire dashboard.

If prediction fails:

```text
Prediction unavailable
```

while current traffic remains visible.

---

# 74. DESIGN SYSTEM COMPONENT STATES

Every component should support:

```text
Default
Hover
Focus
Pressed
Selected
Disabled
Loading
Success
Warning
Critical
Error
Offline
```

For mobile-only contexts where hover does not exist, prioritize:

```text
Default
Pressed
Selected
Disabled
```

---

# 75. NAVIGATION TRANSITIONS

Use subtle native-feeling transitions.

Preferred:

- fade
- slide
- shared element transition where useful

Avoid:

- dramatic zoom
- spinning transitions
- excessive animation

The goal is operational speed.

---

# 76. CONTENT DENSITY

FlowSENSE is data-dense.

However:

**data density must not become cognitive overload.**

Use progressive disclosure.

Example:

```text
Queue
31 vehicles
```

Then expandable:

```text
North
18

East
7

South
3

West
3
```

Then optional:

```text
Prediction
Next 15 minutes
```

---

# 77. OPERATOR COGNITIVE LOAD

The UI should help operators answer five questions immediately:

```text
1. What is happening?
2. Where is it happening?
3. How serious is it?
4. What will happen next?
5. What does FlowSENSE recommend?
```

Every Overview screen should support those five answers.

---

# 78. PRIMARY OVERVIEW REFINEMENT

Final Overview hierarchy:

```text
FlowSENSE
Traffic Operations Center
● System Operational

[ Critical Alert ]

Active Intersections
12 / 16

Average Queue
24 vehicles

Predicted Congestion
68%

[ AI Traffic Forecast ]

[ Traffic Flow Balance ]

[ Adaptive Signal Recommendation ]

[ Gridlock Risk ]

[ Recent Alerts ]
```

Do not place secondary analytics above these elements.

---

# 79. INTERSECTION DETAIL REFINEMENT

Final hierarchy:

```text
Intersection Name
● Operational
Updated 8 sec ago

[ Digital Twin ]

Vehicle Count
Queue
Speed
Occupancy

[ Signal Status ]

[ AI Prediction ]

[ Adaptive Timing Recommendation ]

[ AI Explanation ]

[ Computer Vision ]

[ Pedestrian Safety ]

[ Emergency Priority ]
```

---

# 80. ALERT SCREEN REFINEMENT

Final hierarchy:

```text
Alerts

3 Active

[ Critical ]
Emergency Vehicle

[ Warning ]
Gridlock Risk

[ Information ]
Pedestrian Extension

Filter:
All | Critical | Warning | Info
```

Critical information must visually dominate.

---

# 81. MAP SCREEN REFINEMENT

Final hierarchy:

```text
Traffic Map

[ Search ]

[ Map ]

● Normal
▲ Warning
! Critical
◆ Prediction

[ Selected Intersection Sheet ]
```

Do not cover most of the map with UI.

---

# 82. ANALYTICS REFINEMENT

Final hierarchy:

```text
Traffic Analytics

[ Today | 7D | 30D ]

Average Queue
Average Delay
Congestion
Gridlock Events

[ Queue Trend ]

[ Congestion Trend ]

[ Baseline vs FlowSENSE ]

[ AI Performance ]
```

---

# 83. INFORMATION STATES

Every metric should communicate one of these states:

```text
LIVE
RECENT
STALE
CACHED
PREDICTED
SIMULATED
UNAVAILABLE
```

Use small labels next to data.

Example:

```text
68%
Predicted
Next 15 min
```

Example:

```text
127
Live
8 sec ago
```

Example:

```text
42%
Simulation Data
```

This is particularly important for competition prototypes so judges do not mistake fictional values for actual measurements.

---

# 84. SIMULATION DATA

If the prototype uses fictional data:

Always label it.

Use:

```text
Simulation Data
```

or:

```text
Demo Environment
```

Do not present fabricated traffic metrics as live infrastructure measurements.

---

# 85. AI TRUST MODEL

AI should visually communicate:

```text
Observation
↓
Prediction
↓
Recommendation
↓
Expected impact
```

Not:

```text
AI
↓
Automatic action
```

FlowSENSE remains an operator decision-support platform.

---

# 86. FINAL GOOGLE STITCH INSTRUCTION

Refine the existing FlowSENSE design according to this specification.

Do NOT replace the product concept.

Do NOT turn FlowSENSE into a generic dashboard.

Do NOT add unrelated functionality.

Preserve the existing core information architecture:

- Overview
- Intersections
- Map
- Alerts
- Analytics

Improve:

- responsive behavior
- semantic hierarchy
- accessibility
- typography
- spacing
- component consistency
- state handling
- loading
- error handling
- offline behavior
- AI explainability
- operational clarity
- performance-aware layout
- mobile usability
- localization readiness

The final interface must look polished enough for a **Gemastik 2026 software prototype**, while remaining technically credible for future implementation.

---

# 87. FINAL QUALITY GATE

Before considering the design finished, verify:

## Structure

- [ ] One clear primary page heading
- [ ] Logical content hierarchy
- [ ] Consistent navigation
- [ ] No unnecessary nested containers
- [ ] No horizontal page overflow

## Responsive

- [ ] Works at 320 px
- [ ] Works at 360 px
- [ ] Works at 375 px
- [ ] Works at 390 px
- [ ] Works at 414 px
- [ ] Works at 428 px
- [ ] Works at 448 px

## Accessibility

- [ ] Color is never the only status signal
- [ ] Text remains readable
- [ ] Focus states exist
- [ ] Controls have accessible names
- [ ] Forms have labels
- [ ] Dynamic updates have accessible announcements
- [ ] Logical navigation order
- [ ] Plain language
- [ ] Inclusive terminology

## Operational UX

- [ ] Critical alerts dominate visually
- [ ] Live data is distinguishable from stale data
- [ ] Prediction is distinguishable from observation
- [ ] Simulation data is clearly labeled
- [ ] AI recommendations show confidence
- [ ] AI recommendations show reasoning
- [ ] Emergency states are clearly visible
- [ ] Accessibility events are understandable

## Resilience

- [ ] Loading states
- [ ] Empty states
- [ ] Error states
- [ ] Offline state
- [ ] AI degraded state
- [ ] API failure state
- [ ] System health state

## Performance

- [ ] Avoid unnecessary large images
- [ ] Lazy-load secondary content
- [ ] Avoid layout shifts
- [ ] Keep DOM complexity reasonable
- [ ] Virtualize long lists
- [ ] Defer non-critical functionality
- [ ] Keep charts lightweight
- [ ] Keep maps lightweight
- [ ] Avoid excessive animation

## Security

- [ ] Never expose secrets
- [ ] Never expose tokens
- [ ] Never show production stack traces
- [ ] Secure authentication UX
- [ ] HTTPS-only production assumption
- [ ] No mixed content

## Localization

- [ ] Indonesian is primary
- [ ] Text can expand
- [ ] Numbers are locale-aware
- [ ] Dates are locale-aware
- [ ] UI does not depend on fixed text width

---

# 88. FINAL DESIGN PRINCIPLE

The refined FlowSENSE interface must embody:

**SEE**

What is happening now?

↓

**UNDERSTAND**

Why is it happening?

↓

**PREDICT**

What will happen next?

↓

**RECOMMEND**

What timing strategy does the AI recommend?

↓

**PROTECT**

Are pedestrians, mobility-assisted users, and emergency vehicles safe?

↓

**VERIFY**

Did the intervention improve traffic flow?

The interface should make this entire reasoning chain visible without forcing the operator to navigate through unnecessary screens.

The final product should feel:

**fast, calm, precise, predictive, accessible, resilient, and operational.**