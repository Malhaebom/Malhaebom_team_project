import React, { useEffect, useState } from "react";
import Background from "../Background/Background";
import { useMicrophone } from "../../MicrophoneContext.jsx";
import useQuery from "../../hooks/useQuery.js";
import ScoreCircle from "../../components/ScoreCircle.jsx";

const InterviewHistory = () => {
  const { isMicrophoneActive, stopMicrophone } = useMicrophone();
  const [expandedCategories, setExpandedCategories] = useState(new Set());
  const [interviewData, setInterviewData] = useState([]);
  const [hasProcessedDummyData, setHasProcessedDummyData] = useState(false);
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
      
      // localStorage에 저장
      localStorage.setItem('interviewHistoryData', JSON.stringify(updatedData));
      
      // 상태 업데이트
      setInterviewData(updatedData);
      
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
    
    return {
      id: id,
      date: now.toISOString(),
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



        {interviewData.length > 0 ? (
          <div style={{ display: "flex", flexDirection: "column", gap: "15px" }}>
            {/* 첫 번째 결과만 표시 */}
            {(() => {
              const item = interviewData[0];
              if (!item) return null;
              
              return (
                <div
                  style={{
                    background: "#fff",
                    borderRadius: "12px",
                    boxShadow: "0 4px 12px rgba(0,0,0,0.1)",
                    overflow: "hidden"
                  }}
                >
                  {/* 헤더 - 회차 제거하고 날짜와 점수만 표시 */}
                  <div
                    style={{
                      padding: "20px",
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                      borderBottom: "1px solid #eee"
                    }}
                  >
                    <div style={{ 
                      display: "flex", 
                      alignItems: "center", 
                      gap: "10px" 
                    }}>
                      <span style={{ 
                        fontSize: "16px", 
                        color: "#333",
                        fontFamily: "GmarketSans",
                        fontWeight: "600"
                      }}>
                        {formatDate(item.date)}
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
                        color: getScoreColor(item.score, item.total),
                        fontFamily: "GmarketSans"
                      }}>
                        {`${item.score}/${item.total}점`}
                      </span>
                    </div>
                  </div>

                  {/* 상세 내용 - 항상 표시 */}
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
                </div>
              );
            })()}
          </div>
        ) : (
          <p style={{ textAlign: "center", color: "#888", fontSize: "16px" }}>
            아직 검사 이력이 없습니다.
          </p>
        )}
      </div>
    </div>
  );
};

export default InterviewHistory;
