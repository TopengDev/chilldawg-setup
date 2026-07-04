# Directives

## React Directives

These are React directives, not Next.js specific.

### `'use client'`

Marks a component as a Client Component. Required for:
- React hooks (`useState`, `useEffect`, etc.)
- Event handlers (`onClick`, `onChange`)
- Browser APIs (`window`, `localStorage`)

```tsx
'use client'

import { useState } from 'react'

export function Counter() {
  const [count, setCount] = useState(0)
  return <button onClick={() => setCount(count + 1)}>{count}</button>
}
```

Reference: https://react.dev/reference/rsc/use-client

### `'use server'`

Marks a function as a Server Action. Can be passed to Client Components.

```tsx
'use server'

export async function submitForm(formData: FormData) {
  // Runs on server
}
```

Or inline within a Server Component:

```tsx
export default function Page() {
  async function submit() {
    'use server'
    // Runs on server
  }
  return <form action={submit}>...</form>
}
```

Reference: https://react.dev/reference/rsc/use-server

---

## Next.js Directive

### `'use cache'`

Marks a function or component for caching. Part of Next.js Cache Components.

```tsx
'use cache'

export async function getCachedData() {
  return await fetchData()
}
```

**Enablement is VERSION-GATED — check the installed Next version first (SKILL.md step 0):**

| Installed Next | Enable via | Notes |
|---|---|---|
| 15.x | `experimental: { useCache: true }` | `experimental.dynamicIO` for full Cache Components semantics |
| 16.x | `cacheComponents: true` (TOP-LEVEL) | `experimental.useCache` / `experimental.dynamicIO` are REMOVED in 16 — they error as unrecognized |

**16.x conflict trap:** enabling `cacheComponents` errors at build on ANY route segment that
still exports `dynamic`, `revalidate`, or `fetchCache`. Remove those segment exports and
migrate them to `'use cache'` + cache profiles BEFORE flipping the flag.

Cache profiles (all from `next/cache`): `cacheLife('hours')` sets the entry's revalidation
lifetime; `cacheTag('posts')` labels it for invalidation via `revalidateTag()` / `updateTag()`.
Full API: https://nextjs.org/docs/app/api-reference/directives/use-cache
(Verified against version-16 upgrade guide via context7, 2026-07-03.)
