// 02. web/malhaebom/src/pages/Story/Exam/ResultExam.jsx
import React, { useEffect, useMemo, useRef, useState } from "react";
import Header from "../../../../components/Header.jsx";
import AOS from "aos";
import { useNavigate } from "react-router-dom";
import { useScores } from "../../../../ScoreContext.jsx";
import Background from "../../../Background/Background";
import API, { ensureUserKey } from "../../../../lib/api.js";

/* ─────────────────────────────────────────────────────────
 * 제목 정규화
 *  - 병어리/벙어리 혼용, '의/와' 혼용, 공백/띄어쓰기 정리
 *  - 저장/조회 모두 이 표준 제목으로 통일시켜야 회차가 정상 증가
 * ───────────────────────────────────────────────────────── */
const normalizeSpaces = (s) => String(s || "").replace(/\s+/g, " ").trim();
function canonicalizeTitle(raw) {
  let t = normalizeSpaces(raw || "동화");

  // 맞춤법/오탈자 교정 (병어리 → 벙어리)
  t = t.replace(/병어리/g, "벙어리");

  // '어머니와/어머니의' 혼용 정리: ‘어머니의 벙어리 장갑’이 표준
  // 뒤에 '벙어리 장갑'이 붙어있다면 앞 키워드를 '어머니의'로 통일
  t = t.replace(/어머니(?:와|에)\s*벙어리\s*장갑/g, "어머니의 벙어리 장갑");

  // 전체 표준 타이틀 매핑(필요시 확장)
  const TABLE = {
    "어머니의 벙어리 장갑": "어머니의 벙어리 장갑",
    "아버지와 결혼식": "아버지와 결혼식",
    "아들의 호빵": "아들의 호빵",
    "할머니와 바나나": "할머니와 바나나",
    "꽁당 보리밥": "꽁당 보리밥",
  };

  // 부분 일치 보정 (오탈자/공백이 조금 달라도 흡수)
  const candidates = Object.keys(TABLE);
  for (const k of candidates) {
    const rx = new RegExp("^" + k.replace(/\s+/g, "\\s*") + "$");
    if (rx.test(t)) return TABLE[k];
  }

  // 대표 패턴들
  if (/벙어리\s*장갑/.test(t)) return "어머니의 벙어리 장갑";
  if (/결혼식/.test(t) && /아버지/.test(t)) return "아버지와 결혼식";
  if (/호빵/.test(t)) return "아들의 호빵";
  if (/바나나/.test(t)) return "할머니와 바나나";
  if (/꽁당\s*보리밥|공동보리밥|꽁당보리밥/.test(t)) return "꽁당 보리밥";

  // 모르면 원문 정리본
  return t;
}

function nowKstString() {
  const d = new Date();
  const k = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  const pad = (n) => String(n).padStart(2, "0");
  return `${k.getUTCFullYear()}-${pad(k.getUTCMonth() + 1)}-${pad(k.getUTCDate())} ${pad(k.getUTCHours())}:${pad(k.getUTCMinutes())}:${pad(k.getUTCSeconds())}`;
}

export default function ResultExam() {
  const { scoreAD, scoreAI, scoreB, scoreC, scoreD } = useScores();
  const [bookTitle, setBookTitle] = useState("");
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  const savedOnceRef = useRef(false);
  const navigate = useNavigate();

  // URL 쿼리 user_key (guest는 무시)
  const urlUserKey = (() => {
    const qs = new URLSearchParams(window.location.search);
    const v = (qs.get("user_key") || qs.get("userKey") || "").trim();
    return v && v.toLowerCase() !== "guest" ? v : "";
  })();

  useEffect(() => {
    AOS.init();
    setBookTitle(localStorage.getItem("bookTitle") || "동화");
    const onResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);

  // 점수 요약
  const { total, isPassed, lowIndex } = useMemo(() => {
    const sAD = Number(scoreAD) * 2;
    const sAI = Number(scoreAI) * 2;
    const sB  = Number(scoreB)  * 2;
    const sC  = Number(scoreC)  * 2;
    const sD  = Number(scoreD)  * 2;
    const arr = [sAD, sAI, sB, sC, sD];
    const total = arr.reduce((a, b) => a + b, 0);
    const minScore = Math.min(...arr);
    const lowIndex = arr.indexOf(minScore);
    const isPassed = total >= 28;
    return { total, isPassed, lowIndex };
  }, [scoreAD, scoreAI, scoreB, scoreC, scoreD]);

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

  // 저장: 표준 제목으로 storyKey/Title을 통일하여 전송
  const saveToBookHistory = async () => {
    if (savedOnceRef.current) return;
    savedOnceRef.current = true;

    try {
      const rawTitle = localStorage.getItem("bookTitle") || "동화";
      const canonical = canonicalizeTitle(rawTitle);

      // user_key 확보(guest 금지)
      let targetUserKey =
        urlUserKey ||
        (await ensureUserKey({ retries: 3, delayMs: 200 })) ||
        "";

      if (!targetUserKey || targetUserKey.toLowerCase() === "guest") {
        alert("로그인이 필요합니다. 로그인 후 다시 시도해주세요.");
        return;
      }

      const examResult = {
        storyTitle: canonical,
        storyKey:   canonical,                 // ★ 앱과 동일하게 한글 제목을 key로 사용
        attemptTime: new Date().toISOString(), // 서버에서 DATETIME 변환(없어도 now로 보정)
        clientKst:   nowKstString(),
        score: total,
        total: 40,
        byCategory: {
          A:  { correct: Number(scoreAD), total: 4 },
          AI: { correct: Number(scoreAI), total: 4 },
          B:  { correct: Number(scoreB),  total: 4 },
          C:  { correct: Number(scoreC),  total: 4 },
          D:  { correct: Number(scoreD),  total: 4 },
        },
        byType: {},
        // 앱과 같은 포맷(0~8 점수)을 riskBars에 동봉
        riskBars: {
          A:  Number(scoreAD) * 2,
          AI: Number(scoreAI) * 2,
          B:  Number(scoreB)  * 2,
          C:  Number(scoreC)  * 2,
          D:  Number(scoreD)  * 2,
        },
        riskBarsByType: {},
      };

      // params + header 둘 다 user_key 명시 (쿠키 불안정 대비)
      const { data } = await API.post("/str/attempt", examResult, {
        params:  { user_key: targetUserKey },
        headers: { "x-user-key": targetUserKey },
      });

      if (!data?.ok) {
        console.error("검사 결과 저장 실패:", data);
        alert("검사 결과 저장에 실패했습니다.");
        return;
      }
    } catch (error) {
      console.error("검사 결과 저장 오류:", error);
      alert("검사 결과 저장 중 오류가 발생했습니다.");
    }
  };

  // 첫 렌더에서 한 번만 저장
  useEffect(() => {
    if (total > 0) {
      const onceFlag = sessionStorage.getItem("examCompleted");
      if (!onceFlag) {
        (async () => {
          await saveToBookHistory();
          sessionStorage.setItem("examCompleted", "true");
        })();
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [total]);

  const goHome = () => {
    location.href = "/";
  };

  return (
    <div className="content">
      {windowWidth > 1100 && <Background />}
      <div className="wrap">
        <Header title={canonicalizeTitle(bookTitle)} showBack={false} />
        <div className="inner">
          <div className="ct_banner">화행검사 결과화면</div>
          <div className="ct_inner">
            <div className="ct_question" data-aos="fade-up" data-aos-duration="1000">
              <div>
                <div className="tit">총점</div>
                <div
                  className="sub_tit"
                  id="score"
                  style={{
                    margin: "0 auto",
                    textAlign: "center",
                    borderRadius: "10px",
                    backgroundColor: "white",
                    padding: "20px 0",
                  }}
                >
                  <p>{total} / 40</p>
                </div>
              </div>

              <div>
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
                    id="isPassed"
                    src={isPassed ? "/drawable/speech_clear.png" : "/drawable/speech_fail.png"}
                    className="container"
                    style={{ width: "15%" }}
                    alt=""
                  />
                </div>
              </div>

              <div>
                <div className="tit">검사 결과 평가</div>
                <div className="sub_tit">
                  <div className="num_tit">
                    <p id="opinions_result" style={{ lineHeight: 1.6, whiteSpace: "pre-line" }}>
                      {isPassed ? okOpinion : opinions_result[lowIndex]}
                    </p>
                    {!isPassed && (
                      <p className="num" id="opinions_guide">
                        {opinions_guide[lowIndex]}
                      </p>
                    )}
                  </div>
                </div>
              </div>

              <button className="question_bt" type="button" onClick={goHome}>
                홈으로
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
