import React, { createContext, useContext, useRef, useState, useEffect } from 'react';
import { useLocation } from 'react-router-dom';

const MicrophoneContext = createContext();

export const useMicrophone = () => {
  const context = useContext(MicrophoneContext);
  if (!context) {
    throw new Error('useMicrophone must be used within a MicrophoneProvider');
  }
  return context;
};

export const MicrophoneProvider = ({ children }) => {
  const location = useLocation();
  const [isMicrophoneActive, setIsMicrophoneActive] = useState(false);
  const [hasPermission, setHasPermission] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [recordingError, setRecordingError] = useState(null);
  const mediaRecorderRef = useRef(null);
  const streamRef = useRef(null);
  const chunksRef = useRef([]);

  // 마이크 시작 함수
  const startMicrophone = async () => {
    try {
      if (!navigator.mediaDevices) {
        console.log("마이크를 사용할 수 없는 환경입니다.");
        setRecordingError("마이크를 사용할 수 없는 환경입니다.");
        return false;
      }

      // 이미 마이크가 활성화되어 있고 스트림이 유효하면 중복 실행 방지
      if (isMicrophoneActive && streamRef.current && streamRef.current.active) {
        console.log("마이크가 이미 활성화되어 있습니다.");
        return true;
      }

      // 기존 스트림이 있지만 비활성화된 경우 정리
      if (streamRef.current && !streamRef.current.active) {
        console.log("비활성화된 스트림 정리");
        streamRef.current.getTracks().forEach(track => track.stop());
        streamRef.current = null;
      }

      console.log("마이크 권한 요청 중...");
      const stream = await navigator.mediaDevices.getUserMedia({ 
        audio: true,
        video: false 
      });
      
      streamRef.current = stream;
      setHasPermission(true);
      setIsMicrophoneActive(true);
      setRecordingError(null);
      
      console.log("마이크 활성화 완료");
      return true;
    } catch (error) {
      console.error("마이크 활성화 실패:", error);
      setHasPermission(false);
      setIsMicrophoneActive(false);
      
      // 사용자 친화적인 에러 메시지
      if (error.name === 'NotAllowedError') {
        setRecordingError("마이크 권한이 거부되었습니다. 브라우저 설정에서 마이크 권한을 허용해주세요.");
      } else if (error.name === 'NotFoundError') {
        setRecordingError("마이크를 찾을 수 없습니다. 마이크가 연결되어 있는지 확인해주세요.");
      } else {
        setRecordingError("마이크 활성화에 실패했습니다. 브라우저를 새로고침하고 다시 시도해주세요.");
      }
      return false;
    }
  };

  // 마이크 중지 함수
  const stopMicrophone = () => {
    try {
      // 녹음 중이면 먼저 정지
      if (isRecording) {
        stopRecording();
      }
      
      // MediaRecorder 완전 정리
      if (mediaRecorderRef.current) {
        if (mediaRecorderRef.current.state !== "inactive") {
          mediaRecorderRef.current.stop();
        }
        mediaRecorderRef.current = null; // 참조 완전 제거
      }
      
      // 스트림 정리
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(track => {
          track.stop();
          console.log("마이크 트랙 정리:", track.kind);
        });
        streamRef.current = null;
      }
      
      setIsMicrophoneActive(false);
      setHasPermission(false);
      setRecordingError(null);
      console.log("마이크 비활성화 완료");
    } catch (error) {
      console.error("마이크 비활성화 중 오류:", error);
    }
  };

  // 녹음 시작 함수
  const startRecording = async () => {
    try {
      // 마이크가 활성화되어 있지 않으면 먼저 활성화
      if (!isMicrophoneActive) {
        const success = await startMicrophone();
        if (!success) {
          return false;
        }
      }

      // 이미 녹음 중이면 중복 실행 방지
      if (isRecording) {
        console.log("이미 녹음 중입니다.");
        return true;
      }

      // MediaRecorder 생성 또는 재생성
      if (!mediaRecorderRef.current) {
        if (!streamRef.current) {
          console.log("스트림이 없습니다. 마이크 재활성화 필요");
          const success = await startMicrophone();
          if (!success) {
            return false;
          }
        }
        
        console.log("MediaRecorder 새로 생성");
        const mediaRecorder = new MediaRecorder(streamRef.current);
        mediaRecorderRef.current = mediaRecorder;
        
        mediaRecorder.ondataavailable = (e) => {
          console.log("녹음 데이터 수신:", e.data.size, "bytes");
          chunksRef.current.push(e.data);
        };

        mediaRecorder.onstop = () => {
          console.log("MediaRecorder onstop 이벤트 발생 - 녹음 완료");
          setIsRecording(false);
          console.log("녹음 상태를 false로 설정");
        };

        mediaRecorder.onerror = (event) => {
          console.error("녹음 중 오류:", event.error);
          setRecordingError("녹음 중 오류가 발생했습니다.");
          setIsRecording(false);
        };
      }

      // 녹음 시작
      if (mediaRecorderRef.current && mediaRecorderRef.current.state === "inactive") {
        chunksRef.current = [];
        mediaRecorderRef.current.start();
        setIsRecording(true);
        setRecordingError(null);
        console.log("녹음 시작");
        return true;
      } else {
        console.log("MediaRecorder 상태 문제:", mediaRecorderRef.current?.state);
        return false;
      }

    } catch (error) {
      console.error("녹음 시작 실패:", error);
      setRecordingError("녹음을 시작할 수 없습니다.");
      return false;
    }
  };

  // 녹음 정지 함수
  const stopRecording = () => {
    try {
      console.log("stopRecording 호출됨, MediaRecorder 상태:", mediaRecorderRef.current?.state);
      
      if (mediaRecorderRef.current && mediaRecorderRef.current.state === "recording") {
        mediaRecorderRef.current.stop();
        console.log("MediaRecorder.stop() 호출됨");
      } else {
        console.log("MediaRecorder가 녹음 중이 아닙니다. 현재 상태:", mediaRecorderRef.current?.state);
      }
    } catch (error) {
      console.error("녹음 정지 중 오류:", error);
    }
  };

  // 녹음 데이터 가져오기
  const getRecordingData = () => {
    if (chunksRef.current.length === 0) {
      return null;
    }
    const blob = new Blob(chunksRef.current, { type: "audio/mp3 codecs=opus" });
    return blob;
  };

  // 녹음 데이터 초기화
  const clearRecordingData = () => {
    chunksRef.current = [];
  };

  // 마이크 상태 지속성 보장 함수
  const ensureMicrophoneActive = async () => {
    console.log("마이크 상태 지속성 확인:", {
      isMicrophoneActive,
      hasPermission,
      hasStream: !!streamRef.current,
      streamActive: streamRef.current?.active
    });

    // 마이크가 비활성화되어 있거나 스트림이 없으면 활성화
    if (!isMicrophoneActive || !streamRef.current || !streamRef.current.active) {
      console.log("마이크 재활성화 필요");
      return await startMicrophone();
    }

    return true;
  };

  // 라우팅 변경 감지하여 마이크 자동 제어
  useEffect(() => {
    const currentPath = location.pathname;
    const currentSearch = location.search; // URL 파라미터 포함
    const isInterviewPage = currentPath.includes('/interview/interviewstart');
    const isPlayStartPage = currentPath.includes('/book/training/course/play/start');
    const isInterviewHistoryPage = currentPath.includes('/InterviewHistory');
    
    console.log("라우팅 변경 감지:", currentPath + currentSearch, "인터뷰 페이지:", isInterviewPage, "동화연극 페이지:", isPlayStartPage, "인터뷰 히스토리 페이지:", isInterviewHistoryPage);
    
    if (isInterviewPage || isPlayStartPage) {
      // 인터뷰 페이지 또는 동화연극 페이지 진입 시 마이크 on
      console.log("마이크 사용 페이지 진입 - 마이크 활성화");
      startMicrophone();
    } else if (isInterviewHistoryPage) {
      // 인터뷰 히스토리 페이지 진입 시 마이크 off
      if (isMicrophoneActive) {
        console.log("인터뷰 히스토리 페이지 진입 - 마이크 비활성화");
        stopMicrophone();
      }
    } else {
      // 마이크 사용 페이지 이탈 시 마이크 off
      if (isMicrophoneActive) {
        console.log("마이크 사용 페이지 이탈 - 마이크 비활성화");
        stopMicrophone();
      }
    }
  }, [location.pathname, location.search]); // location.search 의존성 추가

  // 마이크 상태 지속성 모니터링 (PlayStart 페이지에서만)
  useEffect(() => {
    const currentPath = location.pathname;
    const isPlayStartPage = currentPath.includes('/book/training/course/play/start');
    
    if (isPlayStartPage) {
      // PlayStart 페이지에서는 주기적으로 마이크 상태 확인
      const interval = setInterval(async () => {
        if (!isMicrophoneActive || !streamRef.current || !streamRef.current.active) {
          console.log("마이크 상태 지속성 모니터링 - 재활성화 필요");
          await ensureMicrophoneActive();
        }
      }, 5000); // 5초마다 확인

      return () => clearInterval(interval);
    }
  }, [location.pathname, isMicrophoneActive]);

  // 컴포넌트 언마운트 시 마이크 정리
  useEffect(() => {
    return () => {
      if (isMicrophoneActive) {
        console.log("컴포넌트 언마운트 - 마이크 정리");
        stopMicrophone();
      }
    };
  }, []);

  // 페이지 언로드 시 마이크 정리
  useEffect(() => {
    const handleBeforeUnload = () => {
      if (isMicrophoneActive) {
        console.log("페이지 언로드 - 마이크 정리");
        stopMicrophone();
      }
    };

    window.addEventListener('beforeunload', handleBeforeUnload);
    
    return () => {
      window.removeEventListener('beforeunload', handleBeforeUnload);
    };
  }, [isMicrophoneActive]);

  const value = {
    isMicrophoneActive,
    hasPermission,
    isRecording,
    recordingError,
    startMicrophone,
    stopMicrophone,
    startRecording,
    stopRecording,
    getRecordingData,
    clearRecordingData,
    ensureMicrophoneActive,
    mediaRecorderRef,
    streamRef
  };

  return (
    <MicrophoneContext.Provider value={value}>
      {children}
    </MicrophoneContext.Provider>
  );
};

export default MicrophoneContext;
