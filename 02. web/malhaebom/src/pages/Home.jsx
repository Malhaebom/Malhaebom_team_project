// src/pages/Home.jsx
import React, { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import AOS from "aos";
import "aos/dist/aos.css";

export default function Home() {
  const navigate = useNavigate();

  useEffect(() => {
    AOS.init();
  }, []);

  return (
    <div className="content">
      <div className="wrap">
        <header>
          <div className="hd_inner">
            <h1 className="logo">브레인업</h1>
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
            {/* 화상동화 활동 */}
            <div className="box" data-aos="fade-up" data-aos-duration="1500">
              <div>
                <h2>화상동화 활동</h2>
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

            {/* 두뇌 단련 */}
            <div className="box" data-aos="fade-up" data-aos-duration="2000">
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

            {/* 신체 단련 */}
            <div className="box" data-aos="fade-up" data-aos-duration="2500">
              <div>
                <h2>신체 단련</h2>
                <p>몸을 튼튼하게 만들어요</p>
                <img
                  src="/img/home_icon03.png"
                  onError={(e) => (e.currentTarget.src = "/drawable/noImage.png")}
                  alt="신체 단련"
                />
              </div>
              <button type="button" onClick={() => navigate("/exercise")}>
                시작하기
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
