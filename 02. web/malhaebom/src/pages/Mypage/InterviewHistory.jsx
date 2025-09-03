import React, { useEffect, useState } from "react";
import Background from "../Background/Background";
import Pagination from "../../components/Pagination.jsx";
import ScoreCircle from "../../components/ScoreCircle.jsx";

const InterviewHistory = () => {
  const [config, setConfig] = useState(null);
  const [interviews, setInterviews] = useState([]);
  const [expandedCards, setExpandedCards] = useState(new Set());
  const [expandedCategories, setExpandedCategories] = useState(new Set());
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  const [currentPage, setCurrentPage] = useState(1);

  const itemsPerPage = 5;

  // JSON fetch
  useEffect(() => {
    fetch("/autobiography/interviewResult.json")
      .then((res) => res.json())
      .then((data) => setConfig(data))
      .catch((err) => console.error("Failed to load config:", err));

    // 6개 더미 데이터
    const dummyData = [
      { id: 1, date: "2025-09-03T10:00:00", score: 35, total: 40, details: { "반응 시간": { score: 4, total: 4 }, "반복어 비율": { score: 3, total: 4 }, "평균 문장 길이": { score: 2, total: 4 }, "화행 적절성": { score: 12, total: 12 }, "회상어 점수": { score: 6, total: 8 }, "문법 완성도": { score: 8, total: 8 } } },
      { id: 2, date: "2025-09-02T14:30:00", score: 28, total: 40, details: { "반응 시간": { score: 3, total: 4 }, "반복어 비율": { score: 2, total: 4 }, "평균 문장 길이": { score: 3, total: 4 }, "화행 적절성": { score: 6, total: 12 }, "회상어 점수": { score: 4, total: 8 }, "문법 완성도": { score: 4, total: 8 } } },
      { id: 3, date: "2025-09-01T09:15:00", score: 30, total: 40, details: { "반응 시간": { score: 4, total: 4 }, "반복어 비율": { score: 3, total: 4 }, "평균 문장 길이": { score: 3, total: 4 }, "화행 적절성": { score: 8, total: 12 }, "회상어 점수": { score: 6, total: 8 }, "문법 완성도": { score: 6, total: 8 } } },
      { id: 4, date: "2025-08-30T16:45:00", score: 25, total: 40, details: { "반응 시간": { score: 3, total: 4 }, "반복어 비율": { score: 2, total: 4 }, "평균 문장 길이": { score: 2, total: 4 }, "화행 적절성": { score: 6, total: 12 }, "회상어 점수": { score: 4, total: 8 }, "문법 완성도": { score: 4, total: 8 } } },
      { id: 5, date: "2025-08-28T11:20:00", score: 32, total: 40, details: { "반응 시간": { score: 4, total: 4 }, "반복어 비율": { score: 3, total: 4 }, "평균 문장 길이": { score: 3, total: 4 }, "화행 적절성": { score: 10, total: 12 }, "회상어 점수": { score: 6, total: 8 }, "문법 완성도": { score: 6, total: 8 } } },
      { id: 6, date: "2025-08-25T14:50:00", score: 27, total: 40, details: { "반응 시간": { score: 3, total: 4 }, "반복어 비율": { score: 2, total: 4 }, "평균 문장 길이": { score: 3, total: 4 }, "화행 적절성": { score: 6, total: 12 }, "회상어 점수": { score: 4, total: 8 }, "문법 완성도": { score: 4, total: 8 } } },
    ];
    setInterviews(dummyData);
  }, []);

  // 반응형
  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  if (!config || interviews.length === 0) return <div>Loading...</div>;

  const toggleCard = (id) => {
    const newExpanded = new Set(expandedCards);
    newExpanded.has(id) ? newExpanded.delete(id) : newExpanded.add(id);
    setExpandedCards(newExpanded);
  };

  const toggleCategory = (category) => {
    const newExpanded = new Set(expandedCategories);
    newExpanded.has(category) ? newExpanded.delete(category) : newExpanded.add(category);
    setExpandedCategories(newExpanded);
  };

  const getScoreColor = (score, total) => {
    const percentage = (score / total) * 100;
    const matched = config.scoreColors?.find((e) => percentage >= e.minPercentage);
    return matched ? matched.color : "#666";
  };

  const getStatusFromScore = (score, total) => {
    const percentage = (score / total) * 100;
    const matched = config.statusBadges?.find((e) => percentage >= e.minPercentage);
    return matched ? matched.status : "";
  };

  const getStatusColor = (status) => {
    const matched = config.statusBadges?.find((e) => e.status === status);
    return matched ? matched.color : "#666";
  };

  const getOverallEvaluation = (score, total) => {
    const ratio = score / total;
    const matched = config.overallEvaluation?.find((e) => ratio >= e.minRatio);
    return matched ? matched.message : "";
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
  };

  const startIndex = (currentPage - 1) * itemsPerPage;
  const currentInterviews = interviews.slice(startIndex, startIndex + itemsPerPage);

  return (
    <div className="content">
      {windowWidth > 1100 && <Background />}
      <div className="wrap" style={{ maxWidth: '520px', margin: '0 auto', padding: '80px 20px', fontFamily: 'Pretendard-Regular' }}>
        <h2 style={{ textAlign: 'center', marginBottom: '30px', fontFamily: 'ONE-Mobile-Title', fontSize: '32px' }}>인지능력검사 히스토리</h2>

        {currentInterviews.map((result) => {
          const isCardExpanded = expandedCards.has(result.id);
          return (
            <div key={result.id} style={{ background: '#fff', borderRadius: '15px', boxShadow: '0 4px 12px rgba(0,0,0,0.1)', overflow: 'hidden', marginBottom: '20px' }}>
              
              {/* 카드 헤더 */}
              <div onClick={() => toggleCard(result.id)} style={{ padding: '20px', display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid #eee', cursor: 'pointer' }}>
                <span style={{ fontWeight: '600' }}>{formatDate(result.date)}</span>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <span style={{ fontWeight: 'bold', color: getScoreColor(result.score, result.total) }}>{result.score}/{result.total}점</span>
                  <span style={{ fontSize: '16px', color: '#666', transition: 'transform 0.3s ease', transform: isCardExpanded ? 'rotate(180deg)' : 'rotate(0deg)' }}>▼</span>
                </div>
              </div>

              {/* 카드 확장 내용 */}
              {isCardExpanded &&
                <div style={{ padding: '20px', background: '#f8f9fa' }}>

                  {/* 전체 평가 메시지 */}
                  <div style={{ padding: '12px', background: '#fff', borderRadius: '8px', border: '1px solid #e0e0e0', marginBottom: '15px', whiteSpace: 'pre-line' }}>
                    {getOverallEvaluation(result.score, result.total)}
                  </div>

                  {/* ScoreCircle */}
                  <div style={{ display: 'flex', justifyContent: 'center', margin: '20px 0' }}>
                    <ScoreCircle score={result.score} total={result.total} size={120} />
                  </div>

                  {/* 세부 항목 */}
                  {Object.entries(result.details).map(([category, detail]) => {
                    const status = getStatusFromScore(detail.score, detail.total);
                    const isExpanded = expandedCategories.has(category);

                    return (
                      <div key={category} style={{ background: '#fff', borderRadius: '8px', border: '1px solid #e0e0e0', marginBottom: '12px' }}>
                        <div onClick={(e) => { e.stopPropagation(); toggleCategory(category); }} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px', cursor: 'pointer' }}>
                          <span style={{ fontWeight: '600' }}>{category}</span>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                            <span style={{ fontWeight: 'bold', color: getScoreColor(detail.score, detail.total) }}>{detail.score}/{detail.total}</span>
                            <span style={{ fontSize: '12px', padding: '4px 8px', borderRadius: '12px', background: getStatusColor(status) + '20', color: getStatusColor(status), fontWeight: '600' }}>{status}</span>
                            <span style={{ fontSize: '16px', color: '#666', transition: 'transform 0.3s ease', transform: isExpanded ? 'rotate(180deg)' : 'rotate(0deg)' }}>▼</span>
                          </div>
                        </div>
                        {isExpanded &&
                          <div style={{ padding: '12px', borderTop: '1px solid #e0e0e0', background: '#fafafa', whiteSpace: 'pre-line', fontSize: '12px', color: '#6B7280' }}>
                            {config.evaluationCriteria[category]}
                          </div>
                        }
                      </div>
                    );
                  })}
                </div>
              }
            </div>
          )
        })}

        {/* 페이징 */}
        {interviews.length > itemsPerPage &&
          <div style={{ marginTop: "auto", paddingTop: "20px", border: "1px solid #ffffff", borderRadius: "8px", padding: "20px", backgroundColor: "transparent" }}>
            <Pagination
              currentPage={currentPage}
              totalPages={Math.ceil(interviews.length / itemsPerPage)}
              onPageChange={setCurrentPage}
              itemsPerPage={itemsPerPage}
            />
          </div>
        }
      </div>
    </div>
  );
};

export default InterviewHistory;
