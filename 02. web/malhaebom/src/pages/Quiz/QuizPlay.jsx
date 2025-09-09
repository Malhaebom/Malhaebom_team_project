import React, { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useSearchParams, useLocation } from "react-router-dom";
import AOS from "aos";
import "aos/dist/aos.css";
import Background from "../Background/Background";

export default function QuizPlay() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const location = useLocation();
  const BASE = import.meta.env.BASE_URL || "/";

  const state = location.state ?? {};
  const retryIndex = state.retryIndex ?? 0;
  const isRetryMode = state.isRetryMode ?? false; // ✅ 다시풀기 모드
  const initialSubmitArr = state.submitDataArr ?? [];
  const initialAnswerArr = state.answerDataArr ?? [];

  const files = [
    "시공간파악.json",
    "기억집중.json",
    "문제해결능력.json",
    "계산능력.json",
    "언어능력.json",
    "음악과터치.json",
  ];

  const quizType = (() => {
    const q = searchParams.get("quizType");
    const n = Number(q);
    return !isNaN(n) && n >= 0 && n < files.length ? n : 0;
  })();

  const quizFileName = files[quizType] ?? "퀴즈.json";
  const passedQuizTitle = quizFileName.replace(".json", "");

  const [brainTrainingArr, setBrainTrainingArr] = useState(null);
  const [currentTopicArr, setCurrentTopicArr] = useState([]);
  const [currentIndex, setCurrentIndex] = useState(retryIndex);
  const [progress, setProgress] = useState(0);
  const [submitDataArr, setSubmitDataArr] = useState([...initialSubmitArr]);
  const [answerDataArr, setAnswerDataArr] = useState([...initialAnswerArr]);
  const [cnt, setCnt] = useState(0);
  const [showResultBtn, setShowResultBtn] = useState(false); // ✅ 결과보기 버튼 표시 여부
  const [isWide, setIsWide] = useState(window.innerWidth > 1100); // ✅ 브라우저 너비 상태

  // ===== 🎵 오디오 제어용 ref & 헬퍼 =====
  const audioRef = useRef(null);

  const stopAllAudio = () => {
    try {
      if (audioRef.current) {
        audioRef.current.pause();
        audioRef.current.currentTime = 0;
      }
      // 혹시 다른 오디오 엘리먼트가 있다면 모두 정지
      document.querySelectorAll("audio").forEach((a) => {
        if (a !== audioRef.current) {
          a.pause();
          a.currentTime = 0;
        }
      });
    } catch (e) {
      // no-op
    }
  };

  // 브라우저 창 리사이즈 감지
  useEffect(() => {
    const handleResize = () => setIsWide(window.innerWidth > 1100);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  useEffect(() => {
    AOS.init({ once: true });
  }, []);

  // 데이터 로드
  useEffect(() => {
    (async () => {
      try {
        const arr = await Promise.all(
          files.map((f) =>
            fetch(`${BASE}autobiography/brainTraining/${f}`).then((r) =>
              r.json()
            )
          )
        );
        setBrainTrainingArr(arr);
      } catch (e) {
        console.error(e);
      }
    })();
  }, [BASE]);

  // 퀴즈 타입이 바뀌거나 데이터 로드 완료 시 현재 토픽 세팅
  useEffect(() => {
    if (!brainTrainingArr) return;
    const topicArr = brainTrainingArr[quizType] ?? [];
    setCurrentTopicArr(topicArr);

    setCurrentIndex(retryIndex);
    setProgress(0);
    setCnt(0);
    setSubmitDataArr([...initialSubmitArr]);
    setAnswerDataArr([...initialAnswerArr]);
    setShowResultBtn(false);
    stopAllAudio();
  }, [brainTrainingArr, quizType, retryIndex]); // eslint-disable-line

  const current = useMemo(
    () => currentTopicArr[currentIndex] ?? null,
    [currentTopicArr, currentIndex]
  );

  // === 🔁 문항이 바뀔 때마다 안전 초기화 (오디오/카운트/프로그레스) ===
  useEffect(() => {
    // 문항 전환 시 오디오 무조건 정지
    stopAllAudio();
    // Type 3 진입 시 카운트 초기화
    if (current?.type === 3) setCnt(0);
    // (필요 시) per-question progress 초기화
    setProgress(0);
  }, [currentIndex, current?.type]); // current?.type 포함

  // === 🎵 사운드 소스가 바뀔 때 오디오를 새로 로드 (크로스페이드 방지) ===
  useEffect(() => {
    if (current?.type === 3 && audioRef.current) {
      try {
        audioRef.current.pause();
        audioRef.current.currentTime = 0;
        // 소스가 바뀌었을 수 있으니 강제 로드
        audioRef.current.load();
      } catch (e) {
        /* no-op */
      }
    }
  }, [currentIndex, current?.question?.[0]?.sound, current?.type]);

  // 언마운트 시 모든 오디오 정지
  useEffect(() => {
    return () => stopAllAudio();
  }, []);

  const goHome = () => navigate("/");
  const goBack = () => window.history.back();

  const goResult = (submitArr, answerArr) => {
    stopAllAudio();
    navigate("/quiz/result", {
      state: {
        submitDataArr: submitArr,
        answerDataArr: answerArr,
        quizType,
        quizTitle: passedQuizTitle,
        questionArr: currentTopicArr,
      },
    });
  };

  const handleSubmit = (submitValue) => {
    if (!current) return;

    const answer = Number(current?.question?.[0]?.answer ?? -1);
    const newSubmitArr = [...submitDataArr];
    const newAnswerArr = [...answerDataArr];

    newSubmitArr[currentIndex] = submitValue;
    newAnswerArr[currentIndex] = answer;

    setSubmitDataArr(newSubmitArr);
    setAnswerDataArr(newAnswerArr);

    if (isRetryMode) {
      setShowResultBtn(true);
    } else {
      if (currentIndex + 1 < currentTopicArr.length) {
        // ✅ 다음 문항으로 넘어가기 전 오디오/카운트 초기화
        stopAllAudio();
        setCnt(0);
        setCurrentIndex((prev) => prev + 1);
      } else {
        stopAllAudio();
        goResult(newSubmitArr, newAnswerArr);
      }
    }
  };

  const SubmitType0 = (submitData) => handleSubmit(submitData);
  const SubmitType1 = (submitData) => handleSubmit(submitData);

  const SubmitType2 = (submitData) => {
    if (!current) return;
    const maxIndex = current.question.length;

    const newSubmitArr = [...submitDataArr];
    const newAnswerArr = [...answerDataArr];

    newSubmitArr[currentIndex] = submitData;
    // 기존 로직 유지 (데이터 구조에 맞춰진 답 체크)
    newAnswerArr[currentIndex] =
      current.question[submitDataArr.length]?.answer ?? -1;

    setSubmitDataArr(newSubmitArr);
    setAnswerDataArr(newAnswerArr);
    setProgress(((currentIndex + 1) / maxIndex) * 100);

    if (isRetryMode) {
      setShowResultBtn(true);
    } else {
      if (currentIndex + 1 < currentTopicArr.length) {
        stopAllAudio();
        setCnt(0);
        setCurrentIndex((prev) => prev + 1);
      } else {
        stopAllAudio();
        goResult(newSubmitArr, newAnswerArr);
      }
    }
  };

  const CountUpType3 = () => setCnt((c) => c + 1);

  const PlaySoundType3 = () => {
    // 다른 오디오가 겹쳐 나오지 않도록 전체 정지 후 현재만 재생
    stopAllAudio();
    const a = audioRef.current;
    if (a) {
      try {
        a.currentTime = 0;
        // 일부 브라우저는 load 후 play가 안정적
        a.load();
        a.play().catch(() => {});
      } catch (e) {
        /* no-op */
      }
    }
  };

  const SubmitType3 = () => handleSubmit(cnt);

  if (!current)
    return (
      <div className="content">
        <div className="wrap">
          <header>
            <div className="hd_inner">
              <div className="hd_tit">두뇌 단련</div>
            </div>
          </header>
          <div className="inner">로딩 중...</div>
        </div>
      </div>
    );

  const type = current.type;

  return (
    <div className="content">
      {/* ✅ 1100px 이상일 때만 Background 렌더링 */}
      {isWide && <Background />}

      <div className="wrap">
        <header>
          <div className="hd_inner">
            <div className="hd_tit">
              <div className="alert alert-dark text-center">{passedQuizTitle}</div>
            </div>
            <div className="hd_left">
              <a onClick={goBack}>
                <i className="xi-angle-left-min" />
              </a>
            </div>
            <div className="hd_right">
              <a onClick={goHome}>
                <i className="xi-home-o" />
              </a>
            </div>
          </div>
        </header>

        <div className="inner">
          <div className="ct_inner">
            <div className="ct_brain" data-aos="fade-up" data-aos-duration="1000">
              <div className="ct_tit">{current.question?.[0]?.title}</div>

              {/* Type 0 */}
              {type === 0 && (
                <>
                  <div className="ct_img">
                    <img
                      src={`${BASE}autobiography/brainTraining/${current.question[0].image}`}
                      style={{ width: "100%", borderRadius: 10 }}
                    />
                  </div>
                  <div className="bt_flex bt_flex_4">
                    {current.question[0].question?.map((text, idx) => (
                      <button
                        key={idx}
                        className="question_bt"
                        type="button"
                        onClick={() => SubmitType0(idx)}
                      >
                        {text}
                      </button>
                    ))}
                  </div>
                </>
              )}

              {/* Type 1 */}
              {type === 1 && (
                <>
                  <div className="ct_img">
                    <img
                      src={`${BASE}autobiography/brainTraining/${current.question[0].image}`}
                      style={{ width: "100%", borderRadius: 10 }}
                    />
                  </div>
                  <div className="bt_flex bt_flex_2">
                    <button
                      className="question_bt"
                      type="button"
                      onClick={() => SubmitType1(0)}
                    >
                      O
                    </button>
                    <button
                      className="question_bt"
                      type="button"
                      onClick={() => SubmitType1(1)}
                    >
                      X
                    </button>
                  </div>
                </>
              )}

              {/* Type 2 */}
              {type === 2 && (
                <>
                  <div className="ct_img">
                    <img
                      src={`${BASE}autobiography/brainTraining/${current.question[submitDataArr.length].image}`}
                      style={{ width: "100%", borderRadius: 10 }}
                    />
                  </div>
                  <progress
                    id="progressbar"
                    value={progress}
                    min="0"
                    max="100"
                    style={{ width: "100%" }}
                  />
                  <div className="bt_flex bt_flex_2">
                    <button
                      className="question_bt"
                      type="button"
                      onClick={() => SubmitType2(0)}
                    >
                      왼쪽
                    </button>
                    <button
                      className="question_bt bt_color"
                      type="button"
                      onClick={() => SubmitType2(1)}
                    >
                      오른쪽
                    </button>
                  </div>
                </>
              )}

              {/* Type 3 — 음악과터치 */}
              {type === 3 && (
                <>
                  <div className="ct_tit_sub">[ 실제로 노래를 부르며 터치해 보세요 ]</div>
                  <div className="ct_img">
                    <img
                      src={`${BASE}autobiography/brainTraining/${current.question[0].image}`}
                      style={{ width: "100%", borderRadius: 10 }}
                    />
                    <audio
                      key={`t3-${currentIndex}-${current?.question?.[0]?.sound}`} // 🔁 강제 리마운트
                      ref={audioRef}
                      className="soundType3"
                      preload="auto"
                    >
                      <source
                        src={`${BASE}autobiography/brainTraining/${current.question[0].sound}`}
                        type="audio/mpeg"
                      />
                    </audio>
                  </div>
                  <div className="bt_ bt_touch">
                    <button className="bt_color" type="button" onClick={CountUpType3}>
                      {cnt}번
                    </button>
                    <div className="bt_flex bt_flex_2">
                      <button type="button" onClick={PlaySoundType3}>
                        노래 재생하기
                      </button>
                      <button type="button" onClick={SubmitType3}>
                        제출하기
                      </button>
                    </div>
                  </div>
                </>
              )}

              {/* ✅ 결과보기 버튼 (다시풀기 모드에서만) */}
              {showResultBtn && (
                <div style={{ marginTop: "20px", textAlign: "center" }}>
                  <button
                    style={{
                      padding: "12px 24px",
                      backgroundColor: "#488eca",
                      color: "#fff",
                      border: "none",
                      borderRadius: "8px",
                      fontWeight: "bold",
                      cursor: "pointer",
                    }}
                    onClick={() => goResult(submitDataArr, answerDataArr)}
                  >
                    결과보기
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
