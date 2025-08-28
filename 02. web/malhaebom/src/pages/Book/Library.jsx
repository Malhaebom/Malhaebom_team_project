// src/pages/Book/Library.jsx
import React, { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import AOS from "aos";
import "aos/dist/aos.css";
import Background from "../Background/Background";

export default function BookLibrary() {
  const navigate = useNavigate();
  const BASE = (import.meta.env && import.meta.env.BASE_URL) || "/";

  const [fairytales, setFairytales] = useState(null);
  const [SliderCmp, setSliderCmp] = useState(null);
  const [sliderErr, setSliderErr] = useState(null);
  const [sliderKey, setSliderKey] = useState(0);

  const sliderWrapRef = useRef(null);

  // 화면 크기 상태
  const [isWide, setIsWide] = useState(window.innerWidth > 1100);

  // 브라우저 크기 변경 감지
  useEffect(() => {
    const handleResize = () => {
      setIsWide(window.innerWidth > 1100);
    };
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  // AOS 초기화
  useEffect(() => {
    AOS.init({ once: true });
  }, []);

  // react-slick 동적 import
  useEffect(() => {
    let mounted = true;
    import("react-slick")
      .then((m) => {
        const Comp = m?.default || m;
        if (mounted) setSliderCmp(() => Comp);
      })
      .catch((e) => {
        console.error("[BookLibrary] failed to load react-slick:", e);
        setSliderErr(e);
      });
    return () => { mounted = false; };
  }, []);

  // 데이터 로드
  useEffect(() => {
    fetch(`${BASE}autobiography/fairytale.json`)
      .then((r) => r.json())
      .then((json) => {
        setFairytales(json);
        setTimeout(() => {
          window.dispatchEvent(new Event("resize"));
          setSliderKey((k) => k + 1);
        }, 0);
      })
      .catch((e) => {
        console.error("[BookLibrary] failed to load fairytale.json:", e);
        setFairytales({});
      });
  }, [BASE]);

  const go = (bookId) => {
    navigate(`/book/training?bookId=${encodeURIComponent(bookId)}`);
  };

  const buildImgSrc = (imgPath) => {
    const baseClean = BASE.replace(/\/+$/, "");
    return `${baseClean}/autobiography/${imgPath}`;
  };

  // 커스텀 버튼
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

  // react-slick settings
  const settings = useMemo(
    () => ({
      slidesToShow: 1,
      slidesToScroll: 1,
      autoplay: false,
      dots: true,
      arrows: true,
      nextArrow: <NextArrow />,
      prevArrow: <PrevArrow />,
      centerMode: true,
      centerPadding: "50px",
      infinite: true,
      adaptiveHeight: true,
      draggable: true,
      swipe: true,
      swipeToSlide: true,
      touchMove: true,
      waitForAnimate: false,
    }),
    []
  );

  const entries = useMemo(() => {
    if (!fairytales) return [];
    return Object.entries(fairytales);
  }, [fairytales]);

  return (
    <div className="content">
      <style>{`
        .ct_slide01 .slick-list { overflow: hidden !important; }
        .ct_slide01 .slick-track { display: flex !important; align-items: stretch; }
        .ct_slide01 .slick-slide, .ct_slide01 .slick-slide > div { height: 100%; }
        .ct_slide01 .slick-slide > div > div { display: flex; flex-direction: column; height: 100%; }
        .ct_slide01 .slider_img { text-align: center; }
      `}</style>

      {/* 브라우저 가로 크기 1100 이상일 때만 Background 렌더링 */}
      {isWide && <Background />}

      <div className="wrap">
        <header>
          <div className="hd_inner">
            <div className="hd_tit">회상동화 활동 &amp; 화행검사</div>
            <div className="hd_left">
              <button
                type="button"
                onClick={() => window.history.back()}
                aria-label="뒤로가기"
                className="reset-btn"
                style={{ background: "none", border: 0, padding: 0, cursor: "pointer" }}
              >
                <i className="xi-angle-left-min" />
              </button>
            </div>
            <div className="hd_right">
              <button
                type="button"
                onClick={() => (window.location.href = "/")}
                aria-label="홈으로"
                className="reset-btn"
                style={{ background: "none", border: 0, padding: 0, cursor: "pointer" }}
              >
                <i className="xi-home-o" />
              </button>
            </div>
          </div>
        </header>

        <div id="app">
          <div className="inner"></div>

          <div className="ct_slide01 ct_inner" data-aos="fade-up" data-aos-duration="1000">
            {sliderErr && (
              <div style={{ padding: 12, border: "1px solid #f00", marginBottom: 12 }}>
                <strong>슬라이더 로드 실패</strong>
                <div style={{ marginTop: 6, fontSize: 13 }}>
                  react-slick 모듈을 불러오지 못했습니다. 패키지 설치 여부를 확인하세요.
                </div>
              </div>
            )}

            {!SliderCmp || !entries.length ? (
              <div style={{ padding: 12 }}>로딩 중...</div>
            ) : (
              <div ref={sliderWrapRef} style={{ position: "relative" }}>
                <SliderCmp {...settings} key={sliderKey}>
                  {entries.map(([key, value], i) => {
                    const id = value?.id ?? key;
                    const img = value?.image ?? "";
                    const subtitle = value?.subtitle ?? "";

                    return (
                      <div key={key || i}>
                        <div className="slider_img">
                          <img
                            src={buildImgSrc(img)}
                            className="card-img-top"
                            alt={key}
                            onError={(e) => {
                              e.currentTarget.src = `${BASE}drawable/noImage.png`;
                            }}
                            style={{
                              height: 200,
                              display: "inline-block",
                              border: "0.1px #ddd solid",
                            }}
                          />
                        </div>

                        <div className="slider_tit">
                          <h2>{key}</h2>
                          <p>{subtitle}</p>
                        </div>

                        <button type="button" onClick={() => go(id)}>
                          활동하기
                        </button>
                      </div>
                    );
                  })}
                </SliderCmp>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
