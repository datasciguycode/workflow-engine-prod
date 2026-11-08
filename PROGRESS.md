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
  - **All UI/agent feature work landed here since launch** (job numbering, Other Appointments,
    the agent job-grounding fix, per-job chat scoping, Notes section, the two layout fixes —
    see "Status" below for the full list) — not yet ported to dev. This is a large, real
    divergence; a `dev-upstream` merge won't bring any of it in, since dev doesn't have it
    either. Port deliberately (feature by feature) rather than via merge when the time comes.
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
- **Status as of 2026-11-08: live, verified, and actively iterated on.** Launched 2026-11-07
  (migrations replayed, grants fixed to match dev exactly, OAuth configured, repo/Pages live,
  `agent-loop` deployed, bootstrap data in, full verification checklist passed). Since launch,
  substantial UI and agent work has landed here first and **not yet been ported to dev**:
  - A stable, permanent "Job #N" number (`WorkflowDetail.razor`'s `JobNumber`, ranked by
    `created_at` ascending), shown on the Jobs list, job overview, stage view heading, and
    the Other Appointments list. Required adding `CreatedAt` to `ItemSummary` and the
    `items` REST select (`WorkflowApiClient.GetItemsAsync`).
  - An "Other Appointments" list on the Scheduling stage view (any stage whose checklist
    includes `scheduled_at`): next 10 other jobs with a parseable date, excludes the job
    being viewed.
  - **A real agent bug, found via live testing, fixed in `supabase/functions/agent-loop`:**
    with the full unscoped conversation history, the agent could write a value onto a
    different, more-recently-discussed job instead of the one open in the UI. Fixed with:
    `item_id` now optional on `move_stage`/`update_data`/`add_note` (server resolves it to
    `selected_item_id` when omitted, not the model's guess); a much more forceful system-prompt
    reminder of which job is open, including its stable number; and the "other jobs" queue is
    now only sent when no job is open — while one is drilled into, the agent has zero
    visibility into any other job (closes off future same-name-customer collisions, e.g. two
    different "Bob"s, at the source rather than relying on the model to disambiguate).
  - Per-job Claude conversation scoping: one message history per job
    (`_messagesByJob` in `WorkflowDetail.razor`, keyed by item id) instead of one array for
    the whole session — bounds token cost per request to the open job's own activity.
    Deliberately not scoped further to per-stage (cross-stage memory within a job was judged
    more valuable than the extra savings).
  - A Notes section on the job overview page, reading back every `add_note` call (previously
    write-only — the RPC/tool existed, nothing displayed it). New
    `WorkflowApiClient.GetNotesAsync` + `ItemNote` record. Paired with a soft prompt nudge:
    past 5 of the user's own messages in one job+stage, the agent is told to prefer
    `add_note` over continuing to just talk about something.
  - Two layout fixes: `.page-header-chat` centering, and a page-root `overflow-x: hidden`
    backstop (text was running off the right edge instead of wrapping).
  **Porting to dev:** none of this has been merged back yet. The agent-grounding fix in
  particular is a real correctness bug that very likely exists in dev's `agent-loop` too,
  just unconfirmed/untriggered so far — worth prioritizing if dev work resumes.
- **Out of scope for now** (see the plan's "Out of scope" section for the full list and why,
  plus several more deferred ideas raised during 2026-11-07/08 testing): config indirection,
  an admin UI for accounts/members, a custom domain, photo-to-field extraction (e.g. VIN from
  a photo), migrating dev's real data, prod operations (backups/monitoring), scheduling
  visibility as an agent tool, an upcoming-appointments list on the intake screen (separate
  from the Scheduling-stage one above), making this repo private (needs GitHub Pro), an
  Anthropic spend alert (Console-side, not code), and job assignment/claiming (including at
  intake) for multiple workers sharing one account's job queue.
