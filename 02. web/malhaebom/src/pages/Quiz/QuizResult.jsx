import React, { useState, useEffect } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import Background from "../Background/Background";

export default function QuizResult() {
  const location = useLocation();
  const navigate = useNavigate();

  const state = location.state ?? {};
  const submitDataArr = state.submitDataArr ?? [];
  const answerDataArr = state.answerDataArr ?? [];
  const quizTitle = state.quizTitle ?? "퀴즈";
  const questionArr = state.questionArr ?? [];

  const correctCount = submitDataArr.filter(
    (ans, idx) => ans === answerDataArr[idx]
  ).length;

  const handleRetryQuestion = (idx) => {
    navigate(`/quiz/play?quizType=${state.quizType ?? 0}`, {
      state: {
        ...state,
        retryIndex: idx,
        isRetryMode: true, // ✅ 다시풀기 모드 추가
        submitDataArr: [...submitDataArr],
        answerDataArr: [...answerDataArr],
      },
    });
  };

  const goToQuizPlay = (quizType) =>
    navigate(`/quiz/play?quizType=${quizType}&quizId=0&qid=0`, {
      state: {
        submitDataArr: [...submitDataArr],
        answerDataArr: [...answerDataArr],
      },
    });

  // ✅ 브라우저 가로 너비 상태
  const [isWide, setIsWide] = useState(window.innerWidth > 1100);

  useEffect(() => {
    const handleResize = () => setIsWide(window.innerWidth > 1100);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  return (
    <div className="content">
      {/* ✅ 1100px 이상일 때만 Background 렌더링 */}
      {isWide && <Background />}

      <div className="wrap">
        <header>
          <div className="hd_inner">
            <div className="hd_tit">두뇌 단련</div>
          </div>
        </header>

        <div className="inner">
          <p
            style={{
              textAlign: "center",
              fontSize: "34px",
              margin: "20px 0",
            }}
          >
            {quizTitle} 영역 테스트 결과
            <br />
            <span style={{ fontWeight: "bold" }}>
              {submitDataArr.length}개 중{" "}
              <span style={{ color: "#488eca" }}>{correctCount}개</span>를
              맞췄어요!
            </span>
          </p>

          <div
            style={{
              background: "#fff",
              borderRadius: "10px",
              overflow: "hidden",
              boxShadow: "0px 0px 6px rgba(0,0,0,.05)",
            }}
          >
            {questionArr.map((questionItem, idx) => {
              const submitted = submitDataArr[idx];
              const answer = answerDataArr[idx];
              const isAnswered = submitted !== undefined;
              const isCorrect = submitted === answer;
              const qTitle = questionItem?.question?.[0]?.title ?? "문제";

              return (
                <div
                  key={idx}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "space-between",
                    borderBottom:
                      idx !== questionArr.length - 1 ? "1px solid #eee" : "none",
                    padding: "12px",
                    cursor: "pointer",
                  }}
                  onClick={() => handleRetryQuestion(idx)}
                >
                  <div style={{ display: "flex", alignItems: "center" }}>
                    {isAnswered ? (
                      <img
                        src={isCorrect ? "/img/o-color.png" : "/img/x-color.png"}
                        alt={isCorrect ? "O" : "X"}
                        style={{
                          width: "20px",
                          height: "20px",
                          marginRight: "8px",
                        }}
                      />
                    ) : (
                      <span
                        style={{
                          display: "inline-block",
                          width: "20px",
                          height: "20px",
                          marginRight: "8px",
                          textAlign: "center",
                          color: "#ccc",
                          fontSize: "14px",
                        }}
                      >
                        -
                      </span>
                    )}
                    <div>
                      <p
                        style={{
                          margin: 0,
                          fontWeight: "bold",
                          fontSize: "1em",
                        }}
                      >
                        LEVEL {idx + 1}
                      </p>
                      <p
                        style={{
                          margin: 0,
                          fontSize: ".9em",
                          color: "#3f3f3fff",
                        }}
                      >
                        {qTitle}
                      </p>
                    </div>
                  </div>
                  <img
                    src="/img/arrow.png"
                    alt="화살표"
                    style={{ width: "18px", height: "18px" }}
                  />
                </div>
              );
            })}
          </div>

          <div
            style={{
              marginTop: "20px",
              display: "flex",
              flexDirection: "column",
              gap: "10px",
            }}
          >
            <button
              onClick={() => navigate("/")}
              style={{
                width: "100%",
                padding: "14px",
                backgroundColor: "#488eca",
                color: "#fff",
                border: "none",
                borderRadius: "5px",
                fontWeight: "bold",
                cursor: "pointer",
              }}
            >
              홈으로
            </button>
            <button
              onClick={() => goToQuizPlay(state.quizType ?? 1)}
              style={{
                width: "100%",
                padding: "14px",
                backgroundColor: "#eee",
                color: "#333",
                border: "none",
                borderRadius: "5px",
                fontWeight: "bold",
                cursor: "pointer",
              }}
            >
              다시 풀기
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
