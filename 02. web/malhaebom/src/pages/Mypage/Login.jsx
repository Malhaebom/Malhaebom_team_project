import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import Background from "../Background/Background";

const Login = () => {
  const navigate = useNavigate();
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [nick, setNick] = useState(""); // 로그인 후 닉네임

  const handleLogin = () => {
    console.log("로그인 버튼 클릭", { phone, password });
    // 로그인 성공 시 닉네임 설정
    setNick("홍길동");
    navigate("/mypage");
  };

  const handleLogout = () => {
    console.log("로그아웃 클릭");
    setNick("");
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
    maxWidth: "320px",
    margin: "0 auto",
    transition: "all 0.2s",
    fontSize: "18px",
  });

  const socialIconStyle = { width: "24px", height: "24px" };

  const inputStyle = {
    width: "100%",
    maxWidth: "320px",
    padding: "15px",
    fontSize: "18px",
    borderRadius: "12px",
    border: "1px solid #ccc",
    boxSizing: "border-box",
    display: "block",
  };

  const buttonStyle = (bgColor, hoverColor) => ({
    width: "100%",
    maxWidth: "320px",
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
            {/* 소셜 로그인 */}
            <div
              style={{
                display: "flex",
                flexDirection: "column",
                gap: "12px",
                marginBottom: "20px",
              }}
            >
              <button style={socialBtnStyle("#F7E600")}>
                <img src="/img/kakao.png" alt="카카오" style={socialIconStyle} />
                카카오로 시작하기
              </button>
              <button style={socialBtnStyle("#00C73C", "#fff")}>
                <img src="/img/naver.png" alt="네이버" style={socialIconStyle} />
                네이버로 시작하기
              </button>
              <button style={socialBtnStyle("#000", "#fff")}>
                <img src="/img/google.png" alt="구글" style={socialIconStyle} />
                구글로 시작하기
              </button>
            </div>

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
          </>
        )}

        {/* 로그아웃 버튼 */}
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
