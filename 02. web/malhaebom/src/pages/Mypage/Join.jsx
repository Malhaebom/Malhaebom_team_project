<<<<<<< HEAD
// src/pages/Join.jsx
import React, { useState } from "react";
=======
import React, { useState, useEffect } from "react";
>>>>>>> 35b679a0e8a44e8eb4031d1f8d3833f107a499be
import { useNavigate } from "react-router-dom";
import Background from "../Background/Background";
import axios from "axios";

const API = axios.create({
  baseURL: "http://localhost:3001",
  withCredentials: true,
  headers: { "Content-Type": "application/json" },
});

const Join = () => {
  const [nick, setNick] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [passwordCheck, setPasswordCheck] = useState("");
  const [birth, setBirth] = useState("");
  const [gender, setGender] = useState("");
  const navigate = useNavigate();

  // 브라우저 가로 폭 상태
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);

  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  const labelStyle = {
    fontSize: "16px",
    fontWeight: "600",
    fontFamily: "Pretendard-Regular, -apple-system, BlinkMacSystemFont, sans-serif",
    marginBottom: "6px",
    display: "block",
    color: "#4a5568",
    letterSpacing: "0.025em",
    textTransform: "uppercase",
  };

  const inputStyle = {
    width: "100%",
    padding: "14px 16px",
    borderRadius: "12px",
    border: "2px solid #e2e8f0",
    fontSize: "15px",
    marginBottom: "24px",
    backgroundColor: "#f8fafc",
    color: "#1a202c",
    transition: "all 0.2s ease",
    fontFamily: "Pretendard-Regular, sans-serif",
    outline: "none",
  };

  const genderButtonStyle = (selected, type) => {
    let activeColor = type === "male" ? "#4a85d1" : "#f06292";
    return {
      flex: 1,
      padding: "15px",
      fontSize: "18px",
      borderRadius: "12px",
      border: selected ? `2px solid ${activeColor}` : "1px solid #ccc",
      backgroundColor: selected ? activeColor : "#f9f9f9",
      color: selected ? "#fff" : "#333",
      cursor: "pointer",
      textAlign: "center",
      margin: "0 5px",
      transition: "all 0.2s",
    };
  };

  const submit = async () => {
    try {
      if (!nick || !phone || !password || !birth || !gender) {
        alert("필수 항목을 모두 입력하세요.");
        return;
      }
      if (password !== passwordCheck) {
        alert("비밀번호가 일치하지 않습니다.");
        return;
      }

      const payload = {
        phone,       // user_id로 사용
        pwd: password,
        nick,
        birth,       // YYYY-MM-DD → 서버에서 YEAR만 저장
        gender,      // male/female → 서버에서 M/F 변환
      };

      const { data } = await API.post("/userJoin/register", payload);
      if (data?.ok) {
        alert("회원가입이 완료되었습니다. 로그인해 주세요.");
        navigate("/login");
      } else {
        alert(data?.msg || "회원가입 실패");
      }
    } catch (err) {
      console.error("회원가입 오류:", err);
      alert("회원가입 중 오류가 발생했습니다.");
    }
  };

  return (
    <div className="content">
      {/* 브라우저 가로 1100 이상일 때만 배경 렌더링 */}
      {windowWidth > 1100 && <Background />}

      <div
        className="wrap"
        style={{
          maxWidth: "520px",
          margin: "0 auto",
          paddingTop: "80px",
          paddingLeft: "20px",
          paddingRight: "20px",
          fontFamily: "Pretendard-Regular",
        }}
      >
        {/* 타이틀 */}
        <h2
          style={{
            textAlign: "center",
            marginBottom: "40px",
            fontFamily: "Pretendard-Bold, -apple-system, BlinkMacSystemFont, sans-serif",
            fontSize: "32px",
            fontWeight: "800",
            color: "#2d3748",
            letterSpacing: "-0.02em",
            lineHeight: "1.1",
          }}
        >
          회원가입
        </h2>

        {/* 테두리 박스 컨테이너 */}
        <div
          style={{
            border: "2px solid rgba(255, 255, 255, 0.8)",
            borderRadius: "15px",
            padding: "30px",
            margin: "0 5%",
            background: "rgba(255, 255, 255, 0.9)",
            boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15), inset 0 1px 0 rgba(255, 255, 255, 0.3)",
          }}
        >
          {/* 닉네임 */}
          <label style={labelStyle}>닉네임</label>
          <input
            type="text"
            value={nick}
            onChange={(e) => setNick(e.target.value)}
            style={inputStyle}
            placeholder="닉네임을 입력하세요"
          />

          {/* 휴대전화번호 */}
          <label style={labelStyle}>휴대전화번호</label>
          <input
            type="text"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            style={inputStyle}
            placeholder="휴대전화번호를 입력하세요"
          />

          {/* 비밀번호 */}
          <label style={labelStyle}>비밀번호</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            style={inputStyle}
            placeholder="비밀번호를 입력하세요"
          />

          {/* 비밀번호 확인 */}
          <label style={labelStyle}>비밀번호 확인</label>
          <input
            type="password"
            value={passwordCheck}
            onChange={(e) => setPasswordCheck(e.target.value)}
            style={inputStyle}
            placeholder="비밀번호를 다시 입력하세요"
          />

          {/* 생년월일 */}
          <label style={labelStyle}>생년월일</label>
          <input
            type="date"
            value={birth}
            onChange={(e) => setBirth(e.target.value)}
            style={inputStyle}
          />

          {/* 성별 */}
          <label style={labelStyle}>성별</label>
          <div style={{ display: "flex", marginBottom: "20px" }}>
            <div
              style={genderButtonStyle(gender === "male", "male")}
              onClick={() => setGender("male")}
            >
              남성
            </div>
            <div
              style={genderButtonStyle(gender === "female", "female")}
              onClick={() => setGender("female")}
            >
              여성
            </div>
          </div>

          {/* 회원가입 버튼 */}
          <button
            style={{
              width: "100%",
              padding: "15px",
              fontSize: "18px",
              fontWeight: "bold",
              color: "#fff",
              backgroundColor: "#4a85d1",
              borderRadius: "10px",
              border: "none",
              cursor: "pointer",
              transition: "all 0.2s",
            }}
            onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = "#5f9cec")}
            onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = "#4a85d1")}
<<<<<<< HEAD
            onClick={submit}
=======
>>>>>>> 35b679a0e8a44e8eb4031d1f8d3833f107a499be
          >
            회원가입
          </button>

          {/* 로그인 안내 */}
          <div
            style={{
              marginTop: "12px",
              marginBottom: "3px",
              textAlign: "center",
              fontSize: "14px",
              color: "#64748b",
              fontFamily: "Pretendard-Regular, sans-serif",
              lineHeight: "1.5",
            }}
          >
            계정을 보유하고 계신가요?{" "}
            <span
              style={{
                color: "#4a85d1",
                fontWeight: "600",
                cursor: "pointer",
                textDecoration: "underline",
                textUnderlineOffset: "2px",
                transition: "color 0.2s ease",
              }}
              onMouseEnter={(e) => (e.currentTarget.style.color = "#3182ce")}
              onMouseLeave={(e) => (e.currentTarget.style.color = "#4a85d1")}
              onClick={() => navigate("/login")}
            >
              로그인
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Join;
