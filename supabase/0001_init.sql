-- VEYA — initial schema
-- Run in the Supabase SQL editor.
--
-- Security model: every table has RLS on, and access is decided by one
-- question — are you a member of this trip? The policies ARE the authorization
-- layer; the app talks to Postgres with the anon key plus the user's JWT.

-- ---------------------------------------------------------------------------
-- trips
-- ---------------------------------------------------------------------------
create table public.trips (
  id            uuid primary key default gen_random_uuid(),
  name          text not null default '',
  destination   text not null default '',
  start_date    date,
  end_date      date,
  -- planning -> active -> archived. Archived is what "wound down" means: it
  -- stays readable forever and stops appearing beside the trip you are
  -- planning next.
  status        text not null default 'planning'
                check (status in ('planning', 'active', 'archived')),
  created_by    uuid not null references auth.users (id) on delete cascade,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- who is on the trip
-- ---------------------------------------------------------------------------
create table public.trip_members (
  trip_id       uuid not null references public.trips (id) on delete cascade,
  user_id       uuid not null references auth.users (id) on delete cascade,
  -- Editor by default, deliberately. A group trip where only one person can
  -- add anything recreates the spreadsheet this exists to replace.
  role          text not null default 'editor'
                check (role in ('owner', 'editor', 'viewer')),
  display_name  text not null default '',
  joined_at     timestamptz not null default now(),
  primary key (trip_id, user_id)
);

-- Membership is checked by every other policy, and a policy on trip_members
-- that queries trip_members recurses forever. SECURITY DEFINER breaks the
-- loop: this function reads the table without re-entering RLS.
create or replace function public.is_trip_member(check_trip_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.trip_members
    where trip_id = check_trip_id and user_id = auth.uid()
  );
$$;

create or replace function public.is_trip_owner(check_trip_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.trip_members
    where trip_id = check_trip_id and user_id = auth.uid() and role = 'owner'
  );
$$;

-- ---------------------------------------------------------------------------
-- items — the central object. Created while planning, changed during the
-- trip, read back afterwards. It is never copied into another record.
-- ---------------------------------------------------------------------------
create table public.items (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references public.trips (id) on delete cascade,
  day           date not null,
  -- null means "some time that day", which is a different promise from 09:40
  -- and should look different on screen.
  starts_at     timestamptz,
  title         text not null default '',
  detail        text not null default '',
  -- "if there's time". Plans should degrade gracefully rather than fail.
  is_optional   boolean not null default false,
  status        text not null default 'planned'
                check (status in ('planned', 'done', 'skipped', 'moved')),
  -- Added on the day rather than planned. The best parts of a trip are not on
  -- the itinerary, and most apps have nowhere to put them.
  was_off_plan  boolean not null default false,
  position      integer not null default 0,
  created_by    uuid references auth.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index items_trip_day on public.items (trip_id, day, position);

-- ---------------------------------------------------------------------------
-- stays
-- ---------------------------------------------------------------------------
create table public.stays (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references public.trips (id) on delete cascade,
  city          text not null default '',
  name          text not null default '',
  check_in      date,
  check_out     date,
  address       text not null default '',
  detail        text not null default '',
  amount        numeric(12, 2) not null default 0,
  currency      text not null default 'EUR',
  booked        boolean not null default false,
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- money
-- ---------------------------------------------------------------------------
create table public.expenses (
  id              uuid primary key default gen_random_uuid(),
  trip_id         uuid not null references public.trips (id) on delete cascade,
  amount          numeric(12, 2) not null default 0,
  currency        text not null default 'EUR',
  spent_on        date not null default current_date,
  merchant        text not null default '',
  note            text not null default '',
  paid_by         uuid references auth.users (id) on delete set null,
  -- What VEYA knows that a split app does not: the dinner this was.
  linked_item_id  uuid references public.items (id) on delete set null,
  created_at      timestamptz not null default now()
);

-- Who owes what. One row per person per expense; an even split is just equal
-- weights, so there is one code path rather than five.
create table public.expense_shares (
  expense_id    uuid not null references public.expenses (id) on delete cascade,
  user_id       uuid not null references auth.users (id) on delete cascade,
  weight        numeric(12, 4) not null default 1,
  primary key (expense_id, user_id)
);

-- ---------------------------------------------------------------------------
-- the booking checklist
-- ---------------------------------------------------------------------------
create table public.todos (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references public.trips (id) on delete cascade,
  title         text not null default '',
  url           text not null default '',
  done          boolean not null default false,
  position      integer not null default 0,
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Row level security. One rule, applied everywhere: you see a trip you are on.
-- ---------------------------------------------------------------------------
alter table public.trips          enable row level security;
alter table public.trip_members   enable row level security;
alter table public.items          enable row level security;
alter table public.stays          enable row level security;
alter table public.expenses       enable row level security;
alter table public.expense_shares enable row level security;
alter table public.todos          enable row level security;

create policy "trips_select" on public.trips
  for select using (public.is_trip_member(id));
create policy "trips_insert" on public.trips
  for insert with check (created_by = auth.uid());
create policy "trips_update" on public.trips
  for update using (public.is_trip_member(id)) with check (public.is_trip_member(id));
create policy "trips_delete" on public.trips
  for delete using (public.is_trip_owner(id));

create policy "members_select" on public.trip_members
  for select using (public.is_trip_member(trip_id));
-- The first member of a new trip is its creator adding themselves, when no
-- membership row exists yet; after that only an owner may add people.
create policy "members_insert" on public.trip_members
  for insert with check (
    user_id = auth.uid() or public.is_trip_owner(trip_id)
  );
create policy "members_delete" on public.trip_members
  for delete using (public.is_trip_owner(trip_id) or user_id = auth.uid());

create policy "items_all" on public.items
  for all using (public.is_trip_member(trip_id)) with check (public.is_trip_member(trip_id));
create policy "stays_all" on public.stays
  for all using (public.is_trip_member(trip_id)) with check (public.is_trip_member(trip_id));
create policy "expenses_all" on public.expenses
  for all using (public.is_trip_member(trip_id)) with check (public.is_trip_member(trip_id));
create policy "todos_all" on public.todos
  for all using (public.is_trip_member(trip_id)) with check (public.is_trip_member(trip_id));

create policy "shares_all" on public.expense_shares
  for all using (
    exists (select 1 from public.expenses e
            where e.id = expense_id and public.is_trip_member(e.trip_id))
  ) with check (
    exists (select 1 from public.expenses e
            where e.id = expense_id and public.is_trip_member(e.trip_id))
  );

-- ---------------------------------------------------------------------------
-- Live updates. This is what "everyone sees it immediately" actually is.
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table public.items;
alter publication supabase_realtime add table public.stays;
alter publication supabase_realtime add table public.expenses;
alter publication supabase_realtime add table public.todos;
alter publication supabase_realtime add table public.trips;
