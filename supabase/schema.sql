-- Writing diagnosis backend schema (Supabase/Postgres)
-- Run in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.diagnostic_tests (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text,
  total_questions int not null default 20 check (total_questions > 0),
  time_limit_minutes int not null default 40 check (time_limit_minutes > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.diagnostic_sections (
  id uuid primary key default gen_random_uuid(),
  test_id uuid not null references public.diagnostic_tests(id) on delete cascade,
  code text not null,
  name text not null,
  display_order int not null default 1,
  created_at timestamptz not null default now(),
  unique (test_id, code),
  unique (test_id, display_order)
);

create table if not exists public.diagnostic_questions (
  id uuid primary key default gen_random_uuid(),
  test_id uuid not null references public.diagnostic_tests(id) on delete cascade,
  section_id uuid references public.diagnostic_sections(id) on delete set null,
  question_no int not null,
  prompt text not null,
  stem text not null,
  explanation text,
  correct_choice_no smallint not null check (correct_choice_no between 1 and 5),
  difficulty text not null default 'medium',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (test_id, question_no)
);

create table if not exists public.diagnostic_choices (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.diagnostic_questions(id) on delete cascade,
  choice_no smallint not null check (choice_no between 1 and 5),
  content text not null,
  unique (question_id, choice_no)
);

create table if not exists public.learner_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  department text,
  admission_type text,
  grade text,
  prev_semester_score text,
  gender text,
  age_group text,
  final_education text,
  job text,
  updated_at timestamptz not null default now()
);

create table if not exists public.diagnostic_attempts (
  id uuid primary key default gen_random_uuid(),
  test_id uuid not null references public.diagnostic_tests(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'in_progress'
    check (status in ('in_progress', 'submitted', 'saved')),
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  remaining_seconds int not null default 2400,
  total_correct int not null default 0,
  total_score numeric(5,2) not null default 0,
  unique (test_id, user_id, status) deferrable initially immediate
);

create table if not exists public.diagnostic_attempt_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.diagnostic_attempts(id) on delete cascade,
  question_id uuid not null references public.diagnostic_questions(id) on delete cascade,
  selected_choice_no smallint not null check (selected_choice_no between 1 and 5),
  is_correct boolean,
  answered_at timestamptz not null default now(),
  unique (attempt_id, question_id)
);

create table if not exists public.diagnostic_satisfaction (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null unique references public.diagnostic_attempts(id) on delete cascade,
  helpful_for_diagnosis smallint not null check (helpful_for_diagnosis between 1 and 5),
  easy_to_understand_explanation smallint not null check (easy_to_understand_explanation between 1 and 5),
  easy_to_understand_video smallint not null check (easy_to_understand_video between 1 and 5),
  created_at timestamptz not null default now()
);

create index if not exists idx_questions_test_no on public.diagnostic_questions(test_id, question_no);
create index if not exists idx_attempts_user on public.diagnostic_attempts(user_id, started_at desc);
create index if not exists idx_attempt_answers_attempt on public.diagnostic_attempt_answers(attempt_id);

alter table public.diagnostic_tests enable row level security;
alter table public.diagnostic_sections enable row level security;
alter table public.diagnostic_questions enable row level security;
alter table public.diagnostic_choices enable row level security;
alter table public.learner_profiles enable row level security;
alter table public.diagnostic_attempts enable row level security;
alter table public.diagnostic_attempt_answers enable row level security;
alter table public.diagnostic_satisfaction enable row level security;

-- Public read for active question set
create policy "tests_public_read_active"
on public.diagnostic_tests
for select
to anon, authenticated
using (is_active = true);

create policy "sections_public_read"
on public.diagnostic_sections
for select
to anon, authenticated
using (true);

create policy "questions_public_read_active"
on public.diagnostic_questions
for select
to anon, authenticated
using (is_active = true);

create policy "choices_public_read"
on public.diagnostic_choices
for select
to anon, authenticated
using (true);

-- Profile: owner only
create policy "profile_owner_select"
on public.learner_profiles
for select
to authenticated
using (auth.uid() = user_id);

create policy "profile_owner_upsert"
on public.learner_profiles
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Attempts: owner only
create policy "attempt_owner_select"
on public.diagnostic_attempts
for select
to authenticated
using (auth.uid() = user_id);

create policy "attempt_owner_insert"
on public.diagnostic_attempts
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "attempt_owner_update"
on public.diagnostic_attempts
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "attempt_owner_delete"
on public.diagnostic_attempts
for delete
to authenticated
using (auth.uid() = user_id);

-- Answers: owner through attempt
create policy "answer_owner_select"
on public.diagnostic_attempt_answers
for select
to authenticated
using (
  exists (
    select 1
    from public.diagnostic_attempts a
    where a.id = attempt_id
      and a.user_id = auth.uid()
  )
);

create policy "answer_owner_write"
on public.diagnostic_attempt_answers
for all
to authenticated
using (
  exists (
    select 1
    from public.diagnostic_attempts a
    where a.id = attempt_id
      and a.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.diagnostic_attempts a
    where a.id = attempt_id
      and a.user_id = auth.uid()
  )
);

create policy "satisfaction_owner_write"
on public.diagnostic_satisfaction
for all
to authenticated
using (
  exists (
    select 1
    from public.diagnostic_attempts a
    where a.id = attempt_id
      and a.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.diagnostic_attempts a
    where a.id = attempt_id
      and a.user_id = auth.uid()
  )
);

-- Submit helper: compute correctness and score
create or replace function public.submit_diagnostic_attempt(p_attempt_id uuid)
returns table(total_correct int, total_score numeric)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_test_id uuid;
  v_total_questions int;
begin
  select test_id into v_test_id
  from public.diagnostic_attempts
  where id = p_attempt_id;

  if v_test_id is null then
    raise exception 'attempt not found';
  end if;

  update public.diagnostic_attempt_answers aa
  set is_correct = (aa.selected_choice_no = q.correct_choice_no)
  from public.diagnostic_questions q
  where aa.attempt_id = p_attempt_id
    and aa.question_id = q.id;

  select t.total_questions into v_total_questions
  from public.diagnostic_tests t
  where t.id = v_test_id;

  if v_total_questions is null or v_total_questions = 0 then
    v_total_questions := 20;
  end if;

  return query
  with c as (
    select count(*)::int as correct_count
    from public.diagnostic_attempt_answers
    where attempt_id = p_attempt_id
      and is_correct = true
  )
  update public.diagnostic_attempts a
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
