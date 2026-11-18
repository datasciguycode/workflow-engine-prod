# Progress (PROD)

- **This is the production instance**, cloned from dev (`datasciguycode/workflow-engine`) on
  2026-11-07 per `plans/prod-instance-setup/final-plan.md` in the dev repo (that plan directory
  isn't part of this clone; read it in the dev repo for the full rationale/trail).
- **Prod identifiers:**
  - Supabase project: `workflow-engine-prod`, ref `tapguiosrjbdusqyhxqe`, org
    `swdeqnlbogugszsnyqlr` (same org as dev, region `us-west-2`), free tier.
  - GitHub repo: `datasciguycode/workflow-engine-prod`.
  - Pages URL: `https://datasciguycode.github.io/workflow-engine-prod/`.
  - Real account: "Falcon Auto and Performance" (id `10ce6464-48ba-4d17-be4b-485bae13934d`).
  - Test account: "Test Sandbox (not a real shop)" (id `582dfb24-8136-4fa3-a66f-b749e8bce612`,
    created 2026-11-18, `supabase/prod/create_test_account.sql`) — same job-workflow shape as
    Falcon Auto's, isolated from it by the app's existing account-membership RLS, so test jobs
    never show up for real mechanics. Owned by the same Google login used for Falcon Auto; no
    second sign-in needed.
- **Status as of 2026-11-18: feature-parity with dev, minus Nutrition Tracker.** Dev and prod
  had diverged in both directions after launch; a review this session found every "prod-only"
  feature previously listed here (Job #N numbering, search, Notes, per-job chat scoping,
  `agent_events` telemetry, the agent wrong-job fix, layout fixes) had already been hand-ported
  to dev without this file being updated — so dev's codebase was a strict superset of prod's.
  Ported from dev to prod this session: per-stage optional checklist fields, a VIN photo
  scanner (new `scan-vin` function + Diagnosis checklist field), the generic per-workflow
  Report engine (`report_config`/`report_series`/`WorkflowReport.razor`), and the move_stage
  backward-move fix. `WorkflowDetail.razor`, `WorkflowApiClient.cs`, and `agent-loop` were
  replaced wholesale with dev's versions (confirmed strict supersets), keeping only prod's own
  Supabase config/branding. **Deliberately not ported:** Nutrition Tracker workflow and
  `scan-plate` — dev-only scaffolding proving the engine is workflow-agnostic, not something
  Falcon Auto needs; stays dev-only per user decision.
- **Divergences from dev (keep on every merge from `dev-upstream`):**
  - `project_id = "workflow-app-prod"` in `supabase/config.toml` — permanent. Prevents local
    Supabase lifecycle commands (`start`/`stop`/`db reset --local`) from acting on dev's
    containers, which are named by `project_id`, not by directory.
  - `SupabaseConfig.ApiUrl`/`PublishableKey` in `web/Services/WorkflowApiClient.cs` — permanent
    until the deferred config-indirection work lands. **The single worst failure mode**: a merge
    that silently overwrites this back to dev's values would make prod read/write dev's data.
    Always re-check this file after merging, before pushing.
  - The two D1 storage-key edits (`AuthState.StorageKey` derived from `SupabaseConfig.ApiUrl`;
    `index.html`'s `buildCheckDone:` key derived from `document.baseURI`).
  - `supabase/prod/` (bootstrap.sql, add_member.sql, create_test_account.sql) — prod-only, dev
    never has these.
  - `.github/workflows/keep-alive.yml` and `supabase/prod/last-keepalive.txt` — prod-only (dev's
    project doesn't need a keep-alive; see below).
  - This file and the prod header at the top of `CLAUDE.md`.
  - Nutrition Tracker workflow + `scan-plate` function — dev-only, not ported (see above).
- **Merging from dev-upstream:** `git fetch dev-upstream && git merge dev-upstream/main`.
  `PROGRESS.md` (this file) will conflict on every merge since both repos rewrite it — resolve
  with `git checkout --ours PROGRESS.md`. After any merge, before pushing, re-run:
  - `grep -rn utwyvtbzesswpoihmlic web/` → must print nothing.
  - `grep -n '^project_id' supabase/config.toml` → must still show `workflow-app-prod`.
  - `grep -n StorageKey web/Services/AuthState.cs` → must still show the derived form, not a
    literal.
  - Given the history above, prefer porting features deliberately (as this session did) over a
    bulk merge — dev and prod have both carried independent work before.
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
  `create_test_account.sql` is re-runnable as-is (upserts); it only needs editing if you want a
  different test account's shape or a different owner email.
- **Keep-alive:** `.github/workflows/keep-alive.yml` pings prod's Supabase REST endpoint every 3
  days (free tier auto-pauses after ~7 days idle) and commits a timestamp to
  `supabase/prod/last-keepalive.txt`, which resets GitHub's own 60-day scheduled-workflow-disable
  clock. If that timestamp goes stale (>6 days), check `gh run list --workflow=keep-alive.yml`
  for a failure (most likely cause: branch protection blocking the commit step's push).
- **Deploy paths** (same two-path pattern as dev):
  - App/UI: push to `main` → `.github/workflows/deploy-pages.yml` → Pages.
  - Functions: `supabase functions deploy <name> --project-ref tapguiosrjbdusqyhxqe --use-api`
    (always `--use-api`, always name the function explicitly, never a bare `functions deploy`
    with no name — see CLAUDE.md). Currently deployed: `agent-loop`, `scan-vin`, `mcp-server`.
- **Out of scope for now:** config indirection, an admin UI for accounts/members, a custom
  domain, migrating dev's real data, prod operations (backups/monitoring), scheduling
  visibility as an agent tool, an upcoming-appointments list on the intake screen (separate
  from the Scheduling-stage one), making this repo private (needs GitHub Pro), an Anthropic
  spend alert (Console-side, not code), and job assignment/claiming (including at intake) for
  multiple workers sharing one account's job queue.

## Next concrete step

Live smoke test on the deployed Pages site, using the Test Sandbox account: create a job, move
it through Diagnosis and confirm the VIN checklist item + Scan VIN button appear, confirm the
hide-closed toggle and Other Appointments list render, exercise chat on an open job and confirm
it still resolves the right job.
