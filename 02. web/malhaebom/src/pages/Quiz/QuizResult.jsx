import React from "react";
import { useLocation, useNavigate } from "react-router-dom";

export default function QuizResult() {
  const location = useLocation();
  const navigate = useNavigate();

  // QuizPlay에서 전달된 상태 가져오기
  const state = location.state ?? {};
  const submitDataArr = state.submitDataArr ?? [];
  const answerDataArr = state.answerDataArr ?? [];
  const quizTitle = state.quizTitle ?? "퀴즈"; // 전달된 퀴즈 제목

  return (
    <div className="content">
      <div className="wrap">
        <header>
          <h2>{quizTitle} 결과</h2>
        </header>

        <div className="inner">
          {submitDataArr.length === 0 ? (
            <p>퀴즈를 먼저 완료해주세요!</p>
          ) : (
            <>
              <p>문제를 모두 완료했습니다!</p>
              <div className="result_list">
                {submitDataArr.map((submitted, idx) => (
                  <div key={idx} className="result_item">
                    <p>문제 {idx + 1}: 제출: {submitted}, 정답: {answerDataArr[idx]}</p>
                  </div>
                ))}
              </div>
            </>
          )}

          <button onClick={() => navigate("/")}>홈으로 돌아가기</button>
        </div>
      </div>
    </div>
  );
}
