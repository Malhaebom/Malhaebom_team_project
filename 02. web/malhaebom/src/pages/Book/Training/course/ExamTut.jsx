import React, { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import useQuery from "../../../../hooks/useQuery.js";
import Header from "../../../../components/Header.jsx";
import AOS from "aos";
import Slider from "react-slick";
import "slick-carousel/slick/slick.css";
import "slick-carousel/slick/slick-theme.css";
import Background from "../../../Background/Background";

export default function ExamTut() {
  const query = useQuery();
  const bookId = Number(query.get("bookId") ?? "0");
  const navigate = useNavigate();

  const [fairytales, setFairytales] = useState(null);
  const [title, setTitle] = useState("");
  const [windowWidth, setWindowWidth] = useState(window.innerWidth); // 브라우저 너비 상태

  useEffect(() => {
    AOS.init({ once: true });
  }, []);

  useEffect(() => {
    fetch(`/autobiography/fairytale.json`)
      .then((r) => {
        if (!r.ok) throw new Error("fairytale.json 로드 실패");
        return r.json();
      })
      .then((json) => setFairytales(json))
      .catch((e) => {
        console.error(e);
        setFairytales({});
      });
  }, []);

  // 브라우저 리사이즈 감지
  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  const targetFairytale = useMemo(() => {
    if (!fairytales) return null;
    const arr = Object.entries(fairytales);
    const found = arr.find(([, v]) => Number(v?.id) === bookId);
    if (found) {
      setTitle(found[0]);
      return found[1];
    }
    return null;
  }, [fairytales, bookId]);

  const sliderSettings = {
    slidesToShow: 1,
    slidesToScroll: 1,
    autoplay: false,
    dots: true,
    centerMode: true,
    centerPadding: "50px",
    focusOnSelect: true,
    infinite: true,
    adaptiveHeight: true,
    accessibility: false,
  };

  const handleStart = () => {
    if (!targetFairytale?.exam) {
      alert("검사 파일 경로를 찾지 못했습니다.");
      return;
    }
    localStorage.setItem("examPath", targetFairytale.exam);
    localStorage.setItem("bookTitle", title || "");
    navigate(`/book/training/course/exam/start?examId=0`);
  };

  const handleReadStory = () => {
    location.href = `/book/training/course/read?bookId=${bookId}`;
  };

  return (
    <div className="content">
      <style>{`
        .ct_slide01 .slick-track { display:flex !important; margin:0 auto !important; }
        .ct_slide01 .slick-slide > div { display:flex; justify-content:center; box-sizing:border-box; }
        .ct_slide01 .slick-list { padding: 0 50px !important; }
        .ct_slide01 .slick-dots { bottom: -6px; }
        .ct_slide01 { margin-bottom: 8px; }
        .ct_slide01 + .num_tit { margin-top: 8px; }
        .slider_img { position:relative; height:200px; }
        .slider_img img {
          position:absolute; top:50%; left:50%;
          transform: translate(-50%, -50%);
          max-width:100%; max-height:100%;
          width:auto; height:auto;
          border-radius:10px; object-fit:contain; display:block;
        }
      `}</style>

      {/* 브라우저 너비 1100 이상일 때만 Background 렌더링 */}
      {windowWidth > 1100 && <Background />}

      <div className="wrap">
        <Header title={title || "동화"} />
        <div className="inner">
          <div className="ct_banner">화행검사</div>
          <div className="ct_inner">
            <div className="ct_question" data-aos="fade-up" data-aos-duration="1000">
              <div>
                <div className="tit">
                  <p>Q</p>화행검사란?
                </div>
                <div className="sub_tit">
                  <p>제시 질문에 대한 행위에 대한 수행을 기반으로 응답자의 인지능력을 검사합니다.</p>
                </div>
              </div>

              <div>
                <div className="tit">
                  <p>Q</p>검사진행 방법
                </div>
                <div className="sub_tit">
                  <div className="ct_slide01 ct_inner" data-aos="fade-up" data-aos-duration="1000">
                    <Slider {...sliderSettings}>
                      <div>
                        <div className="slider_img">
                          <img
                            src="/drawable/exam_tut_1.png"
                            alt="exam guide 1"
                            onError={(e) => (e.currentTarget.src = "/drawable/noImage.png")}
                          />
                        </div>
                      </div>
                      <div>
                        <div className="slider_img">
                          <img
                            src="/drawable/exam_tut_2.png"
                            alt="exam guide 2"
                            onError={(e) => (e.currentTarget.src = "/drawable/noImage.png")}
                          />
                        </div>
                      </div>
                    </Slider>
                  </div>

                  <div className="num_tit">
                    <p className="num">1. 문제 제시</p>
                    <p>동화의 내용에 기반한 문제 상황을 제시하는 음성이 출력됩니다.</p>
                    <p className="num">2. 답안 선택</p>
                    <p>올바른 답안을 선택합니다.</p>
                  </div>
                </div>
              </div>

              <div>
                <div className="tit">
                  <p>Q</p>동화를 읽으셨나요?
                </div>
                <div className="sub_tit">
                  <p>동화기반의 문제가 출제됩니다. 동화를 꼭 듣고 화행검사를 시작해주세요.</p>
                </div>
              </div>

              <button className="question_bt" type="button" onClick={handleStart}>
                예, 동화를 읽었습니다. (검사 시작)
              </button>
              <button className="question_bt" id="last" type="button" onClick={handleReadStory}>
                아니오, 동화를 읽지 않았습니다. (동화 읽기)
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
