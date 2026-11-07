-- TEMPLATE. Don't run directly and don't edit in place. See PROGRESS.md "Adding a prod member".
insert into public.account_members (account_id, user_id, role, display_name)
select '10ce6464-48ba-4d17-be4b-485bae13934d', id, '__ROLE__', '__DISPLAY_NAME__'
from auth.users where email = '__EMAIL__'
on conflict (account_id, user_id) do nothing
returning account_id, user_id, role;
