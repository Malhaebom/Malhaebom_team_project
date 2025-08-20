import React, { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import useQuery from "../../../../hooks/useQuery.js";
import Header from "../../../../components/Header.jsx";
import AOS from "aos";
import Slider from "react-slick";
import "slick-carousel/slick/slick.css";
import "slick-carousel/slick/slick-theme.css";

export default function ExamTut() {
  const query = useQuery();
  const bookId = Number(query.get("bookId") ?? "0");
  const navigate = useNavigate();

  const [fairytales, setFairytales] = useState(null);
  const [title, setTitle] = useState("");

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
    infinite: true,         // ← 양방향
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
      {/* ✅ 최소 보정만: 정렬/간격 */}
      <style>{`
        /* 오른쪽 치우침 방지 + 가운데 정렬 */
        .ct_slide01 .slick-track { display:flex !important; margin:0 auto !important; }
        .ct_slide01 .slick-slide > div { display:flex; justify-content:center; box-sizing:border-box; }
        /* centerMode 좌우 미리보기 패딩 보장 */
        .ct_slide01 .slick-list { padding: 0 50px !important; }
        /* dots가 아래 설명과 너무 떨어지지 않게 */
        .ct_slide01 .slick-dots { bottom: -6px; }
        /* 슬라이드와 설명 사이 간격 축소 */
        .ct_slide01 { margin-bottom: 8px; }
        .ct_slide01 + .num_tit { margin-top: 8px; }
        /* 이미지 컨테이너(프로젝트 관례: .slider_img는 div 컨테이너) */
        .slider_img { position:relative; height:200px; }
        .slider_img img {
          position:absolute; top:50%; left:50%;
          transform: translate(-50%, -50%);
          max-width:100%; max-height:100%;
          width:auto; height:auto;
          border-radius:10px; object-fit:contain; display:block;
        }
      `}</style>

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
                  {/* ▼ 슬라이더 */}
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

                  {/* ▼ 설명(간격 줄임) */}
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
