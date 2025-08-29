import React, { useEffect, useRef, useState } from "react";
import useQuery from "../../hooks/useQuery.js"; 
import Header from "../../components/Header.jsx";
import AOS from "aos";
import "aos/dist/aos.css";
import ProgressBar from "./ProgressBar.jsx";
import Background from "../Background/Background";
import { useNavigate } from "react-router-dom";
import { useMicrophone } from "../../MicrophoneContext.jsx";

export default function InterviewStart() {
  const query = useQuery();
  const navigate = useNavigate();
  const { 
    isMicrophoneActive, 
    hasPermission, 
    mediaRecorderRef: globalMediaRecorderRef,
    streamRef: globalStreamRef 
  } = useMicrophone();
  const initialQuestionId = Number(query.get("questionId") ?? "0");

  const [bookTitle] = useState("회상훈련");
  const [questions, setQuestions] = useState([]);
  const [questionId, setQuestionId] = useState(initialQuestionId);

  const recordBtnRef = useRef(null);
  const stopBtnRef = useRef(null);
  const soundClipsRef = useRef(null);
  const chunksRef = useRef([]);

  // 브라우저 크기 상태
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);

  useEffect(() => {
    AOS.init();

    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  // 인터뷰 질문 JSON 로드
  useEffect(() => {
    fetch("/autobiography/interview.json")
      .then((r) => {
        if (!r.ok) throw new Error("인터뷰 JSON 로드 실패");
        return r.json();
      })
      .then((json) => setQuestions(json))
      .catch((e) => {
        console.error(e);
        alert("인터뷰 질문을 불러오지 못했습니다.");
      });
  }, []);

  // 뒤로가기 및 페이지 이탈 처리
  useEffect(() => {
    const handleBeforeUnload = (e) => {
      e.preventDefault();
      e.returnValue = "녹음 중인 경우 데이터가 손실될 수 있습니다. 정말 나가시겠습니까?";
      return e.returnValue;
    };
    const handlePopState = (e) => {
      e.preventDefault();
      window.location.reload();
      window.history.back();
    };

    window.addEventListener('beforeunload', handleBeforeUnload);
    window.addEventListener('popstate', handlePopState);

    return () => {
      window.removeEventListener('beforeunload', handleBeforeUnload);
      window.removeEventListener('popstate', handlePopState);
    };
  }, []);

  // 녹음 기능 설정
  useEffect(() => {
    const recordBtn = recordBtnRef.current;
    const stopBtn = stopBtnRef.current;
    const soundClips = soundClipsRef.current;

    if (!recordBtn || !stopBtn || !soundClips) return;
    if (!isMicrophoneActive || !hasPermission) {
      console.log("마이크 권한 대기 중...");
      return;
    }

    if (globalStreamRef.current) {
      const mediaRecorder = new MediaRecorder(globalStreamRef.current);
      globalMediaRecorderRef.current = mediaRecorder;

      recordBtn.onclick = () => {
        mediaRecorder.start();
        recordBtn.style.background = "red";
        recordBtn.style.color = "white";
      };

      stopBtn.onclick = () => {
        mediaRecorder.stop();
        recordBtn.style.background = "";
        recordBtn.style.color = "";
      };

      mediaRecorder.ondataavailable = (e) => chunksRef.current.push(e.data);

      mediaRecorder.onstop = () => {
        while (soundClips.firstChild) soundClips.removeChild(soundClips.firstChild);

        const clipContainer = document.createElement("article");
        const audio = document.createElement("audio");
        audio.setAttribute("controls", "");
        clipContainer.appendChild(audio);

        const blob = new Blob(chunksRef.current, { type: "audio/mp3 codecs=opus" });
        chunksRef.current = [];

        audio.src = URL.createObjectURL(blob);

        const a = document.createElement("a");
        a.href = audio.src;
        a.download = "voiceRecord";
        clipContainer.appendChild(a);

        soundClips.appendChild(clipContainer);
        a.click();

        if (questionId + 1 < questions.length) {
          setQuestionId((prev) => prev + 1);
        } else {
          alert("모든 인터뷰가 완료되었습니다!");
          if (recordBtnRef.current) {
            recordBtnRef.current.style.background = "";
            recordBtnRef.current.style.color = "";
          }
          navigate("/InterviewHistory");
        }
      };
    }
  }, [questionId, questions.length, navigate, isMicrophoneActive, hasPermission]);

  const currentQuestion = Array.isArray(questions) ? questions[questionId] : null;

  return (
    <div className="content">
      {/* 가로 1100 이상일 때만 배경 렌더링 */}
      {windowWidth > 1100 && <Background />}
      
      <div
        className="wrap"
        style={{
          maxWidth: "520px",
          margin: "0 auto",
          padding: "80px 20px",
          fontFamily: "Pretendard-Regular",
          display: "block",
          alignItems: "unset",
          justifyContent: "unset",
        }}
      >
        <Header title={bookTitle} />
        <div className="inner">
          <div className="ct_inner">
            <div
              id="recordBox"
              className="ct_question_a ct_theater_a"
              data-aos="fade-up"
              data-aos-duration="1000"
            >
              <p>{currentQuestion?.speechText ?? "로딩 중..."}</p>
              <div className="bt_flex">
                <button className="question_bt" ref={recordBtnRef}>
                  <i className="xi-play"></i>녹음
                </button>
                <button className="question_bt" ref={stopBtnRef}>
                  <i className="xi-pause"></i>정지
                </button>
              </div>
              <div id="sound-clips" ref={soundClipsRef} style={{ marginTop: 40 }} />
            </div>
          </div>
        </div>
        <ProgressBar current={questionId + 1} total={questions.length} />
      </div>
    </div>
  );
}
