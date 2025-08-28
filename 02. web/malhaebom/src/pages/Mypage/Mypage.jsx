import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import Background from "../Background/Background";

const Mypage = () => {
  const navigate = useNavigate();
  const [nick, setNick] = useState("홍길동"); // 실제 로그인 정보로 변경 가능

  // 브라우저 가로 폭 상태
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);

  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

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
    <div className="content">
      {windowWidth > 1100 && <Background />}

      <div
        className="wrap"
        style={{
          maxWidth: "520px",
          margin: "0 auto",
          padding: "80px 20px",
          fontFamily: "Pretendard-Regular",
        }}
      >
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
          {/* 로그인 하러가기 버튼 */}
          <button
            style={buttonStyle("#488eca", "#3a72a8")}
            onMouseEnter={(e) => handleMouseEnter(e, "#3a72a8")}
            onMouseLeave={(e) => handleMouseLeave(e, "#488eca")}
            onClick={() => navigate("/login")}
          >
            로그인 하러가기
          </button>

          {/* 동화 화행검사 결과 이동 */}
          <button
            style={buttonStyle("#8d61ac", "#6f4988")}
            onMouseEnter={(e) => handleMouseEnter(e, "#6f4988")}
            onMouseLeave={(e) => handleMouseLeave(e, "#8d61ac")}
            onClick={() => navigate("/bookHistory")}
          >
            동화 화행검사 결과
          </button>

          {/* 인지능력검사 결과 이동 */}
          <button
            style={buttonStyle("#a93c7b", "#862d5f")}
            onMouseEnter={(e) => handleMouseEnter(e, "#862d5f")}
            onMouseLeave={(e) => handleMouseLeave(e, "#a93c7b")}
            onClick={() => navigate("/InterviewHistory")}
          >
            인지능력검사 결과
          </button>
        </div>
      </div>
    </div>
  );
};

export default Mypage;
