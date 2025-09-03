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
  const [questionStartTs, setQuestionStartTs] = useState(Date.now());
  const [recordStartTs, setRecordStartTs] = useState(null);
  const resultsRef = useRef([]); // 각 문항 분석 결과 누적

  // 브라우저 크기 상태
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);

  // 🎯 MediaRecorder 관련 refs
  const mediaRecorderRef = useRef(null);
  const chunksRef = useRef([]);
  const lastStartTsRef = useRef(0);

  // 호환 가능한 MediaRecorder 생성 유틸
  const createMediaRecorder = (stream) => {
    const candidates = [
      { mimeType: 'audio/webm;codecs=opus' },
      { mimeType: 'audio/webm' },
      { mimeType: 'audio/ogg;codecs=opus' },
      {} // 브라우저 기본값
    ];
    for (const opt of candidates) {
      try {
        if (opt.mimeType && !MediaRecorder.isTypeSupported(opt.mimeType)) continue;
        const mr = new MediaRecorder(stream, opt);
        return mr;
      } catch (e) {
        console.warn('MediaRecorder 생성 실패, 다음 옵션 시도:', opt.mimeType, e);
      }
    }
    throw new Error('이 브라우저에서 지원하는 오디오 코덱을 찾을 수 없습니다.');
  };

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
      console.log("녹음 완료, 파일 생성 및 분석 서버 전송 준비...");

      const blob = new Blob(chunksRef.current, { type: "audio/mp3 codecs=opus" });
      console.log("녹음 파일 크기:", blob.size, "bytes");
      const localChunks = [...chunksRef.current];
      chunksRef.current = [];

      // 메트릭 계산
      const stopTs = Date.now();
      const audioDuration = recordStartTs ? (stopTs - recordStartTs) / 1000 : 0;
      const responseTime = recordStartTs && questionStartTs ? (recordStartTs - questionStartTs) / 1000 : 0;

      // 백엔드 게이트웨이에 전송
      const currentQuestion = Array.isArray(questions) ? questions[questionId] : null;
      const questionText = currentQuestion?.speechText ?? "";

      const formData = new FormData();
      const fileName = `interview_q${questionId + 1}.webm`;
      formData.append("audio_file", blob, fileName);
      formData.append("question_text", questionText);
      formData.append("response_time", String(responseTime));
      formData.append("audio_duration", String(audioDuration));

      fetch("http://127.0.0.1:4000/process-audio", {
        method: "POST",
        body: formData,
      })
        .then(async (res) => {
          if (!res.ok) {
            const text = await res.text();
            throw new Error(text || "오디오 처리 실패");
          }
          return res.json();
        })
        .then((data) => {
          // 점수 객체 추출: 분석 서버({details, final_score})/게이트웨이({scores})/직접 점수({...}) 모두 지원
          const extracted = (data && typeof data === 'object') ? (data.details || data.scores || data) : {};
          const scoreKeys = ['response_time', 'repetition', 'avg_sentence_length', 'appropriateness', 'recall', 'grammar'];
          const scores = scoreKeys.reduce((acc, k) => {
            acc[k] = Number(extracted?.[k] || 0);
            return acc;
          }, {});
          resultsRef.current.push({
            question: questionText,
            scores: scores,
          });
          console.log("분석 결과 누적:", resultsRef.current);
          setRecordingCompleted(true);
          setIsRecording(false);
          setLocalRecordingError(null);
        })
        .catch((err) => {
          console.error("분석 서버 전송 중 오류:", err);
          // 실패 시에도 녹음 상태는 종료 처리
          setRecordingCompleted(true);
          setIsRecording(false);
          setLocalRecordingError("분석 서버 전송 중 오류가 발생했습니다.");
          // 전송 실패 시 복구를 위해 chunks를 되돌려둠
          chunksRef.current = localChunks;
        });
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
    setQuestionStartTs(Date.now());
    setRecordStartTs(null);

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
        const mediaRecorder = createMediaRecorder(globalStreamRef.current);
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
          const mediaRecorder = createMediaRecorder(globalStreamRef.current);
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
        setRecordStartTs(Date.now());
        lastStartTsRef.current = Date.now();
        setLocalRecordingError(null);
        console.log("녹음 시작 성공");
      } catch (error) {
        console.error("녹음 시작 실패:", error);
        setLocalRecordingError("녹음을 시작할 수 없습니다.");
        setIsRecording(false);
      }
    } else {
      // 안전 재시작: 녹음 중인데 시작 버튼을 또 눌렀을 때 복구 시도
      console.log("MediaRecorder가 이미 활성 상태입니다:", mediaRecorder.state);
      try {
        mediaRecorder.stop();
      } catch { }
      setTimeout(() => {
        try {
          const mr = createMediaRecorder(globalStreamRef.current);
          setupMediaRecorder(mr);
          mr.start();
          mediaRecorderRef.current = mr;
          setIsRecording(true);
          setRecordStartTs(Date.now());
          lastStartTsRef.current = Date.now();
          setLocalRecordingError(null);
          console.log('안전 재시작 성공');
        } catch (e) {
          console.error('안전 재시작 실패', e);
          setLocalRecordingError('녹음을 시작할 수 없습니다. 브라우저 권한 또는 다른 앱의 마이크 점유를 확인해주세요.');
          setIsRecording(false);
        }
      }, 150);
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
      // 모든 인터뷰 완료: 평균 점수 계산 후 결과 페이지로 이동 (로딩 → 결과)
      try {
        const totals = resultsRef.current.map((r) => {
          const s = r?.scores || {};
          const sum = Object.values(s).reduce((acc, v) => acc + (Number(v) || 0), 0);
          return sum;
        });
        const avg = totals.length > 0 ? Math.round(totals.reduce((a, b) => a + b, 0) / totals.length) : 0;

        // 카테고리별 평균 상세 계산 (InterviewHistory에서 사용)
        const categories = [
          { key: 'response_time', total: 4, label: '반응 시간' },
          { key: 'repetition', total: 4, label: '반복어 비율' },
          { key: 'avg_sentence_length', total: 4, label: '평균 문장 길이' },
          { key: 'appropriateness', total: 12, label: '화행 적절성' },
          { key: 'recall', total: 8, label: '회상어 점수' },
          { key: 'grammar', total: 8, label: '문법 완성도' },
        ];
        const averagedDetails = {};
        categories.forEach(({ key, total, label }) => {
          const vals = resultsRef.current.map((r) => Number(r?.scores?.[key] || 0));
          const mean = vals.length ? Math.round(vals.reduce((a, b) => a + b, 0) / vals.length) : 0;
          averagedDetails[label] = { score: mean, total };
        });

        // LocalStorage 저장: 전체 요약 + 문항별 세부 점수 포함
        const now = new Date();
        const newItem = {
          id: Date.now(),
          date: now.toISOString(),
          score: avg,
          total: 40,
          details: averagedDetails,
          perQuestions: resultsRef.current.map((r, idx) => ({
            index: idx + 1,
            question: r.question,
            scores: r.scores,
            total: Object.values(r.scores || {}).reduce((acc, v) => acc + (Number(v) || 0), 0),
          })),
        };
        const existing = JSON.parse(localStorage.getItem('interviewHistoryData') || '[]');
        localStorage.setItem('interviewHistoryData', JSON.stringify([newItem, ...existing]));

        // 결과 페이지로 이동하며 점수 전달
        navigate('/interviewresult', { state: { score: avg, total: 40 } });
      } catch (e) {
        console.error('최종 점수 계산 중 오류:', e);
        navigate('/interviewresult', { state: { score: 0, total: 40 } });
      }
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

              {/* 질문에 음성이 있으면 자동 재생 */}
              {currentQuestion?.sound && (
                <audio
                  src={currentQuestion.sound}
                  autoPlay
                  style={{ display: "none" }}
                />
              )}

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
                    background: 'red',
                    color: 'white',
                    border: 'none',
                    borderRadius: '5px',
                    padding: '12px',
                    fontSize: '1em',
                    fontWeight: 'bold',
                    transition: 'all 0.2s'
                  }}
                >
                  녹음 정지
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
