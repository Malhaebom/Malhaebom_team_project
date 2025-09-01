// src/pages/Book/Training/course/play/PlayStart.jsx
import React, { useEffect, useRef, useState, useMemo } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import Header from "../../../../components/Header.jsx";
import AOS from "aos";
import Background from "../../../Background/Background";
import { useMicrophone } from "../../../../MicrophoneContext.jsx";
import "./PlayStart.css";

// 🔹 useQuery 훅 포함
function useQuery() {
  const { search } = useLocation();
  return useMemo(() => new URLSearchParams(search), [search]);
}

// 진행률 표시 컴포넌트
function ProgressBar({ current, total }) {
  if (!total || total <= 0) return null;
  return (
    <div className="progress-container">
      <span className="progress-circle">
        {current}
      </span>
      <div className="progress-bar">
        <div
          className="progress-fill"
          style={{
            width: `${(current / total) * 100}%`
          }}
        />
      </div>
      <span className="progress-circle inactive">
        {total}
      </span>
    </div>
  );
}

export default function PlayStart() {
  const query = useQuery();
  const navigate = useNavigate();
  const speechId = Number(query.get("speechId") ?? "0");
  const { isMicrophoneActive, hasPermission, mediaRecorderRef: globalMediaRecorderRef, streamRef: globalStreamRef, ensureMicrophoneActive } = useMicrophone();

  const [bookTitle, setBookTitle] = useState("동화");
  const [speech, setSpeech] = useState(null);
  const [audioSrc, setAudioSrc] = useState("");
  const [windowWidth, setWindowWidth] = useState(window.innerWidth); // 브라우저 너비 상태
  const [isOriginalPlaying, setIsOriginalPlaying] = useState(false); // 원본 오디오 재생 상태
  const [isRecording, setIsRecording] = useState(false); // 녹음 상태
  const [recordingCompleted, setRecordingCompleted] = useState(false); // 녹음 완료 상태
  const [isMyRecordingPlaying, setIsMyRecordingPlaying] = useState(false); // 내 녹음 재생 상태

  // 버튼 활성화 상태 계산 함수들 (안정성 강화)
  const isRecordButtonEnabled = () => {
    // 녹음 중이 아니고, 마이크가 활성화되어 있을 때만 활성화
    return !isRecording && isMicrophoneActive && hasPermission;
  };

  const isStopButtonEnabled = () => {
    // 녹음 중이거나 녹음 완료 상태일 때 활성화
    return isRecording || recordingCompleted;
  };

  const isNextButtonEnabled = () => {
    // 녹음 완료 상태일 때만 활성화
    return recordingCompleted;
  };

  const isOriginalButtonEnabled = () => {
    // 녹음 중이 아닐 때만 활성화
    return !isRecording;
  };

  const audioRef = useRef(null);
  const recordBtnRef = useRef(null);
  const stopBtnRef = useRef(null);
  const chunksRef = useRef([]);
  const myRecordingAudioRef = useRef(null); // 내 녹음 재생용 오디오 참조

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

  // 🎯 MediaRecorder 설정 함수 - 중복 제거
  const setupMediaRecorder = (mediaRecorder) => {
    mediaRecorder.ondataavailable = (e) => {
      console.log("녹음 데이터 수신:", e.data.size, "bytes");
      chunksRef.current.push(e.data);
    };

    mediaRecorder.onstop = () => {
      console.log("녹음 완료, 파일 생성 중...");
      
      const blob = new Blob(chunksRef.current, { type: "audio/mp3 codecs=opus" });
      console.log("녹음 파일 크기:", blob.size, "bytes");
      chunksRef.current = [];
      
      // 내 녹음 재생용 오디오 요소에 설정
      if (myRecordingAudioRef.current) {
        myRecordingAudioRef.current.src = URL.createObjectURL(blob);
      }
      
      // 파일명 생성: 영문동화이름_동화연극하기n 형식
      const englishBookTitle = bookTitle.replace(/[^a-zA-Z0-9]/g, ''); // 영문/숫자만 추출
      const fileName = `${englishBookTitle}_동화연극하기${speechId + 1}.mp3`;
      
      // 로컬 스토리지에 녹음 데이터 저장 (선택사항)
      try {
        const recordingData = {
          fileName: fileName,
          timestamp: new Date().toISOString(),
          speechId: speechId,
          bookTitle: bookTitle
        };
        localStorage.setItem(`recording_${speechId}`, JSON.stringify(recordingData));
        console.log("녹음 정보가 로컬 스토리지에 저장되었습니다:", recordingData);
      } catch (error) {
        console.warn("로컬 스토리지 저장 실패:", error);
      }
      
      // 자동 다운로드 (숨겨진 링크로)
      const a = document.createElement("a");
      a.href = myRecordingAudioRef.current.src;
      a.download = fileName;
      a.style.display = "none";
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      console.log("녹음 파일 다운로드 완료");
    };

    mediaRecorder.onerror = (event) => {
      console.error("MediaRecorder 오류:", event.error);
    };

    mediaRecorder.onstart = () => {
      console.log("MediaRecorder 녹음 시작됨");
    };
  };

  // speech JSON 로드 및 녹음 상태 초기화
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
    
         // 새로운 지문으로 이동할 때 녹음 관련 상태 초기화
     console.log(`지문 ${speechId + 1}로 이동, 녹음 상태 초기화`);
     setIsRecording(false);
     setRecordingCompleted(false);
     setIsMyRecordingPlaying(false);
     
     // 이전 녹음 오디오 정지 및 초기화
     if (myRecordingAudioRef.current) {
       myRecordingAudioRef.current.pause();
       myRecordingAudioRef.current.currentTime = 0;
       myRecordingAudioRef.current.src = ""; // 이전 녹음 URL 제거
     }
     
     // 원본 오디오도 정지
     if (audioRef.current) {
       audioRef.current.pause();
       audioRef.current.currentTime = 0;
     }
     setIsOriginalPlaying(false);
     
     // 녹음 데이터 청소
     chunksRef.current = [];
     
     // MediaRecorder 강제 재생성을 위해 참조 초기화
     if (globalMediaRecorderRef.current) {
       console.log("지문 변경으로 인한 MediaRecorder 재생성");
       globalMediaRecorderRef.current = null;
     }
    
  }, [speechId, navigate]);

  // 자동 오디오 재생 제거 - 사용자가 직접 버튼을 클릭해야만 재생되도록 변경
  // useEffect(() => {
  //   if (!audioRef.current || !audioSrc) return;
  //   audioRef.current.load();
  //   audioRef.current.play().catch(() => {
  //     console.log("자동재생 차단됨: 사용자 클릭 후 재생됩니다.");
  //   });
  // }, [audioSrc]);

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

    // 🎯 MediaRecorder 인스턴스 생성 및 초기화 (한 번만!)
  useEffect(() => {
    console.log("MediaRecorder 초기화 시도:", {
      hasStream: !!globalStreamRef.current,
      isMicrophoneActive,
      hasPermission,
      speechId
    });

    // 기존 MediaRecorder가 있으면 정리
    if (globalMediaRecorderRef.current) {
      console.log("기존 MediaRecorder 정리");
      if (globalMediaRecorderRef.current.state !== "inactive") {
        globalMediaRecorderRef.current.stop();
      }
      globalMediaRecorderRef.current = null;
    }

    // 스트림이 있고 권한이 있을 때만 MediaRecorder 생성
    if (globalStreamRef.current && hasPermission) {
      try {
        const mediaRecorder = new MediaRecorder(globalStreamRef.current);
        globalMediaRecorderRef.current = mediaRecorder;
        console.log("MediaRecorder 새로 생성 완료, 상태:", mediaRecorder.state);

        // 🎯 이벤트 핸들러 한 번만 설정
        setupMediaRecorder(mediaRecorder);

      } catch (error) {
        console.error("MediaRecorder 생성 실패:", error);
      }
    } else {
      console.log("MediaRecorder 생성 조건 미충족 - 스트림 또는 권한 부족");
    }
  }, [hasPermission, isMicrophoneActive, bookTitle, speechId]); // isMicrophoneActive 의존성 추가

  // 버튼 이벤트 핸들러 설정
  useEffect(() => {
    const recordBtn = recordBtnRef.current;
    const stopBtn = stopBtnRef.current;
    
    if (!recordBtn || !stopBtn || !globalMediaRecorderRef.current) {
      return;
    }

    const mediaRecorder = globalMediaRecorderRef.current;

    // onClick 속성으로 이미 설정되어 있으므로 제거
    // recordBtn.onclick = handleRecordClick;
    // stopBtn.onclick = handleStopClick;

    // return () => {
    //   recordBtn.onclick = null;
    //   stopBtn.onclick = null;
    // };
  }, [recordingCompleted, isMyRecordingPlaying]);

  const item = Array.isArray(speech) ? speech[speechId] : null;

  // 🎯 녹음 시작/정지 핸들러 함수들 (중복 제거)
  const handleRecordClick = async () => {
    console.log("녹음 버튼 클릭됨, 현재 상태:", {
      hasMediaRecorder: !!globalMediaRecorderRef.current,
      mediaRecorderState: globalMediaRecorderRef.current?.state,
      isMicrophoneActive,
      hasPermission,
      hasStream: !!globalStreamRef.current
    });

    // 마이크 상태 보장
    const microphoneReady = await ensureMicrophoneActive();
    if (!microphoneReady) {
      console.log("마이크 활성화 실패");
      return;
    }

    // 🎯 MediaRecorder가 없으면 재생성 (한 번만!)
    if (!globalMediaRecorderRef.current) {
      console.log("MediaRecorder가 없어 새로 생성");
      
      if (globalStreamRef.current) {
        try {
          const mediaRecorder = new MediaRecorder(globalStreamRef.current);
          globalMediaRecorderRef.current = mediaRecorder;
          
          // 🎯 이벤트 핸들러 설정
          setupMediaRecorder(mediaRecorder);
          
          console.log("MediaRecorder 생성 완료");
        } catch (error) {
          console.error("MediaRecorder 생성 실패:", error);
          return;
        }
      } else {
        console.log("스트림이 없어 MediaRecorder를 생성할 수 없습니다.");
        return;
      }
    }

    const mediaRecorder = globalMediaRecorderRef.current;
    console.log("녹음 버튼 클릭됨, MediaRecorder 상태:", mediaRecorder.state);
    
    if (mediaRecorder.state === "inactive") {
      // 녹음 시작 전에 원본 오디오와 내 녹음 정지
      if (audioRef.current) {
        audioRef.current.pause();
        audioRef.current.currentTime = 0;
      }
      setIsOriginalPlaying(false);
      
      if (myRecordingAudioRef.current) {
        myRecordingAudioRef.current.pause();
        myRecordingAudioRef.current.currentTime = 0;
      }
      setIsMyRecordingPlaying(false);
      
      // 이전 녹음 완료 상태 초기화
      setRecordingCompleted(false);
      
      console.log("녹음 시작 시도...");
      try {
        mediaRecorder.start();
        setIsRecording(true);
        console.log("녹음 시작 성공, 상태 변경: isRecording = true, recordingCompleted = false");
      } catch (error) {
        console.error("녹음 시작 실패:", error);
        setIsRecording(false);
      }
    } else {
      console.log("MediaRecorder가 이미 활성 상태입니다:", mediaRecorder.state);
    }
  };

  const handleStopClick = () => {
    console.log("정지 버튼 클릭됨, 현재 상태:", {
      hasMediaRecorder: !!globalMediaRecorderRef.current,
      mediaRecorderState: globalMediaRecorderRef.current?.state,
      isRecording,
      recordingCompleted,
      isMyRecordingPlaying
    });

    if (!globalMediaRecorderRef.current) {
      console.log("MediaRecorder가 준비되지 않았습니다.");
      return;
    }

    const mediaRecorder = globalMediaRecorderRef.current;
    
    if (mediaRecorder.state === "recording") {
      // 녹음 중이면 녹음 정지
      console.log("녹음 정지...");
      try {
        mediaRecorder.stop();
        setIsRecording(false);
        setRecordingCompleted(true);
        console.log("녹음 상태 변경: isRecording = false, recordingCompleted = true");
      } catch (error) {
        console.error("녹음 정지 실패:", error);
        setIsRecording(false);
      }
    } else if (mediaRecorder.state === "inactive" && recordingCompleted) {
      // 녹음 완료 상태면 내 녹음 듣기/정지
      if (isMyRecordingPlaying) {
        // 내 녹음 재생 중이면 정지
        if (myRecordingAudioRef.current) {
          myRecordingAudioRef.current.pause();
          myRecordingAudioRef.current.currentTime = 0;
        }
        setIsMyRecordingPlaying(false);
        console.log("내 녹음 재생 정지");
      } else {
        // 내 녹음 재생 시작
        if (myRecordingAudioRef.current && myRecordingAudioRef.current.src) {
          myRecordingAudioRef.current.play().catch(error => {
            console.error("내 녹음 재생 실패:", error);
          });
          setIsMyRecordingPlaying(true);
          console.log("내 녹음 재생 시작");
        } else {
          console.log("내 녹음 파일이 없습니다.");
        }
      }
    } else {
      console.log("정지 버튼: 현재 상태에서는 동작하지 않음");
    }
  };

  // 원본 오디오 재생/정지 토글 함수
  const toggleOriginalAudio = () => {
    if (!item?.speechAudio) return;
    
    if (isOriginalPlaying) {
      // 재생 중이면 정지
      if (audioRef.current) {
        audioRef.current.pause();
        audioRef.current.currentTime = 0;
      }
      setIsOriginalPlaying(false);
    } else {
      // 정지 상태면 재생
      const audioSrc = `/autobiography/${item.speechAudio}`;
      if (audioRef.current) {
        audioRef.current.src = audioSrc;
        audioRef.current.play().catch(error => {
          console.error("원본 오디오 재생 실패:", error);
        });
      }
      setIsOriginalPlaying(true);
    }
  };

  // 녹음 시작 시 원본 오디오 정지 함수
  const stopOriginalAudio = () => {
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.currentTime = 0;
    }
    setIsOriginalPlaying(false);
  };

  // 내 녹음 재생/정지 토글 함수
  const toggleMyRecording = () => {
    if (!myRecordingAudioRef.current || !myRecordingAudioRef.current.src) return;
    
    if (isMyRecordingPlaying) {
      // 재생 중이면 정지
      if (myRecordingAudioRef.current) {
        myRecordingAudioRef.current.pause();
        myRecordingAudioRef.current.currentTime = 0;
      }
      setIsMyRecordingPlaying(false);
    } else {
      // 정지 상태면 재생
      if (myRecordingAudioRef.current && myRecordingAudioRef.current.src) {
        myRecordingAudioRef.current.play().catch(error => {
          console.error("내 녹음 재생 실패:", error);
        });
      }
      setIsMyRecordingPlaying(true);
    }
  };

  // 내 녹음 정지 함수
  const stopMyRecording = () => {
    if (myRecordingAudioRef.current) {
      myRecordingAudioRef.current.pause();
      myRecordingAudioRef.current.currentTime = 0;
    }
    setIsMyRecordingPlaying(false);
  };

  // 다음 지문으로 이동 함수
  const goToNextSpeech = () => {
    if (speechId + 1 < speech.length) {
      navigate(`/book/training/course/play/start?speechId=${speechId + 1}`);
    } else {
      alert(`${bookTitle} 동화 연극하기가 종료되었습니다. 다른 동화 연극도 해볼까요?`);
      navigate("/book/library");
    }
  };

  // 오디오 이벤트 리스너 추가
  useEffect(() => {
    if (!audioRef.current) return;

    const handleEnded = () => {
      setIsOriginalPlaying(false);
    };

    const handlePlay = () => {
      setIsOriginalPlaying(true);
    };

    const handlePause = () => {
      setIsOriginalPlaying(false);
    };

    audioRef.current.addEventListener('ended', handleEnded);
    audioRef.current.addEventListener('play', handlePlay);
    audioRef.current.addEventListener('pause', handlePause);

    return () => {
      if (audioRef.current) {
        audioRef.current.removeEventListener('ended', handleEnded);
        audioRef.current.removeEventListener('play', handlePlay);
        audioRef.current.removeEventListener('pause', handlePause);
      }
    };
  }, []);

  // 내 녹음 오디오 이벤트 리스너 추가
  useEffect(() => {
    if (!myRecordingAudioRef.current) return;

    const handleMyRecordingEnded = () => {
      setIsMyRecordingPlaying(false);
    };

    const handleMyRecordingPlay = () => {
      setIsMyRecordingPlaying(true);
    };

    const handleMyRecordingPause = () => {
      setIsMyRecordingPlaying(false);
    };

    myRecordingAudioRef.current.addEventListener('ended', handleMyRecordingEnded);
    myRecordingAudioRef.current.addEventListener('play', handleMyRecordingPlay);
    myRecordingAudioRef.current.addEventListener('pause', handleMyRecordingPause);

    return () => {
      if (myRecordingAudioRef.current) {
        myRecordingAudioRef.current.removeEventListener('ended', handleMyRecordingEnded);
        myRecordingAudioRef.current.removeEventListener('play', handleMyRecordingPlay);
        myRecordingAudioRef.current.removeEventListener('pause', handleMyRecordingPause);
      }
    };
  }, []);

  return (
    <div className="content">
      {/* 일정 너비 이하이면 Background 숨기기 */}
      {windowWidth > 1100 && <Background />}
      <div className="wrap" style={{ margin: "0 auto", maxWidth: 520 }}>
        <Header title={bookTitle} />
                 <audio className="speechAudio0" ref={audioRef}>
           {audioSrc && <source src={audioSrc} type="audio/mpeg" />}
         </audio>
         <audio ref={myRecordingAudioRef} style={{ display: 'none' }} />
        <div className="inner">
          <div className="ct_inner">
                         <div 
               id="recordBox" 
               className="playstart-container"
               data-aos="fade-up" 
               data-aos-duration="1000" 
               style={{
                 background: "#FFFFFF",
                 borderRadius: "12px",
                 padding: "20px",
                 marginBottom: "20px",
                 color: "#333",
                 boxShadow: "0 4px 12px rgba(0, 0, 0, 0.08)",
                 border: "1px solid rgba(232, 244, 253, 0.4)",
                 display: "flex",
                 flexDirection: "column",
                 justifyContent: "space-between",
                 minHeight: "140px",
                 transition: "all 0.3s ease"
               }}
             >
                                                           <div style={{ position: 'relative', flex: '1' }}>
                 <p className="playstart-text" style={{
                   fontSize: "18px",
                   lineHeight: "1.6",
                   margin: "0 0 15px 0",
                   fontFamily: "GmarketSans",
                   fontWeight: "500",
                   textAlign: "left",
                   flex: "1",
                   display: "flex",
                   alignItems: "center",
                   justifyContent: "flex-start",
                   opacity: 1, // 항상 보이도록 명시적 설정
                   visibility: "visible" // 항상 보이도록 명시적 설정
                 }}>
                   {item?.speechText ?? "로딩 중..."}
                 </p>
               </div>
              
              {/* 원본 듣기/정지 버튼 - 토글 기능 */}
              {item?.speechAudio && (
                <div style={{ 
                  textAlign: "center",
                  marginTop: "auto",
                  paddingTop: "15px",
                  opacity: 1, // 항상 보이도록 명시적 설정
                  visibility: "visible", // 항상 보이도록 명시적 설정
                  display: "block" // 항상 보이도록 명시적 설정
                }}>
                                     <button
                     onClick={toggleOriginalAudio}
                     disabled={!isOriginalButtonEnabled()}
                     style={{
                       background: "white",
                       border: "1px solid rgba(0, 0, 0, 0.1)",
                       borderRadius: "25px",
                       padding: "12px 24px",
                       color: "#000",
                       fontSize: "15px",
                       fontWeight: "600",
                       cursor: isOriginalButtonEnabled() ? "pointer" : "not-allowed",
                       display: "inline-flex",
                       alignItems: "center",
                       gap: "10px",
                       boxShadow: "0 2px 8px rgba(0, 0, 0, 0.08)",
                       position: "relative",
                       overflow: "hidden",
                       opacity: isOriginalButtonEnabled() ? 1 : 0.5
                     }}
                   >
                    <div style={{
                      width: "20px",
                      height: "20px",
                      background: "rgba(0, 0, 0, 0.1)",
                      borderRadius: "50%",
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      fontSize: "12px"
                    }}>
                      {isOriginalPlaying ? "⏹️" : "🔊"}
                    </div>
                    <span style={{
                      fontFamily: "GmarketSans",
                      letterSpacing: "0.5px"
                    }}>
                      {isOriginalPlaying ? "탭해서 원본 정지" : "탭해서 원본 듣기"}
                    </span>
                  </button>
                </div>
              )}
              
                             {/* 내 녹음 듣기/정지 버튼 - 항상 표시하되 초기에는 비활성화 */}
               <div style={{ 
                 textAlign: "center",
                 marginTop: "10px",
                 paddingTop: "10px",
                 opacity: 1,
                 visibility: "visible",
                 display: "block"
               }}>
                 <button
                   onClick={toggleMyRecording}
                   disabled={!recordingCompleted}
                   style={{
                     background: "white",
                     border: "1px solid rgba(0, 0, 0, 0.1)",
                     borderRadius: "25px",
                     padding: "12px 24px",
                     color: "#000",
                     fontSize: "15px",
                     fontWeight: "600",
                     cursor: recordingCompleted ? "pointer" : "not-allowed",
                     display: "inline-flex",
                     alignItems: "center",
                     gap: "10px",
                     boxShadow: "0 2px 8px rgba(0, 0, 0, 0.08)",
                     position: "relative",
                     overflow: "hidden",
                     opacity: recordingCompleted ? 1 : 0.5
                   }}
                 >
                   <div style={{
                     width: "20px",
                     height: "20px",
                     background: "rgba(0, 0, 0, 0.1)",
                     borderRadius: "50%",
                     display: "flex",
                     alignItems: "center",
                     justifyContent: "center",
                     fontSize: "12px"
                   }}>
                     {isMyRecordingPlaying ? "⏹️" : "🎤"}
                   </div>
                                       <span style={{
                      fontFamily: "GmarketSans",
                      letterSpacing: "0.5px"
                    }}>
                      {isMyRecordingPlaying ? "탭해서 녹음 듣기 정지" : "탭해서 녹음 듣기"}
                    </span>
                 </button>
               </div>
              
                             {/* sound-clips div 제거 - 기능 중복 방지 */}
            </div>
                                      <div className="playstart-controls" style={{
               display: 'flex',
               gap: '15px',
               justifyContent: 'center',
               alignItems: 'center'
             }}>
                                                               <button 
                   className="question_bt" 
                   id="record" 
                   type="button" 
                   ref={recordBtnRef}
                   onClick={handleRecordClick}
                   disabled={!isRecordButtonEnabled()}
                   style={{
                     opacity: !isRecordButtonEnabled() ? 0.5 : 1,
                     cursor: !isRecordButtonEnabled() ? 'not-allowed' : 'pointer',
                     display: 'flex',
                     alignItems: 'center',
                     justifyContent: 'center',
                     gap: '8px'
                   }}
                 >
                   {isRecording && (
                     <div style={{
                       width: '12px',
                       height: '12px',
                       borderRadius: '50%',
                       backgroundColor: '#ff0000',
                       animation: 'pulse 1s ease-in-out infinite'
                     }} />
                   )}
                   {isRecording ? "녹음 중" : "녹음"}
                 </button>
                                                               <button 
                   className="question_bt" 
                   id="stop" 
                   type="button" 
                   ref={stopBtnRef}
                   onClick={handleStopClick}
                   disabled={!isStopButtonEnabled()}
                   style={{
                     opacity: !isStopButtonEnabled() ? 0.5 : 1,
                     cursor: !isStopButtonEnabled() ? 'not-allowed' : 'pointer'
                   }}
                 >
                   녹음 정지
                 </button>
               <button 
                 className="question_bt" 
                 onClick={goToNextSpeech}
                 disabled={!recordingCompleted}
                 style={{
                   opacity: !recordingCompleted ? 0.5 : 1,
                   cursor: !recordingCompleted ? 'not-allowed' : 'pointer'
                 }}
               >
                 다음 지문으로
               </button>
             </div>
             
             {/* 프로그레스 바를 ct_inner 내부로 이동하여 다른 요소들과 같은 세로선상에 위치 */}
             <ProgressBar current={speechId + 1} total={speech?.length || 0} />
          </div>
        </div>
      </div>
    </div>
  );
}
