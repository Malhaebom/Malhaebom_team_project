import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import AOS from "aos";
import "aos/dist/aos.css";
import axios from "axios";
import Background from "./Background/Background";
import Logo from "../components/Logo.jsx";

const API = axios.create({
  baseURL: "/",
  withCredentials: true,
  headers: { "Content-Type": "application/json" },
});

export default function Home() {
  const navigate = useNavigate();
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  const [nick, setNick] = useState("");

  useEffect(() => {
    AOS.init();
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

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

  const boxStyle = { borderRadius: "20px", overflow: "hidden" };
  const wrapStyle = {
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    flexDirection: "column",
  };

  return (
    <div className="content">
      {windowWidth > 1100 && <Background />}

      <div className="wrap" style={windowWidth <= 1000 ? wrapStyle : {}}>
        <header>
          <div className="hd_inner">
            <Logo className="logo">말해봄</Logo>
            <div className="hd_left">
              <a onClick={() => navigate("/")}>
                <i className="xi-angle-left-min" />
              </a>
            </div>
            <div className="hd_right">
              <a onClick={() => navigate("/")}>
                <i className="xi-home-o" />
              </a>
            </div>
          </div>
        </header>

        <div className="inner">
          <div className="ct_banner">훈련을 통해 활력을 되찾아요!</div>

          <div className="ct_home ct_inner">
            <div className="box" data-aos="fade-up" data-aos-duration="1000" style={boxStyle}>
              <div>
                <h2>인지 능력 검사</h2>
                <p>추억을 나누며 기억을 되살려요</p>
                <img
                  src="/img/home_icon04.png"
                  onError={(e) => (e.currentTarget.src = "/drawable/noImage.png")}
                  alt="회상 훈련"
                />
              </div>
              <button type="button" onClick={() => navigate("/interview/interviewstart")}>
                시작하기
              </button>
            </div>

            <div className="box" data-aos="fade-up" data-aos-duration="1500" style={boxStyle}>
              <div>
                <h2>회상동화 활동</h2>
                <p>이야기를 듣고 활동해요</p>
                <img
                  src="/img/home_icon01.png"
                  onError={(e) => (e.currentTarget.src = "/drawable/noImage.png")}
                  alt="화상동화 활동"
                />
              </div>
              <button type="button" onClick={() => navigate("/book")}>
                시작하기
              </button>
            </div>

            <div className="box" data-aos="fade-up" data-aos-duration="2000" style={boxStyle}>
              <div>
                <h2>두뇌 단련</h2>
                <p>놀이를 통해 뇌를 단련해요</p>
                <img
                  src="/img/home_icon02.png"
                  onError={(e) => (e.currentTarget.src = "/drawable/noImage.png")}
                  alt="두뇌 단련"
                />
              </div>
              <button type="button" onClick={() => navigate("/quiz/library")}>
                시작하기
              </button>
            </div>

            <div className="box" data-aos="fade-up" data-aos-duration="2500" style={boxStyle}>
              <div>
                <h2>마이페이지</h2>
                <p>{nick ? `${nick}님 환영합니다.` : "로그인 후 이용해 주세요."}</p>
                <img
                  src="/img/home_icon03.png"
                  onError={(e) => (e.currentTarget.src = "/drawable/noImage.png")}
                  alt="마이페이지"
                />
              </div>
              <button type="button" onClick={() => navigate("/mypage")}>
                이동하기
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
