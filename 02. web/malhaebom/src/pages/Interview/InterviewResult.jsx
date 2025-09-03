import React, { useEffect, useState } from "react";
import Background from "../Background/Background";
import { useMicrophone } from "../../MicrophoneContext.jsx";
import ScoreCircle from "../../components/ScoreCircle.jsx";

const InterviewResult = ({ result }) => {
  const { isMicrophoneActive, stopMicrophone } = useMicrophone();
  const [expandedCategories, setExpandedCategories] = useState(new Set());
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  const [config, setConfig] = useState(null);

  // JSON fetch
  useEffect(() => {
    fetch("/autobiography/interviewResult.json")
      .then((res) => res.json())
      .then((data) => setConfig(data))
      .catch((err) => console.error("Failed to load config:", err));
  }, []);

  // 반응형
  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  // 페이지 진입 시 마이크 끄기
  useEffect(() => {
    if (isMicrophoneActive) stopMicrophone();
  }, [isMicrophoneActive, stopMicrophone]);

  if (!config) return <div>Loading...</div>;

  // 카테고리 토글
  const toggleCategory = (category) => {
    const newExpanded = new Set(expandedCategories);
    if (newExpanded.has(category)) newExpanded.delete(category);
    else newExpanded.add(category);
    setExpandedCategories(newExpanded);
  };

  const getOverallEvaluation = (score, total) => {
    const ratio = score / total;
    const matched = config.overallEvaluation.find((e) => ratio >= e.minRatio);
    return matched ? matched.message : "";
  };

  const getScoreColor = (score, total) => {
    const percentage = (score / total) * 100;
    const matched = config.scoreColors.find((e) => percentage >= e.minPercentage);
    return matched ? matched.color : "#666";
  };

  const getStatusFromScore = (score, total) => {
    const percentage = (score / total) * 100;
    const matched = config.statusBadges.find((e) => percentage >= e.minPercentage);
    return matched ? matched.status : "";
  };

  const getStatusColor = (status) => {
    const matched = config.statusBadges.find((e) => e.status === status);
    return matched ? matched.color : "#666";
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(
      2,
      "0"
    )}-${String(date.getDate()).padStart(2, "0")} ${String(
      date.getHours()
    ).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
  };

  return (
    <div className="content">
      {windowWidth > 1100 && <Background />}
      <div
        className="wrap"
        style={{ maxWidth: "520px", margin: "0 auto", padding: "80px 20px", fontFamily: "Pretendard-Regular" }}
      >
        <h2 style={{ textAlign: "center", marginBottom: "30px", fontFamily: "ONE-Mobile-Title", fontSize: "32px" }}>
          인지능력검사 결과
        </h2>

        <div style={{ background: "#fff", borderRadius: "12px", boxShadow: "0 4px 12px rgba(0,0,0,0.1)", overflow: "hidden" }}>
          <div style={{ padding: "20px", display: "flex", justifyContent: "space-between", borderBottom: "1px solid #eee" }}>
            <span style={{ fontWeight: "600" }}>{formatDate(result.date)}</span>
            <span style={{ fontWeight: "bold", color: getScoreColor(result.score, result.total) }}>
              {result.score}/{result.total}점
            </span>
          </div>

          <div style={{ padding: "20px", background: "#f8f9fa" }}>
            <div style={{ padding: "12px", background: "#fff", borderRadius: "8px", border: "1px solid #e0e0e0", marginBottom: "15px", whiteSpace: "pre-line" }}>
              {getOverallEvaluation(result.score, result.total)}
            </div>

            <div style={{ display: "flex", justifyContent: "center", margin: "20px 0" }}>
              <ScoreCircle score={result.score} total={result.total} size={120} />
            </div>

            {Object.entries(result.details).map(([category, detail]) => {
              const status = getStatusFromScore(detail.score, detail.total);
              const isExpanded = expandedCategories.has(category);

              return (
                <div key={category} style={{ background: "#fff", borderRadius: "8px", border: "1px solid #e0e0e0", marginBottom: "12px" }}>
                  <div onClick={() => toggleCategory(category)} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "12px", cursor: "pointer" }}>
                    <span style={{ fontWeight: "600" }}>{category}</span>
                    <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                      <span style={{ fontWeight: "bold", color: getScoreColor(detail.score, detail.total) }}>
                        {detail.score}/{detail.total}
                      </span>
                      <span style={{ fontSize: "12px", padding: "4px 8px", borderRadius: "12px", background: getStatusColor(status) + "20", color: getStatusColor(status), fontWeight: "600" }}>
                        {status}
                      </span>
                      <span style={{ fontSize: "16px", color: "#666", transition: "transform 0.3s ease", transform: isExpanded ? "rotate(180deg)" : "rotate(0deg)" }}>
                        ▼
                      </span>
                    </div>
                  </div>
                  {isExpanded && (
                    <div style={{ padding: "12px", borderTop: "1px solid #e0e0e0", background: "#fafafa", whiteSpace: "pre-line", fontSize: "12px", color: "#6B7280" }}>
                      {config.evaluationCriteria[category]}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
};

export default InterviewResult;
