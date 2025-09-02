import React, { useEffect, useState } from "react";
import Background from "../Background/Background";



const baseStories = [
  { story_key: "mother_gloves", story_title: "어머니의 병어리 장갑" },
  { story_key: "father_wedding", story_title: "아버지와 결혼식" },
  { story_key: "sons_bread", story_title: "아들의 호빵" },
  { story_key: "grandma_banana", story_title: "할머니와 바나나" },
  { story_key: "kkongdang_boribap", story_title: "꽁당 보리밥" },
];

// 임시 더미 기록
const dummyRecordsForStory = (b) => [
  {
    id: `${b.story_key}_1`,
    client_attempt_order: 1,
    client_kst: "2025-09-02 10:00",
    story_title: b.story_title,
    scores: {
      scoreAD: 3,
      scoreAI: 2,
      scoreB: 3,
      scoreC: 2,
      scoreD: 1,
    },
  },
  {
    id: `${b.story_key}_2`,
    client_attempt_order: 2,
    client_kst: "2025-09-03 14:30",
    story_title: b.story_title,
    scores: {
      scoreAD: 4,
      scoreAI: 3,
      scoreB: 2,
      scoreC: 3,
      scoreD: 2,
    },
  },
];

function ResultDetailCard({ data }) {
  if (!data) return null;

  const { scoreAD, scoreAI, scoreB, scoreC, scoreD } = data.scores;

  const sAD = Number(scoreAD) * 2;
  const sAI = Number(scoreAI) * 2;
  const sB = Number(scoreB) * 2;
  const sC = Number(scoreC) * 2;
  const sD = Number(scoreD) * 2;

  const arr = [sAD, sAI, sB, sC, sD];
  const total = arr.reduce((a, b) => a + b, 0);
  const minScore = Math.min(...arr);
  const lowIndex = arr.indexOf(minScore);
  const isPassed = total >= 28;

  const okOpinion =
    "당신은 모든 영역(직접화행, 간접화행, 질문화행, 단언화행, 의례화화행)에 좋은 점수를 얻었습니다. 현재는 인지기능 정상입니다.\n하지만 유지하기 위해서 꾸준한 학습과 교육을 통한 관리가 필요합니다.";

  const opinions_result = [
    "당신은 직접화행의 점수가 낮습니다.\n기본적인 대화의 문장인식 즉 문장에 내포된 의미에 대한 이해력이 부족하고 동화에 있는 인물들이 나누는 대화들에 대한 인지능력이 조금 부족해 보입니다.\n선생님과의 프로그램을 통한 동화 인물들에 대한 학습으로 점수를 올릴 수 있습니다.",
    "당신은 간접화행의 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 대화에 대한 이해력이 부족하고 동화책 내용의 간접적 질문에 대한 듣기의 인지능력이 조금 부족해보입니다.\n선생님과의 프로그램을 통한 대화 응용능력 학습으로 점수를 올릴 수 있습니다.",
    "당신은 질문화행 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 인물들이 대화에서 주고 받는 정보에 대한 판단에 대한 인지능력이 부족해보입니다.\n선생님과의 프로그램을 통한 대화정보파악학습으로 점수를 올릴수 있습니다.",
    "당신은 단언화행의 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 동화에서 대화하는 인물들의 말에 대한 의도파악과 관련하여 인지능력이 부족해보입니다.\n선생님과의 프로그램을 통해 인물대사 의도파악학습으로 점수를 올릴 수 있습니다.",
    "당신은 의례화화행 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 동화에서 인물들이 상황에 맞는 자신의 감정을 표현하는 말에 대한 인지능력이 부족해보입니다.\n선생님과의 프로그램을 통해  인물들의 상황 및 정서 파악 학습으로 점수를 올릴 수 있습니다.",
  ];

  const opinions_guide = [
    "A-요구(직접)가 부족합니다.",
    "A-요구(간접)가 부족합니다.",
    "B-질문이 부족합니다.",
    "C-단언이 부족합니다.",
    "D-의례화가 부족합니다.",
  ];

  return (
    <div
      style={{
        background: "#fff",
        borderRadius: "10px",
        padding: "20px",
        marginTop: 12,
        marginBottom: 12,
        boxShadow: "0 6px 18px rgba(0,0,0,0.08)",
      }}
    >
      <div style={{ marginBottom: 20 }}>
        <div className="tit">총점</div>
        <div
          style={{
            margin: "0 auto",
            textAlign: "center",
            borderRadius: "10px",
            backgroundColor: "white",
            padding: "20px 0",
            fontSize: 18,
            fontWeight: 700,
          }}
        >
          {total} / 40
        </div>
      </div>

      <div style={{ marginBottom: 20 }}>
        <div className="tit">인지능력</div>
        <div
          style={{
            margin: "0 auto",
            textAlign: "center",
            borderRadius: "10px",
            backgroundColor: "white",
            padding: "20px 0",
          }}
        >
          <img
            src={isPassed ? "/drawable/speech_clear.png" : "/drawable/speech_fail.png"}
            style={{ width: "15%" }}
          />
        </div>
      </div>

      <div>
        <div className="tit">검사 결과 평가</div>
        <div
          style={{
            padding: "12px 0",
            lineHeight: 1.6,
            whiteSpace: "pre-line",
          }}
        >
          {isPassed ? okOpinion : opinions_result[lowIndex]}
        </div>
        {!isPassed && (
          <div style={{ fontWeight: 700, marginTop: 6 }}>{opinions_guide[lowIndex]}</div>
        )}
      </div>
    </div>
  );
}

export default function BookHistory() {
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  const [openStoryId, setOpenStoryId] = useState(null);
  const [openRecordId, setOpenRecordId] = useState(null);

  useEffect(() => {
    const onResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);

  return (
    <div className="content">
      {windowWidth > 1100 && <Background />}

      <div
        className="wrap"
        style={{
          maxWidth: 520,
          margin: "0 auto",
          padding: "80px 20px",
          fontFamily: "Pretendard-Regular",
        }}
      >
        <h2
          style={{
            textAlign: "center",
            marginBottom: 10,
            fontFamily: "ONE-Mobile-Title",
            fontSize: 32,
          }}
        >
          동화 화행검사 결과
        </h2>

        <div style={{ display: "flex", flexDirection: "column", gap: 15, marginTop: 10 }}>
          {baseStories.map((b, idx) => {
            const storyId = b.story_key || idx;
            const opened = openStoryId === storyId;
            const records = dummyRecordsForStory(b);

            return (
              <div
                key={storyId}
                style={{
                  background: "#fff",
                  borderRadius: 12,
                  boxShadow: "0 4px 12px rgba(0,0,0,0.1)",
                  overflow: "hidden",
                }}
              >
                <div
                  onClick={() => setOpenStoryId(opened ? null : storyId)}
                  style={{
                    padding: "18px 20px",
                    fontSize: 18,
                    fontWeight: 700,
                    cursor: "pointer",
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                  }}
                >
                  <span>{b.story_title}</span>
                  <span style={{ fontSize: 20 }}>{opened ? "▲" : "▼"}</span>
                </div>

                {opened && (
                  <div style={{ padding: "14px 20px", borderTop: "1px solid #eee" }}>
                    {records.map((r) => {
                      const selected = openRecordId === r.id;
                      return (
                        <div key={r.id}>
                          <div
                            onClick={() => setOpenRecordId(selected ? null : r.id)}
                            style={{
                              background: "#fafafa",
                              borderRadius: 8,
                              padding: "12px 16px",
                              display: "flex",
                              justifyContent: "space-between",
                              alignItems: "center",
                              cursor: "pointer",
                            }}
                          >
                            <span style={{ fontSize: 15, color: "#333" }}>
                              {r.client_kst}
                              <span
                                style={{
                                  background: "#eee",
                                  padding: "2px 8px",
                                  borderRadius: 8,
                                  fontSize: 13,
                                  marginLeft: 8,
                                  fontWeight: 600,
                                  color: "#333",
                                }}
                              >
                                {r.client_attempt_order}회차
                              </span>
                            </span>
                          </div>

                          {selected && (
                            <div style={{ marginTop: 12 }}>
                              <ResultDetailCard data={r} />
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
