# Font Optimization

Use `next/font` for automatic font optimization with zero layout shift.

> **Ownership note:** this file owns font LOADING mechanics only. Font SELECTION is owned by
> `/frontend-design` — Inter/Roboto are banned there as AI-slop defaults, and monospace is
> allowed only when the archetype identity is mono (memory: `feedback_no_monospace_unless_archetype`).
> `Sora` / `Fraunces` below are neutral placeholders, NOT choices. House typography floors also
> apply to what you render: no text below weight 500 or size 12px (memory: `feedback_ui_typography_floors`).

## Google Fonts

```tsx
// app/layout.tsx
import { Sora } from 'next/font/google'

const sora = Sora({ subsets: ['latin'] })

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={sora.className}>
      <body>{children}</body>
    </html>
  )
}
```

## Multiple Fonts

```tsx
import { Sora, Fraunces } from 'next/font/google'

const sora = Sora({
  subsets: ['latin'],
  variable: '--font-sora',
})

const fraunces = Fraunces({
  subsets: ['latin'],
  variable: '--font-fraunces',
})

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${sora.variable} ${fraunces.variable}`}>
      <body>{children}</body>
    </html>
  )
}
```

Use in CSS:
```css
body {
  font-family: var(--font-sora);
}

h1, h2 {
  font-family: var(--font-fraunces);
}
```

## Font Weights and Styles

```tsx
// Single weight (house floor: nothing rendered below 500)
const sora = Sora({
  subsets: ['latin'],
  weight: '500',
})

// Multiple weights
const sora = Sora({
  subsets: ['latin'],
  weight: ['500', '600', '700'],
})

// Variable font (recommended) - includes all weights
const sora = Sora({
  subsets: ['latin'],
  // No weight needed - variable fonts support all weights
})

// With italic
const sora = Sora({
  subsets: ['latin'],
  style: ['normal', 'italic'],
})
```

## Local Fonts

```tsx
import localFont from 'next/font/local'

const myFont = localFont({
  src: './fonts/MyFont.woff2',
})

// Multiple files for different weights
const myFont = localFont({
  src: [
    {
      path: './fonts/MyFont-Medium.woff2',
      weight: '500',
      style: 'normal',
    },
    {
      path: './fonts/MyFont-Bold.woff2',
      weight: '700',
      style: 'normal',
    },
  ],
})

// Variable font
const myFont = localFont({
  src: './fonts/MyFont-Variable.woff2',
  variable: '--font-my-font',
})
```

## Tailwind CSS Integration

```tsx
// app/layout.tsx
import { Sora } from 'next/font/google'

const sora = Sora({
  subsets: ['latin'],
  variable: '--font-sora',
})

export default function RootLayout({ children }) {
  return (
    <html lang="en" className={sora.variable}>
      <body>{children}</body>
    </html>
  )
}
```

```js
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      fontFamily: {
        sans: ['var(--font-sora)'],
      },
    },
  },
}
```

## Preloading Subsets

Only load needed character subsets:

```tsx
// Latin only (most common)
const sora = Sora({ subsets: ['latin'] })

// Multiple subsets
const sora = Sora({ subsets: ['latin', 'latin-ext'] })
```

## Display Strategy

Control font loading behavior:

```tsx
const sora = Sora({
  subsets: ['latin'],
  display: 'swap', // Default - shows fallback, swaps when loaded
})

// Options:
// 'auto' - browser decides
// 'block' - short block period, then swap
// 'swap' - immediate fallback, swap when ready (recommended)
// 'fallback' - short block, short swap, then fallback
// 'optional' - short block, no swap (use if font is optional)
```

## Don't Use Manual Font Links

Always use `next/font` instead of `<link>` tags for Google Fonts.

```tsx
// Bad: Manual link tag (blocks rendering, no optimization)
<link href="https://fonts.googleapis.com/css2?family=Sora" rel="stylesheet" />

// Bad: Missing display and preconnect
<link href="https://fonts.googleapis.com/css2?family=Sora" rel="stylesheet" />

// Good: Use next/font (self-hosted, zero layout shift)
import { Sora } from 'next/font/google'

const sora = Sora({ subsets: ['latin'] })
```

## Common Mistakes

```tsx
// Bad: Importing font in every component
// components/Button.tsx
import { Sora } from 'next/font/google'
const sora = Sora({ subsets: ['latin'] }) // Creates new instance each time!

// Good: Import once in layout, use CSS variable
// app/layout.tsx
const sora = Sora({ subsets: ['latin'], variable: '--font-sora' })

// Bad: Using @import in CSS (blocks rendering)
/* globals.css */
@import url('https://fonts.googleapis.com/css2?family=Sora');

// Good: Use next/font (self-hosted, no network request)
import { Sora } from 'next/font/google'

// Bad: Loading all weights when only using a few
const sora = Sora({ subsets: ['latin'] }) // Loads all weights (non-variable case)

// Good: Specify only needed weights (for non-variable fonts)
const sora = Sora({ subsets: ['latin'], weight: ['500', '700'] })

// Bad: Missing subset - loads all characters
const sora = Sora({})

// Good: Always specify subset
const sora = Sora({ subsets: ['latin'] })
```

## Font in Specific Components

```tsx
// For component-specific fonts, export from a shared file
// lib/fonts.ts
import { Sora, Fraunces } from 'next/font/google'

export const sora = Sora({ subsets: ['latin'], variable: '--font-sora' })
export const fraunces = Fraunces({ subsets: ['latin'], variable: '--font-fraunces' })

// components/Heading.tsx
import { fraunces } from '@/lib/fonts'

export function Heading({ children }) {
  return <h1 className={fraunces.className}>{children}</h1>
}
```
