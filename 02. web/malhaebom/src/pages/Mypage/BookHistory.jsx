import React, { useState, useEffect } from "react";
import Background from "../Background/Background";

const BookHistory = () => {
  const [windowWidth, setWindowWidth] = useState(window.innerWidth); // 브라우저 너비 상태
  const [expandedItems, setExpandedItems] = useState(new Set()); // 확장된 아이템 상태

  // 브라우저창 너비 감지
  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

       // localStorage에서 실제 BookHistory 데이터 불러오기
  const [bookData, setBookData] = useState([]);

  // localStorage에서 데이터 로드
  useEffect(() => {
    const loadBookHistory = () => {
      try {
        const savedHistory = localStorage.getItem("bookHistory");
        if (savedHistory) {
          const parsedHistory = JSON.parse(savedHistory);
          setBookData(parsedHistory);
        }
      } catch (error) {
        console.error("BookHistory 데이터 로드 실패:", error);
        setBookData([]);
      }
    };

    loadBookHistory();

    // localStorage 변경 감지 (다른 탭에서 데이터가 추가될 경우)
    const handleStorageChange = (e) => {
      if (e.key === "bookHistory") {
        loadBookHistory();
      }
    };

    window.addEventListener("storage", handleStorageChange);
    return () => window.removeEventListener("storage", handleStorageChange);
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

  const getScoreColor = (score, total) => {
    const percentage = (score / total) * 100;
    if (percentage >= 80) return "#4CAF50";
    if (percentage >= 60) return "#FFC107";
    if (percentage >= 40) return "#FF9800";
    return "#F44336";
  };





  // 저장된 total 값 사용 (이미 계산된 점수)
  const getTotalScore = (item) => {
    // localStorage에 저장된 total 값이 있으면 사용 (이미 0~40점으로 계산됨)
    if (item.total !== undefined && item.total >= 0) {
      return item.total;
    }
    
    // fallback: scoreAD~D는 0~4점 범위이므로 2배로 계산하여 0~40점으로 변환
    const sAD = Number(item.scoreAD) * 2;
    const sAI = Number(item.scoreAI) * 2;
    const sB = Number(item.scoreB) * 2;
    const sC = Number(item.scoreC) * 2;
    const sD = Number(item.scoreD) * 2;
    
    return sAD + sAI + sB + sC + sD;
  };

  const getLowestCategoryIndex = (item) => {
    const scores = [item.scoreAD, item.scoreAI, item.scoreB, item.scoreC, item.scoreD];
    const minScore = Math.min(...scores);
    return scores.indexOf(minScore);
  };

  const getIsPassed = (totalScore) => {
    return totalScore >= 28;
  };

  // ResultExam.jsx와 동일한 평가 메시지
  const okOpinion = "당신은 모든 영역(직접화행, 간접화행, 질문화행, 단언화행, 의례화화행)에 좋은 점수를 얻었습니다. 현재는 인지기능 정상입니다.\n하지만 유지하기 위해서 꾸준한 학습과 교육을 통한 관리가 필요합니다.";

  const opinions_result = [
    "당신은 직접화행의 점수가 낮습니다.\n기본적인 대화의 문장인식 즉 문장에 내포된 의미에 대한 이해력이 부족하고 동화에 있는 인물들이 나누는 대화들에 대한 인지능력이 조금 부족해 보입니다.\n선생님과의 프로그램을 통한 동화 인물들에 대한 학습으로 점수를 올릴 수 있습니다.",
    "당신은 간접화행의 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 대화에 대한 이해력이 부족하고 동화책 내용의 간접적 질문에 대한 듣기의 인지능력이 조금 부족해보입니다.\n선생님과의 프로그램을 통한 대화 응용능력 학습으로 점수를 올릴 수 있습니다.",
    "당신은 질문화행 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 인물들이 대화에서 주고 받는 정보에 대한 판단에 대한 인지능력이 부족해보입니다.\n선생님과의 프로그램을 통한 대화정보파악학습으로 점수를 올릴수 있습니다.",
    "당신은 단언화행의 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 동화에서 대화하는 인물들의 말에 대한 의도파악과 관련하여 인지능력이 부족해보입니다.\n선생님과의 프로그램을 통해 인물대사 의도파악학습으로 점수를 올릴 수 있습니다.",
    "당신은 의례화화행 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 동화에서 인물들이 상황에 맞는 자신의 감정을 표현하는 말에 대한 인지능력이 부족해보입니다.\n선생님과의 프로그램을 통해  인물들의 상황 및 정서 파악 학습으로 점수를 올릴 수 있습니다.",
  ];

  const opinions_guide = [
    "A-요구(직접)가 부족합니다.",
    "A-요구(간접)가 부족합니다.",
    "B-질문이 부족합니다.",
    "C-단언이 부족합니다.",
    "D-의례화가 부족합니다.",
  ];



  return (
    <div className="content">
      {/* 일정 너비 이상일 때만 배경 표시 */}
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
           동화 화행검사 결과 이력
         </h2>

        {bookData.length > 0 ? (
          <div style={{ display: "flex", flexDirection: "column", gap: "15px" }}>
            {bookData.map((item) => {
              const isExpanded = expandedItems.has(item.id);
              
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
                                     {/* 헤더 - 날짜, 시각, 동화제목, 점수, 토글 버튼 */}
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
                       flexDirection: "column",
                       gap: "5px"
                     }}>
                       <span style={{ 
                         fontSize: "18px", 
                         color: "#333",
                         fontFamily: "GmarketSans"
                       }}>
                         {item.date} {item.time}
                       </span>
                       <span style={{ 
                         fontSize: "14px", 
                         color: "#666",
                         fontFamily: "GmarketSans"
                       }}>
                         {item.fairyTale}
                       </span>
                     </div>
                     <div style={{ 
                       display: "flex", 
                       alignItems: "center", 
                       gap: "15px" 
                     }}>
                       <span
                         style={{
                           fontSize: "18px",
                           fontWeight: "bold",
                           color: getScoreColor(getTotalScore(item), 40),
                           fontFamily: "GmarketSans"
                         }}
                       >
                                                   {`${getTotalScore(item)}/40점`}
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
                       {/* 화행검사 결과화면 헤더 */}
                       <div style={{
                         background: "#374151",
                         color: "#fff",
                         padding: "12px 20px",
                         borderRadius: "8px",
                         marginBottom: "20px",
                         textAlign: "center",
                         fontSize: "16px",
                         fontWeight: "600"
                       }}>
                         화행검사 결과화면
                       </div>

                       {/* 총점 섹션 */}
                       <div style={{ marginBottom: "20px" }}>
                         <div style={{
                           fontSize: "16px",
                           fontWeight: "600",
                           color: "#000",
                           marginBottom: "10px",
                           fontFamily: "GmarketSans"
                         }}>
                           총점
                         </div>
                         <div style={{
                           background: "#fff",
                           padding: "20px 0",
                           borderRadius: "10px",
                           textAlign: "center",
                           border: "1px solid #e0e0e0",
                           boxShadow: "0 2px 4px rgba(0,0,0,0.1)"
                         }}>
                           <span style={{
                             fontSize: "18px",
                             fontWeight: "bold",
                             color: "#333"
                           }}>
                             {getTotalScore(item)} / 40
                           </span>
                         </div>
                       </div>

                       {/* 인지능력 섹션 */}
                       <div style={{ marginBottom: "20px" }}>
                         <div style={{
                           fontSize: "16px",
                           fontWeight: "600",
                           color: "#000",
                           marginBottom: "10px",
                           fontFamily: "GmarketSans"
                         }}>
                           인지능력
                         </div>
                         <div style={{
                           background: "#fff",
                           padding: "20px 0",
                           borderRadius: "10px",
                           textAlign: "center",
                           border: "1px solid #e0e0e0",
                           boxShadow: "0 2px 4px rgba(0,0,0,0.1)"
                         }}>
                           <img
                             src={getIsPassed(getTotalScore(item)) ? "/drawable/speech_clear.png" : "/drawable/speech_fail.png"}
                             style={{ 
                               width: "15%",
                               maxWidth: "60px"
                             }}
                             alt="인지능력 상태"
                           />
                         </div>
                       </div>

                       {/* 검사 결과 평가 섹션 */}
                       <div style={{ marginBottom: "20px" }}>
                         <div style={{
                           fontSize: "16px",
                           fontWeight: "600",
                           color: "#000",
                           marginBottom: "10px",
                           fontFamily: "GmarketSans"
                         }}>
                           검사 결과 평가
                         </div>
                         <div style={{
                           background: "#fff",
                           padding: "20px",
                           borderRadius: "10px",
                           border: "1px solid #e0e0e0",
                           boxShadow: "0 2px 4px rgba(0,0,0,0.1)"
                         }}>
                           <div style={{ lineHeight: "1.6" }}>
                             <p style={{
                               fontSize: "14px",
                               color: "#000",
                               margin: "0 0 15px 0",
                               fontFamily: "GmarketSans",
                               whiteSpace: "pre-line"
                             }}>
                               {getIsPassed(getTotalScore(item)) ? okOpinion : opinions_result[getLowestCategoryIndex(item)]}
                             </p>
                             {!getIsPassed(getTotalScore(item)) && (
                               <p style={{
                                 fontSize: "14px",
                                 fontWeight: "600",
                                 color: "#F44336",
                                 margin: "0",
                                 fontFamily: "GmarketSans"
                               }}>
                                 {opinions_guide[getLowestCategoryIndex(item)]}
                               </p>
                             )}
                           </div>
                         </div>
                       </div>
                     </div>
                   )}
                </div>
              );
            })}
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

export default BookHistory;
