// src/pages/Interview/InterviewStart.jsx
import React, { useEffect, useRef, useState } from "react";
import useQuery from "../../hooks/useQuery.js"; // 경로 확인
import Header from "../../components/Header.jsx";
import AOS from "aos";
import "aos/dist/aos.css";

export default function InterviewStart() {
  const query = useQuery();
  const questionId = Number(query.get("questionId") ?? "0");

const [bookTitle] = useState("회상훈련");
  const [questions, setQuestions] = useState([]);

  const recordBtnRef = useRef(null);
  const stopBtnRef = useRef(null);
  const soundClipsRef = useRef(null);
  const mediaRecorderRef = useRef(null);
  const chunksRef = useRef([]);

  useEffect(() => {
    AOS.init();
  }, []);

  // bookTitle 설정
  // useEffect(() => {
  //   setBookTitle(localStorage.getItem("bookTitle") || "인터뷰");
  // }, []);

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

    let streamCleanup = null;

    navigator.mediaDevices
      .getUserMedia({ audio: true })
      .then((stream) => {
        const mediaRecorder = new MediaRecorder(stream);
        mediaRecorderRef.current = mediaRecorder;
        streamCleanup = () => stream.getTracks().forEach((t) => t.stop());

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
      if (streamCleanup) streamCleanup();
    };
  }, []);

  const currentQuestion = Array.isArray(questions) ? questions[questionId] : null;

  return (
    <div className="content">
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
      </div>
    </div>
  );
}
