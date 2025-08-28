import React, { useEffect, useRef, useState } from "react";
import useQuery from "../../hooks/useQuery.js"; 
import Header from "../../components/Header.jsx";
import AOS from "aos";
import "aos/dist/aos.css";
import ProgressBar from "./ProgressBar.jsx";
import Background from "../Background/Background";
import { useNavigate } from "react-router-dom";

export default function InterviewStart() {
  const query = useQuery();
  const navigate = useNavigate();
  const initialQuestionId = Number(query.get("questionId") ?? "0");

  const [bookTitle] = useState("회상훈련");
  const [questions, setQuestions] = useState([]);
  const [questionId, setQuestionId] = useState(initialQuestionId);

  const recordBtnRef = useRef(null);
  const stopBtnRef = useRef(null);
  const soundClipsRef = useRef(null);
  const mediaRecorderRef = useRef(null);
  const chunksRef = useRef([]);
  const streamCleanupRef = useRef(null);

  useEffect(() => {
    AOS.init();
  }, []);

  // 인터뷰 질문 JSON 로드
  useEffect(() => {
    fetch("/autobiography/interview.json")
      .then((r) => {
        if (!r.ok) throw new Error("인터뷰 JSON 로드 실패");
        return r.json();
      })
      .then((json) => {
        setQuestions(json);
      })
      .catch((e) => {
        console.error(e);
        alert("인터뷰 질문을 불러오지 못했습니다.");
      });
  }, []);

  // 뒤로가기 및 페이지 이탈 처리
  useEffect(() => {
    const handleBeforeUnload = (e) => {
      // 마이크 정리
      if (mediaRecorderRef.current && mediaRecorderRef.current.state !== "inactive") {
        mediaRecorderRef.current.stop();
      }
      if (streamCleanupRef.current) {
        streamCleanupRef.current();
      }
      
      // 사용자에게 경고 메시지 표시
      e.preventDefault();
      e.returnValue = "녹음 중인 경우 데이터가 손실될 수 있습니다. 정말 나가시겠습니까?";
      return e.returnValue;
    };

    const handlePopState = (e) => {
      // 뒤로가기 시 새로고침 처리
      e.preventDefault();
      
      // 마이크 정리
      if (mediaRecorderRef.current && mediaRecorderRef.current.state !== "inactive") {
        mediaRecorderRef.current.stop();
      }
      if (streamCleanupRef.current) {
        streamCleanupRef.current();
      }
      
      // 새로고침 후 뒤로가기
      window.location.reload();
      window.history.back();
    };

    // 이벤트 리스너 등록
    window.addEventListener('beforeunload', handleBeforeUnload);
    window.addEventListener('popstate', handlePopState);

    // Cleanup
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
    if (!navigator.mediaDevices) {
      alert("마이크를 사용할 수 없는 환경입니다!");
      history.go(-2);
      return;
    }

    navigator.mediaDevices
      .getUserMedia({ audio: true })
      .then((stream) => {
        const mediaRecorder = new MediaRecorder(stream);
        mediaRecorderRef.current = mediaRecorder;
        streamCleanupRef.current = () => stream.getTracks().forEach((t) => t.stop());

        recordBtn.onclick = () => {
          mediaRecorder.start();
          recordBtn.style.background = "red";
          recordBtn.style.color = "black";
        };

        stopBtn.onclick = () => {
          mediaRecorder.stop();
          recordBtn.style.background = "";
          recordBtn.style.color = "";
        };

        mediaRecorder.ondataavailable = (e) => {
          chunksRef.current.push(e.data);
        };

        mediaRecorder.onstop = () => {
          while (soundClips.firstChild) soundClips.removeChild(soundClips.firstChild);

          const clipContainer = document.createElement("article");
          const audio = document.createElement("audio");
          audio.setAttribute("controls", "");
          clipContainer.appendChild(audio);

          const blob = new Blob(chunksRef.current, { type: "audio/mp3 codecs=opus" });
          chunksRef.current = [];

          const audioURL = URL.createObjectURL(blob);
          audio.src = audioURL;

          const a = document.createElement("a");
          a.href = audio.src;
          a.download = "voiceRecord";
          clipContainer.appendChild(a);

          soundClips.appendChild(clipContainer);
          a.click();

          // 🔹 녹음 후 다음 질문으로 이동
          if (questionId + 1 < questions.length) {
            setQuestionId((prev) => prev + 1);
          } else {
            // 마지막 질문 완료 시 마이크 OFF 후 InterviewHistory 페이지로 이동
            alert("모든 인터뷰가 완료되었습니다!");
            
            // 마이크 명시적 OFF
            try {
              if (mediaRecorderRef.current && mediaRecorderRef.current.state !== "inactive") {
                mediaRecorderRef.current.stop();
              }
              if (streamCleanupRef.current) {
                streamCleanupRef.current();
              }
            } catch (error) {
              console.log("마이크 정리 중 오류:", error);
            }
            
            // 약간의 지연 후 페이지 이동
            setTimeout(() => {
              navigate("/InterviewHistory");
            }, 100);
          }
        };
      })
      .catch((err) => {
        console.log("오류 발생 :", err);
        alert("마이크를 사용할 수 없는 환경입니다!");
        history.go(-2);
      });

    return () => {
      try {
        if (mediaRecorderRef.current && mediaRecorderRef.current.state !== "inactive") {
          mediaRecorderRef.current.stop();
        }
      } catch {}
      if (streamCleanupRef.current) streamCleanupRef.current();
    };
  }, [questionId, questions.length, navigate]);

  const currentQuestion = Array.isArray(questions) ? questions[questionId] : null;

  return (
    <div className="content">
            {/* 공통 배경 추가 */}
      <Background />
      <div className="wrap">
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
