// src/pages/Interview/InterviewStart.jsx
import React, { useEffect, useRef, useState } from "react";
import useQuery from "../../hooks/useQuery.js";
import Header from "../../components/Header.jsx";
import AOS from "aos";
import API, { ensureUserKey } from "../../lib/api";
import "aos/dist/aos.css";
import ProgressBar from "./ProgressBar.jsx";
import Background from "../Background/Background";
import { useNavigate } from "react-router-dom";
import { useMicrophone } from "../../MicrophoneContext.jsx";
import { blobToWav } from "../../lib/BlobToWav.js";

// ===== 설정 =====
const IR_TITLE_BASE = "인지 능력 검사";
const GW_BASE = import.meta.env.VITE_GW_BASE || "/gw"; // 게이트웨이 베이스 주소
const RESULT_MAX_WAIT_MS = 60_000; // 결과 대기 최대 1분
const AUTO_GO_NEXT_ON_STOP = false; // 녹음 끝나면 자동 다음 문항으로
const TEST_QUESTIONS_COUNT = 5;     // 테스트 모드 문항 수

function gwURL(path) {
  const baseRaw = (import.meta.env.VITE_GW_BASE || "/gw").trim();
  const baseAbs = baseRaw.startsWith("http")
    ? baseRaw
    : `${window.location.origin}${baseRaw.startsWith("/") ? "" : "/"}${baseRaw}`;
  const baseDir = baseAbs.endsWith("/") ? baseAbs : baseAbs + "/";
  const rel = path.startsWith("/") ? path.slice(1) : path;
  return new URL(rel, baseDir).toString();
}

// ===== 간단 업로드 큐 =====
const makeQueue = () => {
  const q = [];
  let running = false;

  const run = async (uploadFn) => {
    if (running) return;
    running = true;
    while (q.length) {
      const job = q.shift();
      try {
        await uploadFn(job);
      } catch (e) {
        console.error("[upload] fail:", e);
      }
    }
    running = false;
  };

  return {
    push(job, uploadFn) { q.push(job); run(uploadFn); },
    get length() { return q.length; },
  };
};

function InterviewStart() {
  const query = useQuery();
  const navigate = useNavigate();
  const {
    isMicrophoneActive,
    hasPermission,
    ensureMicrophoneActive,
    streamRef: globalStreamRef,
  } = useMicrophone();

  const initialQuestionId = Number(query.get("questionId") ?? "0");
  const isTestMode = query.get("test") === "true";
  const irTitle = IR_TITLE_BASE;

  const [bookTitle] = useState(isTestMode ? "회상훈련 (테스트)" : "회상훈련");
  const [questions, setQuestions] = useState([]);
  const [questionId, setQuestionId] = useState(initialQuestionId);
  const [recordingCompleted, setRecordingCompleted] = useState(false);
  const [localRecordingError, setLocalRecordingError] = useState(null);
  const [isRecording, setIsRecording] = useState(false);
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  const [isFinalizing, setIsFinalizing] = useState(false);

  // MediaRecorder 관련
  const mediaRecorderRef = useRef(null);
  const chunksRef = useRef([]);
  const lastStartTsRef = useRef(0);

  // 업로드 큐
  const uploadQueueRef = useRef(makeQueue());

  // 호환 가능한 MediaRecorder 생성
  const createMediaRecorder = (stream) => {
    const candidates = [
      { mimeType: "audio/webm;codecs=opus" },
      { mimeType: "audio/webm" },
      { mimeType: "audio/ogg;codecs=opus" },
      {}, // 브라우저 기본값
    ];
    for (const opt of candidates) {
      try {
        if (opt.mimeType && !MediaRecorder.isTypeSupported(opt.mimeType)) continue;
        const mr = new MediaRecorder(stream, opt);
        return mr;
      } catch (e) {
        console.warn("MediaRecorder 생성 실패, 다음 옵션 시도:", opt.mimeType, e);
      }
    }
    throw new Error("이 브라우저에서 지원하는 오디오 코덱을 찾을 수 없습니다.");
  };

  useEffect(() => {
    AOS.init();
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  // 1건 업로드(백그라운드)
  const uploadOne = async (job) => {
    const { blob, idx1, totalLines, questionText } = job;

    // webm/ogg/mp4 → wav (실패 시 원본 전송)
    let wavBlob = null;
    try {
      wavBlob = await blobToWav(blob);
    } catch (e) {
      console.warn("[upload] blobToWav 실패, 원본 전송 시도", e);
      wavBlob = blob;
    }

    const formData = new FormData();
    formData.append("audio", wavBlob, `interview_q${idx1}.wav`);
    formData.append("prompt", questionText);
    formData.append("interviewTitle", irTitle); // ✅ 테스트/일반 구분하여 저장

    const url = new URL(gwURL("ir/analyze"));
    url.searchParams.set("lineNumber", String(idx1));
    url.searchParams.set("totalLines", String(totalLines));
    url.searchParams.set("questionId", String(idx1));

    const userKey = await ensureUserKey({ retries: 2, delayMs: 150 }).catch(() => null);
    const headers = userKey ? { "x-user-key": userKey } : undefined;
    const res = await fetch(url.toString(), { method: "POST", body: formData, headers });

    if (!res.ok) {
      const txt = await res.text().catch(() => "");
      throw new Error(`analyze HTTP ${res.status} ${txt}`);
    }
  };

  // MediaRecorder 설정
  const setupMediaRecorder = (mediaRecorder) => {
    mediaRecorder.ondataavailable = (e) => {
      if (e.data && e.data.size) {
        chunksRef.current.push(e.data);
      }
    };

    mediaRecorder.onstop = () => {
      // 업로드용 Blob
      const blob = new Blob(chunksRef.current, {
        type: mediaRecorderRef.current?.mimeType || "audio/webm;codecs=opus",
      });
      const localChunks = [...chunksRef.current];
      chunksRef.current = [];

      // 문항 메타
      const currentQuestion = Array.isArray(questions) ? questions[questionId] : null;
      const questionText = currentQuestion?.speechText ?? "";
      const idx1 = Math.max(1, (questionId || 0) + 1);
      const totalLines = Array.isArray(questions) ? questions.length : 25; // ✅ 테스트면 5

      // 백그라운드 업로드 큐에 등록
      uploadQueueRef.current.push({ blob, idx1, totalLines, questionText }, uploadOne);

      // UI 상태 업데이트 + 자동 다음
      setRecordingCompleted(true);
      setIsRecording(false);
      setLocalRecordingError(null);

      // if (AUTO_GO_NEXT_ON_STOP) {
      //   if (idx1 < totalLines) {
      //     setTimeout(() => setQuestionId((prev) => prev + 1), 0);
      //   } else {
      //     setTimeout(() => handleNextClick(), 0);
      //   }
      // }

      void localChunks;
    };

    mediaRecorder.onerror = (event) => {
      console.error("MediaRecorder 오류:", event.error);
      setLocalRecordingError("녹음 중 오류가 발생했습니다.");
      setIsRecording(false);
    };
  };

  // 인터뷰 질문 JSON 로드
  useEffect(() => {
    fetch("/autobiography/interview.json")
      .then((r) => {
        if (!r.ok) throw new Error("인터뷰 JSON 로드 실패");
        return r.json();
      })
      .then((json) => {
        // ✅ 테스트 모드면 상위 5문항만
        setQuestions(isTestMode ? json.slice(0, TEST_QUESTIONS_COUNT) : json);
      })
      .catch((e) => {
        console.error(e);
        alert("인터뷰 질문을 불러오지 못했습니다.");
      });
  }, [isTestMode]);

  // 질문 변경 시 상태 초기화
  useEffect(() => {
    setRecordingCompleted(false);
    setLocalRecordingError(null);
    setIsRecording(false);

    // 녹음 데이터 청소
    chunksRef.current = [];

    // MediaRecorder 강제 재생성을 위해 참조 초기화
    if (mediaRecorderRef.current) {
      if (mediaRecorderRef.current.state !== "inactive") {
        try { mediaRecorderRef.current.stop(); } catch { }
      }
      mediaRecorderRef.current = null;
    }
  }, [questionId]);

  // MediaRecorder 인스턴스 생성/초기화
  useEffect(() => {
    // 기존 정리
    if (mediaRecorderRef.current) {
      if (mediaRecorderRef.current.state !== "inactive") {
        try { mediaRecorderRef.current.stop(); } catch { }
      }
      mediaRecorderRef.current = null;
    }

    // 스트림이 있고 권한이 있을 때만 생성
    if (globalStreamRef.current && hasPermission) {
      try {
        const mediaRecorder = createMediaRecorder(globalStreamRef.current);
        mediaRecorderRef.current = mediaRecorder;
        setupMediaRecorder(mediaRecorder);
      } catch (error) {
        console.error("MediaRecorder 생성 실패:", error);
      }
    }
  }, [hasPermission, isMicrophoneActive, globalStreamRef, questionId]);

  // 페이지 이탈 경고
  useEffect(() => {
    const handleBeforeUnload = (e) => {
      if (isRecording) {
        e.preventDefault();
        e.returnValue = "녹음 중인 경우 데이터가 손실될 수 있습니다. 정말 나가시겠습니까?";
        return e.returnValue;
      }
    };
    window.addEventListener("beforeunload", handleBeforeUnload);
    return () => window.removeEventListener("beforeunload", handleBeforeUnload);
  }, [isRecording]);

  // 녹음 시작
  const handleRecordClick = async () => {
    if (isRecording || recordingCompleted) {
      if (recordingCompleted) alert("이미 녹음이 완료되었습니다. 재녹음은 불가능합니다.");
      return;
    }

    const ok = await ensureMicrophoneActive();
    if (!ok) {
      setLocalRecordingError("마이크 활성화에 실패했습니다.");
      return;
    }

    if (!mediaRecorderRef.current) {
      if (globalStreamRef.current) {
        try {
          const mediaRecorder = createMediaRecorder(globalStreamRef.current);
          mediaRecorderRef.current = mediaRecorder;
          setupMediaRecorder(mediaRecorder);
        } catch (error) {
          console.error("MediaRecorder 생성 실패:", error);
          setLocalRecordingError("녹음을 시작할 수 없습니다.");
          return;
        }
      } else {
        setLocalRecordingError("마이크 스트림을 가져올 수 없습니다.");
        return;
      }
    }

    const mediaRecorder = mediaRecorderRef.current;
    if (mediaRecorder.state === "inactive") {
      try {
        mediaRecorder.start();
        setIsRecording(true);
        lastStartTsRef.current = Date.now();
        setLocalRecordingError(null);
      } catch (error) {
        console.error("녹음 시작 실패:", error);
        setLocalRecordingError("녹음을 시작할 수 없습니다.");
        setIsRecording(false);
      }
    } else {
      // 안전 재시작
      try { mediaRecorder.stop(); } catch { }
      setTimeout(() => {
        try {
          const mr = createMediaRecorder(globalStreamRef.current);
          setupMediaRecorder(mr);
          mr.start();
          mediaRecorderRef.current = mr;
          setIsRecording(true);
          lastStartTsRef.current = Date.now();
          setLocalRecordingError(null);
        } catch (e) {
          console.error("안전 재시작 실패", e);
          setLocalRecordingError("녹음을 시작할 수 없습니다. 권한 또는 다른 앱의 마이크 점유를 확인해주세요.");
          setIsRecording(false);
        }
      }, 150);
    }
  };

  // 녹음 정지
  const handleStopClick = () => {
    if (!isRecording) return;
    if (!mediaRecorderRef.current) return;

    const mediaRecorder = mediaRecorderRef.current;
    if (mediaRecorder.state === "recording") {
      try {
        mediaRecorder.stop(); // onstop에서 업로드 큐 처리 & 자동 next
      } catch (error) {
        console.error("녹음 정지 실패:", error);
        setIsRecording(false);
      }
    }
  };

  // 서버 결과 대기 후 이동(미수신은 0점 패딩)
  const waitAndGoResult = async () => {
    setIsFinalizing(true);
    const userKey = await ensureUserKey({ retries: 2, delayMs: 150 }).catch(() => "guest");
    const title = irTitle; // ✅ 테스트/일반 구분
    const total = Array.isArray(questions) ? questions.length : 25;
    const deadline = Date.now() + RESULT_MAX_WAIT_MS;

    // 1) 진행도 수신 대기
    while (Date.now() < deadline) {
      try {
        const u = new URL(gwURL("ir/progress"));
        u.searchParams.set("userKey", userKey || "guest");
        u.searchParams.set("title", title);
        const r = await fetch(u.toString());
        const j = await r.json().catch(() => ({}));
        if ((j.received ?? 0) >= total) break;
      } catch { }
      await new Promise((r) => setTimeout(r, 400));
    }

    // 2) 최종 결과(force=1 → 미수신 0점 패딩)
    let jr;
    try {
      const u2 = new URL(gwURL("ir/result"));
      u2.searchParams.set("userKey", userKey || "guest");
      u2.searchParams.set("title", title);
      u2.searchParams.set("force", "1");
      const r2 = await fetch(u2.toString());
      jr = await r2.json();
    } catch (e) {
      console.error("[result] fetch failed", e);
      jr = null;
    }

    const score = Number(jr?.score ?? 0) || 0;
    const totalMax = Number(jr?.total ?? 40) || 40;

    // 서버에도 시도 저장(실패 무시)
    (async () => {
      try {
        const byCategory = jr?.byCategory || {};
        const riskBars = Object.fromEntries(
          Object.entries(byCategory).map(([k, v]) => {
            const c = Number(v?.correct ?? 0);
            const t = Math.max(1, Number(v?.total ?? 0));
            return [k, Math.max(0, Math.min(1, 1 - c / t))];
          })
        );
        const headers = userKey ? { "x-user-key": userKey } : undefined;
        await API.post(
          "/ir/attempt",
          {
            attemptTime: new Date().toISOString(),
            interviewTitle: title,
            score,
            total: totalMax,
            byCategory: byCategory,
            riskBars,
          },
          { headers }
        );
      } catch (e) {
        console.warn("[attempt] save failed:", e);
      }
    })();

    navigate("/interviewresult", {
      state: { score, total: totalMax, isTestMode: false, title: irTitle },
      replace: true,
    });
  };

  // 다음 질문으로 이동
  const handleNextClick = async () => {
    if (!recordingCompleted) {
      alert("먼저 녹음을 완료해주세요.");
      return;
    }

    if (questionId + 1 < (questions?.length ?? 0)) {
      setQuestionId((prev) => prev + 1);
    } else {
      await waitAndGoResult(); // 최대 1분 대기 후 강제 마감 포함
    }
  };

  const currentQuestion = Array.isArray(questions) ? questions[questionId] : null;

  return (
    <div className="content">
      {/* 공통 배경: 큰 화면에서만 */}
      {windowWidth > 1100 && <Background />}

      {/* 결과 대기 오버레이 */}
      {isFinalizing && (
        <div
          style={{
            position: "fixed",
            inset: 0,
            background: "rgba(255,255,255,0.75)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            zIndex: 9999,
            backdropFilter: "blur(2px)",
          }}
        >
          <div
            style={{
              padding: 20,
              borderRadius: 12,
              background: "#fff",
              boxShadow: "0 6px 20px rgba(0,0,0,0.12)",
              fontFamily: "GmarketSans",
              textAlign: "center",
              minWidth: 260,
            }}
          >
            <div className="spinner" style={{ marginBottom: 10 }}>
              <div
                style={{
                  width: 28,
                  height: 28,
                  borderRadius: "50%",
                  border: "4px solid #e5e7eb",
                  borderTopColor: "#3f51b5",
                  margin: "0 auto",
                  animation: "spin 0.9s linear infinite",
                }}
              />
            </div>
            <div style={{ fontWeight: 700, color: "#1f2937" }}>결과 집계 중입니다...</div>
            <div style={{ fontSize: 13, color: "#6b7280", marginTop: 6 }}>
              최대 1분까지 걸릴 수 있어요.
            </div>
          </div>
          <style>{`@keyframes spin{to{transform:rotate(360deg)}}`}</style>
        </div>
      )}

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
              <p
                style={{
                  backgroundColor: "#ffffff",
                  borderRadius: "10px",
                  border: "1px solid #e0e0e0",
                  padding: "20px",
                  margin: "0",
                  fontSize: "18px",
                  lineHeight: "1.6",
                  fontFamily: "GmarketSans",
                  fontWeight: "500",
                  textAlign: "left",
                  color: "#333",
                  boxShadow: "0 2px 8px rgba(0, 0, 0, 0.1)",
                }}
              >
                {currentQuestion?.speechText ?? "로딩 중..."}
              </p>

              {/* 질문에 음성이 있으면 자동 재생 */}
              {currentQuestion?.sound && (
                <audio src={currentQuestion.sound} autoPlay style={{ display: "none" }} />
              )}

              {/* 에러 메시지 */}
              {localRecordingError && (
                <div
                  style={{
                    color: "red",
                    fontSize: "14px",
                    marginBottom: "10px",
                    textAlign: "center",
                  }}
                >
                  {localRecordingError}
                </div>
              )}

              <div
                className="bt_flex"
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  gap: "10px",
                  marginTop: "30px",
                }}
              >
                <button
                  className="question_bt"
                  onClick={handleRecordClick}
                  disabled={isRecording || recordingCompleted}
                  style={{
                    flex: 1,
                    opacity: isRecording || recordingCompleted ? 0.6 : 1,
                    cursor: isRecording || recordingCompleted ? "not-allowed" : "pointer",
                    background: isRecording || recordingCompleted ? "#4a85d1" : "#3f51b5",
                    color: "white",
                    border: "none",
                    borderRadius: "5px",
                    padding: "12px",
                    fontSize: "1em",
                    fontWeight: "bold",
                    transition: "all 0.2s",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: "8px",
                  }}
                >
                  {isRecording && (
                    <div
                      style={{
                        width: "12px",
                        height: "12px",
                        borderRadius: "50%",
                        backgroundColor: "#ff0000",
                        animation: "pulse 1s ease-in-out infinite",
                      }}
                    />
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
                    cursor: !isRecording ? "not-allowed" : "pointer",
                    background: "red",
                    color: "white",
                    border: "none",
                    borderRadius: "5px",
                    padding: "12px",
                    fontSize: "1em",
                    fontWeight: "bold",
                    transition: "all 0.2s",
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
                    opacity: !recordingCompleted || isRecording ? 0.6 : 1,
                    cursor: !recordingCompleted || isRecording ? "not-allowed" : "pointer",
                    background: "#4CAF50",
                    color: "white",
                    border: "none",
                    borderRadius: "5px",
                    padding: "12px",
                    fontSize: "1em",
                    fontWeight: "bold",
                    transition: "all 0.2s",
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
}

export default InterviewStart;
