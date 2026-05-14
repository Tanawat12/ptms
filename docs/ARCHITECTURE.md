# PTMS — Architecture Decisions Record

**Date:** 2026-05-13
**Status:** Draft for Tanawat's review

This document records the major architecture decisions for the new PTMS SaaS, the alternatives considered, and the trade-offs. Each section is short on purpose — designed for a 1-hour discussion when you wake up.

---

## 1. Stack overview

| Layer | Choice | Why |
|---|---|---|
| Frontend | **Next.js 15 (App Router) + React 19 + TypeScript** | Industry standard, hires easily, free on Vercel |
| UI | **Tailwind CSS + shadcn/ui** | Matches the prototype design system; copy-paste components |
| Backend | **Next.js API routes + Supabase Edge Functions** | Same repo, no separate server; serverless = free tier scales |
| Database | **Supabase Postgres** | Free tier 500MB, scales to enterprise; managed; built-in auth |
| Auth | **Supabase Auth** | Email/password + OAuth (Google, Microsoft for B2B), magic links |
| File storage | **Supabase Storage** | Photos, WI attachments, evidence; signed URLs; CDN included |
| Realtime | **Supabase Realtime** | Free for instant notifications (skill expiry, approvals) |
| Email | **Resend** | Free 100/day; modern API; React Email templates |
| Background jobs | **Supabase Edge Functions + pg_cron** | Skill expiry scans, daily reports — runs in Postgres |
| Search | **Postgres `pg_trgm`** at first, **Meilisearch** if we outgrow it | Postgres handles 50K rows fine; switch only when needed |
| Hosting | **Vercel** (frontend) + **Supabase Cloud** (backend) | Both have generous free tiers; auto-deploy from GitHub |
| Observability | **Vercel Analytics + Sentry** | Free tiers; minimum needed for production |
| Domain | Buy a `.com`, point at Vercel | Free SSL, custom domain |

**Total monthly cost at launch:** ~$0 (until first paying customer)

**When we'll need to pay:**
- Supabase: $25/month "Pro" plan when DB > 500 MB OR > 50K MAU (around 20+ tenants)
- Vercel: $20/month "Pro" plan when bandwidth > 100GB/month (likely never for B2B SaaS)
- Resend: $20/month when emails > 100/day (when ~10+ active tenants)
- Domain: $15/year

---

## 2. Why Next.js over alternatives

**Alternatives considered:**
| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Next.js** ✅ | Free Vercel hosting, RSC, App Router, huge ecosystem, easy hiring | Steeper learning curve for first build | **Chosen** |
| Remix / React Router 7 | Cleaner forms model | Smaller ecosystem | Pass |
| SvelteKit | Lighter, faster | Smaller pool of Thai devs | Pass |
| Plain React (CRA / Vite) | Simple | No SSR, harder SEO, no built-in API | Pass |
| Laravel / Rails | Battle-tested ORM, admin tooling | Need separate frontend + server hosting | Pass (cost) |
| ASP.NET Core | Familiar (since legacy is ASP) | Hosting more expensive, smaller free tier | Pass |

**Why Next.js wins for us:**
- One repo, one deploy
- Server components reduce JS sent to slow factory tablets
- Free Vercel tier matches Supabase free tier
- TypeScript + Prisma/Drizzle = no SQL injection (vs legacy ASP)

---

## 3. Why Supabase over alternatives

**Alternatives considered:**
| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Supabase** ✅ | Postgres + Auth + Storage + Realtime in one; generous free tier; RLS for multi-tenancy | Vendor lock-in on auth | **Chosen** |
| Neon / Vercel Postgres + Clerk + UploadThing | Best-of-breed | 3 vendors, 3 bills, more glue code | Pass |
| AWS (RDS + Cognito + S3) | Enterprise-ready | Steep learning curve, no free tier worth using | Pass |
| Firebase | Easy start | NoSQL doesn't fit our relational data | Pass (data model) |
| PocketBase / Self-hosted | Free forever | I'd manage the server; bad for SaaS uptime | Pass |

**Killer feature: Postgres Row Level Security (RLS) = multi-tenancy enforced at DB level**, not in app code. This is the safest way to do SaaS isolation.

---

## 4. Multi-tenancy strategy

**Decision: Shared schema, single database, RLS-enforced isolation.**

- All business tables have a `tenant_id` column.
- RLS policies enforce: `tenant_id in (select tenant_ids_for_current_user())`.
- Cross-tenant data leakage is **impossible** at the DB level, even if app code has a bug.

**Alternatives considered:**
| Pattern | Verdict |
|---|---|
| **Shared DB, shared schema, RLS** ✅ | Lowest ops cost, best free-tier fit, secure if RLS is right |
| Shared DB, schema-per-tenant | Postgres limits hit at ~50 tenants; harder migrations |
| DB-per-tenant | Too expensive; can't run on free tier |

**Scaling escape hatches** (later, when we have 50+ tenants):
- Move large/noisy tenants to dedicated DBs
- Add read replicas via Supabase
- Cache hot reads in Vercel Edge KV

---

## 5. Authentication & roles

**Decision: Supabase Auth + custom roles per tenant.**

- Email/password to start, magic-link option for factories with poor email habits.
- OAuth: Google for tenant admins (for SSO with Workspace).
- Microsoft 365 SSO for enterprise tier — adds $$$.

**Identity model:**
- One `auth.users` row per real human.
- `profiles` extends with our app-specific fields.
- `tenant_members` links a user to one or more tenants.
- `tenant_member_roles` assigns roles (Admin, Trainer, Quality, etc.) per tenant.

**Why this works:**
- A consultant could belong to 5 tenants — clean.
- An employee in one tenant only — still clean.
- Permissions are RBAC: roles → permissions → checked in app + DB.

---

## 6. Frontend architecture

```
app/
├─ (marketing)/           ← public landing pages, login, signup
├─ (app)/[tenant_slug]/   ← authenticated app, URL-scoped to tenant
│   ├─ dashboard/         ← role-based dashboard
│   ├─ employees/
│   ├─ subcontract/       ← Bluemat
│   ├─ work-instructions/
│   ├─ skill-matrix/
│   ├─ training/
│   ├─ defects/
│   ├─ ppe/
│   ├─ assessment/        ← annual JD review
│   ├─ recruitment/       ← v2
│   └─ settings/
├─ (owner)/owner/         ← Super Owner (you, Tanawat) panel
│   ├─ tenants/
│   ├─ billing/
│   └─ system/
└─ api/                   ← API routes (only for things that can't be RLS-direct)
```

**Routing:** `app.ptms.io/meyer-cap/skill-matrix` → tenant scope embedded in URL.
This makes deep-links shareable + clear for users + easy to revoke (drop tenant access → can't access URLs).

---

## 7. Internationalization (i18n)

**Decision: English + Thai bilingual; per-user language preference.**

- DB columns: `name_en` and `name_th` for catalog data (WIs, PPE, tools, defects).
- UI labels: `next-intl` library with `en.json` and `th.json`.
- User profile stores `preferred_locale` ('en' or 'th').
- Tenant-level default in `tenants.default_locale`.

**Future:** Add other Southeast Asian languages (Vietnamese, Indonesian, Burmese) when expanding.

---

## 8. Mobile & offline

**Decision: Responsive web first; PWA second; native app deferred.**

- Trainers and quality leads need this on **shared tablets** on the factory floor.
- Employees may use **their own phones** for self-service (My Skills, My Training Due).
- The prototype already uses a responsive sidebar — keep that.
- **PWA** ("Add to Home Screen") for offline-capable basics:
  - View skill record (cached)
  - Mark attendance (queued, syncs when online)
  - View PPE issuance history
- Full native app (React Native / Capacitor) only when a customer asks AND will pay.

**Network considerations:** Factories often have spotty WiFi. Use SWR/React Query with stale-while-revalidate. All writes go through a queue with retry.

---

## 9. Data migration from legacy

**Decision: One-time CSV import per tenant; no live sync.**

- Tanawat (you) does this manually for the first paying customer (MEYERCAP themselves, or another factory):
  1. Export 73 Excel sheets → CSV files
  2. Run a one-shot migration script per tenant
  3. Manual cleanup of edge cases
- After v1 launch, **new tenants start fresh** — no legacy baggage.
- Long-term: build a CSV self-import tool for new customers.

---

## 10. Security baseline

| Concern | Decision |
|---|---|
| Password storage | Supabase Auth handles (bcrypt, salt) |
| SQL injection | Drizzle ORM (parameterized) + RLS double protection |
| XSS | React escapes by default; no `dangerouslySetInnerHTML` for user content |
| CSRF | Next.js Server Actions + same-origin cookies |
| Sensitive PII | citizen_id encrypted with `pgcrypto`, masked in queries |
| Photo URLs | Supabase Storage signed URLs (expire in 1 hour) |
| Audit log | Every state-changing action writes to `audit_log` |
| Backups | Supabase Pro = daily PITR; for free tier we'll do weekly manual exports |
| HTTPS | Vercel + Supabase = automatic |
| 2FA | TOTP via Supabase Auth (Pro feature, enable when MRR > $500) |

---

## 11. What we are NOT doing in v1

Listed explicitly so we don't drift:

- ❌ Native mobile apps (responsive web only)
- ❌ Offline-first sync engine (PWA caching only)
- ❌ Real-time WebSocket collaboration (use polling/SWR)
- ❌ Custom report builder (predefined templates only)
- ❌ White-label theming per tenant (just logo + accent color)
- ❌ Full recruitment ATS UI (schema exists, UI is v2)
- ❌ Performance management beyond annual JD assessment
- ❌ Payroll integration (out of scope; export-only)
- ❌ Time-clock integration (manual attendance + import)
- ❌ AI features (we add later, only if customers ask)

---

## 12. Decisions locked in (2026-05-14, with Tanawat)

1. **Pricing model:** ✅ **LOCKED** — Per-active-worker (employees + subcontract together) at **99 THB / ~$3 USD per worker per month**.
   Example: 1,000-worker factory = **99,000 THB ($3,000 USD) per month** = $36,000 USD ARR per customer.
2. **Bluemat** = separate `subcontract_workers` table (different lifecycle from employees). ✅ Locked.
3. **RAD scale** = locked enum 0/1/2 (the differentiator). Per-tenant level naming added if requested. ✅ Locked.
4. **JD Assessment** = fixed 6 dimensions (Purpose / JC / KR / CS / LC / LP) for v1. Configurable in v2. ✅ Locked.
5. **Build order** = Sprints 0 → 12 as drafted. ✅ Locked.

## 12b. Open questions still to decide
1. **First customer:** Is it MEYERCAP themselves? If yes, do they pay or is it a freebie for being the design partner?
2. **Branding:** Keep the prototype's pastel grey + blue, or do you want to rebrand?
3. **Domain name:** Have you bought a `.com` yet? My suggestion: something short like `ptms.app` or `mptms.io` — I can research available domains if you want.
4. **Beta customers:** Do you have 2-3 factories lined up to be early adopters? If yes, we should design with their feedback in the loop.

---

## 13. Build plan (high level)

| Sprint (~1 week each) | Deliverable |
|---|---|
| Sprint 0 | Repo setup, Supabase project, schema migrated, Auth working |
| Sprint 1 | Tenant signup flow, profile, sidebar shell, owner panel skeleton |
| Sprint 2 | Employees CRUD, org structure, RBAC enforcement |
| Sprint 3 | Subcontract (Bluemat) full workflow — agencies, workers, attendance |
| Sprint 4 | Work Instructions builder (PPE + Tools + Defects + KRS) |
| Sprint 5 | Skill Matrix with RAD 3-level, certification flow, history |
| Sprint 6 | Training Records, multi-trainee, evidence upload |
| Sprint 7 | Defects log, PPE issuance log |
| Sprint 8 | Annual JD Assessment with 6 dimensions + Close the Gap |
| Sprint 9 | Notifications, reports, audit log polish |
| Sprint 10 | Billing (Stripe), tenant signup self-service |
| Sprint 11 | Beta with 2-3 customers; bug fixes |
| Sprint 12 | Launch v1 |

**That's ~3 months part-time, ~6 weeks full-time.**

After v1 launches and is paying, then v2 = recruitment full UI, advanced reporting, mobile app.

---

## 14. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Scope creep (legacy has 1000+ files of features) | Strict v1 list above; v2 is anything else |
| Slow factory WiFi | PWA caching, optimistic UI, queued writes |
| Single customer pulls in many directions | Charter: 3 beta customers minimum before locking down v1 |
| Schema gaps discovered late | Excel review tomorrow will catch most |
| Tanawat burns out solo | Hire a Thai-speaking part-time dev for sprint 4+ |

---

**End of architecture record.**

Read this, push back where you disagree, and let's lock it in.
