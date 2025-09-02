import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import Background from "../Background/Background";
import axios from "axios";
import MypageInterviewHistory from "./MypageInterviewHistory.jsx";

const API = axios.create({
  baseURL: "/",                // ← 상대경로 (Nginx 프록시)
  withCredentials: true,
  headers: { "Content-Type": "application/json" },
});

const Mypage = () => {
  const navigate = useNavigate();
  const [nick, setNick] = useState("");

  useEffect(() => {
    (async () => {
      try {
        const { data } = await API.get("/userLogin/me");
        if (data?.ok && data.isAuthed) setNick(data.nick || "");
        else setNick("");
      } catch {
        setNick("");
      }
    })();
  }, []);

  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

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

  const goLogin = () => navigate("/login");
  const goBookHistory = () => navigate("/bookHistory");
  const goInterviewHistory = () => navigate("/mypage-interview-history");

  const logout = async () => {
    try {
      await API.post("/userLogin/logout");
      setNick("");
    } catch (e) {
      console.error("로그아웃 오류:", e);
    }
  };

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

        {nick ? (
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
        ) : (
          <p
            style={{
              textAlign: "center",
              marginBottom: "30px",
              fontSize: "18px",
              color: "#666",
            }}
          >
            로그인 후 이용해 주세요.
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
          {!nick && (
            <button
              style={buttonStyle("#4a85d1", "#5f9cec")}
              onMouseEnter={(e) => handleMouseEnter(e, "#5f9cec")}
              onMouseLeave={(e) => handleMouseLeave(e, "#4a85d1")}
              onClick={goLogin}
            >
              로그인 하러가기
            </button>
          )}

          {nick && (
            <button
              style={buttonStyle("#FF4D4D", "#d13c3c")}
              onMouseEnter={(e) => handleMouseEnter(e, "#d13c3c")}
              onMouseLeave={(e) => handleMouseLeave(e, "#FF4D4D")}
              onClick={logout}
            >
              로그아웃
            </button>
          )}

          <button
            style={buttonStyle("#4E6C50", "#3f5a41")}
            onMouseEnter={(e) => handleMouseEnter(e, "#3f5a41")}
            onMouseLeave={(e) => handleMouseLeave(e, "#4E6C50")}
            onClick={goBookHistory}
          >
            동화 화행검사 결과
          </button>

          <button
            style={buttonStyle("#9C27B0", "#7B1FA2")}
            onMouseEnter={(e) => handleMouseEnter(e, "#7B1FA2")}
            onMouseLeave={(e) => handleMouseLeave(e, "#9C27B0")}
            onClick={goInterviewHistory}
          >
            인지능력검사 결과
          </button>
        </div>
      </div>
    </div>
  );
};

export default Mypage;
