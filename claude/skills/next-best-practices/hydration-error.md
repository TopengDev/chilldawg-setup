# Hydration Errors

Diagnose and fix React hydration mismatch errors.

## Error Signs

- "Hydration failed because the initial UI does not match"
- "Text content does not match server-rendered HTML"

## Debugging

In development, click the hydration error to see the server/client diff.

## Common Causes and Fixes

### Browser-only APIs

```tsx
// Bad: Causes mismatch - window doesn't exist on server
<div>{window.innerWidth}</div>

// Good: Use client component with mounted check
'use client'
import { useState, useEffect } from 'react'

export function ClientOnly({ children }: { children: React.ReactNode }) {
  const [mounted, setMounted] = useState(false)
  useEffect(() => setMounted(true), [])
  return mounted ? children : null
}
```

### Date/Time Rendering

Server and client may be in different timezones:

```tsx
// Bad: Causes mismatch
<span>{new Date().toLocaleString()}</span>

// Good: Render on client only
'use client'
const [time, setTime] = useState<string>()
useEffect(() => setTime(new Date().toLocaleString()), [])
```

### Random Values or IDs

```tsx
// Bad: Random values differ between server and client
<div id={Math.random().toString()}>

// Good: Use useId hook
import { useId } from 'react'

function Input() {
  const id = useId()
  return <input id={id} />
}
```

### Invalid HTML Nesting

```tsx
// Bad: Invalid - div inside p
<p><div>Content</div></p>

// Bad: Invalid - p inside p
<p><p>Nested</p></p>

// Good: Valid nesting
<div><p>Content</p></div>
```

### next-themes / Theme Class on `<html>`

next-themes mutates the `<html>` class/style BEFORE hydration (its inline script applies the
stored theme), so the server-rendered `<html>` attributes never match. This is EXPECTED —
silence it with `suppressHydrationWarning` on the `<html>` element only. House website builds
ship next-themes from commit 0 (CLAUDE.md Website Build Defaults), so this applies to
every Aenoxa-ecosystem Next.js layout:

```tsx
// app/layout.tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id" suppressHydrationWarning>
      <body>
        <ThemeProvider attribute="class">{children}</ThemeProvider>
      </body>
    </html>
  )
}
```

- `suppressHydrationWarning` is one-level-deep — it suppresses only that element's own
  attribute mismatch, nothing inside it.
- NEVER scatter it on arbitrary elements to hide real hydration bugs — the themed `<html>`
  is the sanctioned use.

### Third-party Scripts

Scripts that modify DOM during hydration.

```tsx
// Good: Use next/script with afterInteractive
import Script from 'next/script'

export default function Page() {
  return (
    <Script
      src="https://example.com/script.js"
      strategy="afterInteractive"
    />
  )
}
```
