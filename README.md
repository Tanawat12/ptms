# PTMS — Production Training Management System

Prototype UI for a multi-tenant SaaS for factory production training management.

**Status:** UI prototype only — all data is mock. No real backend or database yet.

## Open locally

Just double-click `index.html`. Works in any modern browser. No build step.

## Deploy to Vercel (free)

### Option 1 — CLI (fastest, ~2 minutes)

```bash
npm i -g vercel
cd deploy
vercel
```

Follow the prompts. Vercel will give you a URL like `ptms-xxx.vercel.app`.

### Option 2 — GitHub + Vercel dashboard (recommended for production)

1. Create a new GitHub repo (e.g. `ptms`)
2. Push this folder to it
3. Go to https://vercel.com/new
4. Import the repo — Vercel auto-detects the static site
5. Click "Deploy"
6. Every `git push` after this auto-deploys

### Custom domain

After deploy, in Vercel dashboard:
1. Project Settings → Domains → Add
2. Enter your `.com` domain
3. Vercel shows you the DNS records to add at your registrar
4. SSL cert is automatic

## What's in the prototype

- 6 user roles (Super Owner, Client Admin, Trainer, Quality, Safety, Employee)
- Login + mock 2FA
- Owner dashboard, client onboarding wizard, billing
- Org structure tree, users, roles & permissions matrix
- Employee directory with detail modal (5 tabs)
- Subcontractors + vendor management
- Work Instruction builder (8 sections: Info, Pre-inspection, PPE, Tools, Tasks, Defects, Post-inspection, KRS)
- Skill matrix (employees × WIs, click any cell)
- Skill expiry alerts
- Defects log, PPE log
- Reports library
- Audit log
- Employee self-service view

State persists in localStorage (role + screen) but mock data resets on refresh.

## What's NOT in the prototype (next phase)

- Real authentication
- Database persistence
- Multi-tenant isolation
- API / backend
- Email notifications
- File uploads
- Stripe billing
- Background workers (skill expiry scan)
