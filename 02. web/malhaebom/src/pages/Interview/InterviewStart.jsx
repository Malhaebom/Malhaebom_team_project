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
    startRecording,
    stopRecording,
    getRecordingData,
    clearRecordingData,
    ensureMicrophoneActive,
    isRecording: globalIsRecording,
    recordingError: globalRecordingError
  } = useMicrophone();
  
  const initialQuestionId = Number(query.get("questionId") ?? "0");

  const [bookTitle] = useState("회상훈련");
  const [questions, setQuestions] = useState([]);
  const [questionId, setQuestionId] = useState(initialQuestionId);
  const [recordingCompleted, setRecordingCompleted] = useState(false);
  const [localRecordingError, setLocalRecordingError] = useState(null);
  const [hasStartedRecording, setHasStartedRecording] = useState(false); // 녹음 시작 여부 추적

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

    // 질문 변경 시 상태 초기화
  useEffect(() => {
    console.log(`질문 ${questionId + 1}로 이동, 녹음 상태 초기화`);
    setRecordingCompleted(false);
    setLocalRecordingError(null);
    setHasStartedRecording(false); // 녹음 시작 여부도 초기화
    clearRecordingData();
  }, [questionId, clearRecordingData]);

  // 뒤로가기 및 페이지 이탈 처리
  useEffect(() => {
    const handleBeforeUnload = (e) => {
      if (globalIsRecording) {
        e.preventDefault();
        e.returnValue = "녹음 중인 경우 데이터가 손실될 수 있습니다. 정말 나가시겠습니까?";
        return e.returnValue;
      }
    };

    window.addEventListener('beforeunload', handleBeforeUnload);

    return () => {
      window.removeEventListener('beforeunload', handleBeforeUnload);
    };
  }, [globalIsRecording]);

    // 녹음 시작 핸들러
  const handleRecordClick = async () => {
    console.log("녹음 버튼 클릭됨");
    
    // 이미 녹음 중이거나 완료된 경우 처리하지 않음
    if (globalIsRecording || recordingCompleted) {
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

    // 녹음 시작
    const success = await startRecording();
    if (success) {
      setLocalRecordingError(null);
      setHasStartedRecording(true); // 녹음이 실제로 시작되었음을 표시
    } else {
      setLocalRecordingError("녹음을 시작할 수 없습니다.");
    }
  };

    // 녹음 정지 핸들러
  const handleStopClick = () => {
    console.log("녹음 정지 버튼 클릭됨");
    
    // 녹음 중이 아닌 경우 처리하지 않음
    if (!globalIsRecording) {
      console.log("녹음 중이 아닙니다.");
      return;
    }
    
    console.log("녹음 정지 실행");
    stopRecording();
    
    // 녹음 완료 상태는 전역 녹음 상태 변경 감지 useEffect에서 처리
    console.log("녹음 정지 요청 완료 - onstop 이벤트 대기 중");
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

  // 전역 녹음 상태 변경 감지 - 녹음 완료 후 파일 다운로드
  useEffect(() => {
    console.log("녹음 상태 변경 감지:", { globalIsRecording, recordingCompleted, hasStartedRecording });
    
    // 녹음이 시작되었다가 정지된 경우 (녹음 완료) - 실제 녹음이 시작된 경우에만
    if (!globalIsRecording && hasStartedRecording && !recordingCompleted) {
      console.log("녹음 완료 감지 - 완료 상태 설정 및 파일 다운로드 시작");
      
      // 녹음 완료 상태 설정
      setRecordingCompleted(true);
      setLocalRecordingError(null);
      
      // 약간의 지연을 두어 onstop 이벤트가 완전히 처리되도록 함
      setTimeout(() => {
        const recordingData = getRecordingData();
        if (recordingData) {
          const fileName = `인터뷰_질문${questionId + 1}.mp3`;
          const a = document.createElement("a");
          a.href = URL.createObjectURL(recordingData);
          a.download = fileName;
          a.style.display = "none";
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          console.log("인터뷰 녹음 파일 다운로드 완료:", fileName);
        } else {
          console.warn("녹음 데이터를 가져올 수 없습니다.");
        }
      }, 200); // 200ms 지연으로 증가
    }
  }, [globalIsRecording, recordingCompleted, hasStartedRecording, questionId, getRecordingData]);

  // 녹음 상태 변경 디버깅용 useEffect
  useEffect(() => {
    console.log("녹음 상태 변경:", { 
      globalIsRecording, 
      recordingCompleted, 
      hasStartedRecording,
      questionId,
      hasRecordingData: !!getRecordingData()
    });
  }, [globalIsRecording, recordingCompleted, hasStartedRecording, questionId, getRecordingData]);

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
                             <p style={{
                 background: 'linear-gradient(to bottom, #d7effc, #ffffff)',
                 borderRadius: '10px',
                 border: '1px solid #e1e1e1',
                 padding: '20px',
                 margin: '0',
                 fontSize: "18px",
                 lineHeight: "1.6",
                 fontFamily: "GmarketSans",
                 fontWeight: "500",
                 textAlign: "left",
                 color: "#333"
               }}>
                 {currentQuestion?.speechText ?? "로딩 중..."}
               </p>
              
              {/* 에러 메시지 표시 */}
              {(localRecordingError || globalRecordingError) && (
                <div style={{
                  color: "red",
                  fontSize: "14px",
                  marginBottom: "10px",
                  textAlign: "center"
                }}>
                  {localRecordingError || globalRecordingError}
                </div>
              )}
              
              {/* 녹음 완료 상태 표시 - 제거됨 */}
              {/* 녹음 완료 메시지를 제거하여 버튼 위치 고정 */}
              
              <div className="bt_flex" style={{
                display: 'flex',
                justifyContent: 'space-between',
                gap: '10px',
                marginTop: '30px'
              }}>
                                                                   <button 
                   className="question_bt"
                   onClick={handleRecordClick}
                   disabled={globalIsRecording || recordingCompleted}
                   style={{
                     flex: 1,
                     opacity: (globalIsRecording || recordingCompleted) ? 0.6 : 1,
                     cursor: (globalIsRecording || recordingCompleted) ? 'not-allowed' : 'pointer',
                     background: (globalIsRecording || recordingCompleted) ? '#4a85d1' : '#3f51b5',
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
                   {globalIsRecording && (
                     <div style={{
                       width: '12px',
                       height: '12px',
                       borderRadius: '50%',
                       backgroundColor: '#ff0000',
                       animation: 'pulse 1s ease-in-out infinite'
                     }} />
                   )}
                   {globalIsRecording ? "녹음 중" : "녹음 시작"}
                 </button>
                <button 
                  className="question_bt" 
                  onClick={handleStopClick}
                  disabled={!globalIsRecording}
                  style={{
                    flex: 1,
                    opacity: !globalIsRecording ? 0.6 : 1,
                    cursor: !globalIsRecording ? 'not-allowed' : 'pointer',
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
                  disabled={!recordingCompleted || globalIsRecording}
                  style={{
                    flex: 1,
                    opacity: (!recordingCompleted || globalIsRecording) ? 0.6 : 1,
                    cursor: (!recordingCompleted || globalIsRecording) ? 'not-allowed' : 'pointer',
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
