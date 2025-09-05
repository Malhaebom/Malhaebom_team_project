import React, { useEffect, useState } from "react";
import Background from "../Background/Background";
import ScoreCircle from "../../components/ScoreCircle.jsx";
import API, { ensureUserKey } from "../../lib/api";

const TITLE = "인지 능력 검사";
const CAT_MAX = {
  "반응 시간": 4,
  "반복어 비율": 4,
  "평균 문장 길이": 4,
  "화행 적절성": 12,
  "회상어 점수": 8,
  "문법 완성도": 8,
};

const InterviewResult = () => {
  const [item, setItem] = useState(null);
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  const [config, setConfig] = useState(null);
  const [loading, setLoading] = useState(true);
  // ✅ 세부 항목 토글 상태
  const [expandedCategories, setExpandedCategories] = useState(new Set());

  const toggleCategory = (category) => {
    const next = new Set(expandedCategories);
    next.has(category) ? next.delete(category) : next.add(category);
    setExpandedCategories(next);
  };

  const formatDate = (isoString) => {
    if (!isoString) return "";
    const d = new Date(isoString);
    const p = (n) => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
  };

  const byCategoryToDetails = (by = {}) => {
    const out = {};
    for (const [k, v] of Object.entries(by)) {
      const max = CAT_MAX[k] ?? 4;
      const corr = Number(v?.correct || 0);
      const tot = Math.max(1, Number(v?.total || 100));
      const ratio = Math.max(0, Math.min(1, corr / tot));
      const score = Math.round(ratio * max);
      out[k] = { score, total: max };
    }
    return out;
  };

  useEffect(() => {
    const onResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);

  useEffect(() => {
    fetch("/autobiography/interviewResult.json")
      .then((res) => res.json())
      .then(setConfig)
      .catch((err) => console.error("Failed to load config:", err));
  }, []);

  useEffect(() => {
    (async () => {
      try {
        setLoading(true);
        const userKey = await ensureUserKey({ retries: 2, delayMs: 150 });
        const headers = userKey ? { "x-user-key": userKey } : undefined;

        const { data } = await API.get("/ir/latest", {
          headers,
          params: { title: TITLE },
        });

        let latest = data?.ok ? data.latest : null;

        if (!latest) {
          try {
            const arr = JSON.parse(localStorage.getItem("interviewHistoryData") || "[]");
            if (Array.isArray(arr) && arr.length > 0) {
              const recent = arr[0];
              const details = recent?.details || {};
              const totals = Object.values(details);
              const score = totals.reduce((a, b) => a + (b?.score || 0), 0);
              const total = totals.reduce((a, b) => a + (b?.total || 0), 0) || 40;
              setItem({
                date: recent?.date,
                score,
                total,
                details,
                order: 1,
              });
              return;
            }
          } catch (e) {
            console.warn("[InterviewResult] localStorage fallback parse error:", e);
          }
          setItem(null);
          return;
        }

        const details = byCategoryToDetails(latest.byCategory || {});
        const totals = Object.values(details);
        const score = totals.reduce((a, b) => a + (b?.score || 0), 0);
        const total = totals.reduce((a, b) => a + (b?.total || 0), 0) || 40;

        setItem({
          date: latest.attemptTime || latest.clientKst || latest.createdAt,
          score,
          total,
          details,
          // 서버 산출 오름차순 회차 우선 사용
          order:
            latest.serverAttemptOrderAsc ??
            latest.serverAttemptOrder ??
            latest.clientAttemptOrder ??
            latest.clientRound ??
            1,
        });
      } catch (e) {
        console.error("[InterviewResult] fetch error, trying localStorage fallback:", e);
        try {
          const arr = JSON.parse(localStorage.getItem("interviewHistoryData") || "[]");
          if (Array.isArray(arr) && arr.length > 0) {
            const recent = arr[0];
            const details = recent?.details || {};
            const totals = Object.values(details);
            const score = totals.reduce((a, b) => a + (b?.score || 0), 0);
            const total = totals.reduce((a, b) => a + (b?.total || 0), 0) || 40;
            setItem({ date: recent?.date, score, total, details, order: 1 });
          } else {
            setItem(null);
          }
        } catch {
          setItem(null);
        }
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const getScoreColor = (score, total) => {
    if (!config) return "#666";
    const pct = (Number(score) / Math.max(1, Number(total))) * 100;
    const m = config.scoreColors.find((e) => pct >= e.minPercentage);
    return m ? m.color : "#666";
  };
  const getStatusFromScore = (score, total) => {
    if (!config) return "";
    const pct = (Number(score) / Math.max(1, Number(total))) * 100;
    const m = config.statusBadges.find((e) => pct >= e.minPercentage);
    return m ? m.status : "";
  };
  const getStatusColor = (status) => {
    if (!config) return "#666";
    const m = config.statusBadges.find((e) => e.status === status);
    return m ? m.color : "#666";
  };
  const getOverallEvaluation = (score, total) => {
    if (!config) return "";
    const ratio = Number(score) / Math.max(1, Number(total));
    const m = config.overallEvaluation.find((e) => ratio >= e.minRatio);
    return m ? m.message : "";
  };

  if (loading) return <div className="content"><div style={{ textAlign: "center", padding: "80px 0" }}>Loading...</div></div>;
  if (!item || !config)
    return (
      <div className="content">
        <p style={{ textAlign: "center", color: "#888", fontSize: 16, marginTop: 100 }}>
          아직 검사 이력이 없습니다.
        </p>
      </div>
    );

  return (
    <div className="content">
      {windowWidth > 1100 && <Background />}
      <div className="wrap" style={{ maxWidth: 520, margin: "0 auto", padding: "80px 20px", fontFamily: "Pretendard-Regular" }}>
        <h2 style={{ textAlign: "center", marginBottom: 30, fontFamily: "ONE-Mobile-Title", fontSize: 32 }}>
          인지능력검사 결과
        </h2>

        <div style={{ background: "#fff", borderRadius: 12, boxShadow: "0 4px 12px rgba(0,0,0,0.1)", overflow: "hidden" }}>
          {/* 헤더 (날짜 + 회차) */}
          <div style={{ padding: "16px 20px", display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid #eee" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <span style={{ fontSize: 16, color: "#555", fontWeight: 600 }}>{formatDate(item.date)}</span>
              <span
                style={{
                  fontSize: 16,
                  padding: "2px 8px",
                  borderRadius: 12,
                  background: "#EEF2FF",
                  color: "#4338CA",
                  fontWeight: 600,
                }}
              >
                {item.order}회차
              </span>
            </div>
            <span style={{ fontSize: 18, fontWeight: 700, color: getScoreColor(item.score, item.total) }}>
              {item.score}/{item.total}점
            </span>
          </div>

          <div style={{ padding: 20, background: "#f8f9fa" }}>
            {/* 전체 평가 */}
            <div style={{ marginBottom: 15 }}>
              <p style={{ fontSize: 14, color: "#4B5563", lineHeight: 1.5, margin: 0, whiteSpace: "pre-line" }}>
                {getOverallEvaluation(item.score, item.total)}
              </p>
            </div>

            {/* 원형 점수 */}
            <div style={{ display: "flex", justifyContent: "center", marginBottom: 20 }}>
              <ScoreCircle score={item.score} total={item.total} size={120} />
            </div>

            {/* ✅ 세부 항목: 히스토리와 동일하게 토글 + 설명 문구 */}
            <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
              {Object.entries(item.details).map(([category, detail]) => {
                const status = getStatusFromScore(detail.score, detail.total);
                const isExpanded = expandedCategories.has(category);
                return (
                  <div key={category} style={{ background: "#fff", borderRadius: 8, border: "1px solid #e0e0e0", overflow: "hidden" }}>
                    {/* 행 클릭 → 토글 */}
                    <div
                      onClick={() => toggleCategory(category)}
                      style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: 12, cursor: "pointer" }}
                    >
                      <span style={{ fontSize: 16, fontWeight: 600, color: "#333" }}>{category}</span>
                      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                        <span style={{ fontSize: 14, fontWeight: "bold", color: getScoreColor(detail.score, detail.total) }}>
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
                        <span
                          style={{
                            fontSize: 16,
                            color: "#666",
                            transition: "transform 0.3s ease",
                            transform: isExpanded ? "rotate(180deg)" : "rotate(0deg)",
                          }}
                        >
                          ▼
                        </span>
                      </div>
                    </div>

                    {/* 펼친 경우: 기준 문구 */}
                    {isExpanded && (
                      <div style={{ padding: 12, borderTop: "1px solid #e0e0e0", background: "#fafafa", whiteSpace: "pre-line", fontSize: 14, color: "#6B7280" }}>
                        {config.evaluationCriteria?.[category]}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        <div style={{ marginTop: 20, textAlign: "center" }}>
          <button className="question_bt" type="button" onClick={() => (location.href = "/")}>
            홈으로
          </button>
        </div>
      </div>
    </div>
  );
};

export default InterviewResult;
