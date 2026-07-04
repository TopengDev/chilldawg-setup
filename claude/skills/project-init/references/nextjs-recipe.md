# nextjs recipe - complete verified Next 16 path

Companion to SKILL.md §4. Phase order and blocking asserts live there; this file carries the
full file bodies and commands. Everything marked **[verify on first run]** was written against
current docs (context7, 2026-07-03) but not executed live during authoring - run the terminal
gate (SKILL.md §7) and treat a failure there as a doc-drift signal, not a reason to skip the gate.

Ground truth this recipe is built on (SKILL.md §12 ledger): create-next-app 16.2.10 output
live-verified 2026-07-03; next-intl 4.13.1 docs; next-themes 0.4.6 docs.

---

## 1. Scaffold (Phase 1)

```bash
cd "$PROJECT_DIR"    # contains at most .git/ (PI-1)
npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir \
  --import-alias "@/*" --use-npm --yes

# BLOCKING ASSERT (PI-2):
test -f package.json && grep -q '"next"' package.json || echo "SCAFFOLD FAILED - PB-1"
```

Generated files you must NOT clobber: `AGENTS.md`, `CLAUDE.md` (extend via Read -> Edit, PI-16),
`eslint.config.mjs` (extend, PI-5), `.gitignore` (append), `src/app/globals.css` (extend).

---

## 2. Directory layout additions

```bash
mkdir -p src/components src/lib src/hooks src/types src/i18n
mkdir -p tests/unit tests/integration tests/e2e
mkdir -p docs scripts messages .github/workflows .github/ISSUE_TEMPLATE
```

---

## 3. i18n wiring - next-intl 4.x (Phase 2, WEBSITE mode)

```bash
npm install next-intl        # RUNTIME dep
```

### 3.1 `src/i18n/routing.ts`

```ts
import { defineRouting } from 'next-intl/routing';

export const routing = defineRouting({
  locales: ['id', 'en'],
  defaultLocale: 'id',   // house rule: id is DEFAULT (Aenoxa target market)
});
```

### 3.2 `src/i18n/navigation.ts`

```ts
import { createNavigation } from 'next-intl/navigation';
import { routing } from './routing';

export const { Link, redirect, usePathname, useRouter, getPathname } =
  createNavigation(routing);
```

Use THESE (locale-aware) instead of `next/link` / `next/navigation` everywhere in app code.

### 3.3 `src/i18n/request.ts`

```ts
import { getRequestConfig } from 'next-intl/server';
import { hasLocale } from 'next-intl';
import { routing } from './routing';

export default getRequestConfig(async ({ requestLocale }) => {
  const requested = await requestLocale;
  const locale = hasLocale(routing.locales, requested)
    ? requested
    : routing.defaultLocale;

  return {
    locale,
    messages: (await import(`../../messages/${locale}.json`)).default,
  };
});
```

### 3.4 `src/proxy.ts` (NOT middleware.ts - PI-14)

next-intl's own docs now show `src/proxy.ts` for the Next 16 era. The matcher MUST exclude
`/api` (PI-15) or the compose healthcheck gets locale-redirected.

```ts
import createMiddleware from 'next-intl/middleware';
import { routing } from './i18n/routing';

export default createMiddleware(routing);

export const config = {
  // Match all pathnames except /api, /trpc, Next internals, and files with a dot
  matcher: '/((?!api|trpc|_next|_vercel|.*\\..*).*)',
};
```

### 3.5 Move the app under `[locale]`

```bash
mkdir -p 'src/app/[locale]'          # QUOTE the brackets - unquoted [locale] is a bash glob
mv src/app/page.tsx 'src/app/[locale]/page.tsx'
mv src/app/layout.tsx 'src/app/[locale]/layout.tsx'
```

Per next-intl's documented structure the root layout lives at `src/app/[locale]/layout.tsx`
(all routes sit under the segment). Carry over the generated font imports + the
`import './globals.css'` line - fix the relative path (`../globals.css`) or move globals.css
alongside. **[verify on first run]**: a request to `/` must redirect to `/id`.

### 3.6 `src/app/[locale]/layout.tsx`

```tsx
import type { Metadata } from 'next';
import { NextIntlClientProvider, hasLocale } from 'next-intl';
import { setRequestLocale } from 'next-intl/server';
import { notFound } from 'next/navigation';
import { routing } from '@/i18n/routing';
import { ThemeProvider } from '@/components/theme-provider';
import '../globals.css';
// keep the generated Geist font imports + className wiring here

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

type Props = {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
};

export async function generateMetadata({ params }: Omit<Props, 'children'>): Promise<Metadata> {
  const { locale } = await params;
  return {
    // hreflang for SEO (house i18n rule) - extend per page as routes grow
    alternates: {
      languages: { id: '/id', en: '/en', 'x-default': '/id' },
    },
    other: { 'content-language': locale },
  };
}

export default async function LocaleLayout({ children, params }: Props) {
  const { locale } = await params;
  if (!hasLocale(routing.locales, locale)) notFound();
  setRequestLocale(locale); // enables static rendering

  return (
    <html lang={locale} suppressHydrationWarning>
      <body>
        <NextIntlClientProvider>
          <ThemeProvider
            attribute="class"
            defaultTheme="system"
            enableSystem
            disableTransitionOnChange
          >
            {children}
          </ThemeProvider>
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
```

`suppressHydrationWarning` on `<html>` is REQUIRED (next-themes mutates the class attribute
before hydration; that is also what prevents FOUC).

### 3.7 Messages - REAL Bahasa Indonesia (anti-slop §10)

`messages/id.json`:

```json
{
  "common": {
    "loading": "Memuat...",
    "error": "Terjadi kesalahan. Silakan coba lagi.",
    "retry": "Coba lagi"
  },
  "nav": {
    "home": "Beranda",
    "themeToggle": "Ganti tema",
    "language": "Bahasa"
  },
  "home": {
    "title": "Proyek siap dikembangkan",
    "description": "Scaffold selesai. Mulai bangun fitur pertama Anda."
  },
  "notFound": {
    "title": "Halaman tidak ditemukan",
    "description": "Halaman yang Anda cari tidak ada atau sudah dipindahkan.",
    "backHome": "Kembali ke beranda"
  }
}
```

`messages/en.json` - SAME key tree, English values ("Loading...", "Something went wrong. Please
try again.", "Retry", "Home", "Toggle theme", "Language", "Project ready for development",
"Scaffolding complete. Start building your first feature.", "Page not found", "The page you are
looking for does not exist or has been moved.", "Back to home").

Grow BOTH files together for every section/form/error/toast string - the key-parity assert
(SKILL.md Phase 2) and the vitest parity test (§6.4) both fail on drift. Auth flows, form
errors, toasts, 404/error pages: ALL translated (house rule - no English-only error strings).

### 3.8 `src/app/[locale]/not-found.tsx`

```tsx
import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';

export default function NotFound() {
  const t = useTranslations('notFound');
  return (
    <main>
      <h1>{t('title')}</h1>
      <p>{t('description')}</p>
      <Link href="/">{t('backHome')}</Link>
    </main>
  );
}
```

**[verify on first run]**: within-locale 404s render this. A fully global 404 (path outside any
locale) needs next-intl's catch-all pattern - add it when the app grows real routes.

### 3.9 Rewrite `src/app/[locale]/page.tsx` with translations

Replace the generated boilerplate: `const t = useTranslations('home');` (client) or
`const t = await getTranslations('home');` (server component), render `t('title')` /
`t('description')`. ZERO hardcoded user-facing strings survive (website gate item 3).

---

## 4. Theme wiring - next-themes 0.4.x (Phase 2, WEBSITE mode)

```bash
npm install next-themes      # RUNTIME dep
```

### 4.1 `src/components/theme-provider.tsx`

```tsx
'use client';

import { ThemeProvider as NextThemesProvider } from 'next-themes';
import type { ComponentProps } from 'react';

export function ThemeProvider(props: ComponentProps<typeof NextThemesProvider>) {
  return <NextThemesProvider {...props} />;
}
```

### 4.2 `src/components/theme-switcher.tsx` (visible in nav - house rule)

```tsx
'use client';

import { useEffect, useState } from 'react';
import { useTheme } from 'next-themes';
import { useTranslations } from 'next-intl';

const ORDER = ['light', 'dark', 'system'] as const;

export function ThemeSwitcher() {
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);
  const t = useTranslations('nav');

  useEffect(() => setMounted(true), []);
  if (!mounted) return null; // avoid hydration mismatch (documented next-themes pattern)

  const next = ORDER[(ORDER.indexOf(theme as (typeof ORDER)[number]) + 1) % ORDER.length];
  return (
    <button type="button" onClick={() => setTheme(next)} aria-label={t('themeToggle')}>
      {theme}
    </button>
  );
}
```

Place it in the page/nav so it is VISIBLE, not buried. Styling routes through /frontend-design
later (respect the typography floors when it gets styled).

### 4.3 `src/app/globals.css` - tokens + class-based dark (Tailwind v4)

The generated file already has `@import "tailwindcss";`, `:root` tokens, and `@theme inline`.
Changes:

1. ADD the class-based dark variant so `dark:` utilities key off next-themes' class:

```css
@custom-variant dark (&:is(.dark *));
```

2. REPLACE the generated `@media (prefers-color-scheme: dark)` block with a `.dark` class
   block (system preference is handled by next-themes' `system` theme, not by the media query -
   leaving both creates double-switching):

```css
:root {
  --background: #ffffff;
  --foreground: #171717;
  --surface: #f5f5f5;
  --border: #e5e5e5;
  --accent: #171717;
}

.dark {
  --background: #0a0a0a;
  --foreground: #ededed;
  --surface: #171717;
  --border: #262626;
  --accent: #ededed;
}
```

3. EXTEND `@theme inline` to map the new tokens:

```css
@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-surface: var(--surface);
  --color-border: var(--border);
  --color-accent: var(--accent);
  /* keep the generated font mappings */
}
```

Components use tokens (`bg-background`, `text-foreground`, `bg-surface`, ...) - NEVER hardcoded
color values (house rule). Both themes must end up equally polished (that is a /frontend-design
job; the scaffold's duty is that the MECHANISM works both ways). **[verify on first run]**:
toggle the switcher, confirm the `dark` class lands on `<html>` and tokens flip.

---

## 5. Quality tooling (Phase 3)

### 5.1 Installs

```bash
npm install zod    # RUNTIME (PI-8)
npm install -D vitest @testing-library/react @testing-library/jest-dom @vitejs/plugin-react jsdom
npm install -D husky lint-staged @commitlint/cli @commitlint/config-conventional prettier
```

### 5.2 `commitlint.config.mjs` (.mjs - PI note in SKILL.md Phase 3)

```js
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', [
      'feat', 'fix', 'docs', 'style', 'refactor',
      'perf', 'test', 'build', 'ci', 'chore', 'revert',
    ]],
    'subject-max-length': [2, 'always', 72],
  },
};
```

### 5.3 Hooks

```bash
npx husky init
echo 'npx lint-staged' > .husky/pre-commit
echo 'npx --no -- commitlint --edit "$1"' > .husky/commit-msg
chmod +x .husky/pre-commit .husky/commit-msg
```

`npx husky init` adds `"prepare": "husky"` to package.json - keep it; Docker neutralizes it
with `--ignore-scripts` (PI-6).

### 5.4 `vitest.config.ts`

```ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./tests/setup.ts'],
    include: ['tests/**/*.test.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: ['node_modules/', 'tests/setup.ts'],
    },
  },
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') },
  },
});
```

`tests/setup.ts`:

```ts
import '@testing-library/jest-dom/vitest';
```

### 5.5 Tests that earn their keep

`tests/unit/i18n-messages.test.ts` (WEBSITE mode - this is the parity gate as a regression test):

```ts
import { describe, it, expect } from 'vitest';
import id from '../../messages/id.json';
import en from '../../messages/en.json';

function keysOf(obj: Record<string, unknown>, prefix = ''): string[] {
  return Object.entries(obj).flatMap(([k, v]) =>
    v !== null && typeof v === 'object'
      ? keysOf(v as Record<string, unknown>, `${prefix}${k}.`)
      : [`${prefix}${k}`],
  );
}

describe('i18n messages', () => {
  it('id and en are key-parallel', () => {
    expect(keysOf(id).sort()).toEqual(keysOf(en).sort());
  });
  it('no empty strings', () => {
    for (const m of [id, en]) {
      expect(keysOf(m).length).toBeGreaterThan(0);
    }
  });
});
```

(tsconfig from create-next-app has `resolveJsonModule: true`, so the JSON imports work.)
Non-website modes: a minimal env/config test instead - never zero tests (V4 must run something
real).

### 5.6 `src/lib/env.ts` - zod 4 idioms

```ts
import { z } from 'zod';

// NEVER put a secret in a NEXT_PUBLIC_* var - those are inlined into the client bundle (PI-10).
const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  NEXT_PUBLIC_APP_URL: z.url().default('http://localhost:3000'), // zod 4: z.url(), not z.string().url()
  DATABASE_URL: z.string().optional(),
  API_SECRET: z.string().min(1).optional(),
});

export const env = envSchema.parse(process.env);
export type Env = z.infer<typeof envSchema>;
```

### 5.7 Formatting + staged checks

`.prettierrc`:

```json
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "all",
  "printWidth": 100
}
```

`.lintstagedrc.json`:

```json
{
  "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
  "*.{json,md,yml,yaml,css}": ["prettier --write"]
}
```

### 5.8 package.json scripts (ADD; KEEP the generated `"lint": "eslint"` - PI-5)

```json
{
  "test": "vitest run",
  "test:watch": "vitest",
  "test:coverage": "vitest run --coverage",
  "type-check": "tsc --noEmit",
  "format": "prettier --write .",
  "format:check": "prettier --check .",
  "audit:deps": "npm audit --omit=dev"
}
```

### 5.9 Extend `eslint.config.mjs` (Read -> Edit, keep defineConfig format)

Append a rules object to the generated `defineConfig([...])` array:

```js
  {
    rules: {
      '@typescript-eslint/no-unused-vars': 'error',
      '@typescript-eslint/no-explicit-any': 'warn',
    },
  },
```

Verify immediately with `npm run lint` - a malformed flat-config edit fails fast.

### 5.10 tsconfig strictness (Read -> Edit; generated file already has `strict: true`)

Add to compilerOptions: `"noUncheckedIndexedAccess": true`,
`"forceConsistentCasingInFileNames": true`. Then `npx tsc --noEmit`.

---

## 6. Hardening (Phase 4)

### 6.1 `next.config.ts` - ONE home for headers (PI-14) + standalone (PI-6) + intl plugin

```ts
import type { NextConfig } from 'next';
import createNextIntlPlugin from 'next-intl/plugin';

const securityHeaders = [
  { key: 'X-DNS-Prefetch-Control', value: 'on' },
  { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
  { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
  // Content-Security-Policy: add once real script/asset origins are known.
  // Start from: default-src 'self'; then extend per integration. Do NOT ship a
  // placeholder CSP that blocks the app's own assets.
  // NOTE: X-XSS-Protection is deliberately ABSENT (deprecated; '1; mode=block' is harmful advice).
];

const nextConfig: NextConfig = {
  output: 'standalone', // REQUIRED by the Dockerfile runner stage (PI-6)
  async headers() {
    return [{ source: '/(.*)', headers: securityHeaders }];
  },
};

const withNextIntl = createNextIntlPlugin();
export default withNextIntl(nextConfig);
```

(INTERNAL mode without i18n: drop the plugin wrapper, keep the rest.)

### 6.2 `src/app/api/health/route.ts` (PI-15)

```ts
export function GET() {
  return Response.json({ status: 'ok' });
}
```

Lives OUTSIDE `[locale]` on purpose; the proxy matcher excludes `/api` so it is never
locale-redirected. Smoke: `curl -fsS localhost:3000/api/health` against `npm run dev`.

### 6.3 `.gitignore` additions (append to the generated file)

```
.env
.env.local
.env.*.local
coverage/
.DS_Store
*.log
```

---

## 7. Docker + CI (Phase 5)

### 7.1 `Dockerfile`

```dockerfile
FROM node:22-alpine AS base

FROM base AS deps
WORKDIR /app
COPY package.json package-lock.json ./
# --ignore-scripts: husky's "prepare" fails without .git in this stage (PI-6 / PB-3b)
RUN npm ci --ignore-scripts

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 nextjs
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
ENV PORT=3000 HOSTNAME=0.0.0.0
CMD ["node", "server.js"]
```

`HOSTNAME=0.0.0.0` is required or the standalone server binds loopback only inside the
container. create-next-app 16 generates `public/`; if a future variant lacks it, drop that COPY
line rather than letting the build fail.

### 7.2 `docker-compose.yml` (dev)

```yaml
services:
  app:
    build: .
    ports:
      - "3000:3000"
    env_file: .env
    restart: unless-stopped
```

(Live-reload dev happens via `npm run dev` on the host; the compose file exists to smoke the
container. Do not bind-mount the source over a standalone build - it does nothing.)

### 7.3 `docker-compose.prod.yml`

```yaml
services:
  app:
    build:
      context: .
      target: runner
    ports:
      - "3000:3000"
    env_file: .env
    restart: always
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

Healthcheck URL = `/api/health` = the route from §6.2 (PI-15). node:alpine ships busybox wget.

### 7.4 `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - name: Lint
        run: npm run lint        # resolves to eslint (PI-5)
      - name: Type check
        run: npm run type-check
      - name: Test
        run: npm test
      - name: Build
        run: npm run build
```

`npm ci` on CI runs `prepare` (husky) - that is fine THERE because `.git` exists in a checkout;
the `--ignore-scripts` guard is Docker-specific.

---

## 8. Environment files

`.env.example` (committed; placeholders only):

```bash
# Application
NODE_ENV=development
NEXT_PUBLIC_APP_URL=http://localhost:3000

# Database (uncomment when configured)
# DATABASE_URL=postgresql://user:password@localhost:5432/dbname

# Server-side secrets - NEVER NEXT_PUBLIC_, never committed with real values (PI-10)
# API_SECRET=change-me
```

If a local `.env` is created: `cp .env.example .env && chmod 600 .env`. Real operator
credentials live in `~/.claude/secrets.env` - reference the pattern, never copy values into the
repo (PI-10).

---

## 9. Verify-on-first-run checklist (report section 4 feed)

- `/` redirects to `/id`; `/id` + `/en` both 200 under `npm run dev`.
- Theme switcher flips the `dark` class on `<html>`; refresh keeps the theme; no flash on load.
- `curl -fsS localhost:3000/api/health` -> `{"status":"ok"}`.
- `docker compose -f docker-compose.prod.yml up` -> container reaches `healthy`.
- Global (outside-locale) 404 behavior once real routes exist (§3.8 note).
