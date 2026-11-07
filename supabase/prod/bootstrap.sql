-- Prod-only bootstrap. Run as postgres via:
--   supabase db query --project-ref tapguiosrjbdusqyhxqe -f supabase/prod/bootstrap.sql
-- Never part of migrations or seed.sql (must not replay into dev or local).
-- Re-runnable: accounts are insert-once; workflows/stages are upserted, so edits here
-- take effect on re-run. Removing a stage from this file does NOT delete it; swapping
-- titles or moving is_initial needs hand-ordered updates (unique constraints).
--
-- Stage shape and checklists copied from dev's "Joe's Auto Repair" workflow
-- (33333333-3333-3333-3333-333333333330) via a read-only query, 2026-11-07 (plan U6/U5
-- option A). Account/workflow renamed per the user's decision (U4): "Falcon Auto and
-- Performance" instead of "Joe's Auto Repair".

insert into public.accounts (id, name) values
  ('10ce6464-48ba-4d17-be4b-485bae13934d', 'Falcon Auto and Performance')
  on conflict (id) do nothing;

insert into public.workflows (id, account_id, name, item_label) values
  ('5417783a-2182-4adb-8aa4-3f42897c68a2', '10ce6464-48ba-4d17-be4b-485bae13934d', 'Falcon Auto and Performance', 'job')
  on conflict (id) do update set
    name = excluded.name,
    item_label = excluded.item_label;

insert into public.stages (id, workflow_id, title, sequence_order, is_initial, is_terminal, checklist) values
  ('42333fe8-686a-4684-abd6-a079011ef392', '5417783a-2182-4adb-8aa4-3f42897c68a2', 'intake', 1, true, false,
    '["customer","phone","address","vehicle","description"]'::jsonb),
  ('60c9c82c-bf50-49c3-ac07-1f666c86be10', '5417783a-2182-4adb-8aa4-3f42897c68a2', 'scheduling', 2, false, false,
    '["scheduled_at"]'::jsonb),
  ('04d3e4ac-f1ef-473a-979d-dd6ed014b5e9', '5417783a-2182-4adb-8aa4-3f42897c68a2', 'diagnosis', 3, false, false,
    '["diagnosis","parts_needed"]'::jsonb),
  ('a868dd7f-ca97-427d-bd8f-d7715fd1e15c', '5417783a-2182-4adb-8aa4-3f42897c68a2', 'estimated', 4, false, false,
    '["estimate_amount","estimated_completion"]'::jsonb),
  ('b74b3469-5220-4ca1-be44-f117fff34992', '5417783a-2182-4adb-8aa4-3f42897c68a2', 'approval', 5, false, false,
    '["approved"]'::jsonb),
  ('6e3287e6-bff2-4d82-88fb-a1d98955de4f', '5417783a-2182-4adb-8aa4-3f42897c68a2', 'in_progress', 6, false, false,
    '["technician","work_started_at"]'::jsonb),
  ('350079cf-471f-4261-9e47-6492e7248c7a', '5417783a-2182-4adb-8aa4-3f42897c68a2', 'invoicing', 7, false, false,
    '["invoice_amount","invoice_number"]'::jsonb),
  ('ef1f7b61-105e-40df-af3c-6c17039a4636', '5417783a-2182-4adb-8aa4-3f42897c68a2', 'payment_receipt_submitted', 8, false, true,
    '["payment_method","receipt_number"]'::jsonb),
  ('8c1304bc-6fe8-4f94-a7d2-07359ecb9225', '5417783a-2182-4adb-8aa4-3f42897c68a2', 'closed', null, false, true,
    null)
  on conflict (id) do update set
    title = excluded.title,
    sequence_order = excluded.sequence_order,
    is_initial = excluded.is_initial,
    is_terminal = excluded.is_terminal,
    checklist = excluded.checklist;
