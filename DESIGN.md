# DevHub Design System

## Direction

The DevHub documentation uses an Apple-inspired local developer aesthetic: clear, quiet, sharp, and premium without becoming decorative. The interface should feel like a native macOS utility page for infrastructure work.

Physical scene: a developer reads this on a laptop during the day while setting up multiple local branches. The page should reduce friction and make the workflow feel controlled.

## Color Strategy

Restrained. Use cool tinted neutrals with a single system-blue accent. Blue should stay under roughly ten percent of the page and mark actions, CLI terms, and small status elements.

Use OKLCH tokens from `docs/input.css`:

```css
--color-page: oklch(97.6% 0.004 250);
--color-panel: oklch(99.1% 0.003 250);
--color-window: oklch(96.7% 0.005 250);
--color-soft: oklch(94.2% 0.006 250);
--color-hairline: oklch(86.5% 0.008 250);
--color-graphite: oklch(21% 0.012 255);
--color-muted: oklch(48% 0.018 255);
--color-blue: oklch(58% 0.19 255);
--color-blue-strong: oklch(52% 0.21 255);
--color-blue-soft: oklch(93.5% 0.035 255);
--color-code: oklch(24% 0.016 255);
--color-code-text: oklch(92% 0.006 255);
```

Avoid pure black and pure white. Avoid warm beige, forest green, copper, amber, purple gradients, and broad color washes.

## Typography

Use the system font stack to stay close to native Apple surfaces:

```css
-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", ui-sans-serif, system-ui, "Segoe UI", sans-serif
```

Guidelines:

- Hero product name uses very large system type, semibold, tight negative tracking.
- Body copy is calm and readable, with line length under 75 characters where possible.
- Section headings use strong scale changes, not color decoration.
- Code uses SF Mono where available.

## Layout

- Maximum content width: `1120px`.
- Use one dominant hero idea, then documentation sections.
- Keep cards shallow and purposeful. Radius should stay at `rounded-lg`.
- Prefer hairline borders and subtle shadows over heavy containers.
- Tables and code blocks should remain practical and scannable.
- Mobile layout must keep the runtime preview readable without horizontal overflow.

## Components

### Header

Sticky, translucent, hairline border, compact brand mark. Navigation stays quiet and text-only.

### Buttons

Primary: blue pill with panel text. Secondary: panel pill with hairline border. Buttons are used only for direct actions.

### Runtime Preview

Use a macOS-style window frame to explain the worktree model visually. It should be a product diagram, not a decorative card. Keep status colors limited to small window dots and small status pills.

### Code Blocks

Dark graphite background, muted light code text, rounded-lg radius, copy button in the top-right. Commands must remain easy to copy.

### Content Cards

Use white-tinted panels with hairline borders and subtle shadow. Avoid repeated icon grids.

## Motion

Keep motion minimal. Use hover transitions only on navigation and buttons. Do not animate layout properties.

## Copy Rules

- French interface copy is acceptable.
- Be direct and technical.
- Prefer short sentences.
- Do not use em dashes.
- Do not over-explain features already obvious from a command.

## Accessibility

- Preserve semantic headings, tables, captions, and nav labels.
- Keep color contrast readable on all text.
- Ensure mobile navigation toggles `aria-expanded`.
- Do not rely on color alone to explain the workflow.
