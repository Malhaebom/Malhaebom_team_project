import React, { useEffect, useState } from "react";
import Background from "../Background/Background";
import Pagination from "../../components/Pagination.jsx";
import ScoreCircle from "../../components/ScoreCircle.jsx";
import API, { ensureUserKey } from "../../lib/api";

const TITLE = "인지 능력 검사";

// 카테고리별 만점(합계 40)
const CAT_MAX = {
  "반응 시간": 4,
  "반복어 비율": 4,
  "평균 문장 길이": 4,
  "화행 적절성": 12,
  "회상어 점수": 8,
  "문법 완성도": 8,
};

const itemsPerPage = 5;

const InterviewHistory = () => {
  const [config, setConfig] = useState(null);
  const [interviews, setInterviews] = useState([]);
  const [expandedCards, setExpandedCards] = useState(new Set());
  const [expandedCategories, setExpandedCategories] = useState(new Set());
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  const [currentPage, setCurrentPage] = useState(1);
  const [loading, setLoading] = useState(true);

  // 공통 유틸
  const formatDate = (isoString) => {
    if (!isoString) return "";
    const d = new Date(isoString);
    const p = (n) => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
  };

  // 서버에서 온 byCategory({correct,total}) → UI(details: {score,total})로 환산
  const byCategoryToDetails = (by = {}) => {
    const out = {};
    for (const [k, v] of Object.entries(by)) {
      const max = CAT_MAX[k] ?? 4;
      const corr = Number(v?.correct || 0);
      const tot = Math.max(1, Number(v?.total || 100)); // 서버 기본 100일 수 있음
      const ratio = Math.max(0, Math.min(1, corr / tot));
      const score = Math.round(ratio * max);
      out[k] = { score, total: max };
    }
    return out;
  };

  // 카드 열고 닫기
  const toggleCard = (id) => {
    const next = new Set(expandedCards);
    next.has(id) ? next.delete(id) : next.add(id);
    setExpandedCards(next);
  };
  const toggleCategory = (category) => {
    const next = new Set(expandedCategories);
    next.has(category) ? next.delete(category) : next.add(category);
    setExpandedCategories(next);
  };

  // 반응형
  useEffect(() => {
    const onResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);

  // 설정 JSON (평가 문구/색상)
  useEffect(() => {
    fetch("/autobiography/interviewResult.json")
      .then((r) => r.json())
      .then(setConfig)
      .catch((e) => console.error("Failed to load config:", e));
  }, []);

  // DB에서 히스토리 불러오기 (user_key 기준)
  useEffect(() => {
    (async () => {
      try {
        setLoading(true);
        const userKey = await ensureUserKey({ retries: 2, delayMs: 150 });
        const headers = userKey ? { "x-user-key": userKey } : undefined;

        const { data } = await API.get("/ir/attempt/list", {
          headers,
          params: { limit: 100 },
        });

        const rows = Array.isArray(data?.list) ? data.list : [];

        // 제목이 정확히 "인지 능력 검사"인 것만 사용
        const mine = rows.filter((r) => String(r?.title || "").trim() === TITLE);

        // 서버 응답을 화면 포맷으로 변환
        const mapped = mine.map((row, idx) => {
          const details = byCategoryToDetails(row.byCategory || {});
          const totals = Object.values(details);
          const score = totals.reduce((a, b) => a + (b?.score || 0), 0);
          const total = totals.reduce((a, b) => a + (b?.total || 0), 0) || 40;

          return {
            id: row.id || `${row.attemptTime || ""}-${idx}`,
            date: row.attemptTime || row.clientKst || row.createdAt, // ISO 우선
            score,
            total,
            details,
            order: row.serverAttemptOrderAsc ?? row.serverAttemptOrder ?? row.clientAttemptOrder ?? row.clientRound ?? (idx + 1),
          };
        });

        setInterviews(mapped);
      } catch (e) {
        console.error("[InterviewHistory] fetch error:", e);
        setInterviews([]);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  if (!config || loading) return <div className="content"><div style={{ textAlign: "center", padding: "80px 0" }}>Loading...</div></div>;
  if (interviews.length === 0) return <div className="content"><div style={{ textAlign: "center", padding: "80px 0" }}>아직 검사 이력이 없습니다.</div></div>;

  const getScoreColor = (score, total) => {
    const pct = (Number(score) / Math.max(1, Number(total))) * 100;
    const m = config.scoreColors?.find((e) => pct >= e.minPercentage);
    return m ? m.color : "#666";
  };
  const getStatusFromScore = (score, total) => {
    const pct = (Number(score) / Math.max(1, Number(total))) * 100;
    const m = config.statusBadges?.find((e) => pct >= e.minPercentage);
    return m ? m.status : "";
  };
  const getStatusColor = (status) => {
    const m = config.statusBadges?.find((e) => e.status === status);
    return m ? m.color : "#666";
  };
  const getOverallEvaluation = (score, total) => {
    const ratio = Number(score) / Math.max(1, Number(total));
    const m = config.overallEvaluation?.find((e) => ratio >= e.minRatio);
    return m ? m.message : "";
  };

  const startIndex = (currentPage - 1) * itemsPerPage;
  const currentInterviews = interviews.slice(startIndex, startIndex + itemsPerPage);

  return (
    <div className="content">
      {windowWidth > 1100 && <Background />}
      <div className="wrap" style={{ maxWidth: 520, margin: "0 auto", padding: "80px 20px", fontFamily: "Pretendard-Regular" }}>
        <h2 style={{ textAlign: "center", marginBottom: 30, fontFamily: "ONE-Mobile-Title", fontSize: 32 }}>
          인지능력검사 히스토리
        </h2>

        {currentInterviews.map((result) => {
          const isCardExpanded = expandedCards.has(result.id);
          return (
            <div key={result.id} style={{ background: "#fff", borderRadius: 15, boxShadow: "0 4px 12px rgba(0,0,0,0.1)", overflow: "hidden", marginBottom: 20 }}>
              {/* 카드 헤더 */}
              <div
                onClick={() => toggleCard(result.id)}
                style={{ padding: 20, display: "flex", justifyContent: "space-between", borderBottom: "1px solid #eee", cursor: "pointer" }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                  <span style={{ fontWeight: 600 }}>{formatDate(result.date)}</span>
                  <span
                    style={{
                      fontSize: 16,
                      padding: "4px 8px",
                      borderRadius: 12,
                      background: "#EEF2FF",
                      color: "#4338CA",
                      fontWeight: 700,
                    }}
                  >
                    {result.order}회차
                  </span>
                </div>
                {/* 점수/토글 */}
                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                  <span style={{ fontWeight: "bold", color: getScoreColor(result.score, result.total) }}>
                    {result.score}/{result.total}점
                  </span>
                  <span style={{ fontSize: 16, color: "#666", transition: "transform 0.3s ease", transform: isCardExpanded ? "rotate(180deg)" : "rotate(0deg)" }}>▼</span>
                </div>
              </div>

              {/* 카드 확장 */}
              {isCardExpanded && (
                <div style={{ padding: 20, background: "#f8f9fa" }}>
                  {/* 전체 평가 */}
                  <div style={{ padding: 12, background: "#fff", borderRadius: 8, border: "1px solid #e0e0e0", marginBottom: 15, whiteSpace: "pre-line" }}>
                    {getOverallEvaluation(result.score, result.total)}
                  </div>

                  {/* 원형 점수 */}
                  <div style={{ display: "flex", justifyContent: "center", margin: "20px 0" }}>
                    <ScoreCircle score={result.score} total={result.total} size={120} />
                  </div>

                  {/* 세부 항목 */}
                  {Object.entries(result.details).map(([category, detail]) => {
                    const status = getStatusFromScore(detail.score, detail.total);
                    const isExpanded = expandedCategories.has(category);
                    return (
                      <div key={category} style={{ background: "#fff", borderRadius: 8, border: "1px solid #e0e0e0", marginBottom: 12 }}>
                        <div
                          onClick={(e) => { e.stopPropagation(); toggleCategory(category); }}
                          style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: 12, cursor: "pointer" }}
                        >
                          <span style={{ fontWeight: 600 }}>{category}</span>
                          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                            <span style={{ fontWeight: "bold", color: getScoreColor(detail.score, detail.total) }}>
                              {detail.score}/{detail.total}
                            </span>
                            <span
                              style={{
                                fontSize: 12,
                                padding: "4px 8px",
                                borderRadius: 12,
                                background: getStatusColor(status) + "20",
                                color: getStatusColor(status),
                                fontWeight: 600,
                              }}
                            >
                              {status}
                            </span>
                            <span style={{ fontSize: 16, color: "#666", transition: "transform 0.3s ease", transform: isExpanded ? "rotate(180deg)" : "rotate(0deg)" }}>
                              ▼
                            </span>
                          </div>
                        </div>
                        {isExpanded && (
                          <div style={{ padding: 12, borderTop: "1px solid #e0e0e0", background: "#fafafa", whiteSpace: "pre-line", fontSize: 14, color: "#6B7280" }}>
                            {config.evaluationCriteria?.[category]}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          );
        })}

        {/* 페이징 */}
        {interviews.length > itemsPerPage && (
          <div style={{ marginTop: "auto", paddingTop: 20, border: "1px solid #ffffff", borderRadius: 8, padding: 20, backgroundColor: "transparent" }}>
            <Pagination
              currentPage={currentPage}
              totalPages={Math.ceil(interviews.length / itemsPerPage)}
              onPageChange={setCurrentPage}
              itemsPerPage={itemsPerPage}
            />
          </div>
        )}
      </div>
    </div>
  );
};

export default InterviewHistory;
