import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import Background from "../Background/Background";
import Logo from "../../components/Logo.jsx";
import axios from "axios";

const API = axios.create({
  baseURL: "http://localhost:3001",
  withCredentials: true,
  headers: { "Content-Type": "application/json" },
});

const Login = () => {
  const navigate = useNavigate();
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [nick, setNick] = useState("");

  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  useEffect(() => {
    (async () => {
      try {
        const { data } = await API.get("/userLogin/me");
        if (data?.ok && data.isAuthed) {
          setNick(data.nick || "");
          navigate("/");
        } else {
          setNick("");
        }
      } catch {
        setNick("");
      }
    })();
  }, [navigate]);

  const handleLogin = async () => {
    try {
      const login_id = (phone || "").trim();
      const pwd = (password || "").trim();

      if (!login_id || !pwd) {
        alert("전화번호와 비밀번호를 모두 입력하세요.");
        return;
      }

      const { data } = await API.post("/userLogin/login", { login_id, pwd });
      if (data?.ok) {
        setNick(data.nick || "");
        navigate("/");
      } else {
        alert(data?.msg || "로그인 실패");
      }
    } catch (err) {
      const msg =
        err?.response?.data?.msg ||
        (err?.response?.status === 400
          ? "요청 형식이 올바르지 않습니다."
          : "로그인 중 오류가 발생했습니다.");
      console.error("로그인 오류:", err);
      alert(msg);
    }
  };

  // SNS 시작 (백엔드 OAuth 시작 URL로 이동)
  const startKakao  = () => (window.location.href = "http://localhost:3001/auth/kakao");
  const startNaver  = () => (window.location.href = "http://localhost:3001/auth/naver");
  const startGoogle = () => (window.location.href = "http://localhost:3001/auth/google");

  const socialBtnStyle = (bgColor, color = "#000") => ({
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    gap: "10px",
    backgroundColor: bgColor,
    color: color,
    padding: "15px",
    borderRadius: "12px",
    fontWeight: "bold",
    cursor: "pointer",
    width: "100%",
    transition: "all 0.2s",
    fontSize: "18px",
  });
  const socialIconStyle = { width: "24px", height: "24px" };
  const inputStyle = {
    width: "100%",
    padding: "15px",
    fontSize: "18px",
    borderRadius: "12px",
    border: "1px solid #ccc",
    boxSizing: "border-box",
    display: "block",
  };
  const buttonStyle = (bgColor) => ({
    width: "100%",
    padding: "15px",
    fontSize: "20px",
    backgroundColor: bgColor,
    color: "#fff",
    border: "none",
    borderRadius: "12px",
    cursor: "pointer",
    transition: "all 0.2s",
    textAlign: "center",
    display: "block",
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
          paddingTop: "80px",
          fontFamily: "Pretendard-Regular",
        }}
      >
        <Logo
          src="/img/logo.png"
          alt="말해봄 로고"
          style={{
            width: "200px",
            height: "200px",
            objectFit: "contain",
            display: "block",
            margin: "0 auto 20px auto",
          }}
        />

        <h6 style={{ fontSize: "30px", color: "#000", textAlign: "center", marginBottom: "10px" }}>
          나를 지키는 특별한 습관
        </h6>
        <p style={{ fontSize: "26px", color: "#000", textAlign: "center", marginBottom: "30px" }}>
          지금 시작하세요!
        </p>

        <div
          style={{
            background: "#fff",
            padding: "15px 10px",
            borderRadius: "15px",
            boxShadow: "0 4px 12px rgba(0,0,0,0.1)",
            display: "flex",
            flexDirection: "column",
            gap: "15px",
            maxWidth: "400px",
            margin: "0 auto",
          }}
        >
          <button style={socialBtnStyle("#F7E600")} onClick={startKakao}>
            <img src="/img/kakao.png" alt="카카오" style={socialIconStyle} />
            카카오로 시작하기
          </button>
          <button style={socialBtnStyle("#00C73C", "#fff")} onClick={startNaver}>
            <img src="/img/naver.png" alt="네이버" style={socialIconStyle} />
            네이버로 시작하기
          </button>
          <button style={socialBtnStyle("#000", "#fff")} onClick={startGoogle}>
            <img src="/img/google.png" alt="구글" style={socialIconStyle} />
            구글로 시작하기
          </button>

          <input
            type="text"
            placeholder="전화번호"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            style={inputStyle}
          />
          <input
            type="password"
            placeholder="비밀번호"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            style={inputStyle}
          />

          <button
            style={buttonStyle("#4a85d1")}
            onMouseEnter={(e) => handleMouseEnter(e, "#5f9cec")}
            onMouseLeave={(e) => handleMouseLeave(e, "#4a85d1")}
            onClick={handleLogin}
          >
            로그인
          </button>
        </div>

        <p style={{ textAlign: "center", fontSize: "16px", marginTop: "20px", width: "100%", display: "block" }}>
          아직 계정이 없으신가요?{" "}
          <span
            style={{
              color: "#4a85d1",
              cursor: "pointer",
              fontWeight: "bold",
              display: "inline-block",
              marginLeft: "5px",
            }}
            onClick={() => navigate("/join")}
          >
            회원가입
          </span>
        </p>
      </div>
    </div>
  );
};

export default Login;
