-- Seed 1 test + 4 sections + 20 questions
-- Run after schema.sql

insert into public.diagnostic_tests (slug, title, description, total_questions, time_limit_minutes)
values (
  'knou-writing-basic-v1',
  '방송대 글쓰기 기초능력 진단',
  '20문항 객관식 기반 진단',
  20,
  40
)
on conflict (slug) do update
set
  title = excluded.title,
  description = excluded.description,
  total_questions = excluded.total_questions,
  time_limit_minutes = excluded.time_limit_minutes;

with test_row as (
  select id
  from public.diagnostic_tests
  where slug = 'knou-writing-basic-v1'
),
section_rows as (
  insert into public.diagnostic_sections (test_id, code, name, display_order)
  select test_row.id, s.code, s.name, s.display_order
  from test_row
  cross join (
    values
      ('vocab', '적확한 어휘 사용', 1),
      ('norm', '어문 규범의 이해', 2),
      ('org', '글의 조직 능력', 3),
      ('sent', '적절한 문장', 4)
  ) as s(code, name, display_order)
  on conflict (test_id, code) do update
  set name = excluded.name, display_order = excluded.display_order
  returning id, code, test_id
),
questions as (
  select
    q.no,
    q.prompt,
    q.stem,
    q.explanation,
    q.correct_choice_no,
    q.section_code,
    q.choice_1,
    q.choice_2,
    q.choice_3,
    q.choice_4,
    q.choice_5
  from (
    values
      (1, '밑줄 친 단어의 문맥 상 의미로 가장 적절한 것은?', '나는 그의 돌출 행동을 납득하기 어려웠다.', '문맥상 납득하다=이해하다.', 2, 'vocab', '① 인정하기', '② 이해하기', '③ 판단하기', '④ 설득하기', '⑤ 설파하기'),
      (2, '밑줄 친 단어와 문맥 상 의미가 가장 유사한 것은?', '무슨 수를 써서라도 이번 사건의 진실을 밝히고야 말겠어.', '밝히다=진실을 드러내다.', 2, 'vocab', '① 먹을 것을 밝히다', '② 사리를 밝혀 분쟁을 없애다', '③ 두뇌를 밝히다', '④ 눈을 밝히다', '⑤ 밤을 밝히다'),
      (3, '다음 문장에서 가장 어색한 어휘를 고르시오.', '그의 행동은 모두에게 큰 위로를 주었다.', '문맥에 맞는 어휘를 선택하는 문제.', 3, 'vocab', '① 행동', '② 모두', '③ 위로', '④ 주었다', '⑤ 큰'),
      (4, '문맥에 맞는 단어를 고르시오.', '발표자는 핵심 근거를 분명하게 ( ) 했다.', '동사 선택 문제.', 1, 'vocab', '① 제시', '② 이동', '③ 침묵', '④ 정지', '⑤ 생략'),
      (5, '의미가 가장 가까운 단어를 고르시오.', '그는 문제 해결에 매우 적극적이다.', '유의어 문제.', 4, 'vocab', '① 소극적', '② 단순한', '③ 불확실한', '④ 능동적', '⑤ 폐쇄적'),
      (6, '밑줄 친 부분의 표기가 바르지 않은 것은?', '다음 보기 중 맞춤법 표기가 틀린 문장을 고르세요.', '호랑이에요 -> 호랑이예요가 바른 표기.', 4, 'norm', '① 아니에요', '② 저는 장남이에요', '③ 제 고향은 대구예요', '④ 이 그림이 호랑이에요', '⑤ 제 이름은 김아영이에요'),
      (7, '다음 중 띄어쓰기가 올바른 것은?', '보기 중 맞는 띄어쓰기를 선택하시오.', '기본 띄어쓰기 규칙.', 1, 'norm', '① 할 수 있다', '② 할수 있다', '③ 할수있다', '④ 할 수있다', '⑤ 할수  있다'),
      (8, '다음 중 표준어 표기가 맞는 것은?', '표준어 규정에 맞는 표현 선택.', '표준어 문제.', 3, 'norm', '① 되게', '② 되계', '③ 되게', '④ 돼게', '⑤ 돼계'),
      (9, '다음 문장 부호 사용이 올바른 것은?', '문장 부호 규칙 문제.', '쉼표/마침표 사용.', 2, 'norm', '① 오늘은 비가 온다,', '② 오늘은 비가 온다.', '③ 오늘은 비가 온다?', '④ 오늘은 비가 온다!', '⑤ 오늘은 비가 온다;'),
      (10, '다음 중 외래어 표기가 맞는 것은?', '외래어 표기법 문제.', '기본 표기 규칙.', 5, 'norm', '① 컴퓨터어', '② 컴퓨타', '③ 콤퓨터', '④ 컴퓨타어', '⑤ 컴퓨터'),
      (11, '문단의 중심 문장으로 가장 적절한 것은?', '아래 문장을 읽고 중심 문장을 고르시오.', '핵심문장 파악.', 1, 'org', '① 첫 문장', '② 둘째 문장', '③ 셋째 문장', '④ 넷째 문장', '⑤ 다섯째 문장'),
      (12, '문단 순서 배열로 가장 자연스러운 것은?', '문장 A~D를 읽고 순서를 고르시오.', '문단 전개 구조 문제.', 3, 'org', '① A-B-C-D', '② B-A-D-C', '③ A-C-B-D', '④ C-B-A-D', '⑤ D-A-B-C'),
      (13, '논리 전개상 어색한 연결어를 고르시오.', '다음 문장 간 연결을 확인하시오.', '접속어 선택 문제.', 4, 'org', '① 따라서', '② 그러나', '③ 또한', '④ 그래서(부적절)', '⑤ 한편'),
      (14, '요약문으로 적절한 것은?', '원문을 읽고 가장 적절한 요약을 고르시오.', '요약 정확성 문제.', 2, 'org', '① 세부정보 중심', '② 핵심내용 중심', '③ 예시 나열', '④ 감상 중심', '⑤ 인용 중심'),
      (15, '주장-근거 관계가 타당한 것은?', '다음 보기 중 논리 관계를 고르시오.', '논증 구조 문제.', 5, 'org', '① 주장만 있음', '② 근거만 있음', '③ 반복 서술', '④ 비약', '⑤ 주장+근거 일치'),
      (16, '다음 문장에서 가장 자연스러운 문장은?', '문장 호응 관계를 확인하시오.', '문장성분 호응 문제.', 1, 'sent', '① 자연스러운 문장', '② 주어-서술어 불일치', '③ 시제 불일치', '④ 중복 서술', '⑤ 의미 충돌'),
      (17, '문장 다듬기로 적절한 것은?', '불필요한 표현을 줄이시오.', '군더더기 제거 문제.', 3, 'sent', '① 장문 유지', '② 중복 강조', '③ 핵심만 남김', '④ 피동 남용', '⑤ 수식 과다'),
      (18, '주어와 서술어 호응이 맞는 문장은?', '보기 중 호응이 맞는 문장을 고르시오.', '문장 문법 문제.', 4, 'sent', '① 호응 어긋남', '② 주어 누락', '③ 서술어 누락', '④ 호응 적절', '⑤ 시제 충돌'),
      (19, '다음 중 가장 명확한 문장은?', '문장의 명료성을 판단하시오.', '명확성 문제.', 2, 'sent', '① 중의적 표현', '② 의미 명확', '③ 수식 과다', '④ 문장 파편화', '⑤ 불필요 반복'),
      (20, '다음 문장의 종결 표현으로 가장 적절한 것은?', '대상과 상황에 맞는 종결어미를 고르시오.', '상황 적합성 문제.', 1, 'sent', '① 상황에 맞는 종결', '② 지나친 반말', '③ 지나친 경어', '④ 어색한 종결', '⑤ 문체 혼합')
  ) as q(no, prompt, stem, explanation, correct_choice_no, section_code, choice_1, choice_2, choice_3, choice_4, choice_5)
),
upsert_questions as (
  insert into public.diagnostic_questions (
    test_id,
    section_id,
    question_no,
    prompt,
    stem,
    explanation,
    correct_choice_no
  )
  select
    sr.test_id,
    sr.id as section_id,
    q.no,
    q.prompt,
    q.stem,
    q.explanation,
    q.correct_choice_no
  from questions q
  join section_rows sr
    on sr.code = q.section_code
  on conflict (test_id, question_no) do update
  set
    section_id = excluded.section_id,
    prompt = excluded.prompt,
    stem = excluded.stem,
    explanation = excluded.explanation,
    correct_choice_no = excluded.correct_choice_no
  returning id, question_no
)
insert into public.diagnostic_choices (question_id, choice_no, content)
select uq.id, c.choice_no, c.content
from upsert_questions uq
join questions q on q.no = uq.question_no
cross join lateral (
  values
    (1, q.choice_1),
    (2, q.choice_2),
    (3, q.choice_3),
    (4, q.choice_4),
    (5, q.choice_5)
) as c(choice_no, content)
on conflict (question_id, choice_no) do update
set content = excluded.content;
