-- Prod-only test sandbox. Run as postgres via:
--   supabase db query --project-ref tapguiosrjbdusqyhxqe -f supabase/prod/create_test_account.sql
-- Never part of migrations or seed.sql (must not replay into dev or local) -- same reasoning as
-- bootstrap.sql.
--
-- Purpose: a second account, isolated from "Falcon Auto and Performance" by the app's existing
-- account_members-based RLS (private.is_member/can_access_workflow -- see
-- 20261012035437_phase0_core_schema.sql), so test jobs never show up for the real mechanics.
-- Workflow/stage shape mirrors Falcon Auto's real job workflow (copied 2026-11-18) so testing
-- here exercises the same checklist/VIN-scan/move_stage paths realistically.
--
-- Re-runnable: account is insert-once; workflow/stages/membership are upserted.

insert into public.accounts (id, name) values
  ('582dfb24-8136-4fa3-a66f-b749e8bce612', 'Test Sandbox (not a real shop)')
  on conflict (id) do nothing;

insert into public.workflows (id, account_id, name, item_label) values
  ('aa8f33a6-a46e-4759-977d-8c35e5d6c102', '582dfb24-8136-4fa3-a66f-b749e8bce612', 'Test Sandbox', 'job')
  on conflict (id) do update set
    name = excluded.name,
    item_label = excluded.item_label;

insert into public.stages (id, workflow_id, title, sequence_order, is_initial, is_terminal, checklist, optional_checklist) values
  ('b9603031-7c85-4ed7-a690-b2a43cfd78e9', 'aa8f33a6-a46e-4759-977d-8c35e5d6c102', 'intake', 1, true, false,
    '["customer","phone","address","vehicle","description"]'::jsonb, '[]'::jsonb),
  ('31277b7f-f109-4d9a-8052-828fc7c91364', 'aa8f33a6-a46e-4759-977d-8c35e5d6c102', 'scheduling', 2, false, false,
    '["scheduled_at"]'::jsonb, '[]'::jsonb),
  ('f6b13296-2d98-490e-b838-c15c6b2acc5c', 'aa8f33a6-a46e-4759-977d-8c35e5d6c102', 'diagnosis', 3, false, false,
    '["diagnosis","parts_needed","vin"]'::jsonb, '["vin"]'::jsonb),
  ('5ff36865-d002-4248-98ce-8ccfec38050b', 'aa8f33a6-a46e-4759-977d-8c35e5d6c102', 'estimated', 4, false, false,
    '["estimate_amount","estimated_completion"]'::jsonb, '[]'::jsonb),
  ('59ddd767-7b01-4790-8f5e-8304505a80da', 'aa8f33a6-a46e-4759-977d-8c35e5d6c102', 'approval', 5, false, false,
    '["approved"]'::jsonb, '[]'::jsonb),
  ('72a93e6f-0a65-44fe-bb86-01fe34e3949e', 'aa8f33a6-a46e-4759-977d-8c35e5d6c102', 'in_progress', 6, false, false,
    '["technician","work_started_at"]'::jsonb, '[]'::jsonb),
  ('96ec2c6f-3811-4a23-b8f5-12bffe245513', 'aa8f33a6-a46e-4759-977d-8c35e5d6c102', 'invoicing', 7, false, false,
    '["invoice_amount","invoice_number"]'::jsonb, '[]'::jsonb),
  ('18a3855b-6e01-480e-8314-3e8f35a674d1', 'aa8f33a6-a46e-4759-977d-8c35e5d6c102', 'payment_receipt_submitted', 8, false, true,
    '["payment_method","receipt_number"]'::jsonb, '[]'::jsonb),
  ('e30e34b3-6feb-4239-8c02-318f59689906', 'aa8f33a6-a46e-4759-977d-8c35e5d6c102', 'closed', null, false, true,
    '["closed_at"]'::jsonb, '["closed_at"]'::jsonb)
  on conflict (id) do update set
    title = excluded.title,
    sequence_order = excluded.sequence_order,
    is_initial = excluded.is_initial,
    is_terminal = excluded.is_terminal,
    checklist = excluded.checklist,
    optional_checklist = excluded.optional_checklist;

-- Owner access for the same account signed into Falcon Auto today (fly.data.sci.guy@gmail.com,
-- confirmed 2026-11-18 via auth.users) -- no second sign-in needed.
insert into public.account_members (account_id, user_id, role, display_name)
select '582dfb24-8136-4fa3-a66f-b749e8bce612', id, 'owner', 'Micah'
from auth.users where email = 'fly.data.sci.guy@gmail.com'
on conflict (account_id, user_id) do nothing;
