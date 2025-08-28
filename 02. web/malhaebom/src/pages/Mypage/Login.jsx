import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import Background from "../Background/Background";
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
  const [nick, setNick] = useState(""); // 로그인 후 닉네임

  // 로그인 상태 복구: 이미 로그인되어 /login에 오면 홈으로 보냄
  useEffect(() => {
    (async () => {
      try {
        const { data } = await API.get("/userLogin/me");
        if (data?.ok && data.isAuthed) {
          setNick(data.nick || "");
          navigate("/"); // ✅ 이미 로그인 상태면 홈으로
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
      const user_id = (phone || "").trim();
      const pwd = (password || "").trim();

      if (!user_id || !pwd) {
        alert("전화번호와 비밀번호를 모두 입력하세요.");
        return;
      }

      const { data } = await API.post("/userLogin/login", {
        user_id, // 서버에서 받는 키로 고정
        pwd,
      });

      if (data?.ok) {
        setNick(data.nick || "");
        navigate("/"); // ✅ 로그인 성공 후 홈으로 이동
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

  const handleLogout = async () => {
    try {
      await API.post("/userLogin/logout");
      setNick("");
      setPhone("");
      setPassword("");
    } catch (err) {
      console.error("로그아웃 오류:", err);
    }
  };

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

  const buttonStyle = (bgColor, hoverColor) => ({
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

  // SNS 시작 (백엔드 OAuth 시작 URL로 이동)
  const startKakao = () => (window.location.href = "http://localhost:3001/auth/kakao");
  const startNaver = () => (window.location.href = "http://localhost:3001/auth/naver");
  const startGoogle = () => (window.location.href = "http://localhost:3001/auth/google");

  return (
    <div className="content">
      {/* 공통 배경 */}
      <Background />

      <div
        className="wrap"
        style={{
          maxWidth: "520px",
          margin: "0 auto",
          paddingTop: "80px",
          fontFamily: "Pretendard-Regular",
        }}
      >
        {/* 로그인 후 환영 문구 */}
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

        {/* 로고 */}
        <img
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

        <h6
          style={{
            fontSize: "30px",
            color: "#000",
            textAlign: "center",
            marginBottom: "10px",
          }}
        >
          나를 지키는 특별한 습관
        </h6>
        <p
          style={{
            fontSize: "26px",
            color: "#000",
            textAlign: "center",
            marginBottom: "30px",
          }}
        >
          지금 시작하세요!
        </p>

        {!nick && (
          <>
            {/* 흰색 카드 컨테이너 - 디자인 유지 */}
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

              {/* 입력칸 */}
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

              {/* 로그인 버튼 */}
              <button
                style={buttonStyle("#4a85d1", "#5f9cec")}
                onMouseEnter={(e) => handleMouseEnter(e, "#5f9cec")}
                onMouseLeave={(e) => handleMouseLeave(e, "#4a85d1")}
                onClick={handleLogin}
              >
                로그인
              </button>
            </div>
          </>
        )}

        {/* 로그아웃 버튼 (로그인 시에만 표시) */}
        {nick && (
          <button
            style={buttonStyle("#FF4D4D", "#d13c3c")}
            onMouseEnter={(e) => handleMouseEnter(e, "#d13c3c")}
            onMouseLeave={(e) => handleMouseLeave(e, "#FF4D4D")}
            onClick={handleLogout}
          >
            로그아웃
          </button>
        )}

        {/* 회원가입 */}
        <p
          style={{
            textAlign: "center",
            fontSize: "16px",
            marginTop: "20px",
            width: "100%",
            display: "block",
          }}
        >
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
