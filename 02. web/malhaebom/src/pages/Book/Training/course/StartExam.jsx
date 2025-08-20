// src/pages/Book/Training/course/StartExam.jsx
import { useNavigate } from "react-router-dom";
import React, { useEffect, useMemo, useRef, useState } from "react";
import useQuery from "../../../../hooks/useQuery.js";
import Header from "../../../../components/Header.jsx";
import AOS from "aos";
import { useScores } from "../../../../ScoreContext.jsx";


export default function StartExam() {
  const query = useQuery();
  const examId = Number(query.get("examId") ?? "0");
  const navigate = useNavigate();
  const {
    setScoreAD,
    setScoreAI,
    setScoreB,
    setScoreC,
    setScoreD,
    resetScores,
  } = useScores();

  const [bookTitle, setBookTitle] = useState("");
  const [exam, setExam] = useState(null);
  const [examDirectory, setExamDirectory] = useState("");

  // 버튼 강조용 상태
  const [activeBtn, setActiveBtn] = useState(0);

  // 오디오 refs
  const audio0Ref = useRef(null);
  const audio1Ref = useRef(null);
  const audio2Ref = useRef(null);
  const audio3Ref = useRef(null);
  const audio4Ref = useRef(null);

  // 초기화
  useEffect(() => {
    AOS.init();
  }, []);

  // 최초 진입 시 알림 + 점수 초기화(첫 문제일 때만)
  useEffect(() => {
    if (examId === 0) {
      alert("문제를 시작합니다");
      resetScores();
    } else {
      alert("다음 문제를 시작합니다");
    }
  }, [examId, resetScores]);

  // fairytale 제목
  useEffect(() => {
    setBookTitle(localStorage.getItem("bookTitle") || "동화");
  }, []);

  // exam JSON 로드
  useEffect(() => {
    const examPath = localStorage.getItem("examPath");
    if (!examPath) {
      alert("검사 파일 경로가 없습니다. 안내 화면으로 이동합니다.");
      navigate(`/book/training/course/exam?bookId=0`);
      return;
    }
    fetch(`/autobiography/${examPath}`)
      .then((r) => {
        if (!r.ok) throw new Error("exam JSON 로드 실패");
        return r.json();
      })
      .then((json) => {
        setExam(json);
        setExamDirectory(`/autobiography/${json.directory}`);
      })
      .catch((e) => {
        console.error(e);
        alert("검사 파일을 불러오지 못했습니다.");
      });
  }, [navigate]);

  // 오디오 체인 재생
  useEffect(() => {
    if (!exam) return;

    // 버튼 스타일 초기화
    setActiveBtn(0);

    const a0 = audio0Ref.current;
    const a1 = audio1Ref.current;
    const a2 = audio2Ref.current;
    const a3 = audio3Ref.current;
    const a4 = audio4Ref.current;

    if (!a0 || !a1 || !a2 || !a3 || !a4) return;

    const onEnd0 = () => {
      a1.play();
      setActiveBtn(1);
    };
    const onEnd1 = () => {
      a2.play();
      setActiveBtn(2);
    };
    const onEnd2 = () => {
      a3.play();
      setActiveBtn(3);
    };
    const onEnd3 = () => {
      a4.play();
      setActiveBtn(4);
    };
    const onEnd4 = () => {
      setActiveBtn(0); // 모두 종료 후 초기화
    };

    a0.addEventListener("ended", onEnd0);
    a1.addEventListener("ended", onEnd1);
    a2.addEventListener("ended", onEnd2);
    a3.addEventListener("ended", onEnd3);
    a4.addEventListener("ended", onEnd4);

    // 재시작 로직
    try {
      a0.currentTime = 0;
      a1.currentTime = 0;
      a2.currentTime = 0;
      a3.currentTime = 0;
      a4.currentTime = 0;
    } catch {}

    a0.load();
    a1.load();
    a2.load();
    a3.load();
    a4.load();

    a0.play().catch(() => {
      // 자동재생이 막히면 사용자 상호작용 유도
      console.warn("자동재생이 차단되었습니다. 첫 오디오를 클릭해 주세요.");
    });

    return () => {
      a0.removeEventListener("ended", onEnd0);
      a1.removeEventListener("ended", onEnd1);
      a2.removeEventListener("ended", onEnd2);
      a3.removeEventListener("ended", onEnd3);
      a4.removeEventListener("ended", onEnd4);
      [a0, a1, a2, a3, a4].forEach((a) => {
        try {
          a.pause();
        } catch {}
      });
    };
  }, [exam, examId]);

  const handleClickChoice = (choiceIdx) => {
    if (!exam) return;

    const current = exam.data[examId];
    const isCorrect = Number(current.answer) === Number(choiceIdx);

    // 1~20번 문항별 영역 매핑 (Vue 로직 그대로)
    const qNum = examId + 1;
    if (isCorrect) {
      if (qNum <= 4) {
        setScoreAD((v) => v + 1);
      } else if (qNum <= 8) {
        setScoreAI((v) => v + 1);
      } else if (qNum <= 12) {
        setScoreB((v) => v + 1);
      } else if (qNum <= 16) {
        setScoreC((v) => v + 1);
      } else if (qNum <= 20) {
        setScoreD((v) => v + 1);
      }
    }

    if (qNum < 20) {
      navigate(`/book/training/course/exam/start?examId=${examId + 1}`);
    } else {
      alert("화행검사가 끝났습니다");
      navigate(`/book/training/course/exam/result`);
    }
  };

  if (!exam) {
    return (
      <div className="content">
        <div className="wrap">
          <Header title={bookTitle} />
          <div className="inner">
            <div className="ct_banner">로딩 중...</div>
          </div>
        </div>
      </div>
    );
  }

  const current = exam.data[examId];

  return (
    <div className="content">
      <div className="wrap">
        <Header title={bookTitle} />
        <div className="inner">
          <div className="ct_banner">{current?.type}</div>
          <div className="ct_inner">
            <div
              className="ct_question_a"
              data-aos="fade-up"
              data-aos-duration="1000"
            >
              <p>{current?.title}</p>

              {/* 문제 오디오 */}
              <audio ref={audio0Ref} className="examAudio0">
                <source
                  src={`${examDirectory}/${examId + 1}/문제.mp3`}
                  type="audio/mpeg"
                />
              </audio>

              {/* 보기 4개 + 보기 오디오 */}
              {current?.list?.map((value, idx) => {
                const n = idx + 1;
                const isActive = activeBtn === n;
                return (
                  <div key={idx}>
                    <button
                      className={`question_bt alert text-center ${
                        isActive ? "alert-danger" : "alert-dark"
                      }`}
                      id={`examBtn${n}`}
                      type="button"
                      onClick={() => handleClickChoice(idx)}
                    >
                      {n}. {value}
                    </button>
                    <audio ref={[audio1Ref, audio2Ref, audio3Ref, audio4Ref][idx]} className={`examAudio${n}`}>
                      <source
                        src={`${examDirectory}/${examId + 1}/${n}.mp3`}
                        type="audio/mpeg"
                      />
                    </audio>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
