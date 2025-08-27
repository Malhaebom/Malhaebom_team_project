import React, { useState } from "react";
import { useNavigate } from "react-router-dom"; // ✅ 추가
import Background from "../Background/Background";


const Signup = () => {
  const [nick, setNick] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [passwordCheck, setPasswordCheck] = useState("");
  const [birth, setBirth] = useState("");
  const [gender, setGender] = useState("");
  const navigate = useNavigate(); // ✅ 네비게이트 훅

  const labelStyle = {
    fontSize: "16px",
    fontWeight: "bold",
    marginBottom: "8px",
    display: "block",
  };

  const inputStyle = {
    width: "100%",
    padding: "12px",
    borderRadius: "10px",
    border: "1px solid #ccc",
    fontSize: "16px",
    marginBottom: "20px",
  };

  const genderButtonStyle = (selected, type) => {
    let activeColor = type === "male" ? "#4a85d1" : "#f06292"; // 남: 파랑, 여: 분홍
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

  return (
    <div
      style={{
        maxWidth: "520px",
        margin: "0 auto",
        padding: "50px 20px",
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
        회원가입
      </h2>

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
        onMouseEnter={(e) =>
          (e.currentTarget.style.backgroundColor = "#5f9cec")
        }
        onMouseLeave={(e) =>
          (e.currentTarget.style.backgroundColor = "#4a85d1")
        }
      >
        회원가입
      </button>

      {/* 로그인 안내 */}
      <div
        style={{
          marginTop: "20px",
          textAlign: "center",
          fontSize: "14px",
        }}
      >
        계정을 보유하고 계신가요?{" "}
        <span
          style={{
            color: "#4a85d1",
            fontWeight: "bold",
            cursor: "pointer",
          }}
          onClick={() => navigate("/login")} // ✅ 로그인 페이지 이동
        >
          로그인
        </span>
      </div>
    </div>
  );
};

export default Signup;
