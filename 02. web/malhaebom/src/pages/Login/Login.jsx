import React from "react";
import { useNavigate } from "react-router-dom";

const Login = () => {
    const navigate = useNavigate();

    const handleLogin = () => {
        // 로그인 로직 추가 가능
        console.log("로그인 버튼 클릭");
    };

    return (
        <div
            style={{
                width: "520px",
                margin: "0 auto",
                paddingTop: "80px"
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
                    margin: "0 auto",
                    marginBottom: "20px"
                }}
            />
            <h6
                style={{
                    fontSize: "30px",
                    color: "#000",
                    textAlign: "center",
                    marginBottom: "10px"
                }}
            >
                나를 지키는 특별한 습관
            </h6>
            <p
                style={{
                    fontSize: "26px",
                    color: "#000",
                    textAlign: "center",
                    marginBottom: "30px"
                }}
            >
                지금 시작하세요!
            </p>

            {/* 입력칸 */}
            <input
                type="text"
                placeholder="전화번호"
                style={{
                    width: "100%",
                    padding: "15px",
                    fontSize: "18px",
                    marginBottom: "15px",
                    borderRadius: "8px",
                    border: "1px solid #ccc",
                    boxSizing: "border-box"
                }}
            />
            <input
                type="password"
                placeholder="비밀번호"
                style={{
                    width: "100%",
                    padding: "15px",
                    fontSize: "18px",
                    marginBottom: "20px",
                    borderRadius: "8px",
                    border: "1px solid #ccc",
                    boxSizing: "border-box"
                }}
            />

            {/* 로그인 버튼 */}
            <button
                onClick={handleLogin}
                style={{
                    width: "100%",
                    padding: "15px",
                    fontSize: "20px",
                    backgroundColor: "#344CB7",
                    color: "#fff",
                    border: "none",
                    borderRadius: "8px",
                    cursor: "pointer"
                }}
            >
                로그인
            </button>
        </div>
    );
};

export default Login;
