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
  const mediaRecorderRef = useRef(null);
  const streamRef = useRef(null);

  // 마이크 시작 함수
  const startMicrophone = async () => {
    try {
      if (!navigator.mediaDevices) {
        console.log("마이크를 사용할 수 없는 환경입니다.");
        return false;
      }

      // 이미 마이크가 활성화되어 있다면 중복 실행 방지
      if (isMicrophoneActive) {
        console.log("마이크가 이미 활성화되어 있습니다.");
        return true;
      }

      console.log("마이크 권한 요청 중...");
      const stream = await navigator.mediaDevices.getUserMedia({ 
        audio: true,
        video: false 
      });
      
      streamRef.current = stream;
      setHasPermission(true);
      setIsMicrophoneActive(true);
      
      console.log("마이크 활성화 완료");
      return true;
    } catch (error) {
      console.error("마이크 활성화 실패:", error);
      setHasPermission(false);
      setIsMicrophoneActive(false);
      return false;
    }
  };

  // 마이크 중지 함수
  const stopMicrophone = () => {
    try {
      // MediaRecorder 정리
      if (mediaRecorderRef.current) {
        if (mediaRecorderRef.current.state !== "inactive") {
          mediaRecorderRef.current.stop();
        }
        mediaRecorderRef.current = null;
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
      console.log("마이크 비활성화 완료");
    } catch (error) {
      console.error("마이크 비활성화 중 오류:", error);
    }
  };

  // 라우팅 변경 감지하여 마이크 자동 제어
  useEffect(() => {
    const currentPath = location.pathname;
    const isInterviewPage = currentPath.includes('/interview/interviewstart');
    const isPlayStartPage = currentPath.includes('/book/training/course/play/start');
    
    console.log("라우팅 변경 감지:", currentPath, "인터뷰 페이지:", isInterviewPage, "동화연극 페이지:", isPlayStartPage);
    
    if (isInterviewPage || isPlayStartPage) {
      // 인터뷰 페이지 또는 동화연극 페이지 진입 시 마이크 on
      console.log("마이크 사용 페이지 진입 - 마이크 활성화");
      startMicrophone();
    } else {
      // 마이크 사용 페이지 이탈 시 마이크 off
      if (isMicrophoneActive) {
        console.log("마이크 사용 페이지 이탈 - 마이크 비활성화");
        stopMicrophone();
      }
    }
  }, [location.pathname]);

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
    startMicrophone,
    stopMicrophone,
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
