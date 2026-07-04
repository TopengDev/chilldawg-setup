# RSC Boundaries

Detect and prevent invalid patterns when crossing Server/Client component boundaries.

## Detection Rules

### 1. Async Client Components Are Invalid

Client components **cannot** be async functions. Only Server Components can be async.

**Detect:** File has `'use client'` AND component is `async function` or returns `Promise`

```tsx
// Bad: async client component
'use client'
export default async function UserProfile() {
  const user = await getUser() // Cannot await in client component
  return <div>{user.name}</div>
}

// Good: Remove async, fetch data in parent server component
// page.tsx (server component - no 'use client')
export default async function Page() {
  const user = await getUser()
  return <UserProfile user={user} />
}

// UserProfile.tsx (client component)
'use client'
export function UserProfile({ user }: { user: User }) {
  return <div>{user.name}</div>
}
```

```tsx
// Bad: async arrow function client component
'use client'
const Dashboard = async () => {
  const data = await fetchDashboard()
  return <div>{data}</div>
}

// Good: Fetch in server component, pass data down
```

### 2. Non-Serializable Props to Client Components (React 19 rules)

React 19 serializes Server → Client props with React's own wire format — **NOT plain JSON**.
The allowed list is much wider than JSON (source: react.dev `'use client'` reference,
verified against React 19 docs 2026-07-03).

**Serializable — NEVER flag these as bugs:**
- Primitives: `string`, `number`, `bigint`, `boolean`, `undefined`, `null`, Symbols registered via `Symbol.for`
- `Array`, `Map`, `Set`, `TypedArray`, `ArrayBuffer`
- `Date`
- Plain objects (object-literal shaped, serializable values)
- JSX elements
- `Promise`s (unwrap client-side with `use()` — streaming recipe below)
- Server Functions (`'use server'` — see Rule 3)
- `FormData` instances

**NOT serializable — flag ONLY these:**
- Functions that are NOT Server Functions (event handlers/callbacks defined server-side)
- Classes and class instances (methods stripped / render error)
- Objects with a null prototype (`Object.create(null)`)
- Symbols not registered via `Symbol.for`

> Pre-React-19 lore said Date/Map/Set were unserializable and demanded `.toISOString()` /
> `Object.fromEntries()` conversion churn. That is OBSOLETE on the house estate (all repos
> run Next 15/16 = React 19 era). Do not generate those refactors.

```tsx
// Bad: Function prop (not a Server Function)
// page.tsx (server)
export default function Page() {
  const handleClick = () => console.log('clicked')
  return <ClientButton onClick={handleClick} />
}

// Good: Define function inside client component
// ClientButton.tsx
'use client'
export function ClientButton() {
  const handleClick = () => console.log('clicked')
  return <button onClick={handleClick}>Click</button>
}
```

```tsx
// Bad: Class instance
const user = new UserModel(data)
<ClientProfile user={user} /> // Methods will be stripped

// Good: Pass plain object
const user = await getUser()
<ClientProfile user={{ id: user.id, name: user.name }} />
```

```tsx
// Fine in React 19 — no conversion needed:
<PostCard createdAt={post.createdAt} />          // Date passes through as a Date
<ClientComponent items={new Map([['a', 1]])} />  // Map passes through as a Map
```

**Streaming recipe — pass a Promise, unwrap with `use()`:**

```tsx
// page.tsx (server) — do NOT await; hand the promise down
import { Suspense } from 'react'

export default function Page() {
  const postsPromise = getPosts() // no await — render is not blocked
  return (
    <Suspense fallback={<PostsSkeleton />}>
      <Posts postsPromise={postsPromise} />
    </Suspense>
  )
}

// Posts.tsx (client)
'use client'
import { use } from 'react'

export function Posts({ postsPromise }: { postsPromise: Promise<Post[]> }) {
  const posts = use(postsPromise) // suspends until resolved, streams in
  return <ul>{posts.map(p => <li key={p.id}>{p.title}</li>)}</ul>
}
```

### 3. Server Actions Are the Exception

Functions marked with `'use server'` CAN be passed to client components.

```tsx
// Valid: Server Action can be passed
// actions.ts
'use server'
export async function submitForm(formData: FormData) {
  // server-side logic
}

// page.tsx (server)
import { submitForm } from './actions'
export default function Page() {
  return <ClientForm onSubmit={submitForm} /> // OK!
}

// ClientForm.tsx (client)
'use client'
export function ClientForm({ onSubmit }: { onSubmit: (data: FormData) => Promise<void> }) {
  return <form action={onSubmit}>...</form>
}
```

## Quick Reference

| Pattern | Valid? | Fix |
|---------|--------|-----|
| `'use client'` + `async function` | No | Fetch in server parent, pass data |
| Pass `() => {}` (non-Server-Function) to client | No | Define in client or use a Server Action |
| Pass class instance to client | No | Pass plain object |
| Pass null-prototype object to client | No | Rebuild as a plain object |
| Pass unregistered `Symbol()` to client | No | Use `Symbol.for('name')` |
| Pass `new Date()` to client | Yes (React 19) | - |
| Pass `new Map()` / `new Set()` / TypedArray | Yes (React 19) | - |
| Pass a `Promise` to client | Yes | Unwrap with `use()` inside `<Suspense>` |
| Pass Server Action (`'use server'`) to client | Yes | - |
| Pass `string/number/boolean` | Yes | - |
| Pass plain object/array/JSX | Yes | - |
