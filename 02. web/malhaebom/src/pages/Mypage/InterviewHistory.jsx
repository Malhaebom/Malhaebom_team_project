import React, { useEffect, useState } from "react";
import Background from "../Background/Background";
import { useMicrophone } from "../../MicrophoneContext.jsx";
import useQuery from "../../hooks/useQuery.js";
import ScoreCircle from "../../components/ScoreCircle.jsx";

const InterviewHistory = () => {
  const { isMicrophoneActive, stopMicrophone } = useMicrophone();
  const [expandedItems, setExpandedItems] = useState(new Set());
  const [expandedCategories, setExpandedCategories] = useState(new Set());
  const [interviewData, setInterviewData] = useState([]);
  const [hasProcessedDummyData, setHasProcessedDummyData] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage] = useState(5);
  const query = useQuery();

  // 브라우저 가로 폭 상태
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);

  // 브라우저 창 너비 감지
  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  // 페이지 진입 시 마이크 상태 확인 및 비활성화
  useEffect(() => {
    console.log("InterviewHistory 페이지 진입 - 마이크 상태:", isMicrophoneActive);
    
    // 페이지 진입 시 마이크가 활성화되어 있다면 비활성화
    if (isMicrophoneActive) {
      console.log("InterviewHistory 페이지 진입 - 마이크 비활성화 실행");
      stopMicrophone();
    }
  }, [isMicrophoneActive, stopMicrophone]);

  // URL 파라미터에서 더미 데이터 확인 및 처리
  useEffect(() => {
    const dummyData = query.get("dummyData");
    if (dummyData === "true" && !hasProcessedDummyData) {
      // 중복 처리 방지
      setHasProcessedDummyData(true);
      
      // 더미 데이터 생성
      const newResult = generateDummyResult();
      
      // localStorage에서 기존 데이터 불러오기
      const existingData = JSON.parse(localStorage.getItem('interviewHistoryData') || '[]');
      
      // 새 데이터를 맨 앞에 추가
      const updatedData = [newResult, ...existingData];
      
      // 최대 17개까지만 유지 (페이징 테스트용)
      const limitedData = updatedData.slice(0, 17);
      
      // localStorage에 저장
      localStorage.setItem('interviewHistoryData', JSON.stringify(limitedData));
      
      // 상태 업데이트
      setInterviewData(limitedData);
      setCurrentPage(1); // 새 데이터 추가 시 1페이지로 이동
      setExpandedItems(new Set()); // 확장된 항목들 닫기
      
      // URL에서 더미 데이터 파라미터 즉시 제거 (중복 생성 방지)
      setTimeout(() => {
        window.history.replaceState({}, document.title, window.location.pathname);
      }, 100);
    } else if (!hasProcessedDummyData) {
      // 일반 조회 시 localStorage에서 데이터 불러오기
      const savedData = JSON.parse(localStorage.getItem('interviewHistoryData') || '[]');
      
      // 기존 데이터에 회차 정보가 없는 경우 추가
      const processedData = savedData.map((item, index) => {
        if (!item.attemptOrder) {
          return {
            ...item,
            attemptOrder: savedData.length - index // 최신 데이터가 높은 회차
          };
        }
        return item;
      });
      
      setInterviewData(processedData);
    }
  }, [query, hasProcessedDummyData]);

  // 더미 데이터 생성 함수 (40점 만점 기준)
  const generateDummyResult = () => {
    const now = new Date();
    const id = Date.now();
    
    // 이미지의 배점 기준에 따른 랜덤 점수 생성
    const 반응시간 = Math.floor(Math.random() * 5); // 0-4점 (10% 가중치)
    const 반복어비율 = Math.floor(Math.random() * 5); // 0-4점 (10% 가중치)
    const 평균문장길이 = Math.floor(Math.random() * 5); // 0-4점 (10% 가중치)
    const 화행적절성 = Math.floor(Math.random() * 13); // 0-12점 (30% 가중치)
    const 회상어점수 = Math.floor(Math.random() * 9); // 0-8점 (20% 가중치)
    const 문법완성도 = Math.floor(Math.random() * 9); // 0-8점 (20% 가중치)
    
    const totalScore = 반응시간 + 반복어비율 + 평균문장길이 + 화행적절성 + 회상어점수 + 문법완성도;
    
    // 기존 데이터에서 회차 계산
    const existingData = JSON.parse(localStorage.getItem('interviewHistoryData') || '[]');
    const attemptOrder = existingData.length + 1;
    
    return {
      id: id,
      date: now.toISOString(),
      attemptOrder: attemptOrder, // 회차 정보 추가
      score: totalScore,
      total: 40, // 40점 만점으로 변경
      details: {
        "반응 시간": { score: 반응시간, total: 4 }, // 10% 가중치
        "반복어 비율": { score: 반복어비율, total: 4 }, // 10% 가중치
        "평균 문장 길이": { score: 평균문장길이, total: 4 }, // 10% 가중치
        "화행 적절성": { score: 화행적절성, total: 12 }, // 30% 가중치
        "회상어 점수": { score: 회상어점수, total: 8 }, // 20% 가중치
        "문법 완성도": { score: 문법완성도, total: 8 } // 20% 가중치
      }
    };
  };

  // 전체 점수에 따른 평가 메시지 생성 (마침표 기준 줄바꿈)
  const getOverallEvaluation = (score, total) => {
    const ratio = score / total;
    if (ratio >= 0.8) {
      return "전반적으로 양호합니다.\n필요 시 추가 학습으로 안정적 이해를 유지하세요.";
    } else if (ratio >= 0.6) {
      return "일부 영역에서 개선이 필요합니다.\n꾸준한 훈련으로 인지능력을 향상시킬 수 있습니다.";
    } else {
      return "인지 기능 저하가 의심됩니다.\n전문가와 상담을 권장합니다.";
    }
  };

  // 평가 기준 텍스트 (40점 만점 기준) - 마침표 기준 줄바꿈
  const evaluationCriteria = {
    "반응 시간": "질문 종료 시점부터 응답 시작까지의 시간을 측정합니다.\n3초 이내: 4점 / 3-6초: 2점 / 6초 초과: 0점 (10% 가중치)",
    "반복어 비율": "동일 단어·문장이 반복되는 비율을 분석합니다.\n5% 이하: 4점 / 10% 이상: 2점 / 20% 이상: 0점 (10% 가중치)",
    "평균 문장 길이": "응답의 평균 단어(또는 음절) 수를 측정합니다.\n적정 범위(8-15어): 4점 / 너무 짧거나 긴 경우: 2점 이하 (10% 가중치)",
    "화행 적절성": "질문의 화행과 응답의 화행이 일치하는지 판정합니다.\n정답: 12점 / 부적절: 6점 / 무응답 또는 무관한 응답: 0점 (30% 가중치)",
    "회상어 점수": "사람·장소·사건 등 회상 관련 키워드의 포함을 평가합니다.\n회상 키워드 포함: 8점 / 부분 포함: 4점 / 미포함: 0점 (20% 가중치)",
    "문법 완성도": "비문, 조사·부착, 주어·서술어 일치 등 문법적 오류를 분석합니다.\n오류 없음: 8점 / 일부 오류: 4점 / 비문: 0점 (20% 가중치)"
  };

  // 컬러 슬라이드 컴포넌트 (앱 디자인과 통일)
  const ColorSlider = ({ score, total, category }) => {
    const ratio = score / total;
    
    // 앱과 동일한 색상 팔레트 사용 (그라데이션용)
    const getSliderColors = () => {
      return {
        green: "#10B981",    // 양호 (초록)
        lightGreen: "#34D399", // 밝은 초록
        yellow: "#FCD34D",   // 노랑
        orange: "#F59E0B",   // 보통 (주황)
        lightRed: "#F87171", // 밝은 빨강
        red: "#EF4444"       // 주의 (빨강)
      };
    };
    
    // 점수에 따른 색상 결정
    const getScoreColor = (ratio) => {
      if (ratio > 0.75) return getSliderColors().green;
      if (ratio > 0.5) return getSliderColors().orange;
      if (ratio > 0.25) return getSliderColors().red;
      return getSliderColors().red;
    };
    
    return (
      <div style={{ 
        display: "flex", 
        alignItems: "center", 
        gap: "12px",
        padding: "8px 0"
      }}>
        {/* 슬라이더 컨테이너 */}
        <div style={{
          flex: 1,
          height: "12px",
          backgroundColor: "#F3F4F6",
          borderRadius: "6px",
          position: "relative",
          overflow: "hidden",
          border: "1px solid #E5E7EB"
        }}>
          {/* 그라데이션 배경 (앱과 동일한 색상 전환) */}
          <div style={{
            position: "absolute",
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: `linear-gradient(to right, 
              ${getSliderColors().green} 0%, 
              ${getSliderColors().lightGreen} 20%, 
              ${getSliderColors().yellow} 40%, 
              ${getSliderColors().orange} 60%, 
              ${getSliderColors().lightRed} 80%, 
              ${getSliderColors().red} 100%)`,
            borderRadius: "6px"
          }} />
          
          {/* 슬라이더 핸들 (앱과 동일한 흰색 원형) */}
          <div 
            style={{
              position: "absolute",
              top: "50%",
              left: `${ratio * 100}%`,
              transform: "translate(-50%, -50%)",
              width: "16px",
              height: "16px",
              backgroundColor: "#FFFFFF",
              borderRadius: "50%",
              border: "2px solid #E5E7EB",
              boxShadow: "0 2px 4px rgba(0,0,0,0.1)",
              transition: "left 0.3s ease",
              zIndex: 10
            }}
          />
        </div>
        
        {/* 점수 표시 */}
        <div style={{
          minWidth: "60px",
          textAlign: "right"
        }}>
          <span style={{
            fontSize: "14px",
            fontWeight: "600",
            color: getScoreColor(ratio)
          }}>
            {score}/{total}
          </span>
        </div>
      </div>
    );
  };

  // 카테고리 토글 함수
  const toggleCategory = (category) => {
    const newExpanded = new Set(expandedCategories);
    if (newExpanded.has(category)) {
      newExpanded.delete(category);
    } else {
      newExpanded.add(category);
    }
    setExpandedCategories(newExpanded);
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}`;
  };

  const getScoreColor = (score, total) => {
    const percentage = (score / total) * 100;
    if (percentage >= 80) return "#4CAF50";
    if (percentage >= 60) return "#FFC107";
    if (percentage >= 40) return "#FF9800";
    return "#F44336";
  };

  const getStatusColor = (status) => {
    switch (status) {
      case "양호": return "#4CAF50";
      case "보통": return "#FF9800";
      case "주의": return "#FFC107";
      case "매우 주의": return "#F44336";
      default: return "#666";
    }
  };

  const getStatusFromScore = (score, total) => {
    const percentage = (score / total) * 100;
    if (percentage >= 80) return "양호";
    if (percentage >= 50) return "보통";
    if (percentage >= 30) return "주의";
    return "매우 주의";
  };

  const toggleExpanded = (id) => {
    const newExpanded = new Set(expandedItems);
    if (newExpanded.has(id)) {
      newExpanded.delete(id);
    } else {
      newExpanded.add(id);
    }
    setExpandedItems(newExpanded);
    // 항목 토글 시 카테고리 확장 상태 초기화
    setExpandedCategories(new Set());
  };

  // 페이징 관련 함수들
  const totalPages = Math.ceil(interviewData.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const endIndex = startIndex + itemsPerPage;
  const currentData = interviewData.slice(startIndex, endIndex);

  // 현재 페이지의 데이터를 5개로 맞추기 (빈 항목 추가)
  const getCurrentPageData = () => {
    const data = [...currentData];
    
    // 5개 미만이면 빈 항목들을 추가
    while (data.length < itemsPerPage) {
      data.push(null);
    }
    
    return data;
  };

  const handlePageChange = (page) => {
    setCurrentPage(page);
    // 페이지 변경 시 모든 확장된 항목 닫기
    setExpandedItems(new Set());
  };

  const renderPagination = () => {
    if (totalPages <= 1) return null;

    return (
      <div style={{
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        marginTop: "30px",
        marginBottom: "20px",
        gap: "12px"
      }}>
        {/* 이전 페이지 버튼 - 항상 표시하되 첫 페이지에서는 비활성화 */}
        <button
          onClick={() => currentPage > 1 && handlePageChange(currentPage - 1)}
          disabled={currentPage === 1}
          style={{
            padding: "8px 12px",
            border: "none",
            backgroundColor: currentPage === 1 ? "#f5f5f5" : "#e0e0e0",
            borderRadius: "5px",
            cursor: currentPage === 1 ? "not-allowed" : "pointer",
            fontSize: "16px",
            fontWeight: "bold",
            color: currentPage === 1 ? "#bdbdbd" : "#666",
            transition: "all 0.2s ease",
            minWidth: "44px",
            height: "44px",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            boxShadow: "0px 0px 10px rgba(0, 0, 0, 0.1)"
          }}
          onMouseEnter={(e) => {
            if (currentPage > 1) {
              e.target.style.backgroundColor = "#488eca";
              e.target.style.color = "#fff";
              e.target.style.boxShadow = "0px 0px 15px rgba(0, 0, 0, 0.2)";
            }
          }}
          onMouseLeave={(e) => {
            if (currentPage > 1) {
              e.target.style.backgroundColor = "#e0e0e0";
              e.target.style.color = "#666";
              e.target.style.boxShadow = "0px 0px 10px rgba(0, 0, 0, 0.1)";
            }
          }}
        >
          ‹
        </button>

        {/* 현재 페이지 번호 */}
        <div style={{
          padding: "8px 16px",
          border: "1px solid #fff",
          backgroundColor: "#fff",
          borderRadius: "5px",
          fontSize: "16px",
          fontWeight: "bold",
          color: "#333",
          minWidth: "50px",
          height: "44px",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          boxShadow: "0px 2px 8px rgba(0, 0, 0, 0.1)"
        }}>
          {currentPage}
        </div>

        {/* 다음 페이지 버튼 - 항상 표시하되 마지막 페이지에서는 비활성화 */}
        <button
          onClick={() => currentPage < totalPages && handlePageChange(currentPage + 1)}
          disabled={currentPage === totalPages}
          style={{
            padding: "8px 12px",
            border: "none",
            backgroundColor: currentPage === totalPages ? "#f5f5f5" : "#e0e0e0",
            borderRadius: "5px",
            cursor: currentPage === totalPages ? "not-allowed" : "pointer",
            fontSize: "16px",
            fontWeight: "bold",
            color: currentPage === totalPages ? "#bdbdbd" : "#666",
            transition: "all 0.2s ease",
            minWidth: "44px",
            height: "44px",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            boxShadow: "0px 0px 10px rgba(0, 0, 0, 0.1)"
          }}
          onMouseEnter={(e) => {
            if (currentPage < totalPages) {
              e.target.style.backgroundColor = "#488eca";
              e.target.style.color = "#fff";
              e.target.style.boxShadow = "0px 0px 15px rgba(0, 0, 0, 0.2)";
            }
          }}
          onMouseLeave={(e) => {
            if (currentPage < totalPages) {
              e.target.style.backgroundColor = "#e0e0e0";
              e.target.style.color = "#666";
              e.target.style.boxShadow = "0px 0px 10px rgba(0, 0, 0, 0.1)";
            }
          }}
        >
          ›
        </button>
      </div>
    );
  };

  return (
    <div className="content">
      {/* 가로 1100 이상일 때만 배경 렌더링 */}
      {windowWidth > 1100 && <Background />}

      <div
        className="wrap"
        style={{
          maxWidth: "520px",
          margin: "0 auto",
          padding: "80px 20px",
          fontFamily: "Pretendard-Regular",
        }}
      >
        {/* 타이틀 */}
        <h2
          style={{
            textAlign: "center",
            marginBottom: "30px",
            fontFamily: "ONE-Mobile-Title",
            fontSize: "32px",
          }}
        >
          인지능력검사 결과
        </h2>

        {/* 테스트용 더미 데이터 생성 버튼 */}
        <div style={{ 
          textAlign: "center", 
          marginBottom: "20px",
          display: "flex",
          gap: "10px",
          justifyContent: "center"
        }}>
          <button
            onClick={() => {
              const newResult = generateDummyResult();
              // 기존 데이터에 새 데이터 추가 (기존 데이터 유지)
              const existingData = JSON.parse(localStorage.getItem('interviewHistoryData') || '[]');
              const updatedData = [newResult, ...existingData];
              
              // 기존 데이터에 회차 정보가 없는 경우 추가
              const processedData = updatedData.map((item, index) => {
                if (!item.attemptOrder) {
                  return {
                    ...item,
                    attemptOrder: updatedData.length - index // 최신 데이터가 높은 회차
                  };
                }
                return item;
              });
              
              // 최대 17개까지만 유지 (페이징 테스트용)
              const limitedData = processedData.slice(0, 17);
              localStorage.setItem('interviewHistoryData', JSON.stringify(limitedData));
              setInterviewData(limitedData);
              setCurrentPage(1); // 새 데이터 추가 시 1페이지로 이동
              setExpandedItems(new Set()); // 확장된 항목들 닫기
            }}
            style={{
              padding: "10px 20px",
              backgroundColor: "#4CAF50",
              color: "white",
              border: "none",
              borderRadius: "8px",
              cursor: "pointer",
              fontSize: "14px",
              fontWeight: "600"
            }}
          >
            테스트용 더미 데이터 추가
          </button>
          
          <button
            onClick={() => {
              // localStorage 완전 초기화
              localStorage.removeItem('interviewHistoryData');
              setInterviewData([]);
              setCurrentPage(1);
              setExpandedItems(new Set());
            }}
            style={{
              padding: "10px 20px",
              backgroundColor: "#f44336",
              color: "white",
              border: "none",
              borderRadius: "8px",
              cursor: "pointer",
              fontSize: "14px",
              fontWeight: "600"
            }}
          >
            모든 데이터 지우기
          </button>
        </div>

        {interviewData.length > 0 ? (
          <div style={{ display: "flex", flexDirection: "column", gap: "15px" }}>
            {getCurrentPageData().map((item, index) => (
              <div
                key={index} // Use index as key for null items
                style={{
                  background: item ? "#fff" : "#fff",
                  borderRadius: "12px",
                  boxShadow: item ? "0 4px 12px rgba(0,0,0,0.1)" : "none",
                  overflow: "hidden",
                  opacity: item ? 1 : 0,
                  border: item ? "none" : "1px solid #fff",
                  height: item ? "auto" : "80px", // 빈 항목은 고정 높이
                  minHeight: item ? "80px" : "80px" // 최소 높이도 동일하게 설정
                }}
              >
                {/* 탭 헤더 */}
                <div
                  style={{
                    padding: "20px",
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    cursor: item ? "pointer" : "default",
                    borderBottom: expandedItems.has(item?.id) ? "1px solid #eee" : "none",
                  }}
                  onClick={() => item && toggleExpanded(item.id)}
                >
                  <div style={{ 
                    display: "flex", 
                    alignItems: "center", 
                    gap: "10px" 
                  }}>
                    {item && item.attemptOrder && (
                      <span style={{
                        fontSize: "16px",
                        fontWeight: "bold",
                        color: "#488eca", // 파란색으로 회차 표시
                        fontFamily: "GmarketSans"
                      }}>
                        {item.attemptOrder}회차
                      </span>
                    )}
                    <span style={{ 
                      fontSize: "16px", 
                      color: item ? "#333" : "#fff",
                      fontFamily: "GmarketSans",
                      fontWeight: "600"
                    }}>
                      {item ? formatDate(item.date) : ""}
                    </span>
                  </div>
                  <div style={{ 
                    display: "flex", 
                    alignItems: "center", 
                    gap: "10px" 
                  }}>
                    <span style={{ 
                      fontSize: "18px", 
                      fontWeight: "bold", 
                      color: item ? getScoreColor(item.score, item.total) : "#fff",
                      fontFamily: "GmarketSans"
                    }}>
                      {item ? `${item.score}/${item.total}점` : ""}
                    </span>
                    {item && (
                      <span style={{
                        fontSize: "20px",
                        color: "#666",
                        transition: "transform 0.3s ease",
                        transform: expandedItems.has(item.id) ? "rotate(180deg)" : "rotate(0deg)"
                      }}>
                        ▼
                      </span>
                    )}
                  </div>
                </div>

                {/* 상세 내용 */}
                {item && expandedItems.has(item.id) && (
                  <div style={{ padding: "20px", background: "#f8f9fa" }}>
                    <div style={{ marginBottom: "15px" }}>
                      <h3 style={{
                        fontSize: "18px",
                        fontWeight: "bold",
                        color: "#333",
                        marginBottom: "10px",
                        fontFamily: "GmarketSans"
                      }}>
                        상세 결과
                      </h3>
                      {/* 전체 점수에 따른 평가 메시지 */}
                      <div style={{
                        padding: "12px",
                        background: "#fff",
                        borderRadius: "8px",
                        border: "1px solid #e0e0e0",
                        marginBottom: "15px"
                      }}>
                                                 <p style={{
                           fontSize: "14px",
                           color: "#4B5563",
                           lineHeight: "1.5",
                           margin: "0",
                           fontFamily: "GmarketSans",
                           whiteSpace: "pre-line"
                         }}>
                           {getOverallEvaluation(item.score, item.total)}
                         </p>
                      </div>
                    </div>
                    
                    {/* 원형 점수 표시 */}
                    <div style={{ 
                      display: "flex", 
                      justifyContent: "center", 
                      marginBottom: "20px",
                      padding: "20px 0"
                    }}>
                      <ScoreCircle score={item.score} total={item.total} size={120} />
                    </div>
                    
                    <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
                      {Object.entries(item.details).map(([category, detail]) => {
                        const status = getStatusFromScore(detail.score, detail.total);
                        const isExpanded = expandedCategories.has(category);
                        
                        return (
                          <div
                            key={category}
                            style={{
                              background: "#fff",
                              borderRadius: "8px",
                              border: "1px solid #e0e0e0",
                              overflow: "hidden"
                            }}
                          >
                            {/* 카테고리 헤더 - 클릭 가능 */}
                            <div
                              onClick={() => toggleCategory(category)}
                              style={{
                                display: "flex",
                                justifyContent: "space-between",
                                alignItems: "center",
                                padding: "12px",
                                cursor: "pointer",
                                transition: "background-color 0.2s ease"
                              }}
                              onMouseEnter={(e) => e.target.style.backgroundColor = "#f9fafb"}
                              onMouseLeave={(e) => e.target.style.backgroundColor = "#fff"}
                            >
                              <span style={{
                                fontSize: "16px",
                                fontWeight: "600",
                                color: "#333",
                                fontFamily: "GmarketSans"
                              }}>
                                {category}
                              </span>
                              <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                                <span style={{
                                  fontSize: "14px",
                                  fontWeight: "bold",
                                  color: getScoreColor(detail.score, detail.total)
                                }}>
                                  {detail.score}/{detail.total}
                                </span>
                                <span style={{
                                  fontSize: "12px",
                                  padding: "4px 8px",
                                  borderRadius: "12px",
                                  background: getStatusColor(status) + "20",
                                  color: getStatusColor(status),
                                  fontWeight: "600"
                                }}>
                                  {status}
                                </span>
                                <span style={{
                                  fontSize: "16px",
                                  color: "#666",
                                  transition: "transform 0.3s ease",
                                  transform: isExpanded ? "rotate(180deg)" : "rotate(0deg)"
                                }}>
                                  ▼
                                </span>
                              </div>
                            </div>
                            
                                                         {/* 확장된 세부사항 */}
                             {isExpanded && (
                               <div style={{
                                 padding: "12px",
                                 borderTop: "1px solid #e0e0e0",
                                 background: "#fafafa"
                               }}>
                                 <ColorSlider 
                                   score={detail.score} 
                                   total={detail.total} 
                                   category={category} 
                                 />
                                 {/* 평가 기준 텍스트 */}
                                 <div style={{
                                   marginTop: "12px",
                                   padding: "8px 0",
                                   borderTop: "1px solid #e5e7eb"
                                 }}>
                                                                       <p style={{
                                      fontSize: "12px",
                                      color: "#6B7280",
                                      lineHeight: "1.4",
                                      margin: "0",
                                      fontFamily: "GmarketSans",
                                      whiteSpace: "pre-line"
                                    }}>
                                      {evaluationCriteria[category]}
                                    </p>
                                 </div>
                               </div>
                             )}
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}
              </div>
            ))}
          </div>
        ) : (
          <p style={{ textAlign: "center", color: "#888", fontSize: "16px" }}>
            아직 검사 이력이 없습니다.
          </p>
        )}

        {/* 페이징 네비게이션 */}
        {renderPagination()}
      </div>
    </div>
  );
};

export default InterviewHistory;
