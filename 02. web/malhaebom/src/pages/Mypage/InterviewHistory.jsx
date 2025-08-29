import React, { useEffect, useState } from "react";
import Background from "../Background/Background";
import { useMicrophone } from "../../MicrophoneContext.jsx";
import useQuery from "../../hooks/useQuery.js";

const InterviewHistory = () => {
  const { isMicrophoneActive } = useMicrophone();
  const [expandedItems, setExpandedItems] = useState(new Set());
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

  // 페이지 진입 시 마이크 상태 확인
  useEffect(() => {
    console.log("InterviewHistory 페이지 진입 - 마이크 상태:", isMicrophoneActive);
  }, [isMicrophoneActive]);

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
      setInterviewData(savedData);
    }
  }, [query, hasProcessedDummyData]);

  // 더미 데이터 생성 함수
  const generateDummyResult = () => {
    const now = new Date();
    const id = Date.now();
    
    // 각 카테고리별 랜덤 점수 생성 (0-10점)
    const 요구 = Math.floor(Math.random() * 11);
    const 질문 = Math.floor(Math.random() * 11);
    const 단언 = Math.floor(Math.random() * 11);
    const 의례화 = Math.floor(Math.random() * 11);
    
    const totalScore = 요구 + 질문 + 단언 + 의례화;
    
    return {
      id: id,
      date: now.toISOString(),
      score: totalScore,
      total: 40,
      details: {
        "요구": { score: 요구, total: 10 },
        "질문": { score: 질문, total: 10 },
        "단언": { score: 단언, total: 10 },
        "의례화": { score: 의례화, total: 10 }
      }
    };
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
              // 최대 17개까지만 유지 (페이징 테스트용)
              const limitedData = updatedData.slice(0, 17);
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
                  <span style={{ 
                    fontSize: "16px", 
                    color: item ? "#333" : "#fff",
                    fontFamily: "GmarketSans",
                    fontWeight: "600"
                  }}>
                    {item ? formatDate(item.date) : ""}
                  </span>
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
                    </div>
                    
                    <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
                      {Object.entries(item.details).map(([category, detail]) => {
                        const status = getStatusFromScore(detail.score, detail.total);
                        return (
                          <div
                            key={category}
                            style={{
                              display: "flex",
                              justifyContent: "space-between",
                              alignItems: "center",
                              padding: "12px",
                              background: "#fff",
                              borderRadius: "8px",
                              border: "1px solid #e0e0e0"
                            }}
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
                            </div>
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
