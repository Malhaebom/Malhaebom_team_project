// src/pages/book/training/Course.jsx
import React, { useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import Slider from "react-slick";
import AOS from "aos";
import "aos/dist/aos.css";

export default function Course() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const bookId = Number(searchParams.get("bookId") ?? "0");
  const BASE = import.meta.env.BASE_URL || "/";

  const [title, setTitle] = useState("");
  const [loading, setLoading] = useState(true);

  const menu = useMemo(
    () => ({
      "동화듣기": {
        desc: "타임슬랩으로 진행되는 동화 듣기",
        image: "/drawable/course_read.jpg",
        course: "/book/training/course/read?bookId=",
      },
      "화행검사": {
        desc: "동화에 대한 질의를 통한 인지능력 판단",
        image: "/drawable/course_exam.jpg",
        course: "/book/training/course/exam?bookId=",
      },
      "동화 연극하기": {
        desc: "이야기 주인공의 대사 따라하기",
        image: "/drawable/course_play.jpg",
        course: "/book/training/course/play?bookId=",
      },
      "워크북 풀어보기": {
        desc: "워크북 풀어보기",
        image: "/drawable/course_workbook.jpg",
        course: "/book/training/course/workbook?bookId=",
      },
    }),
    []
  );

  useEffect(() => { AOS.init({ once: true }); }, []);

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch(`${BASE}autobiography/fairytale.json`);
        const json = await res.json();
        const entry = Object.entries(json).find(([, v]) => Number(v?.id) === bookId);
        setTitle(entry ? entry[0] : "");
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    })();
  }, [bookId, BASE]);

  const goCourse = (courseBase) => navigate(`${courseBase}${bookId}`);

  // ▶ QuizLibrary와 동일한 slick 옵션
  const settings = {
    slidesToShow: 1,
    slidesToScroll: 1,
    autoplay: false,
    autoplaySpeed: 4000,
    dots: true,
    centerMode: true,       // 옆 카드 살짝 보이기
    centerPadding: "50px",  // 원본과 동일
    focusOnSelect: true,
    infinite: true,
    arrows: false,
    adaptiveHeight: true,
    accessibility: false,
  };

  return (
    <div className="content">
      {/* ✅ 최소 보정: 오른쪽 치우침 제거 + 좌우 패딩 대칭 보장 */}
      <style>{`
        .ct_slide01 .slick-track { display:flex !important; margin:0 auto !important; }
        .ct_slide01 .slick-slide > div { display:flex; justify-content:center; box-sizing:border-box; }
        .ct_slide01 .slick-list { padding: 0 50px !important; }
        .slider_img { position:relative; height:200px; }
      `}</style>

      <div className="wrap">
        <header>
          <div className="hd_inner">
            <div className="hd_tit">회상동화 활동 & 화행검사</div>
            <div className="hd_left">
              <a onClick={() => window.history.back()}>
                <i className="xi-angle-left-min"></i>
              </a>
            </div>
            <div className="hd_right">
              <a onClick={() => (window.location.href = "/")}>
                <i className="xi-home-o"></i>
              </a>
            </div>
          </div>
        </header>

        <div id="app">
          <div className="inner" role="alert">
            <div className="ct_banner">{loading ? "로딩 중..." : title}</div>
          </div>

          <div className="ct_slide01 ct_inner" data-aos="fade-up" data-aos-duration="1000">
            <Slider {...settings}>
              {Object.entries(menu).map(([key, value]) => (
                <div key={key}>
                  <div className="slider_img">
                    <img
                      src={value.image}
                      alt={key}
                      onError={(e) => (e.currentTarget.src = "/drawable/noImage.png")}
                      style={{
                        width: "100%",
                        height: 200,
                        display: "inline-block",
                        borderRadius: 10,
                        objectFit: "cover",
                      }}
                    />
                  </div>
                  <div className="slider_tit">
                    <h2>{key}</h2>
                    <p className="slider_p">{value.desc}</p>
                  </div>
                  <button type="button" onClick={() => goCourse(value.course)}>
                    시작하기
                  </button>
                </div>
              ))}
            </Slider>
          </div>
        </div>
      </div>
    </div>
  );
}
