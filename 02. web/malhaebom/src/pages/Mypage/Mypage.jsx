import React, { useState } from "react";
import { useNavigate } from "react-router-dom";

const Mypage = () => {
  const navigate = useNavigate();
  const [nick, setNick] = useState("홍길동"); // 예시, 실제는 로그인 정보 가져오기

  // 버튼 스타일 통합 함수
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

  const handleMouseEnter = (e, hoverColor) => (e.currentTarget.style.backgroundColor = hoverColor);
  const handleMouseLeave = (e, bgColor) => (e.currentTarget.style.backgroundColor = bgColor);

  return (
    <div
      style={{
        maxWidth: "520px",
        margin: "0 auto",
        padding: "80px 20px",
        fontFamily: 'Pretendard-Regular',
      }}
    >
      {/* 타이틀 */}
      <h2
        style={{
          textAlign: "center",
          marginBottom: "30px",
          fontFamily: 'ONE-Mobile-Title',
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

        {/* 이력관리 이동 버튼 */}
        <button
          style={buttonStyle("#4E6C50", "#3f5a41")} // 초록 계열
          onMouseEnter={(e) => handleMouseEnter(e, "#3f5a41")}
          onMouseLeave={(e) => handleMouseLeave(e, "#4E6C50")}
          onClick={() => navigate("/history")}
        >
          이력 관리
        </button>
      </div>
    </div>
  );
};

export default Mypage;
