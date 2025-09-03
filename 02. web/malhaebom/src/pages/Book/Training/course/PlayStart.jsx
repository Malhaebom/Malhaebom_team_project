// src/pages/Book/Training/course/play/PlayStart.jsx
import React, { useEffect, useRef, useState } from "react";
import useQuery from "../../../../hooks/useQuery.js";
import Header from "../../../../components/Header.jsx";
import AOS from "aos";
import "aos/dist/aos.css";
import Background from "../../../Background/Background";
import { useNavigate } from "react-router-dom";

export default function PlayStart() {
  const query = useQuery();
  const navigate = useNavigate();
  const speechId = Number(query.get("speechId") ?? "0");

  const [bookTitle, setBookTitle] = useState("동화");
  const [speech, setSpeech] = useState([]);
  const [audioSrc, setAudioSrc] = useState("");
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);

  const [isRecording, setIsRecording] = useState(false);
  const [recordingCompleted, setRecordingCompleted] = useState(false);
  const [localRecordingError, setLocalRecordingError] = useState(null);
  const [recordingUrl, setRecordingUrl] = useState("");

  const audioRef = useRef(null);
  const mediaRecorderRef = useRef(null);
  const chunksRef = useRef([]);
  const streamRef = useRef(null);
  const alertShownRef = useRef(false);

  // 창 크기 감지
  useEffect(() => {
    AOS.init();
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  // bookTitle
  useEffect(() => {
    setBookTitle(localStorage.getItem("bookTitle") || "동화");
  }, []);

  // speech JSON 로드
  useEffect(() => {
    const speechPath = localStorage.getItem("speechPath");
    if (!speechPath) {
      alert("연극 데이터 경로가 없습니다. 목록으로 이동합니다.");
      navigate("/book/training/course/play?bookId=0");
      return;
    }

    fetch(`/autobiography/${speechPath}`)
      .then((r) => {
        if (!r.ok) throw new Error("speech JSON 로드 실패");
        return r.json();
      })
      .then((json) => {
        setSpeech(json);
        const item = json?.[speechId];
        if (item?.speechAudio) setAudioSrc(`/autobiography/${item.speechAudio}`);
      })
      .catch((e) => {
        console.error(e);
        alert("연극 데이터를 불러오지 못했습니다.");
      });
  }, [speechId, navigate]);

  // 페이지 진입 알림 (한 번만)
  useEffect(() => {
    if (!alertShownRef.current) {
      alert("연극을 시작합니다");
      alertShownRef.current = true;
    }
  }, []);

  // 음성 자동 재생
  useEffect(() => {
    const audio = audioRef.current;
    if (!audio || !audioSrc) return;
    audio.load();
    audio.play().catch(() => {
      console.warn("자동재생 차단됨: 사용자 클릭 후 재생됩니다.");
    });
  }, [audioSrc]);

  // MediaRecorder 생성 및 녹음 시작
  const startRecording = async () => {
    if (!navigator.mediaDevices) {
      alert("마이크를 사용할 수 없는 환경입니다!");
      return;
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;

      const mediaRecorder = new MediaRecorder(stream);
      mediaRecorderRef.current = mediaRecorder;
      chunksRef.current = [];

      mediaRecorder.ondataavailable = (e) => chunksRef.current.push(e.data);

      mediaRecorder.onstop = () => {
        if (!chunksRef.current.length) return;

        const blob = new Blob(chunksRef.current, { type: "audio/mp3 codecs=opus" });
        chunksRef.current = [];

        const playUrl = URL.createObjectURL(blob);
        setRecordingUrl(playUrl);

        // 자동 다운로드 파일명: 책제목_문항n.mp3
        const fileName = `${bookTitle}_문항${speechId + 1}.mp3`;
        const a = document.createElement("a");
        a.href = playUrl;
        a.download = fileName;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);

        setRecordingCompleted(true);
        setIsRecording(false);

        // 마이크 종료
        if (streamRef.current) {
          streamRef.current.getTracks().forEach((track) => track.stop());
          streamRef.current = null;
        }
        mediaRecorderRef.current = null;
      };

      mediaRecorder.onerror = (e) => {
        console.error("MediaRecorder 오류:", e.error);
        setLocalRecordingError("녹음 중 오류가 발생했습니다.");
        setIsRecording(false);
        if (streamRef.current) {
          streamRef.current.getTracks().forEach((track) => track.stop());
          streamRef.current = null;
        }
        mediaRecorderRef.current = null;
      };

      mediaRecorder.start();
      setIsRecording(true);
      setRecordingCompleted(false);
      setLocalRecordingError(null);
    } catch (err) {
      console.error("마이크 접근 실패:", err);
      alert("마이크를 사용할 수 없는 환경입니다!");
    }
  };

  // 녹음 정지
  const stopRecording = () => {
    if (!mediaRecorderRef.current) return;
    if (mediaRecorderRef.current.state === "recording") {
      mediaRecorderRef.current.stop();
    }
  };

  // 다음 연극 문장 이동
  const goToNextSpeech = () => {
    const nextSpeechId = speechId + 1;
    navigate(`/book/training/course/play/start?speechId=${nextSpeechId}`);
  };

  const item = Array.isArray(speech) ? speech[speechId] : null;

  return (
    <div className="content">
      {windowWidth > 1100 && <Background />}
      <div className="wrap">
        <Header title={bookTitle} />
        <audio ref={audioRef}>
          {audioSrc && <source src={audioSrc} type="audio/mpeg" />}
        </audio>
        <div className="inner">
          <div className="ct_inner">
            <div
              id="recordBox"
              className="ct_question_a ct_theater_a"
              data-aos="fade-up"
              data-aos-duration="1000"
            >
              <p>{item?.speechText ?? "로딩 중..."}</p>

              {localRecordingError && (
                <div style={{ color: "red", marginBottom: 10 }}>{localRecordingError}</div>
              )}

              {/* 녹음/정지/다음 버튼 */}
              <div className="bt_flex" style={{ gap: "10px", marginTop: 10 }}>
                <button
                  className="question_bt"
                  onClick={startRecording}
                  disabled={isRecording}
                  style={{
                    flex: 1,
                    opacity: isRecording ? 0.6 : 1,
                    cursor: isRecording ? "not-allowed" : "pointer",
                    background: (isRecording || recordingCompleted) ? '#4a85d1' : '#3f51b5',
                    color: "white",
                    border: "none",
                    borderRadius: 5,
                    padding: "12px",
                    fontWeight: "bold",
                    transition: "all 0.2s",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: "8px"
                  }}
                >
                  {isRecording && (
                    <div
                      style={{
                        width: "12px",
                        height: "12px",
                        borderRadius: "50%",
                        backgroundColor: "#ff0000",
                        animation: "pulse 1s ease-in-out infinite"
                      }}
                    />
                  )}
                  {isRecording ? "녹음 중" : "녹음 시작"}
                </button>

                <button
                  className="question_bt"
                  onClick={stopRecording}
                  disabled={!isRecording}
                  style={{
                    flex: 1,
                    opacity: !isRecording ? 0.6 : 1,
                    cursor: !isRecording ? "not-allowed" : "pointer",
                    backgroundColor: "red",
                    color: "white",
                    border: "none",
                    borderRadius: 5,
                    padding: "12px",
                    fontWeight: "bold",
                    transition: "all 0.2s"
                  }}
                >
                  녹음 정지
                </button>

                <button
                  className="question_bt"
                  onClick={goToNextSpeech}
                  disabled={!recordingCompleted || isRecording}
                  style={{
                    flex: 1,
                    opacity: !recordingCompleted || isRecording ? 0.6 : 1,
                    cursor: !recordingCompleted || isRecording ? "not-allowed" : "pointer",
                    backgroundColor: "#4CAF50",
                    color: "white",
                    border: "none",
                    borderRadius: 5,
                    padding: "12px",
                    fontWeight: "bold",
                    transition: "all 0.2s"
                  }}
                >
                  다음
                </button>
              </div>

              {/* 녹음 완료 후 재생바 */}
              {recordingCompleted && recordingUrl && (
                <audio
                  controls
                  src={recordingUrl}
                  style={{
                    marginTop: 15,
                    width: "100%",
                    height: "50px",
                    borderRadius: 8,
                    background: "#f5f5f5"
                  }}
                />
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
