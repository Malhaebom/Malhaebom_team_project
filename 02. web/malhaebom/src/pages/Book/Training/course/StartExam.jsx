// src/pages/Book/Training/course/StartExam.jsx
import { useNavigate } from "react-router-dom";
import React, { useEffect, useRef, useState } from "react";
import useQuery from "../../../../hooks/useQuery.js";
import Header from "../../../../components/Header.jsx";
import AOS from "aos";
import Background from "../../../Background/Background";

export default function StartExam() {
  const query = useQuery();
  const examId = Number(query.get("examId") ?? "0");
  const navigate = useNavigate();

  const [bookTitle, setBookTitle] = useState("");
  const [exam, setExam] = useState(null);
  const [examDirectory, setExamDirectory] = useState("");
  const [activeBtn, setActiveBtn] = useState(0);

  // 문제별 점수 관리 (0: 틀림, 1: 맞음, null: 미선택)
  const [scores, setScores] = useState(Array(20).fill(null));

  // 오디오 refs
  const audio0Ref = useRef(null);
  const audio1Ref = useRef(null);
  const audio2Ref = useRef(null);
  const audio3Ref = useRef(null);
  const audio4Ref = useRef(null);

  // 이전 examId 저장용
  const prevExamIdRef = useRef(null);

  // 초기화
  useEffect(() => {
    AOS.init();
  }, []);

  // 최초 진입 / 앞으로 이동 시 알림
  useEffect(() => {
    if (prevExamIdRef.current === null) {
      // 최초 진입
      alert("문제를 시작합니다");
      setScores(Array(20).fill(null)); // 점수 초기화
    } else if (examId > prevExamIdRef.current) {
      // 앞으로 이동
      alert("다음 문제를 시작합니다");
    } else if (examId < prevExamIdRef.current) {
      // 뒤로 이동 시 해당 문제 점수 초기화
      const newScores = [...scores];
      newScores[examId] = null;
      setScores(newScores);
    }
    prevExamIdRef.current = examId;
  }, [examId]);

  // 제목 불러오기
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

    setActiveBtn(0);

    const a0 = audio0Ref.current;
    const a1 = audio1Ref.current;
    const a2 = audio2Ref.current;
    const a3 = audio3Ref.current;
    const a4 = audio4Ref.current;

    if (!a0 || !a1 || !a2 || !a3 || !a4) return;

    const onEnd0 = () => { a1.play(); setActiveBtn(1); };
    const onEnd1 = () => { a2.play(); setActiveBtn(2); };
    const onEnd2 = () => { a3.play(); setActiveBtn(3); };
    const onEnd3 = () => { a4.play(); setActiveBtn(4); };
    const onEnd4 = () => { setActiveBtn(0); };

    a0.addEventListener("ended", onEnd0);
    a1.addEventListener("ended", onEnd1);
    a2.addEventListener("ended", onEnd2);
    a3.addEventListener("ended", onEnd3);
    a4.addEventListener("ended", onEnd4);

    try {
      a0.currentTime = 0;
      a1.currentTime = 0;
      a2.currentTime = 0;
      a3.currentTime = 0;
      a4.currentTime = 0;
    } catch {}

    a0.load(); a1.load(); a2.load(); a3.load(); a4.load();

    a0.play().catch(() => {
      console.warn("자동재생이 차단되었습니다. 첫 오디오를 클릭해 주세요.");
    });

    return () => {
      a0.removeEventListener("ended", onEnd0);
      a1.removeEventListener("ended", onEnd1);
      a2.removeEventListener("ended", onEnd2);
      a3.removeEventListener("ended", onEnd3);
      a4.removeEventListener("ended", onEnd4);

      [a0, a1, a2, a3, a4].forEach((a) => {
        try { a.pause(); } catch {}
      });
    };
  }, [exam, examId]);

  const handleClickChoice = (choiceIdx) => {
    if (!exam) return;

    const current = exam.data[examId];
    const isCorrect = Number(current.answer) === Number(choiceIdx);

    const newScores = [...scores];
    newScores[examId] = isCorrect ? 1 : 0; // 문제 단위 점수 저장
    setScores(newScores);

    if (examId + 1 < 20) {
      navigate(`/book/training/course/exam/start?examId=${examId + 1}`);
    } else {
      alert("화행검사가 끝났습니다");
      // 최종 점수 계산 가능: newScores.reduce((a,b)=>a+b,0)
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
                  {/* 공통 배경 추가 */}
      <Background />
      <div className="wrap">
        <Header title={bookTitle} />
        <div className="inner">
          <div className="ct_banner">{current?.type}</div>
          <div className="ct_inner">
            <div className="ct_question_a" data-aos="fade-up" data-aos-duration="1000">
              <p>{current?.title}</p>

              {/* 문제 오디오 */}
              <audio ref={audio0Ref} className="examAudio0">
                <source src={`${examDirectory}/${examId + 1}/문제.mp3`} type="audio/mpeg" />
              </audio>

              {/* 보기 4개 */}
              {current?.list?.map((value, idx) => {
                const n = idx + 1;
                const isActive = activeBtn === n;
                return (
                  <div key={idx}>
                    <button
                      className={`question_bt alert text-center ${isActive ? "alert-danger" : "alert-dark"}`}
                      id={`examBtn${n}`}
                      type="button"
                      onClick={() => handleClickChoice(idx)}
                    >
                      {n}. {value}
                    </button>
                    <audio
                      ref={[audio1Ref, audio2Ref, audio3Ref, audio4Ref][idx]}
                      className={`examAudio${n}`}
                    >
                      <source src={`${examDirectory}/${examId + 1}/${n}.mp3`} type="audio/mpeg" />
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
