-- Project-based layer for multi-project diagnostic operations
-- Run after schema.sql

create extension if not exists pgcrypto;

-- 1) Project (admin creates multiple projects from one base test)
create table if not exists public.diagnostic_projects (
  id uuid primary key default gen_random_uuid(),
  test_id uuid not null references public.diagnostic_tests(id) on delete cascade,
  name text not null,
  slug text not null unique,
  description text,
  access_code text not null unique default encode(gen_random_bytes(8), 'hex'),
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_projects_test on public.diagnostic_projects(test_id);
create index if not exists idx_projects_creator on public.diagnostic_projects(created_by);

-- 2) Project member (admin/learner)
create table if not exists public.project_members (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.diagnostic_projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin', 'learner')),
  joined_at timestamptz not null default now(),
  unique (project_id, user_id)
);

create index if not exists idx_project_members_user on public.project_members(user_id);

-- 3) Optional whitelist for "A 그룹만 사용 가능"
-- Student can join only if their student_key is whitelisted for the project
create table if not exists public.project_student_whitelist (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.diagnostic_projects(id) on delete cascade,
  student_key text not null,
  memo text,
  created_at timestamptz not null default now(),
  unique (project_id, student_key)
);

-- 4) Project-specific question set
-- Clone from base questions, then admin can reorder/edit/deactivate per project
create table if not exists public.project_questions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.diagnostic_projects(id) on delete cascade,
  source_question_id uuid references public.diagnostic_questions(id) on delete set null,
  question_no int not null,
  section_name text,
  prompt text not null,
  stem text not null,
  explanation text,
  correct_choice_no smallint not null check (correct_choice_no between 1 and 5),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (project_id, question_no)
);

create table if not exists public.project_question_choices (
  id uuid primary key default gen_random_uuid(),
  project_question_id uuid not null references public.project_questions(id) on delete cascade,
  choice_no smallint not null check (choice_no between 1 and 5),
  content text not null,
  unique (project_question_id, choice_no)
);

create index if not exists idx_project_questions_project_no on public.project_questions(project_id, question_no);

-- 5) Project attempt (separated from global attempt)
create table if not exists public.project_attempts (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.diagnostic_projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'in_progress'
    check (status in ('in_progress', 'saved', 'submitted')),
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  remaining_seconds int not null default 2400,
  total_correct int not null default 0,
  total_score numeric(5,2) not null default 0
);

create index if not exists idx_project_attempts_project_user on public.project_attempts(project_id, user_id, started_at desc);

create table if not exists public.project_attempt_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.project_attempts(id) on delete cascade,
  project_question_id uuid not null references public.project_questions(id) on delete cascade,
  selected_choice_no smallint not null check (selected_choice_no between 1 and 5),
  is_correct boolean,
  answered_at timestamptz not null default now(),
  unique (attempt_id, project_question_id)
);

-- RLS
alter table public.diagnostic_projects enable row level security;
alter table public.project_members enable row level security;
alter table public.project_student_whitelist enable row level security;
alter table public.project_questions enable row level security;
alter table public.project_question_choices enable row level security;
alter table public.project_attempts enable row level security;
alter table public.project_attempt_answers enable row level security;

-- helper function: project membership check
create or replace function public.is_project_member(p_project_id uuid, p_user_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.project_members pm
    where pm.project_id = p_project_id
      and pm.user_id = p_user_id
  );
$$;

create or replace function public.is_project_admin(p_project_id uuid, p_user_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.project_members pm
    where pm.project_id = p_project_id
      and pm.user_id = p_user_id
      and pm.role = 'admin'
  );
$$;

-- projects: admin can fully manage, members can read
create policy "project_admin_full"
on public.diagnostic_projects
for all
to authenticated
using (created_by = auth.uid() or public.is_project_admin(id, auth.uid()))
with check (created_by = auth.uid() or public.is_project_admin(id, auth.uid()));

create policy "project_member_read"
on public.diagnostic_projects
for select
to authenticated
using (public.is_project_member(id, auth.uid()));

-- members: admin manage, member can read own membership
create policy "project_members_admin_manage"
on public.project_members
for all
to authenticated
using (public.is_project_admin(project_id, auth.uid()))
with check (public.is_project_admin(project_id, auth.uid()));

create policy "project_members_self_read"
on public.project_members
for select
to authenticated
using (user_id = auth.uid());

-- whitelist: admin only
create policy "project_whitelist_admin_manage"
on public.project_student_whitelist
for all
to authenticated
using (public.is_project_admin(project_id, auth.uid()))
with check (public.is_project_admin(project_id, auth.uid()));

-- project questions: members read, admin write
create policy "project_questions_member_read"
on public.project_questions
for select
to authenticated
using (public.is_project_member(project_id, auth.uid()) and is_active = true);

create policy "project_questions_admin_write"
on public.project_questions
for all
to authenticated
using (public.is_project_admin(project_id, auth.uid()))
with check (public.is_project_admin(project_id, auth.uid()));

create policy "project_choices_member_read"
on public.project_question_choices
for select
to authenticated
using (
  exists (
    select 1
    from public.project_questions pq
    where pq.id = project_question_id
      and public.is_project_member(pq.project_id, auth.uid())
      and pq.is_active = true
  )
);

create policy "project_choices_admin_write"
on public.project_question_choices
for all
to authenticated
using (
  exists (
    select 1
    from public.project_questions pq
    where pq.id = project_question_id
      and public.is_project_admin(pq.project_id, auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.project_questions pq
    where pq.id = project_question_id
      and public.is_project_admin(pq.project_id, auth.uid())
  )
);

-- attempts/answers: learner own, admin can read project-wide
create policy "project_attempt_owner_rw"
on public.project_attempts
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "project_attempt_admin_read"
on public.project_attempts
for select
to authenticated
using (public.is_project_admin(project_id, auth.uid()));

create policy "project_attempt_answer_owner_rw"
on public.project_attempt_answers
for all
to authenticated
using (
  exists (
    select 1
    from public.project_attempts a
    where a.id = attempt_id
      and a.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.project_attempts a
    where a.id = attempt_id
      and a.user_id = auth.uid()
  )
);

create policy "project_attempt_answer_admin_read"
on public.project_attempt_answers
for select
to authenticated
using (
  exists (
    select 1
    from public.project_attempts a
    where a.id = attempt_id
      and public.is_project_admin(a.project_id, auth.uid())
  )
);

-- Helper: create project + clone question set from base test
create or replace function public.create_project_from_test(
  p_test_id uuid,
  p_name text,
  p_slug text,
  p_description text default null
)
returns table(project_id uuid, access_code text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_project_id uuid;
  v_access_code text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'auth required';
  end if;

  insert into public.diagnostic_projects (test_id, name, slug, description, created_by)
  values (p_test_id, p_name, p_slug, p_description, v_user_id)
  returning id, access_code into v_project_id, v_access_code;

  insert into public.project_members (project_id, user_id, role)
  values (v_project_id, v_user_id, 'admin');

  insert into public.project_questions (
    project_id,
    source_question_id,
    question_no,
    section_name,
    prompt,
    stem,
    explanation,
    correct_choice_no
  )
  select
    v_project_id,
    q.id,
    q.question_no,
    s.name,
    q.prompt,
    q.stem,
    q.explanation,
    q.correct_choice_no
  from public.diagnostic_questions q
  left join public.diagnostic_sections s on s.id = q.section_id
  where q.test_id = p_test_id
    and q.is_active = true
  order by q.question_no;

  insert into public.project_question_choices (project_question_id, choice_no, content)
  select
    pq.id,
    c.choice_no,
    c.content
  from public.project_questions pq
  join public.diagnostic_choices c on c.question_id = pq.source_question_id
  where pq.project_id = v_project_id;

  return query
  select v_project_id, v_access_code;
end;
$$;

-- Helper: submit scoring by project attempt
create or replace function public.submit_project_attempt(p_attempt_id uuid)
returns table(total_correct int, total_score numeric)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_project_id uuid;
  v_total_questions int;
begin
  select project_id into v_project_id
  from public.project_attempts
  where id = p_attempt_id;

  if v_project_id is null then
    raise exception 'attempt not found';
  end if;

  update public.project_attempt_answers aa
  set is_correct = (aa.selected_choice_no = q.correct_choice_no)
  from public.project_questions q
  where aa.attempt_id = p_attempt_id
    and aa.project_question_id = q.id;

  select count(*)::int into v_total_questions
  from public.project_questions
  where project_id = v_project_id
    and is_active = true;

  if v_total_questions = 0 then
    v_total_questions := 20;
  end if;

  return query
  with c as (
    select count(*)::int as correct_count
    from public.project_attempt_answers
    where attempt_id = p_attempt_id
      and is_correct = true
  )
  update public.project_attempts a
  set
    status = 'submitted',
    submitted_at = now(),
    total_correct = c.correct_count,
    total_score = round((c.correct_count::numeric / v_total_questions) * 100, 2)
  from c
  where a.id = p_attempt_id
  returning a.total_correct, a.total_score;
end;
$$;
