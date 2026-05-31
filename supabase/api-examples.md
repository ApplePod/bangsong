# Supabase API Example (Starter)

프로젝트 URL: `https://invprwpzxosrhegxsfec.supabase.co`

아래는 프론트에서 바로 붙일 수 있는 최소 예시입니다.

## 1) 클라이언트 초기화

```ts
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  "https://invprwpzxosrhegxsfec.supabase.co",
  import.meta.env.VITE_SUPABASE_ANON_KEY
);
```

## 2) 활성 진단 + 20문항 로드

```ts
const { data: test } = await supabase
  .from("diagnostic_tests")
  .select("id, slug, title, total_questions, time_limit_minutes")
  .eq("slug", "knou-writing-basic-v1")
  .eq("is_active", true)
  .single();

const { data: questions } = await supabase
  .from("diagnostic_questions")
  .select(`
    id, question_no, prompt, stem, explanation, correct_choice_no,
    diagnostic_choices(choice_no, content)
  `)
  .eq("test_id", test.id)
  .eq("is_active", true)
  .order("question_no", { ascending: true });
```

## 3) 응시 시작

```ts
const { data: user } = await supabase.auth.getUser();

const { data: attempt } = await supabase
  .from("diagnostic_attempts")
  .insert({
    test_id: test.id,
    user_id: user.user?.id,
    status: "in_progress",
    remaining_seconds: test.time_limit_minutes * 60,
  })
  .select("id")
  .single();
```

## 4) 문항 답안 저장 (upsert)

```ts
await supabase
  .from("diagnostic_attempt_answers")
  .upsert({
    attempt_id: attempt.id,
    question_id,
    selected_choice_no,
  }, { onConflict: "attempt_id,question_id" });
```

## 5) 임시저장

```ts
await supabase
  .from("diagnostic_attempts")
  .update({
    status: "saved",
    remaining_seconds: remainSeconds,
  })
  .eq("id", attempt.id);
```

## 6) 제출 + 점수 계산 (RPC)

```ts
const { data: submitResult, error } = await supabase
  .rpc("submit_diagnostic_attempt", { p_attempt_id: attempt.id });

// submitResult[0] -> { total_correct, total_score }
```

## 7) 결과 화면 로드

```ts
const { data: result } = await supabase
  .from("diagnostic_attempts")
  .select("id, total_correct, total_score, submitted_at")
  .eq("id", attempt.id)
  .single();

const { data: answerRows } = await supabase
  .from("diagnostic_attempt_answers")
  .select(`
    is_correct, selected_choice_no,
    diagnostic_questions(question_no, prompt, section_id)
  `)
  .eq("attempt_id", attempt.id);
```

## 8) 만족도 저장

```ts
await supabase.from("diagnostic_satisfaction").upsert({
  attempt_id: attempt.id,
  helpful_for_diagnosis: 4,
  easy_to_understand_explanation: 4,
  easy_to_understand_video: 3,
});
```

## 9) 관리자용 데이터 추출 (서버/서비스키 권장)

```sql
select
  a.id as attempt_id,
  a.user_id,
  lp.department,
  lp.admission_type,
  lp.gender,
  lp.final_education,
  a.total_score,
  a.submitted_at
from public.diagnostic_attempts a
left join public.learner_profiles lp on lp.user_id = a.user_id
where a.status = 'submitted'
order by a.submitted_at desc;
```

---

실제 연결하려면 `anon key`, 운영/배치에는 `service_role key`가 필요합니다.
