// src/pages/QuizLibrary.jsx
import React, { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import Slider from "react-slick";
import AOS from "aos";
import "aos/dist/aos.css";
import "@fortawesome/fontawesome-free/css/all.min.css";

export default function QuizLibrary() {
  const navigate = useNavigate();

  useEffect(() => {
    AOS.init({ once: true });
  }, []);

  const goHome = () => (window.location.href = "/");
  const goToQuizPlay = (quizType) => navigate(`/quiz/play?quizType=${quizType}&quizId=0&qid=0`);

  // ✅ BookLibrary와 동일한 커스텀 화살표
  const NextArrow = ({ onClick }) => (
    <div
      style={{
        position: "absolute",
        top: "50%",
        right: -50,
        transform: "translateY(-50%)",
        cursor: "pointer",
        zIndex: 10,
      }}
      onClick={onClick}
    >
      <img src="/img/next.png" alt="Next" style={{ width: 40, height: 40 }} />
    </div>
  );

  const PrevArrow = ({ onClick }) => (
    <div
      style={{
        position: "absolute",
        top: "50%",
        left: -50,
        transform: "translateY(-50%)",
        cursor: "pointer",
        zIndex: 10,
      }}
      onClick={onClick}
    >
      <img src="/img/prev.png" alt="Prev" style={{ width: 40, height: 40 }} />
    </div>
  );

  const settings = {
    slidesToShow: 1,
    slidesToScroll: 1,
    autoplay: false,
    autoplaySpeed: 4000,
    dots: true,
    centerMode: true,
    centerPadding: "50px",
    focusOnSelect: true,
    infinite: true,
    arrows: true,           // Book과 동일하게 화살표 표시
    nextArrow: <NextArrow />,
    prevArrow: <PrevArrow />,
    adaptiveHeight: true,
    accessibility: false,
  };

  const items = [
    { label: "시공간파악", icon: "fa-clock", color: "#ff0000", type: 0 },
    { label: "기억집중", icon: "fa-brain", color: "#ff7300", type: 1 },
    { label: "문제해결능력", icon: "fa-pen-to-square", color: "#dbc900", type: 2 },
    { label: "계산능력", icon: "fa-calculator", color: "#00b837", type: 3 },
    { label: "언어능력", icon: "fa-language", color: "#755000", type: 4 },
    { label: "음악과 터치", icon: "fa-headset", color: "#bb00ff", type: 5 },
  ];

  return (
    <div className="content">
      <style>{`
        /* 1) react-slick 구조에서 카드가 오른쪽으로 치우치는 현상 방지 */
        .ct_slide01 .slick-track { display:flex !important; margin:0 auto !important; }
        .ct_slide01 .slick-slide > div { display:flex; justify-content:center; box-sizing:border-box; }

        /* 2) centerMode의 좌우 패딩이 테마 CSS에 덮이는 경우 대비(대칭 보장) */
        .ct_slide01 .slick-list { padding: 0 50px !important; }

        /* 3) 아이콘 정확히 중앙 배치 (위로 쏠림 보정) */
        .slider_img { position:relative; height:200px; }
        .slider_img i {
          position:absolute; top:45%; left:50%;
          transform: translate(-50%, -50%);
        }
      `}</style>

      <div className="wrap">
        <header>
          <div className="hd_inner">
            <div className="hd_tit">두뇌 단련</div>
            <div className="hd_left">
              <a onClick={() => window.history.back()} aria-label="뒤로가기">
                <i className="xi-angle-left-min" />
              </a>
            </div>
            <div className="hd_right">
              <a onClick={goHome} aria-label="홈으로">
                <i className="xi-home-o" />
              </a>
            </div>
          </div>
        </header>

        <div className="inner">
          <div className="ct_banner">원하는 훈련을 선택해 두뇌를 단련해요!</div>
        </div>

        <div className="ct_slide01 ct_inner" data-aos="fade-up" data-aos-duration="1000">
          <Slider {...settings}>
            {items.map(({ label, icon, color, type }) => (
              <div key={type}>
                <div className="slider_img">
                  <i className={`fa-solid ${icon} fa-4x`} style={{ color }} />
                </div>
                <div className="slider_tit"><h2>{label}</h2></div>
                <button type="button" onClick={() => goToQuizPlay(type)}>시작하기</button>
              </div>
            ))}
          </Slider>
        </div>
      </div>
    </div>
  );
}
