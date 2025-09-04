import React, { useEffect, useMemo, useRef, useState } from "react";
import Header from "../../../../components/Header.jsx";
import AOS from "aos";
import { useNavigate } from "react-router-dom";
import { useScores } from "../../../../ScoreContext.jsx";
import Background from "../../../Background/Background";
import API, { ensureUserKey } from "../../../../lib/api.js";

// 서버와 동일 정규화
function nspace(s){ return String(s||"").replace(/\s+/g," ").trim(); }
function ntitle(s){
  let x = nspace(s);
  x = x.replaceAll("병어리","벙어리");
  x = x.replaceAll("어머니와","어머니의");
  x = x.replaceAll("벙어리장갑","벙어리 장갑");
  x = x.replaceAll("꽁당보리밥","꽁당 보리밥");
  x = x.replaceAll("할머니와바나나","할머니와 바나나");
  return x;
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
  const navigate = useNavigate();
  const savedOnceRef = useRef(false);

  const query = new URLSearchParams(window.location.search);
  const userKeyFromUrl = (query.get("user_key") || "").trim();

  const [windowWidth, setWindowWidth] = useState(window.innerWidth);

  useEffect(() => {
    AOS.init();
    const raw = localStorage.getItem("bookTitle") || "동화";
    const fixed = ntitle(raw);
    setBookTitle(fixed);

    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

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
    "C-단언이 부족습니다.",
    "D-의례화가 부족합니다.",
  ];

  async function saveToBookHistory(resolvedUserKey, axiosCfg = {}) {
    const rawTitle = localStorage.getItem("bookTitle") || "동화";
    const title = ntitle(rawTitle); // "꽁당 보리밥"

    const examResult = {
      storyTitle: title,
      storyKey: title, // 서버가 제목을 저장키로 사용
      attemptTime: new Date().toISOString(),
      clientKst: nowKstString(),
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
      riskBars: {
        A:  Number(scoreAD) * 2,
        AI: Number(scoreAI) * 2,
        B:  Number(scoreB)  * 2,
        C:  Number(scoreC)  * 2,
        D:  Number(scoreD)  * 2,
      },
      riskBarsByType: {},
    };

    const { data } = await API.post("/str/attempt", examResult, axiosCfg);
    if (!data?.ok) {
      console.error("검사 결과 저장 실패:", data);
      alert("검사 결과 저장에 실패했습니다.");
    }
  }

  useEffect(() => {
    (async () => {
      if (savedOnceRef.current) return;
      savedOnceRef.current = true;

      let targetUserKey = userKeyFromUrl && userKeyFromUrl !== "guest" ? userKeyFromUrl : null;
      if (!targetUserKey) {
        targetUserKey = await ensureUserKey({ retries: 3, delayMs: 200 });
      }
      if (!targetUserKey) {
        alert("로그인이 필요합니다. 로그인 후 다시 시도해주세요.");
        return;
      }

      try {
        // 서버가 실제 사용하는 키 조회
        let usedKey = targetUserKey;
        let isAuthed = false;
        try {
          const who = await API.get("/str/whoami", { params:{ user_key: targetUserKey } });
          usedKey = (who?.data?.used || usedKey || "").trim();
          isAuthed = !!who?.data?.isAuthed;
        } catch (_e) {}

        // 쿠키 인증이 있으면 충돌 방지 위해 헤더/쿼리 전달 X
        const cfg = isAuthed ? {} : { params:{ user_key: usedKey }, headers:{ "x-user-key": usedKey } };

        await saveToBookHistory(usedKey, cfg);
      } catch (error) {
        console.error("검사 결과 저장 오류:", error?.response?.data || error);
        alert("검사 결과 저장 중 오류가 발생했습니다.");
      }
    })();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [total]);

  const goHome = () => { location.href = "/"; };

  return (
    <div className="content">
      {windowWidth > 1100 && <Background />}
      <div className="wrap">
        <Header title={bookTitle} showBack={false} />
        <div className="inner">
          <div className="ct_banner">화행검사 결과화면</div>
          <div className="ct_inner">
            <div className="ct_question" data-aos="fade-up" data-aos-duration="1000">
              <div>
                <div className="tit">총점</div>
                <div className="sub_tit" id="score" style={{ margin: "0 auto", textAlign: "center", borderRadius: "10px", backgroundColor: "white", padding: "20px 0" }}>
                  <p>{total} / 40</p>
                </div>
              </div>

              <div>
                <div className="tit">인지능력</div>
                <div style={{ margin: "0 auto", textAlign: "center", borderRadius: "10px", backgroundColor: "white", padding: "20px 0" }}>
                  <img id="isPassed" src={isPassed ? "/drawable/speech_clear.png" : "/drawable/speech_fail.png"} className="container" style={{ width: "15%" }} />
                </div>
              </div>

              <div>
                <div className="tit">검사 결과 평가</div>
                <div className="sub_tit">
                  <div className="num_tit">
                    <p id="opinions_result" style={{ lineHeight: 1.6, whiteSpace: "pre-line" }}>
                      {isPassed
                        ? "당신은 모든 영역(직접화행, 간접화행, 질문화행, 단언화행, 의례화화행)에 좋은 점수를 얻었습니다. 현재는 인지기능 정상입니다.\n하지만 유지하기 위해서 꾸준한 학습과 교육을 통한 관리가 필요합니다."
                        : opinions_result[lowIndex]}
                    </p>
                    {!isPassed && <p className="num" id="opinions_guide">{opinions_guide[lowIndex]}</p>}
                  </div>
                </div>
              </div>

              <button className="question_bt" type="button" onClick={goHome}>홈으로</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
