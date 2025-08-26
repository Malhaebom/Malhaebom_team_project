import React from "react";
import { useLocation, useNavigate } from "react-router-dom";

export default function QuizResult() {
  const location = useLocation();
  const navigate = useNavigate();

  const {
    submitDataArr = [],
    answerDataArr = [],
    currentTopicArr = [],
    quizType
  } = location.state || {};
  const quizTitle = location.state?.quizTitle || "퀴즈";


  const correctCount = answerDataArr.filter((ans, idx) => ans === submitDataArr[idx]).length;

  return (
    <div className="content">
      <div className="wrap">
        <header>
          <div className="hd_inner"><div className="hd_tit">퀴즈 결과</div></div>
        </header>

        <div className="inner">
          <div className="text-center mb-4">
            <h3>{quizTitle} 테스트 결과</h3>
            <p style={{ fontSize: "18px", marginTop: "8px" }}>
              {answerDataArr.length}개 중 <span style={{ color: "#007bff", fontWeight: "bold" }}>{correctCount}개</span>를 맞췄어요!
            </p>
          </div>
          {/* 문제별 결과 */}
          <div className="result-list">
            {currentTopicArr.map((q, idx) => {
              const isCorrect = answerDataArr[idx] === submitDataArr[idx];
              return (
                <div key={idx} className="result-item" style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "12px", borderBottom: "1px solid #eee" }}>
                  <div style={{ display: "flex", alignItems: "center" }}>
                    <img src={isCorrect ? "/img/o-color.png" : "/img/x-color.png"} alt={isCorrect ? "정답" : "오답"} style={{ width: 24, height: 24, marginRight: 12 }} />
                    <div>
                      <div style={{ fontWeight: "bold" }}>LEVEL {idx + 1}</div>
                      <div style={{ fontSize: "14px", color: "#666" }}>{q?.question?.[0]?.title}</div>
                    </div>
                  </div>
                  <div style={{ fontSize: "18px", color: "#999" }}>›</div>
                </div>
              );
            })}
          </div>
          {/* 버튼 */}
          <div style={{ marginTop: "24px", textAlign: "center" }}>
            <button style={{ width: "100%", padding: "12px", marginBottom: "12px", background: "#007bff", color: "white", border: "none", borderRadius: "8px", fontSize: "16px" }} onClick={() => navigate("/")}>홈으로</button>
            <button style={{ width: "100%", padding: "12px", background: "#eee", color: "#333", border: "none", borderRadius: "8px", fontSize: "16px" }} onClick={() => navigate("/quiz/play?quizType=" + (quizType ?? 0))}>다시 풀기</button>
          </div>
        </div>
      </div>
    </div>
  );
}
