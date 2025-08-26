import React, { useState } from "react";
import { useNavigate } from "react-router-dom";

const Join = () => {
  const navigate = useNavigate();

  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");

  const handleJoin = () => {
    if (!name || !phone || !password || !confirmPassword) {
      alert("모든 항목을 입력하세요.");
      return;
    }

    if (password !== confirmPassword) {
      alert("비밀번호가 일치하지 않습니다.");
      return;
    }

    alert("회원가입 성공! 로그인 페이지로 이동합니다.");
    navigate("/login");
  };

  const inputStyle = {
    width: "100%",
    padding: "15px",
    fontSize: "18px",
    marginBottom: "15px",
    borderRadius: "12px",
    border: "1px solid #ccc",
    boxSizing: "border-box",
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
    marginBottom: "20px",
    transition: "all 0.2s",
    textAlign: "center",
  });

  const handleMouseEnter = (e, hoverColor) =>
    (e.currentTarget.style.backgroundColor = hoverColor);
  const handleMouseLeave = (e, bgColor) =>
    (e.currentTarget.style.backgroundColor = bgColor);

  return (
    <div className="content">
      <div
        className="wrap"
        style={{
          maxWidth: "520px",
          margin: "0 auto",
          paddingTop: "80px",
          fontFamily: "Pretendard-Regular",
        }}
      >
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
          회원가입
        </h6>
        <p
          style={{
            fontSize: "22px",
            color: "#555",
            textAlign: "center",
            marginBottom: "30px",
          }}
        >
          정보를 입력해 주세요
        </p>

        <input
          type="text"
          placeholder="이름"
          value={name}
          onChange={(e) => setName(e.target.value)}
          style={inputStyle}
        />
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
        <input
          type="password"
          placeholder="비밀번호 확인"
          value={confirmPassword}
          onChange={(e) => setConfirmPassword(e.target.value)}
          style={inputStyle}
        />

        {/* 회원가입 버튼 */}
    <button
  style={{
    width: "100%",
    padding: "15px",
    fontSize: "20px",
    backgroundColor: "#4a85d1",
    color: "#fff",
    border: "none",
    borderRadius: "12px",
    cursor: "pointer",
    marginBottom: "20px",
    transition: "all 0.2s",
    textAlign: "center",
  }}
  onMouseEnter={(e) => e.currentTarget.style.backgroundColor = "#5f9cec"}
  onMouseLeave={(e) => e.currentTarget.style.backgroundColor = "#4a85d1"}
  onClick={handleJoin}
>
  회원가입
</button>


        {/* 로그인 페이지 이동 */}
        <p
          style={{
            textAlign: "center",
            fontSize: "16px",
            marginTop: "20px",
            width: "100%",
            display: "block",
          }}
        >
          이미 계정이 있으신가요?{" "}
          <span
            style={{
              color: "#4a85d1", // 로그인과 동일
              cursor: "pointer",
              fontWeight: "bold",
              display: "inline-block",
              marginLeft: "5px",
            }}
            onClick={() => navigate("/login")}
          >
            로그인
          </span>
        </p>
      </div>
    </div>
  );
};

export default Join;
