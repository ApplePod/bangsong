# 프로젝트 단위 운영 흐름 (A프로젝트 / B프로젝트)

요구사항 반영:
- 프로젝트를 여러 개 생성
- 프로젝트별 별도 링크 발급
- 특정 학생 그룹만 접근 허용
- 프로젝트마다 문제 구성을 다르게 운영

---

## 1) 프로젝트 생성 (관리자)

```sql
select * from public.create_project_from_test(
  p_test_id := '<diagnostic_tests.id>',
  p_name := 'A 프로젝트',
  p_slug := 'a-project-2026',
  p_description := 'A그룹 대상 글쓰기 진단'
);
```

반환값:
- `project_id`
- `access_code`

학생용 링크 예시:
- `https://your-domain.com/project/a-project-2026`
- 또는 `https://your-domain.com/join/<access_code>`

---

## 2) A그룹 학생만 허용

### 방법 A: user_id 직접 등록
```sql
insert into public.project_members(project_id, user_id, role)
values
  ('<project_id>', '<student_user_id_1>', 'learner'),
  ('<project_id>', '<student_user_id_2>', 'learner');
```

### 방법 B: 학번/코드 whitelist 등록
```sql
insert into public.project_student_whitelist(project_id, student_key, memo)
values
  ('<project_id>', '2026A001', 'A반'),
  ('<project_id>', '2026A002', 'A반');
```

프론트 가입 로직에서:
1) access_code 검증
2) 사용자 student_key가 whitelist에 있는지 확인
3) 통과 시 `project_members`에 learner 등록

---

## 3) 프로젝트별 문제 다르게 구성

`create_project_from_test`가 기본 20문항을 프로젝트로 복제합니다.

복제 후 프로젝트 전용 편집:
```sql
-- 문항 비활성화
update public.project_questions
set is_active = false
where project_id = '<project_id>' and question_no in (3, 8);

-- 문항 텍스트 수정
update public.project_questions
set prompt = 'A프로젝트 전용 문항 문구'
where project_id = '<project_id>' and question_no = 6;

-- 보기 수정
update public.project_question_choices
set content = '④ (수정된 보기)'
where project_question_id = '<project_question_id>' and choice_no = 4;
```

---

## 4) 학생 응시

```sql
insert into public.project_attempts(project_id, user_id, status, remaining_seconds)
values ('<project_id>', '<auth.uid()>', 'in_progress', 2400)
returning id;
```

답안 저장:
```sql
insert into public.project_attempt_answers(attempt_id, project_question_id, selected_choice_no)
values ('<attempt_id>', '<project_question_id>', 2)
on conflict (attempt_id, project_question_id)
do update set selected_choice_no = excluded.selected_choice_no;
```

제출:
```sql
select * from public.submit_project_attempt('<attempt_id>');
```

---

## 5) 관리자 결과 조회

```sql
select
  p.name as project_name,
  a.user_id,
  a.total_correct,
  a.total_score,
  a.submitted_at
from public.project_attempts a
join public.diagnostic_projects p on p.id = a.project_id
where p.id = '<project_id>'
  and a.status = 'submitted'
order by a.submitted_at desc;
```

---

이 구조면 말씀한 운영 방식(A그룹/B그룹 분리, 링크 분리, 프로젝트별 문제 차별화)을 그대로 구현할 수 있습니다.
