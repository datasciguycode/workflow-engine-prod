# Progress (PROD)

- **This is the production instance**, cloned from dev (`datasciguycode/workflow-engine`) on
  2026-11-07 per `plans/prod-instance-setup/final-plan.md` in the dev repo (that plan directory
  isn't part of this clone; read it in the dev repo for the full rationale/trail).
- **Prod identifiers:**
  - Supabase project: `workflow-engine-prod`, ref `tapguiosrjbdusqyhxqe`, org
    `swdeqnlbogugszsnyqlr` (same org as dev, region `us-west-2`), free tier.
  - GitHub repo: `datasciguycode/workflow-engine-prod` (to be created in Step 6).
  - Pages URL: `https://datasciguycode.github.io/workflow-engine-prod/`.
  - Account: "Falcon Auto and Performance" (same stage shape as dev's "Joe's Auto Repair",
    renamed per user decision 2026-11-07).
- **Divergences from dev (keep on every merge from `dev-upstream`):**
  - `project_id = "workflow-app-prod"` in `supabase/config.toml` — permanent. Prevents local
    Supabase lifecycle commands (`start`/`stop`/`db reset --local`) from acting on dev's
    containers, which are named by `project_id`, not by directory.
  - `SupabaseConfig.ApiUrl`/`PublishableKey` in `web/Services/WorkflowApiClient.cs` — permanent
    until the deferred config-indirection work lands. **The single worst failure mode**: a merge
    that silently overwrites this back to dev's values would make prod read/write dev's data.
    Always re-check this file after merging, before pushing.
  - The two D1 storage-key edits (`AuthState.StorageKey` derived from `SupabaseConfig.ApiUrl`;
    `index.html`'s `buildCheckDone:` key derived from `document.baseURI`) — these are
    upstreamable to dev unchanged whenever convenient (dev users get signed out once when it
    happens); until then they're a divergence only because dev still has the old literal keys.
  - `supabase/prod/` (bootstrap.sql, add_member.sql) — prod-only, dev never has these.
  - `.github/workflows/keep-alive.yml` and `supabase/prod/last-keepalive.txt` — prod-only (dev's
    project doesn't need a keep-alive; see below).
  - This file and the prod header at the top of `CLAUDE.md`.
  - The A2 fallback in `supabase/functions/agent-loop/index.ts`, if it was ever applied (see
    plan's Risks section) — record here if so.
- **Merging from dev-upstream:** `git fetch dev-upstream && git merge dev-upstream/main`.
  `PROGRESS.md` (this file) will conflict on every merge since both repos rewrite it — resolve
  with `git checkout --ours PROGRESS.md`. After any merge, before pushing, re-run:
  - `grep -rn utwyvtbzesswpoihmlic web/` → must print nothing.
  - `grep -n '^project_id' supabase/config.toml` → must still show `workflow-app-prod`.
  - `grep -n StorageKey web/Services/AuthState.cs` → must still show the derived form, not a
    literal.
- **Adding a prod member:** person signs into prod once via Google (creates their `auth.users`
  row with no access yet), then:
  ```bash
  sed -e "s/__EMAIL__/their@email.com/" -e "s/__ROLE__/member/" -e "s/__DISPLAY_NAME__/Their Name/" \
      supabase/prod/add_member.sql > /tmp/add_member.run.sql
  grep -n "__" /tmp/add_member.run.sql   # must print nothing
  supabase db query --project-ref tapguiosrjbdusqyhxqe -f /tmp/add_member.run.sql
  rm /tmp/add_member.run.sql
  ```
  `role` is `owner` or `member`. Expect 1 row back; 0 means they haven't signed in yet or are
  already a member. Never edit `add_member.sql` itself — the `__PLACEHOLDERS__` stay as a
  template; `git checkout -- supabase/prod/add_member.sql` if it's ever accidentally modified.
- **Keep-alive:** `.github/workflows/keep-alive.yml` pings prod's Supabase REST endpoint every 3
  days (free tier auto-pauses after ~7 days idle) and commits a timestamp to
  `supabase/prod/last-keepalive.txt`, which resets GitHub's own 60-day scheduled-workflow-disable
  clock. If that timestamp goes stale (>6 days), check `gh run list --workflow=keep-alive.yml`
  for a failure (most likely cause: branch protection blocking the commit step's push).
- **Deploy paths** (same two-path pattern as dev):
  - App/UI: push to `main` → `.github/workflows/deploy-pages.yml` → Pages.
  - Agent: `supabase functions deploy agent-loop --project-ref tapguiosrjbdusqyhxqe --use-api`
    (always `--use-api`, never a bare `functions deploy` with no name — see CLAUDE.md).
- **Status as of 2026-11-07:** project created, migrations replayed (all 12, grants verified to
  match dev's exact 19-grant/`authenticated`-only surface after discovering and fixing a
  fresh-project default-privilege discrepancy), code edits in progress. Not yet live — Google
  OAuth setup (dashboard, needs the user), repo creation + Pages enablement, agent-loop deploy,
  and bootstrap data are still ahead. See the plan for the full step list and verification
  checklist before calling this live.
- **Out of scope for now** (see the plan's "Out of scope" section for the full list and why):
  config indirection, an admin UI for accounts/members, a custom domain, photo-to-field
  extraction (e.g. VIN from a photo), migrating dev's real data, prod operations
  (backups/monitoring).
