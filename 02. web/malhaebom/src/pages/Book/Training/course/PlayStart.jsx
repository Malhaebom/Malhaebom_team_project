import React, { useEffect, useRef, useState } from "react";
import useQuery from "../../../../hooks/useQuery.js";
import Header from "../../../../components/Header.jsx";
import AOS from "aos";
import Background from "../../../Background/Background";
import { useMicrophone } from "../../../../MicrophoneContext.jsx";
import { useNavigate } from "react-router-dom";

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
  const { 
    isMicrophoneActive, 
    hasPermission, 
    mediaRecorderRef: globalMediaRecorderRef,
    streamRef: globalStreamRef 
  } = useMicrophone();

  const [bookTitle, setBookTitle] = useState("동화");
  const [speech, setSpeech] = useState(null); // 배열
  const [audioSrc, setAudioSrc] = useState(""); // 문제 음성

  const audioRef = useRef(null);
  const recordBtnRef = useRef(null);
  const stopBtnRef = useRef(null);
  const soundClipsRef = useRef(null);
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

  // 3) 페이지 진입 시 알림 + 음성 재생
  useEffect(() => {
    // alert 제거 - 더 이상 시작 메시지 표시하지 않음
  }, []); // speechId 의존성 제거하여 1회만 실행

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio || !audioSrc) return;
    // 자동재생 시도
    audio.load();
    audio.play().catch(() => {
      console.warn("자동재생 차단됨: 사용자 클릭 후 재생됩니다.");
    });
  }, [audioSrc]);

  // 4) 뒤로가기 및 페이지 이탈 처리
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

  // 5) 녹음 기능 설정 (회상훈련 방식으로 개선)
  useEffect(() => {
    const recordBtn = recordBtnRef.current;
    const stopBtn = stopBtnRef.current;
    const soundClips = soundClipsRef.current;

    if (!recordBtn || !stopBtn || !soundClips) return;
    
    // 전역 마이크가 활성화되지 않았다면 대기
    if (!isMicrophoneActive || !hasPermission) {
      console.log("마이크 권한 대기 중...");
      return;
    }

    // 전역 스트림을 사용하여 MediaRecorder 생성
    if (globalStreamRef.current) {
      const mediaRecorder = new MediaRecorder(globalStreamRef.current);
      globalMediaRecorderRef.current = mediaRecorder;

      // 이벤트 리스너 정리 함수
      const cleanup = () => {
        recordBtn.onclick = null;
        stopBtn.onclick = null;
      };

      // 녹음 버튼 클릭 이벤트
      const handleRecordClick = () => {
        console.log("녹음 버튼 클릭됨, MediaRecorder 상태:", mediaRecorder.state);
        if (mediaRecorder.state === "inactive") {
          mediaRecorder.start();
          
          // 녹음 버튼 스타일 적용 (빨간바탕 하얀글씨) - !important 사용
          recordBtn.style.setProperty('background', 'red', 'important');
          recordBtn.style.setProperty('color', 'white', 'important');
          recordBtn.style.setProperty('border-color', 'red', 'important');
          
          // 정지 버튼 스타일 적용 (파란바탕 하얀글씨) - !important 사용
          stopBtn.style.setProperty('background', '#3f51b5', 'important');
          stopBtn.style.setProperty('color', 'white', 'important');
          stopBtn.style.setProperty('border-color', '#3f51b5', 'important');
          
          console.log("녹음 시작 - 버튼 스타일 적용됨");
          console.log("녹음 버튼 스타일:", recordBtn.style.background, recordBtn.style.color);
          console.log("정지 버튼 스타일:", stopBtn.style.background, stopBtn.style.color);
        }
      };

      // 정지 버튼 클릭 이벤트
      const handleStopClick = () => {
        console.log("정지 버튼 클릭됨, MediaRecorder 상태:", mediaRecorder.state);
        if (mediaRecorder.state === "recording") {
          mediaRecorder.stop();
          
          // 버튼 스타일 초기화 - !important 사용
          recordBtn.style.setProperty('background', '', 'important');
          recordBtn.style.setProperty('color', '', 'important');
          recordBtn.style.setProperty('border-color', '', 'important');
          stopBtn.style.setProperty('background', '', 'important');
          stopBtn.style.setProperty('color', '', 'important');
          stopBtn.style.setProperty('border-color', '', 'important');
          
          console.log("녹음 정지 - 버튼 스타일 초기화됨");
        }
      };

      // 이벤트 리스너 등록
      recordBtn.onclick = handleRecordClick;
      stopBtn.onclick = handleStopClick;

      mediaRecorder.ondataavailable = (e) => {
        chunksRef.current.push(e.data);
      };

      mediaRecorder.onstop = () => {
        console.log("MediaRecorder onstop 이벤트 발생");
        while (soundClips.firstChild) {
          soundClips.removeChild(soundClips.firstChild);
        }

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
        a.download = `동화연극_${bookTitle}_${speechId + 1}.mp3`;
        clipContainer.appendChild(a);

        soundClips.appendChild(clipContainer);
        a.click();

        // 🔹 녹음 후 즉시 다음 지문으로 자동 이동 (딜레이 제거)
        if (speechId + 1 < speech.length) {
          console.log(`다음 지문으로 이동: ${speechId + 1} -> ${speechId + 2}`);
          navigate(`/book/training/course/play/start?speechId=${speechId + 1}`);
        } else {
          // 마지막 지문 완료 시
          alert("동화연극이 완료되었습니다!");
          
          // 녹음 버튼 상태 초기화
          if (recordBtnRef.current) {
            recordBtnRef.current.style.setProperty('background', '', 'important');
            recordBtnRef.current.style.setProperty('color', '', 'important');
            recordBtnRef.current.style.setProperty('border-color', '', 'important');
          }
          if (stopBtnRef.current) {
            stopBtnRef.current.style.setProperty('background', '', 'important');
            stopBtnRef.current.style.setProperty('color', '', 'important');
            stopBtnRef.current.style.setProperty('border-color', '', 'important');
          }
          
          console.log("동화연극 완료 - 목록으로 이동");
          
          // 목록 페이지로 이동
          navigate("/book/training/course/play");
        }
      };

      // 컴포넌트 언마운트 시 이벤트 리스너 정리
      return cleanup;
    }
  }, [speechId, speech, navigate, isMicrophoneActive, hasPermission, bookTitle]);

  // 6) 페이지 로드 시 버튼 스타일 초기화
  useEffect(() => {
    const recordBtn = recordBtnRef.current;
    const stopBtn = stopBtnRef.current;
    
    if (recordBtn && stopBtn) {
      // 페이지 로드 시 버튼 스타일 초기화 - !important 사용
      recordBtn.style.setProperty('background', '', 'important');
      recordBtn.style.setProperty('color', '', 'important');
      recordBtn.style.setProperty('border-color', '', 'important');
      stopBtn.style.setProperty('background', '', 'important');
      stopBtn.style.setProperty('color', '', 'important');
      stopBtn.style.setProperty('border-color', '', 'important');
      console.log("페이지 로드 - 버튼 스타일 초기화됨");
    }
  }, [speechId]); // speechId가 변경될 때마다 버튼 스타일 초기화

  const item = Array.isArray(speech) ? speech[speechId] : null;

  return (
    <div className="content">
      <Background />
      <div className="wrap">
        <Header title={bookTitle} />
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
        <ProgressBar current={speechId + 1} total={speech?.length || 0} />
      </div>
    </div>
  );
}
