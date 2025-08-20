import React, { useEffect, useRef, useState } from "react";
import useQuery from "../../../../hooks/useQuery.js";
import Header from "../../../../components/Header.jsx";
import AOS from "aos";


export default function PlayStart() {
  const query = useQuery();
  const speechId = Number(query.get("speechId") ?? "0");

  const [bookTitle, setBookTitle] = useState("동화");
  const [speech, setSpeech] = useState(null); // 배열
  const [audioSrc, setAudioSrc] = useState(""); // 문제 음성

  const audioRef = useRef(null);
  const recordBtnRef = useRef(null);
  const stopBtnRef = useRef(null);
  const soundClipsRef = useRef(null);
  const mediaRecorderRef = useRef(null);
  const chunksRef = useRef([]);

  useEffect(() => {
    AOS.init();
  }, []);

  // 1) bookTitle
  useEffect(() => {
    setBookTitle(localStorage.getItem("bookTitle") || "동화");
  }, []);

  // 2) speech JSON 로드
  useEffect(() => {
    const speechPath = localStorage.getItem("speechPath");
    if (!speechPath) {
      alert("연극 데이터 경로가 없습니다. 목록으로 이동합니다.");
      location.href = "/book/training/course/play?bookId=0";
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
  }, [speechId]);

  // 3) 페이지 진입 시 알림 + 음성 재생
  useEffect(() => {
    alert("연극을 시작합니다");
  }, []);

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio || !audioSrc) return;
    // 자동재생 시도
    audio.load();
    audio.play().catch(() => {
      console.warn("자동재생 차단됨: 사용자 클릭 후 재생됩니다.");
    });
  }, [audioSrc]);

  // 4) 녹음 기능 설정
  useEffect(() => {
    const recordBtn = recordBtnRef.current;
    const stopBtn = stopBtnRef.current;
    const soundClips = soundClipsRef.current;

    if (!recordBtn || !stopBtn || !soundClips) return;

    if (!navigator.mediaDevices) {
      alert("마이크를 사용할 수 없는 환경입니다!");
      // Vue 코드에서는 recordBox 제거 + history.go(-2)
      history.go(-2);
      return;
    }

    let streamCleanup = null;

    navigator.mediaDevices
      .getUserMedia({ audio: true })
      .then((stream) => {
        const mediaRecorder = new MediaRecorder(stream);
        mediaRecorderRef.current = mediaRecorder;
        streamCleanup = () => {
          stream.getTracks().forEach((t) => t.stop());
        };

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
          // 컨테이너 비우고 새로 추가
          while (soundClips.firstChild) {
            soundClips.removeChild(soundClips.firstChild);
          }

          const clipContainer = document.createElement("article");
          const audio = document.createElement("audio");
          audio.setAttribute("controls", "");
          clipContainer.appendChild(audio);

          const blob = new Blob(chunksRef.current, {
            type: "audio/mp3 codecs=opus",
          });
          chunksRef.current = [];

          const audioURL = URL.createObjectURL(blob);
          audio.src = audioURL;

          // 파일 저장 링크
          const a = document.createElement("a");
          a.href = audio.src;
          a.download = "voiceRecord";
          clipContainer.appendChild(a);

          soundClips.appendChild(clipContainer);

          // 자동 다운로드 (원본 로직과 동일)
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
      if (streamCleanup) {
        streamCleanup();
      }
    };
  }, []);

  const item = Array.isArray(speech) ? speech[speechId] : null;

  return (
    <div className="content">
      <div className="wrap">
        <Header title={bookTitle} />
        {/* 원본: 상단에 오디오 태그 */}
        <audio className="speechAudio0" ref={audioRef}>
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
              <div className="bt_flex">
                <button
                  className="question_bt"
                  id="record"
                  type="button"
                  ref={recordBtnRef}
                >
                  <i className="xi-play"></i>녹음
                </button>
                <button
                  className="question_bt"
                  id="stop"
                  type="button"
                  ref={stopBtnRef}
                >
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
