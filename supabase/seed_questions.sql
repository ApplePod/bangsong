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
      (1, '밑줄 친 단어의 문맥상 의미로 가장 적절한 것은?', '나는 그의 돌출 행동을 납득하기 어려웠다.', '문맥상 납득하다=이해하다.', 2, 'vocab', '① 인정하기', '② 이해하기', '③ 설득하기', '④ 자랑하기', '⑤ 비교하기'),
      (2, '밑줄 친 단어와 문맥상 의미가 가장 유사한 것은?', '무슨 수를 써서라도 이번 사건의 진실을 밝혀내고야 말겠어.', '밝히다=진실을 드러내다.', 2, 'vocab', '① 그는 먹을 것을 밝히는 성격이다.', '② 모든 일의 사리를 밝혀, 분쟁을 없애야 한다.', '③ 인류는 수천 년 동안 두뇌를 밝혀 문명을 일으켰다.', '④ 아무리 눈을 밝혀 뒤를 밟아도 범인을 잡지 못했다.', '⑤ 뜬눈으로 밤을 밝히고, 아침 일찍 딸의 방문을 두드렸다.'),
      (3, '밑줄 친 단어를 바꿔 쓸 때 의미가 가장 가까운 것은?', '그는 맡은 일을 성실하게 끝까지 해냈다.', '성실하게=꾸준하고 책임감 있게.', 2, 'vocab', '① 무성의하게', '② 꾸준하게', '③ 즉흥적으로', '④ 소홀하게', '⑤ 무작정'),
      (4, '밑줄 친 단어와 의미가 가장 가까운 것을 고르시오.', '문제를 한쪽 관점에서만 보면 해결이 어렵다.', '관점=사물을 보는 시각.', 1, 'vocab', '① 시각', '② 형태', '③ 위치', '④ 판단', '⑤ 방향'),
      (5, '문맥상 밑줄 친 표현과 의미가 가장 가까운 것은?', '주장을 설득력 있게 하려면 근거를 구체화해야 한다.', '구체화하다=명확히 드러내다.', 3, 'vocab', '① 축소해야 한다', '② 단순화해야 한다', '③ 명확히 드러내야 한다', '④ 외면해야 한다', '⑤ 생략해야 한다'),
      (6, '밑줄 친 부분의 표기가 바르지 않은 것은?', '다음 보기 중 맞춤법 표기가 틀린 문장을 고르세요.', '호랑이에요 -> 호랑이예요가 바른 표기.', 4, 'norm', '① 아니에요.', '② 저는 장남이에요.', '③ 제 고향은 대구예요.', '④ 이 그림이 호랑이에요.', '⑤ 제 이름은 김아영이에요.'),
      (7, '다음 중 띄어쓰기가 올바른 것은?', '보기 중 가장 바른 표현을 고르세요.', '의존 명사 띄어쓰기 규칙.', 1, 'norm', '① 할 수 있다', '② 할수 있다', '③ 할 수있다', '④ 할수있다', '⑤ 할 수  있다'),
      (8, '높임 표현이 올바른 문장을 고르시오.', '문장 내 주체 높임이 적절한 것은?', '주체 높임 선어말어미 사용.', 2, 'norm', '① 선생님이 오셨어.', '② 선생님께서 오셨어요.', '③ 선생님이 오셨다요.', '④ 선생님께서 왔다.', '⑤ 선생님이 오셨어요께.'),
      (9, '문장 부호 사용이 올바른 것은?', '다음 보기 중 표기가 바른 문장을 고르시오.', '마침표 사용 규칙.', 2, 'norm', '① 오늘은 비가 온다,', '② 오늘은 비가 온다.', '③ 오늘은 비가 온다,,', '④ 오늘은 비가 온다..', '⑤ 오늘은 비가 온다?'),
      (10, '다음 중 표준어 사용이 바른 것은?', '문맥에 맞는 단어를 고르시오.', '맞히다/맞추다 구분.', 3, 'norm', '① 정답을 맞추다(정답 여부)', '② 시계를 맞히다(시간 조정)', '③ 시간을 맞추다(시간 조정)', '④ 과녁을 맞추다(명중)', '⑤ 비밀번호를 맞히다(조정)'),
      (11, '문단의 중심 문장으로 가장 적절한 것은?', '아래 문단은 ''독서 습관의 중요성''을 설명하고 있다.', '중심문장 파악.', 1, 'org', '① 독서는 사고력을 기르는 데 도움을 준다.', '② 나는 어제 도서관에 갔다.', '③ 책 표지가 예쁘면 눈에 띈다.', '④ 독서실은 조용하다.', '⑤ 서점은 주말에 사람이 많다.'),
      (12, '문장 배열 순서로 가장 자연스러운 것은?', 'A. 주제를 제시한다 B. 근거를 설명한다 C. 예시를 든다 D. 결론을 정리한다', '일반적 전개 순서.', 1, 'org', '① A-B-C-D', '② B-A-D-C', '③ C-B-A-D', '④ D-A-B-C', '⑤ A-C-D-B'),
      (13, '문장 연결어로 가장 적절한 것은?', '자료를 충분히 조사했다. (   ), 결론은 신중히 제시해야 한다.', '앞문장과 뒷문장의 인과 관계.', 1, 'org', '① 따라서', '② 그러나', '③ 결국', '④ 동시에', '⑤ 게다가'),
      (14, '원문 요약으로 가장 적절한 것은?', '원문: ''규칙적인 운동은 체력을 높이고 스트레스를 줄이며 수면의 질을 개선한다.''', '핵심 정보 유지 요약.', 2, 'org', '① 운동은 피곤하므로 가끔만 해야 한다.', '② 규칙적 운동은 건강 전반에 긍정적 영향을 준다.', '③ 수면만 좋아지면 운동은 필요 없다.', '④ 체력은 운동과 관련이 없다.', '⑤ 스트레스는 운동으로 늘어난다.'),
      (15, '주장과 근거의 연결이 가장 타당한 것은?', '주장: 학교 도서관 운영 시간을 연장해야 한다.', '주장을 직접 뒷받침하는 근거 선택.', 2, 'org', '① 책이 무겁기 때문이다.', '② 학생들이 야간에도 학습 공간이 필요하기 때문이다.', '③ 도서관 건물이 오래됐기 때문이다.', '④ 사서 선생님이 친절하기 때문이다.', '⑤ 학교 운동장이 넓기 때문이다.'),
      (16, '주어와 서술어의 호응이 가장 자연스러운 것은?', '다음 중 문법적으로 가장 자연스러운 문장을 고르시오.', '문장 성분 호응.', 1, 'sent', '① 이 자료들은 분석이 필요하다.', '② 이 자료들은 분석이 필요한다.', '③ 이 자료들은 분석을 필요하다.', '④ 이 자료는 분석들이 필요하다.', '⑤ 이 자료들은 분석을 필요로 한다는.'),
      (17, '중복 표현을 고쳐 쓴 문장으로 가장 적절한 것은?', '원문: ''그는 앞으로의 미래 계획을 세웠다.''', '''앞으로''와 ''미래'' 중복 제거.', 2, 'sent', '① 그는 앞으로의 미래 계획을 세웠다.', '② 그는 미래 계획을 세웠다.', '③ 그는 앞의 미래를 계획했다.', '④ 그는 계획의 미래를 세웠다.', '⑤ 그는 미래를 앞으로 세웠다.'),
      (18, '문장의 명확성을 높이도록 고친 것은?', '원문: ''회의가 끝나고 보고서를 빨리 검토해 주세요.''', '중복 부사 제거로 명확성 향상.', 1, 'sent', '① 회의가 끝나고 보고서를 검토해 주세요.', '② 회의 끝나고 빨리 빨리 검토해 주세요.', '③ 회의가 끝난 뒤에는 보고서를 얼른 빨리 검토해 주세요.', '④ 보고서를 회의가 끝나고 검토해 빠르게 주세요.', '⑤ 끝난 회의 보고서를 빨리 검토해 주세요.'),
      (19, '문체가 일관된 문장을 고르시오.', '다음 보기 중 문체 혼합이 없는 문장은?', '문체 일관성 판단.', 1, 'sent', '① 오늘 발표는 여기까지 하겠습니다.', '② 오늘 발표는 여기까지 한다요.', '③ 오늘 발표는 여기까지 함.', '④ 오늘 발표는 여기까지 할게요다.', '⑤ 오늘 발표는 여기까지 한다네.'),
      (20, '공식 안내문에 가장 적절한 문장은?', '학사 공지 문장으로 적절한 표현을 고르시오.', '공식 문서 문체 선택.', 1, 'sent', '① 신청 기간은 6월 1일부터 6월 7일까지입니다.', '② 신청 기간은 6월 1일부터 6월 7일까지임.', '③ 신청 기간은 6월 1일부터 6월 7일까지야.', '④ 신청 기간은 6월 1일부터 6월 7일까지거든요.', '⑤ 신청 기간은 6월 1일부터 6월 7일까지다요.')
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
