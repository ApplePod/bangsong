const EXAM_META = {
  totalQuestions: 20,
  limitMinutes: 40,
};

const QUESTION_STATUS = [
  { no: 1, isCorrect: true, area: "적확한 어휘 사용" },
  { no: 2, isCorrect: true, area: "적확한 어휘 사용" },
  { no: 3, isCorrect: true, area: "적확한 어휘 사용" },
  { no: 4, isCorrect: true, area: "적확한 어휘 사용" },
  { no: 5, isCorrect: false, area: "적확한 어휘 사용" },
  { no: 6, isCorrect: false, area: "어문 규범의 이해" },
  { no: 7, isCorrect: true, area: "어문 규범의 이해" },
  { no: 8, isCorrect: false, area: "어문 규범의 이해" },
  { no: 9, isCorrect: false, area: "어문 규범의 이해" },
  { no: 10, isCorrect: true, area: "어문 규범의 이해" },
  { no: 11, isCorrect: true, area: "글의 조직 능력" },
  { no: 12, isCorrect: true, area: "글의 조직 능력" },
  { no: 13, isCorrect: false, area: "글의 조직 능력" },
  { no: 14, isCorrect: false, area: "글의 조직 능력" },
  { no: 15, isCorrect: true, area: "글의 조직 능력" },
  { no: 16, isCorrect: true, area: "적절한 문장" },
  { no: 17, isCorrect: false, area: "적절한 문장" },
  { no: 18, isCorrect: true, area: "적절한 문장" },
  { no: 19, isCorrect: true, area: "적절한 문장" },
  { no: 20, isCorrect: true, area: "적절한 문장" },
];

const EXPLANATION_DETAIL = {
  no: 6,
  title: "밑줄 친 부분의 표기가 바르지 않은 것은?",
  choices: [
    "① 아니에요.",
    "② 저는 장남이에요.",
    "③ 제 고향은 대구예요.",
    "④ 이 그림이 호랑이에요.",
    "⑤ 제 이름은 김아영이에요.",
  ],
  answer: "④",
  area: "어문 규범의 이해",
  criterion: "일상생활에서 자주 쓰이는 어휘와 표현에 대해 바른 표기법을 안다.",
  explanation:
    "‘호랑이에요’는 ‘호랑이 + 이 + 에 + 요’의 결합형이며 ‘이 + 에’가 줄어 ‘예’가 되므로, 바른 표기는 ‘호랑이예요’입니다.",
};

const DIAGNOSTIC_QUESTIONS = Array.from({ length: EXAM_META.totalQuestions }, (_, index) => {
  const no = index + 1;
  const status = QUESTION_STATUS[index];

  if (no === 2) {
    return {
      no,
      prompt: "밑줄 친 단어와 문맥 상 의미가 가장 유사한 것은?",
      stem: "무슨 수를 써서라도 이번 사건의 진실을 밝혀내고야 말겠어.",
      choices: [
        "① 그는 먹을 것을 밝히는 성격이다.",
        "② 모든 일의 사리를 밝혀, 분쟁을 없애야 한다.",
        "③ 인류는 수 천년 동안 두뇌를 밝혀 문명을 일으켰다.",
        "④ 아무리 눈을 밝혀 뒤를 밟아도 범인을 잡지 못했다.",
        "⑤ 뜬눈으로 밤을 밝히고, 아침 일찍 딸의 방문을 두드렸다.",
      ],
    };
  }

  if (no === 6) {
    return {
      no,
      prompt: "밑줄 친 부분의 표기가 바르지 않은 것은?",
      stem: "다음 보기 중 맞춤법 표기가 틀린 문장을 고르세요.",
      choices: [
        "① 아니에요.",
        "② 저는 장남이에요.",
        "③ 제 고향은 대구예요.",
        "④ 이 그림이 호랑이에요.",
        "⑤ 제 이름은 김아영이에요.",
      ],
    };
  }

  return {
    no,
    prompt: `${status.area} 영역 문항입니다. 문맥에 맞는 답을 고르세요.`,
    stem: `문항 ${no}의 제시문을 읽고 가장 적절한 보기를 선택하십시오.`,
    choices: [
      "① 보기 1",
      "② 보기 2",
      "③ 보기 3",
      "④ 보기 4",
      "⑤ 보기 5",
    ],
  };
});
