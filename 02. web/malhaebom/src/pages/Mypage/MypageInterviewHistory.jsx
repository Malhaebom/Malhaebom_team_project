import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import Background from "../Background/Background";
import ScoreCircle from "../../components/ScoreCircle.jsx";
import Pagination from "../../components/Pagination.jsx";

const MypageInterviewHistory = () => {
  const navigate = useNavigate();
  const [interviewData, setInterviewData] = useState([]);
  const [expandedItems, setExpandedItems] = useState(new Set());
  const [expandedCategories, setExpandedCategories] = useState(new Set());
  const [currentPage, setCurrentPage] = useState(1);
  
  // 브라우저 가로 폭 상태
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  
  // 브라우저 창 너비 감지
  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  // localStorage에서 데이터 불러오기
  useEffect(() => {
    const savedData = JSON.parse(localStorage.getItem('interviewHistoryData') || '[]');
    setInterviewData(savedData);
  }, []);

  // 아이템 토글 함수
  const toggleItem = (itemId) => {
    const newExpanded = new Set(expandedItems);
    if (newExpanded.has(itemId)) {
      newExpanded.delete(itemId);
    } else {
      newExpanded.add(itemId);
    }
    setExpandedItems(newExpanded);
  };

  // 카테고리 토글 함수
  const toggleCategory = (itemId, category) => {
    const key = `${itemId}-${category}`;
    const newExpandedCategories = new Set(expandedCategories);
    if (newExpandedCategories.has(key)) {
      newExpandedCategories.delete(key);
    } else {
      newExpandedCategories.add(key);
    }
    setExpandedCategories(newExpandedCategories);
  };

  // 페이징 관련 함수들
  const itemsPerPage = 5;
  const totalPages = Math.ceil(interviewData.length / itemsPerPage);
  
  const handlePageChange = (page) => {
    setCurrentPage(page);
    // 페이지 변경 시 확장된 아이템들 초기화
    setExpandedItems(new Set());
    setExpandedCategories(new Set());
  };
  
  // 현재 페이지에 표시할 데이터 계산
  const getCurrentPageData = () => {
    const startIndex = (currentPage - 1) * itemsPerPage;
    const endIndex = startIndex + itemsPerPage;
    return interviewData.slice(startIndex, endIndex);
  };

  // 날짜 포맷팅
  const formatDate = (dateString) => {
    const date = new Date(dateString);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}`;
  };

  // 점수에 따른 색상
  const getScoreColor = (score, total) => {
    const percentage = (score / total) * 100;
    if (percentage >= 80) return "#4CAF50";
    if (percentage >= 60) return "#FFC107";
    if (percentage >= 40) return "#FF9800";
    return "#F44336";
  };

  // 상태 색상
  const getStatusColor = (status) => {
    switch (status) {
      case "양호": return "#4CAF50";
      case "보통": return "#FF9800";
      case "주의": return "#FFC107";
      case "매우 주의": return "#F44336";
      default: return "#666";
    }
  };

  // 점수로부터 상태 결정
  const getStatusFromScore = (score, total) => {
    const percentage = (score / total) * 100;
    if (percentage >= 80) return "양호";
    if (percentage >= 50) return "보통";
    if (percentage >= 30) return "주의";
    return "매우 주의";
  };

  // 전체 점수에 따른 평가 메시지
  const getOverallEvaluation = (score, total) => {
    const ratio = score / total;
    if (ratio >= 0.8) {
      return "전반적으로 양호합니다. 필요 시 추가 학습으로 안정적 이해를 유지하세요.";
    } else if (ratio >= 0.6) {
      return "일부 영역에서 개선이 필요합니다. 꾸준한 훈련으로 인지능력을 향상시킬 수 있습니다.";
    } else {
      return "인지 기능 저하가 의심됩니다. 전문가와 상담을 권장합니다.";
    }
  };

  // 평가 기준 텍스트
  const evaluationCriteria = {
    "반응 시간": "질문 종료 시점부터 응답 시작까지의 시간을 측정합니다. 3초 이내: 4점 / 3-6초: 2점 / 6초 초과: 0점 (10% 가중치)",
    "반복어 비율": "동일 단어·문장이 반복되는 비율을 분석합니다. 5% 이하: 4점 / 10% 이상: 2점 / 20% 이상: 0점 (10% 가중치)",
    "평균 문장 길이": "응답의 평균 단어(또는 음절) 수를 측정합니다. 적정 범위(8-15어): 4점 / 너무 짧거나 긴 경우: 2점 이하 (10% 가중치)",
    "화행 적절성": "질문의 화행과 응답의 화행이 일치하는지 판정합니다. 정답: 12점 / 부적절: 6점 / 무응답 또는 무관한 응답: 0점 (30% 가중치)",
    "회상어 점수": "사람·장소·사건 등 회상 관련 키워드의 포함을 평가합니다. 회상 키워드 포함: 8점 / 부분 포함: 4점 / 미포함: 0점 (20% 가중치)",
    "문법 완성도": "비문, 조사·부착, 주어·서술어 일치 등 문법적 오류를 분석합니다. 오류 없음: 8점 / 일부 오류: 4점 / 비문: 0점 (20% 가중치)"
  };

  // 컬러 슬라이더 컴포넌트
  const ColorSlider = ({ score, total, category }) => {
    const ratio = score / total;
    
    return (
      <div style={{ 
        display: "flex", 
        alignItems: "center", 
        gap: "12px",
        padding: "8px 0"
      }}>
        <div style={{
          flex: 1,
          height: "12px",
          borderRadius: "6px",
          position: "relative",
          overflow: "hidden",
          background: "linear-gradient(to right, #EF4444 0%, #F59E0B 50%, #10B981 100%)"
        }}>
          {/* 슬라이더 바 */}
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
              border: "2px solid #374151",
              boxShadow: "0 2px 4px rgba(0,0,0,0.2)",
              zIndex: 10
            }}
          />
        </div>
        
        <div style={{
          minWidth: "60px",
          textAlign: "right"
        }}>
          <span style={{
            fontSize: "14px",
            fontWeight: "600",
            color: "#374151"
          }}>
            {score}/{total}
          </span>
        </div>
      </div>
    );
  };

  return (
    <div className="content">
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
        {/* 헤더 */}
        <div style={{
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          marginBottom: "30px"
        }}>
                     <h2
             style={{
               margin: 0,
               fontFamily: "ONE-Mobile-Title",
               fontSize: "32px",
               textAlign: "center"
             }}
           >
             인지능력검사 결과이력
           </h2>
        </div>

        {interviewData.length === 0 ? (
          <div style={{
            background: "#fff",
            padding: "20px",
            borderRadius: "12px",
            boxShadow: "0 4px 12px rgba(0,0,0,0.1)",
            textAlign: "center"
          }}>
            <p style={{ color: "#888", fontSize: "16px", margin: 0 }}>
              아직 검사 이력이 없습니다.
            </p>
          </div>
        ) : (
          <>
            <div style={{ display: "flex", flexDirection: "column", gap: "15px" }}>
              {getCurrentPageData().map((item, index) => {
                const isExpanded = expandedItems.has(item.id);
                const globalIndex = (currentPage - 1) * itemsPerPage + index;
                const roundNumber = interviewData.length - globalIndex; // 최신 검사가 1회차
                
                return (
                  <div
                    key={item.id}
                    style={{
                      background: "#fff",
                      borderRadius: "12px",
                      boxShadow: "0 4px 12px rgba(0,0,0,0.1)",
                      overflow: "hidden"
                    }}
                  >
                    {/* 헤더 - 회차, 날짜, 점수, 토글 버튼 */}
                    <div
                      style={{
                        padding: "20px",
                        display: "flex",
                        justifyContent: "space-between",
                        alignItems: "center",
                        borderBottom: isExpanded ? "1px solid #eee" : "none",
                        cursor: "pointer"
                      }}
                      onClick={() => toggleItem(item.id)}
                    >
                      <div style={{ 
                        display: "flex", 
                        alignItems: "center", 
                        gap: "15px" 
                      }}>
                        <span style={{ 
                          fontSize: "16px", 
                          color: "#333",
                          fontFamily: "GmarketSans",
                          fontWeight: "600"
                        }}>
                          {roundNumber}회차
                        </span>
                        <span style={{ 
                          fontSize: "16px", 
                          color: "#666",
                          fontFamily: "GmarketSans"
                        }}>
                          {formatDate(item.date)}
                        </span>
                      </div>
                      <div style={{ 
                        display: "flex", 
                        alignItems: "center", 
                        gap: "15px" 
                      }}>
                        <span style={{ 
                          fontSize: "18px", 
                          fontWeight: "bold", 
                          color: getScoreColor(item.score, item.total),
                          fontFamily: "GmarketSans"
                        }}>
                          {`${item.score}/${item.total}점`}
                        </span>
                        <span style={{ 
                          fontSize: "20px", 
                          color: "#666",
                          transition: "transform 0.2s ease",
                          transform: isExpanded ? "rotate(180deg)" : "rotate(0deg)"
                        }}>
                          ▼
                        </span>
                      </div>
                    </div>

                    {/* 상세 내용 - 토글로 표시/숨김 */}
                    {isExpanded && (
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
                              fontFamily: "GmarketSans"
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
                                {/* 카테고리 헤더 */}
                                <div 
                                  style={{
                                    display: "flex",
                                    justifyContent: "space-between",
                                    alignItems: "center",
                                    padding: "12px",
                                    cursor: "pointer"
                                  }}
                                  onClick={() => toggleCategory(item.id, category)}
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
                                      transition: "transform 0.2s ease",
                                      transform: expandedCategories.has(`${item.id}-${category}`) ? "rotate(180deg)" : "rotate(0deg)"
                                    }}>
                                      ▼
                                    </span>
                                  </div>
                                </div>
                                
                                {/* 카테고리 상세 내용 - 토글로 표시/숨김 */}
                                {expandedCategories.has(`${item.id}-${category}`) && (
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
                                        fontFamily: "GmarketSans"
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
                );
              })}
            </div>
            
                        {/* 페이징 컨트롤 */}
            <div style={{ marginTop: "30px" }}>
              <Pagination
                currentPage={currentPage}
                totalPages={totalPages}
                onPageChange={handlePageChange}
                itemsPerPage={itemsPerPage}
              />
            </div>
          </>
        )}
      </div>
    </div>
  );
};

export default MypageInterviewHistory;
