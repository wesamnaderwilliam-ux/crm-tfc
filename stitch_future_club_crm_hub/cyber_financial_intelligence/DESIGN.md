---
name: Cyber-Financial Intelligence
colors:
  surface: '#111317'
  surface-dim: '#111317'
  surface-bright: '#37393e'
  surface-container-lowest: '#0c0e12'
  surface-container-low: '#1a1c20'
  surface-container: '#1e2024'
  surface-container-high: '#282a2e'
  surface-container-highest: '#333539'
  on-surface: '#e2e2e8'
  on-surface-variant: '#b9cac4'
  inverse-surface: '#e2e2e8'
  inverse-on-surface: '#2f3035'
  outline: '#83948f'
  outline-variant: '#3a4a46'
  surface-tint: '#00dfc1'
  primary: '#d7fff3'
  on-primary: '#00382f'
  primary-container: '#00f5d4'
  on-primary-container: '#006c5c'
  inverse-primary: '#006b5b'
  secondary: '#ffb1c2'
  on-secondary: '#66002b'
  secondary-container: '#980044'
  on-secondary-container: '#ffa1b7'
  tertiary: '#edf8ff'
  on-tertiary: '#003545'
  tertiary-container: '#a6e3ff'
  on-tertiary-container: '#006784'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#26fedc'
  primary-fixed-dim: '#00dfc1'
  on-primary-fixed: '#00201a'
  on-primary-fixed-variant: '#005144'
  secondary-fixed: '#ffd9e0'
  secondary-fixed-dim: '#ffb1c2'
  on-secondary-fixed: '#3f0018'
  on-secondary-fixed-variant: '#8f0040'
  tertiary-fixed: '#bce9ff'
  tertiary-fixed-dim: '#6cd3fc'
  on-tertiary-fixed: '#001f2a'
  on-tertiary-fixed-variant: '#004d63'
  background: '#111317'
  on-background: '#e2e2e8'
  surface-variant: '#333539'
typography:
  display-lg:
    fontFamily: Sora
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Sora
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Sora
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Sora
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.05em
  mono-data:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 8px
  container-padding-desktop: 40px
  container-padding-mobile: 16px
  gutter: 24px
  card-gap: 24px
  section-margin: 48px
---

## Brand & Style

The design system is engineered to evoke a sense of "pre-cognitive" financial management—where data is not just recorded but visualized as a living, glowing entity. It is tailored for high-stakes financial consultancy, balancing the gravity of institutional banking with the agility of a tech-forward startup.

The visual style is **Futuristic Glassmorphism**. It utilizes deep, infinite backgrounds to create a sense of vast space, punctuated by high-fidelity glass surfaces that prioritize content through transparency and blur. The emotional response is one of exclusivity, precision, and "The Future Club" atmosphere: a private, high-tech sanctuary for wealth management.

- **Primary Motif:** High-contrast luminescence against obsidian depths.
- **Tone:** Visionary, Elite, and Technically Precise.
- **Visual Influence:** Modern SaaS dashboards blended with cinematic data visualization.

## Colors

This design system operates exclusively in **Dark Mode** to reduce eye strain during intensive data analysis and to maximize the "neon" contrast of financial indicators.

- **Primary (Electric Cyan):** Used for growth, active states, and "success" metrics. It should often carry a subtle outer glow (drop shadow) to simulate light emission.
- **Secondary (Soft Magenta):** Used for attention-grabbing elements, warnings, or "The Future Club" signature branding highlights.
- **Functional Neutrals:** The palette relies on deep charcoals and pure blacks to create infinite depth. Surface levels are defined by transparency rather than solid color shifts.
- **Status Indicators:** Vibrant greens for market gains and soft reds for losses, always utilizing high-saturation values to pop against the dark background.

## Typography

The typography strategy focuses on geometric precision. **Sora** provides a tech-forward, wide-aperture look for headlines that feels premium and architectural. **Hanken Grotesk** is used for functional UI and body text to ensure maximum legibility within dense CRM tables and data grids.

- **Display Text:** Reserved for key financial figures (e.g., Portfolio Value). Should use a slight "glow" text-shadow in primary colors.
- **Labels:** Always uppercase with increased letter spacing to provide a "instrument panel" feel.
- **Data Mono:** While Hanken Grotesk is used, numeric data should utilize tabular lining (mono-spacing for numbers) to ensure columns of figures align perfectly.

## Layout & Spacing

The layout is based on a **12-column fluid grid** with generous internal padding to maintain an "expensive" and airy feel. 

- **Sidebar:** A slim, glass-textured sidebar (80px collapsed, 240px expanded) anchored to the left.
- **Data density:** Use an 8px base unit. For Bank Employees (high density), use the 4px half-step for compact tables. For Company Employees (executive view), use 16px and 24px increments to create more breathing room.
- **Breakpoints:** 
    - Mobile: < 768px (Single column, hidden sidebar)
    - Tablet: 768px - 1280px (Stacked widgets)
    - Desktop: > 1280px (Full dashboard layout)

## Elevation & Depth

Depth is achieved through **Backdrop Blurs** and **Tonal Stacking** rather than traditional shadows.

- **Level 0 (Background):** Pure `#050505` or a very deep radial gradient.
- **Level 1 (Card/Surface):** Semi-transparent dark grey (`rgba(20, 22, 26, 0.6)`) with a `blur(20px)`.
- **Level 2 (Hover/Active):** Increase opacity and add a 1px inner border using a gradient from the primary color to transparent.
- **Floating Elements (Modals/Popovers):** Highest elevation. Uses a 1px border of `rgba(255, 255, 255, 0.1)` and a wide, low-opacity outer glow matching the component's context (e.g., cyan glow for primary actions).

## Shapes

The shape language is "Hyper-Rounded." This softens the technical nature of the financial data and makes the interface feel more approachable and modern.

- **Cards:** Use `rounded-xl` (1.5rem) to create distinct "pods" of information.
- **Buttons & Chips:** Use a full pill-shape (`rounded-full`) for high-level actions.
- **Inputs:** Use `rounded-lg` (1rem) to differentiate data-entry fields from actionable buttons.
- **Visual Accents:** Use circular shapes for status indicators, ensuring they have a soft-diffused radial glow behind them.

## Components

### Buttons
- **Primary:** Full fill of Primary Cyan. Text is black for maximum legibility. Hover state adds a cyan drop-shadow (glow).
- **Secondary (Glass):** Transparent background with a 1px Primary Cyan border. 
- **Ghost:** No border, Primary Cyan text. Used for less prominent actions in sidebars.

### Input Fields
- Dark backgrounds (`rgba(0,0,0,0.3)`) with a bottom-only or subtle 1px frame. 
- **Focus state:** The entire border glows in Primary Cyan, and the label floats above the field with a reduced font size.

### Cards & Widgets
- Standardized dashboard containers. Every card must have a `backdrop-filter: blur(20px)`.
- Header area of cards should feature a `label-md` category title and an optional icon with a subtle background glow.

### Status Indicators
- **Financial Growth:** A Cyan dot with a 4px blur pulse animation.
- **Action Required:** A Secondary Magenta dot.
- **Neutral/Idle:** A low-opacity white/grey dot.

### Lists & Tables
- Row hover states should use a subtle highlight: `rgba(255, 255, 255, 0.03)`.
- Dividers between rows should be very faint (`rgba(255, 255, 255, 0.05)`).