import React, { useEffect, useRef, useState } from "react";
import useQuery from "../../hooks/useQuery.js"; 
import Header from "../../components/Header.jsx";
import AOS from "aos";
import "aos/dist/aos.css";
import ProgressBar from "./ProgressBar.jsx";
import Background from "../Background/Background";
import { useNavigate } from "react-router-dom";
import { useMicrophone } from "../../MicrophoneContext.jsx";

function InterviewStart() {
  const query = useQuery();
  const navigate = useNavigate();
  const { 
    isMicrophoneActive, 
    hasPermission, 
    ensureMicrophoneActive,
    streamRef: globalStreamRef
  } = useMicrophone();
  
  const initialQuestionId = Number(query.get("questionId") ?? "0");

  const [bookTitle] = useState("회상훈련");
  const [questions, setQuestions] = useState([]);
  const [questionId, setQuestionId] = useState(initialQuestionId);
  const [recordingCompleted, setRecordingCompleted] = useState(false);
  const [localRecordingError, setLocalRecordingError] = useState(null);
  const [isRecording, setIsRecording] = useState(false); // 로컬 녹음 상태

  // 브라우저 크기 상태
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);

  // 🎯 MediaRecorder 관련 refs
  const mediaRecorderRef = useRef(null);
  const chunksRef = useRef([]);

  useEffect(() => {
    AOS.init();

    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    
    return () => window.removeEventListener("resize", handleResize);
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
      
      // 파일명 생성: 인터뷰_질문n 형식
      const fileName = `인터뷰_질문${questionId + 1}.mp3`;
      
      // 자동 다운로드
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = fileName;
      a.style.display = "none";
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      console.log("인터뷰 녹음 파일 다운로드 완료:", fileName);
      
      // 상태 업데이트
      setRecordingCompleted(true);
      setIsRecording(false);
      setLocalRecordingError(null);
    };

    mediaRecorder.onerror = (event) => {
      console.error("MediaRecorder 오류:", event.error);
      setLocalRecordingError("녹음 중 오류가 발생했습니다.");
      setIsRecording(false);
    };

    mediaRecorder.onstart = () => {
      console.log("MediaRecorder 녹음 시작됨");
    };
  };

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

  // 질문 변경 시 상태 초기화
  useEffect(() => {
    console.log(`질문 ${questionId + 1}로 이동, 녹음 상태 초기화`);
    setRecordingCompleted(false);
    setLocalRecordingError(null);
    setIsRecording(false);
    
    // 녹음 데이터 청소
    chunksRef.current = [];
    
    // MediaRecorder 강제 재생성을 위해 참조 초기화
    if (mediaRecorderRef.current) {
      console.log("질문 변경으로 인한 MediaRecorder 재생성");
      mediaRecorderRef.current = null;
    }
  }, [questionId]);

  // 🎯 MediaRecorder 인스턴스 생성 및 초기화 (한 번만!)
  useEffect(() => {
    console.log("MediaRecorder 초기화 시도:", {
      hasStream: !!globalStreamRef.current,
      isMicrophoneActive,
      hasPermission,
      questionId
    });

    // 기존 MediaRecorder가 있으면 정리
    if (mediaRecorderRef.current) {
      console.log("기존 MediaRecorder 정리");
      if (mediaRecorderRef.current.state !== "inactive") {
        mediaRecorderRef.current.stop();
      }
      mediaRecorderRef.current = null;
    }

    // 스트림이 있고 권한이 있을 때만 MediaRecorder 생성
    if (globalStreamRef.current && hasPermission) {
      try {
        const mediaRecorder = new MediaRecorder(globalStreamRef.current);
        mediaRecorderRef.current = mediaRecorder;
        console.log("MediaRecorder 새로 생성 완료, 상태:", mediaRecorder.state);

        // 🎯 이벤트 핸들러 한 번만 설정
        setupMediaRecorder(mediaRecorder);

      } catch (error) {
        console.error("MediaRecorder 생성 실패:", error);
      }
    } else {
      console.log("MediaRecorder 생성 조건 미충족 - 스트림 또는 권한 부족");
    }
  }, [hasPermission, isMicrophoneActive, questionId]);

  // 뒤로가기 및 페이지 이탈 처리
  useEffect(() => {
    const handleBeforeUnload = (e) => {
      if (isRecording) {
        e.preventDefault();
        e.returnValue = "녹음 중인 경우 데이터가 손실될 수 있습니다. 정말 나가시겠습니까?";
        return e.returnValue;
      }
    };

    window.addEventListener('beforeunload', handleBeforeUnload);

    return () => {
      window.removeEventListener('beforeunload', handleBeforeUnload);
    };
  }, [isRecording]);

  // 🎯 녹음 시작 핸들러 (중복 제거)
  const handleRecordClick = async () => {
    console.log("녹음 버튼 클릭됨");
    
    // 이미 녹음 중이거나 완료된 경우 처리하지 않음
    if (isRecording || recordingCompleted) {
      if (recordingCompleted) {
        alert("이미 녹음이 완료되었습니다. 재녹음은 불가능합니다.");
      }
      return;
    }

    // 마이크 상태 보장
    const microphoneReady = await ensureMicrophoneActive();
    if (!microphoneReady) {
      setLocalRecordingError("마이크 활성화에 실패했습니다.");
      return;
    }

    // 🎯 MediaRecorder가 없으면 재생성 (한 번만!)
    if (!mediaRecorderRef.current) {
      console.log("MediaRecorder가 없어 새로 생성");
      
      if (globalStreamRef.current) {
        try {
          const mediaRecorder = new MediaRecorder(globalStreamRef.current);
          mediaRecorderRef.current = mediaRecorder;
          
          // 🎯 이벤트 핸들러 설정
          setupMediaRecorder(mediaRecorder);
          
          console.log("MediaRecorder 생성 완료");
        } catch (error) {
          console.error("MediaRecorder 생성 실패:", error);
          setLocalRecordingError("녹음을 시작할 수 없습니다.");
          return;
        }
      } else {
        console.log("스트림이 없어 MediaRecorder를 생성할 수 없습니다.");
        setLocalRecordingError("마이크 스트림을 가져올 수 없습니다.");
        return;
      }
    }

    const mediaRecorder = mediaRecorderRef.current;
    console.log("녹음 버튼 클릭됨, MediaRecorder 상태:", mediaRecorder.state);
    
    if (mediaRecorder.state === "inactive") {
      console.log("녹음 시작 시도...");
      try {
        mediaRecorder.start();
        setIsRecording(true);
        setLocalRecordingError(null);
        console.log("녹음 시작 성공");
      } catch (error) {
        console.error("녹음 시작 실패:", error);
        setLocalRecordingError("녹음을 시작할 수 없습니다.");
        setIsRecording(false);
      }
    } else {
      console.log("MediaRecorder가 이미 활성 상태입니다:", mediaRecorder.state);
    }
  };

  // 🎯 녹음 정지 핸들러 (중복 제거)
  const handleStopClick = () => {
    console.log("녹음 정지 버튼 클릭됨");
    
    // 녹음 중이 아닌 경우 처리하지 않음
    if (!isRecording) {
      console.log("녹음 중이 아닙니다.");
      return;
    }
    
    if (!mediaRecorderRef.current) {
      console.log("MediaRecorder가 준비되지 않았습니다.");
      return;
    }

    const mediaRecorder = mediaRecorderRef.current;
    
    if (mediaRecorder.state === "recording") {
      console.log("녹음 정지...");
      try {
        mediaRecorder.stop(); // 이때 onstop 이벤트 자동 발생!
        console.log("녹음 정지 요청 완료 - onstop 이벤트 대기 중");
      } catch (error) {
        console.error("녹음 정지 실패:", error);
        setIsRecording(false);
      }
    } else {
      console.log("MediaRecorder가 녹음 중이 아닙니다. 현재 상태:", mediaRecorder.state);
    }
  };

  // 다음 질문으로 이동 핸들러
  const handleNextClick = () => {
    if (!recordingCompleted) {
      alert("먼저 녹음을 완료해주세요.");
      return;
    }

    if (questionId + 1 < questions.length) {
      setQuestionId((prev) => prev + 1);
    } else {
      alert("모든 인터뷰가 완료되었습니다!");
      navigate("/InterviewHistory");
    }
  };

  const currentQuestion = Array.isArray(questions) ? questions[questionId] : null;

  return (
    <div className="content">
      {/* 공통 배경 추가 - 화면이 클 때만 표시 */}
      {windowWidth > 1100 && <Background />}
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
              <p style={{
                backgroundColor: '#ffffff',
                borderRadius: '10px',
                border: '1px solid #e0e0e0',
                padding: '20px',
                margin: '0',
                fontSize: "18px",
                lineHeight: "1.6",
                fontFamily: "GmarketSans",
                fontWeight: "500",
                textAlign: "left",
                color: "#333",
                boxShadow: '0 2px 8px rgba(0, 0, 0, 0.1)'
              }}>
                {currentQuestion?.speechText ?? "로딩 중..."}
              </p>
              
              {/* 에러 메시지 표시 */}
              {localRecordingError && (
                <div style={{
                  color: "red",
                  fontSize: "14px",
                  marginBottom: "10px",
                  textAlign: "center"
                }}>
                  {localRecordingError}
                </div>
              )}
              
              <div className="bt_flex" style={{
                display: 'flex',
                justifyContent: 'space-between',
                gap: '10px',
                marginTop: '30px'
              }}>
                <button 
                  className="question_bt"
                  onClick={handleRecordClick}
                  disabled={isRecording || recordingCompleted}
                  style={{
                    flex: 1,
                    opacity: (isRecording || recordingCompleted) ? 0.6 : 1,
                    cursor: (isRecording || recordingCompleted) ? 'not-allowed' : 'pointer',
                    background: (isRecording || recordingCompleted) ? '#4a85d1' : '#3f51b5',
                    color: 'white',
                    border: 'none',
                    borderRadius: '5px',
                    padding: '12px',
                    fontSize: '1em',
                    fontWeight: 'bold',
                    transition: 'all 0.2s',
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
                  {isRecording ? "녹음 중" : "녹음 시작"}
                </button>
                <button 
                  className="question_bt" 
                  onClick={handleStopClick}
                  disabled={!isRecording}
                  style={{
                    flex: 1,
                    opacity: !isRecording ? 0.6 : 1,
                    cursor: !isRecording ? 'not-allowed' : 'pointer',
                    background: '#4a85d1',
                    color: 'white',
                    border: 'none',
                    borderRadius: '5px',
                    padding: '12px',
                    fontSize: '1em',
                    fontWeight: 'bold',
                    transition: 'all 0.2s'
                  }}
                >
                  녹음 끝내기
                </button>
                <button 
                  className="question_bt" 
                  onClick={handleNextClick}
                  disabled={!recordingCompleted || isRecording}
                  style={{
                    flex: 1,
                    opacity: (!recordingCompleted || isRecording) ? 0.6 : 1,
                    cursor: (!recordingCompleted || isRecording) ? 'not-allowed' : 'pointer',
                    background: '#4CAF50',
                    color: 'white',
                    border: 'none',
                    borderRadius: '5px',
                    padding: '12px',
                    fontSize: '1em',
                    fontWeight: 'bold',
                    transition: 'all 0.2s'
                  }}
                >
                  다음
                </button>
              </div>
            </div>
          </div>
        </div>
        <ProgressBar current={questionId + 1} total={questions?.length || 0} />
      </div>
    </div>
  );
};

export default InterviewStart;
