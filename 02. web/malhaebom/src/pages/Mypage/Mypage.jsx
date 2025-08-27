import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import Background from "../Background/Background";


const Mypage = () => {
  const navigate = useNavigate();
  const [nick, setNick] = useState("홍길동"); // 실제 로그인 정보로 변경 가능

  // 버튼 스타일 함수
  const buttonStyle = (bgColor, hoverColor) => ({
    width: "100%",
    padding: "15px",
    fontSize: "18px",
    fontWeight: "bold",
    color: "#fff",
    backgroundColor: bgColor,
    borderRadius: "10px",
    border: "none",
    cursor: "pointer",
    transition: "all 0.2s",
    textAlign: "center",
  });

  const handleMouseEnter = (e, hoverColor) =>
    (e.currentTarget.style.backgroundColor = hoverColor);
  const handleMouseLeave = (e, bgColor) =>
    (e.currentTarget.style.backgroundColor = bgColor);

  return (
    <div
      style={{
        maxWidth: "520px",
        margin: "0 auto",
        padding: "80px 20px",
        fontFamily: "Pretendard-Regular",
      }}
    >
      {/* 타이틀 */}
      <h2
        style={{
          textAlign: "center",
          marginBottom: "30px",
          fontFamily: "ONE-Mobile-Title",
          fontSize: "32px",
        }}
      >
        마이페이지
      </h2>

      {/* 환영 문구 */}
      {nick && (
        <p
          style={{
            textAlign: "center",
            marginBottom: "30px",
            fontSize: "18px",
            fontWeight: "bold",
            color: "#344CB7",
          }}
        >
          {nick}님 환영합니다!
        </p>
      )}

      {/* 버튼 컨테이너 */}
      <div
        style={{
          background: "#fff",
          padding: "30px 20px",
          borderRadius: "15px",
          boxShadow: "0 4px 12px rgba(0,0,0,0.1)",
          display: "flex",
          flexDirection: "column",
          gap: "15px",
        }}
      >
        {/* 로그인 이동 버튼 */}
        <button
          style={buttonStyle("#4a85d1", "#5f9cec")}
          onMouseEnter={(e) => handleMouseEnter(e, "#5f9cec")}
          onMouseLeave={(e) => handleMouseLeave(e, "#4a85d1")}
          onClick={() => navigate("/login")}
        >
          로그인 하러가기
        </button>

        {/* 동화 화행검사 결과 이동 */}
        <button
          style={buttonStyle("#4E6C50", "#3f5a41")}
          onMouseEnter={(e) => handleMouseEnter(e, "#3f5a41")}
          onMouseLeave={(e) => handleMouseLeave(e, "#4E6C50")}
          onClick={() => navigate("/bookHistory")}
        >
          동화 화행검사 결과
        </button>

        {/* 인지능력검사 결과 이동 */}
        <button
          style={buttonStyle("#9C27B0", "#7B1FA2")}
          onMouseEnter={(e) => handleMouseEnter(e, "#7B1FA2")}
          onMouseLeave={(e) => handleMouseLeave(e, "#9C27B0")}
          onClick={() => navigate("/InterviewHistory")}
        >
          인지능력검사 결과
        </button>
      </div>
    </div>
  );
};

export default Mypage;
