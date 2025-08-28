// src/pages/Book/Training/course/StartExam.jsx
import { useNavigate } from "react-router-dom";
import React, { useEffect, useRef, useState } from "react";
import useQuery from "../../../../hooks/useQuery.js";
import Header from "../../../../components/Header.jsx";
import AOS from "aos";
import Background from "../../../Background/Background";
import { useScores } from "../../../../ScoreContext.jsx";
import { scoreBucketByQuestionNumber } from "../utils.js";

export default function StartExam() {
  const query = useQuery();
  const examId = Number(query.get("examId") ?? "0");
  const navigate = useNavigate();
  const { setScoreAD, setScoreAI, setScoreB, setScoreC, setScoreD, resetScores } = useScores();

  const [bookTitle, setBookTitle] = useState("");
  const [exam, setExam] = useState(null);
  const [examDirectory, setExamDirectory] = useState("");
  const [isLoading, setIsLoading] = useState(true); // 로딩 상태 추가

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
    AOS.init({ once: true }); // once: true로 설정하여 한 번만 실행
  }, []);

  // 최초 진입 시에만 초기화
  useEffect(() => {
    if (prevExamIdRef.current === null) {
      // 최초 진입 시에만 실행
      setScores(Array(20).fill(null)); // 점수 초기화
      resetScores(); // ScoreContext 점수 초기화
    }
    prevExamIdRef.current = examId;
  }, [resetScores]); // examId 의존성 제거

  // 제목 불러오기
  useEffect(() => {
    setBookTitle(localStorage.getItem("bookTitle") || "동화");
  }, []);

  // exam JSON 로드 (한 번만 로드)
  useEffect(() => {
    // 이미 exam이 로드되어 있으면 다시 로드하지 않음
    if (exam) return;
    
    setIsLoading(true); // 로딩 시작
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
        setIsLoading(false); // 로딩 완료
      })
      .catch((e) => {
        console.error(e);
        alert("검사 파일을 불러오지 못했습니다.");
        setIsLoading(false); // 에러 시에도 로딩 완료
      });
  }, [navigate]); // exam 의존성 제거하여 무한 루프 방지

  // examId가 변경될 때마다 해당 문제의 음성을 자동 재생
  useEffect(() => {
    if (exam && examDirectory && audio0Ref.current) {
      // 이전 오디오 정지
      audio0Ref.current.pause();
      audio0Ref.current.currentTime = 0;
      
      // 새로운 문제 음성 재생
      const playAudio = async () => {
        try {
          await audio0Ref.current.play();
        } catch (error) {
          console.error("오디오 재생 실패:", error);
        }
      };
      
      // 오디오 로드 완료 후 재생
      audio0Ref.current.addEventListener('loadeddata', playAudio, { once: true });
      
      // 오디오 로드 시작
      audio0Ref.current.load();
    }
  }, [examId, exam, examDirectory]);

  const handleClickChoice = (choiceIdx) => {
    if (!exam) return;

    const current = exam.data[examId];
    const isCorrect = Number(current.answer) === Number(choiceIdx);

    const newScores = [...scores];
    newScores[examId] = isCorrect ? 1 : 0; // 문제 단위 점수 저장
    setScores(newScores);

    // ScoreContext 업데이트 - 정답인 경우에만 점수 추가
    if (isCorrect) {
      const questionNumber = examId + 1; // 1-based 문제 번호
      const scoreKey = scoreBucketByQuestionNumber(questionNumber);
      
      switch(scoreKey) {
        case 'scoreAD':
          setScoreAD(prev => prev + 1);
          break;
        case 'scoreAI':
          setScoreAI(prev => prev + 1);
          break;
        case 'scoreB':
          setScoreB(prev => prev + 1);
          break;
        case 'scoreC':
          setScoreC(prev => prev + 1);
          break;
        case 'scoreD':
          setScoreD(prev => prev + 1);
          break;
        default:
          console.warn('Unknown score key:', scoreKey);
      }
    }

    if (examId + 1 < 20) {
      navigate(`/book/training/course/exam/start?examId=${examId + 1}`);
    } else {
      alert("화행검사가 끝났습니다");
      // 최종 점수 계산 가능: newScores.reduce((a,b)=>a+b,0)
      navigate(`/book/training/course/exam/result`);
    }
  };

  const current = exam && exam.data && exam.data[examId] ? exam.data[examId] : null;

  // current가 없으면 로딩 화면 표시
  if (!current) {
    return (
      <div className="content">
        <Background />
        <div className="wrap">
          <Header title={bookTitle} />
          <div className="inner">
            <div className="ct_banner">문제를 준비하고 있습니다...</div>
            <div className="ct_inner">
              <div className="ct_question_a" style={{ textAlign: 'center', padding: '40px 0' }}>
                <p style={{ fontSize: '16px', color: '#666' }}>잠시만 기다려주세요</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="content">
      <Background />
      <div className="wrap">
        <Header title={bookTitle} />
        <div className="inner">
          <div className="ct_banner">{current?.type}</div>
          <div className="ct_inner">
            <div className="ct_question_a" data-aos="fade-up" data-aos-duration="1000" key={examId}>
              <p style={{ fontSize: '18px', lineHeight: '1.6', marginBottom: '20px', fontWeight: '500' }}>
                {current?.title}
              </p>

              {/* 문제 오디오 */}
              <audio ref={audio0Ref} className="examAudio0">
                <source src={`${examDirectory}/${examId + 1}/문제.mp3`} type="audio/mpeg" />
              </audio>

              {/* 보기 4개 */}
              {current?.list?.map((value, idx) => {
                const n = idx + 1;
                return (
                  <div key={idx}>
                    <button
                      className="question_bt alert alert-dark text-center"
                      id={`examBtn${n}`}
                      type="button"
                      onClick={() => handleClickChoice(idx)}
                      style={{ marginBottom: '10px', fontSize: '16px', padding: '12px' }}
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
