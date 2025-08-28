// src/pages/Book/Training/course/play/PlayStart.jsx
import React, { useEffect, useRef, useState, useMemo } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import Header from "../../../../components/Header.jsx";
import AOS from "aos";
import Background from "../../../Background/Background";
import { useMicrophone } from "../../../../MicrophoneContext.jsx";

// 🔹 useQuery 훅 포함
function useQuery() {
  const { search } = useLocation();
  return useMemo(() => new URLSearchParams(search), [search]);
}

// 진행률 표시 컴포넌트
function ProgressBar({ current, total }) {
  if (!total || total <= 0) return null;
  return (
    <div
      style={{
        width: "100%",
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        marginTop: 20,
      }}
    >
      <span
        style={{
          width: 30,
          height: 30,
          borderRadius: "50%",
          border: "2px solid #3f51b5",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          color: "#3f51b5",
          fontWeight: "bold",
        }}
      >
        {current}
      </span>
      <div
        style={{
          flex: 1,
          height: 8,
          background: "#ccc",
          margin: "0 10px",
          borderRadius: 4,
          position: "relative",
        }}
      >
        <div
          style={{
            width: `${(current / total) * 100}%`,
            height: "100%",
            background: "#3f51b5",
            borderRadius: 4,
            transition: "width 0.3s ease",
          }}
        />
      </div>
      <span
        style={{
          width: 30,
          height: 30,
          borderRadius: "50%",
          border: "2px solid #ccc",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          color: "#999",
          fontWeight: "bold",
        }}
      >
        {total}
      </span>
    </div>
  );
}

export default function PlayStart() {
  const query = useQuery();
  const navigate = useNavigate();
  const speechId = Number(query.get("speechId") ?? "0");
  const { isMicrophoneActive, hasPermission, mediaRecorderRef: globalMediaRecorderRef, streamRef: globalStreamRef } = useMicrophone();

  const [bookTitle, setBookTitle] = useState("동화");
  const [speech, setSpeech] = useState(null);
  const [audioSrc, setAudioSrc] = useState("");
  const [windowWidth, setWindowWidth] = useState(window.innerWidth); // 브라우저 너비 상태

  const audioRef = useRef(null);
  const recordBtnRef = useRef(null);
  const stopBtnRef = useRef(null);
  const soundClipsRef = useRef(null);
  const chunksRef = useRef([]);

  // AOS 초기화
  useEffect(() => { AOS.init(); }, []);

  // 브라우저 창 너비 감지
  useEffect(() => {
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
        if (item?.speechAudio) {
          setAudioSrc(`/autobiography/${item.speechAudio}`);
        }
      })
      .catch((e) => {
        console.error(e);
        alert("연극 데이터를 불러오지 못했습니다.");
      });
  }, [speechId, navigate]);

  // 자동 오디오 재생
  useEffect(() => {
    if (!audioRef.current || !audioSrc) return;
    audioRef.current.load();
    audioRef.current.play().catch(() => {
      console.warn("자동재생 차단됨: 사용자 클릭 후 재생됩니다.");
    });
  }, [audioSrc]);

  // 뒤로가기/이탈 방지
  useEffect(() => {
    const handleBeforeUnload = (e) => {
      e.preventDefault();
      e.returnValue = "녹음 중인 경우 데이터가 손실될 수 있습니다. 정말 나가시겠습니까?";
      return e.returnValue;
    };
    window.addEventListener('beforeunload', handleBeforeUnload);
    return () => window.removeEventListener('beforeunload', handleBeforeUnload);
  }, []);

  // 녹음 기능
  useEffect(() => {
    const recordBtn = recordBtnRef.current;
    const stopBtn = stopBtnRef.current;
    const soundClips = soundClipsRef.current;
    if (!recordBtn || !stopBtn || !soundClips) return;
    if (!isMicrophoneActive || !hasPermission) return;

    if (globalStreamRef.current) {
      const mediaRecorder = new MediaRecorder(globalStreamRef.current);
      globalMediaRecorderRef.current = mediaRecorder;

      const cleanup = () => {
        recordBtn.onclick = null;
        stopBtn.onclick = null;
      };

      recordBtn.onclick = () => {
        if (mediaRecorder.state === "inactive") {
          mediaRecorder.start();
          recordBtn.style.setProperty('background', 'red', 'important');
          recordBtn.style.setProperty('color', 'white', 'important');
          stopBtn.style.setProperty('background', '#3f51b5', 'important');
          stopBtn.style.setProperty('color', 'white', 'important');
        }
      };

      stopBtn.onclick = () => {
        if (mediaRecorder.state === "recording") {
          mediaRecorder.stop();
          recordBtn.style.setProperty('background', '', 'important');
          recordBtn.style.setProperty('color', '', 'important');
          stopBtn.style.setProperty('background', '', 'important');
          stopBtn.style.setProperty('color', '', 'important');
        }
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
        a.download = `동화연극_${bookTitle}_${speechId + 1}.mp3`;
        clipContainer.appendChild(a);

        soundClips.appendChild(clipContainer);
        a.click();

        if (speechId + 1 < speech.length) {
          navigate(`/book/training/course/play/start?speechId=${speechId + 1}`);
        } else {
          alert("동화연극이 완료되었습니다! 화행검사 결과 페이지로 이동합니다.");
          navigate("/bookHistory");
        }
      };

      return cleanup;
    }
  }, [speechId, speech, navigate, isMicrophoneActive, hasPermission, bookTitle]);

  const item = Array.isArray(speech) ? speech[speechId] : null;

  return (
    <div className="content">
      {/* 일정 너비 이하이면 Background 숨기기 */}
      {windowWidth > 1100 && <Background />}
      <div className="wrap" style={{ margin: "0 auto", maxWidth: 520 }}>
        <Header title={bookTitle} />
        <audio className="speechAudio0" ref={audioRef}>
          {audioSrc && <source src={audioSrc} type="audio/mpeg" />}
        </audio>
        <div className="inner">
          <div className="ct_inner">
            <div id="recordBox" className="ct_question_a ct_theater_a" data-aos="fade-up" data-aos-duration="1000">
              <p>{item?.speechText ?? "로딩 중..."}</p>
              <div className="bt_flex">
                <button className="question_bt" id="record" type="button" ref={recordBtnRef}>녹음</button>
                <button className="question_bt" id="stop" type="button" ref={stopBtnRef}>정지</button>
              </div>
              <div id="sound-clips" ref={soundClipsRef} style={{ marginTop: 40 }} />
            </div>
          </div>
        </div>
        <ProgressBar current={speechId + 1} total={speech?.length || 0} />
      </div>
    </div>
  );
}
