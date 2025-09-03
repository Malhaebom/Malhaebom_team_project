import React, { useEffect, useState } from "react";
import Background from "../Background/Background";
import ScoreCircle from "../../components/ScoreCircle.jsx";

const InterviewResult = () => {
  const [interviewData, setInterviewData] = useState([]);
  const [expandedCategories, setExpandedCategories] = useState(new Set());
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  const [config, setConfig] = useState(null); // JSON config

  // 브라우저 창 크기 감지
  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  // localStorage에서 데이터 불러오기
  useEffect(() => {
    const savedData = JSON.parse(localStorage.getItem("interviewHistoryData") || "[]");
    setInterviewData(savedData);
    setExpandedCategories(new Set());
  }, []);

  // JSON config 불러오기
  useEffect(() => {
    fetch("/autobiography/interviewResult.json")
      .then((res) => res.json())
      .then((data) => setConfig(data))
      .catch((err) => console.error("Failed to load config:", err));
  }, []);

  const toggleCategory = (category) => {
    const newExpanded = new Set(expandedCategories);
    if (newExpanded.has(category)) newExpanded.delete(category);
    else newExpanded.add(category);
    setExpandedCategories(newExpanded);
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")} ${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
  };

  if (interviewData.length === 0 || !config) {
    return (
      <div className="content">
        <p style={{ textAlign: "center", color: "#888", fontSize: "16px", marginTop: "100px" }}>
          아직 검사 이력이 없습니다.
        </p>
      </div>
    );
  }

  const item = interviewData[0];

  // JSON 기반 헬퍼 함수
  const getScoreColor = (score, total) => {
    const percentage = (score / total) * 100;
    const matched = config.scoreColors.find(e => percentage >= e.minPercentage);
    return matched ? matched.color : "#666";
  };

  const getStatusFromScore = (score, total) => {
    const percentage = (score / total) * 100;
    const matched = config.statusBadges.find(e => percentage >= e.minPercentage);
    return matched ? matched.status : "";
  };

  const getStatusColor = (status) => {
    const matched = config.statusBadges.find(e => e.status === status);
    return matched ? matched.color : "#666";
  };

  const getOverallEvaluation = (score, total) => {
    const ratio = score / total;
    const matched = config.overallEvaluation.find(e => ratio >= e.minRatio);
    return matched ? matched.message : "";
  };

  return (
    <div className="content">
      {windowWidth > 1100 && <Background />}
      <div className="wrap" style={{ maxWidth: "520px", margin: "0 auto", padding: "80px 20px", fontFamily: "Pretendard-Regular" }}>
        <h2 style={{ textAlign: "center", marginBottom: "30px", fontFamily: "ONE-Mobile-Title", fontSize: "32px" }}>
          인지능력검사 결과
        </h2>

        <div style={{ background: "#fff", borderRadius: "12px", boxShadow: "0 4px 12px rgba(0,0,0,0.1)", overflow: "hidden" }}>
          <div style={{ padding: "16px 20px", display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid #eee" }}>
            <span style={{ fontSize: "16px", color: "#555", fontWeight: "600" }}>{formatDate(item.date)}</span>
            <span style={{ fontSize: "18px", fontWeight: "700", color: getScoreColor(item.score, item.total) }}>
              {item.score}/{item.total}점
            </span>
          </div>

          <div style={{ padding: "20px", background: "#f8f9fa" }}>
            <div style={{ marginBottom: "15px" }}>
              <p style={{ fontSize: "14px", color: "#4B5563", lineHeight: "1.5", margin: 0, whiteSpace: "pre-line" }}>
                {getOverallEvaluation(item.score, item.total)}
              </p>
            </div>

            <div style={{ display: "flex", justifyContent: "center", marginBottom: "20px" }}>
              <ScoreCircle score={item.score} total={item.total} size={120} />
            </div>

            <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
              {Object.entries(item.details).map(([category, detail]) => {
                const status = getStatusFromScore(detail.score, detail.total);
                const isExpanded = expandedCategories.has(category);

                return (
                  <div key={category} style={{ background: "#fff", borderRadius: "8px", border: "1px solid #e0e0e0", overflow: "hidden" }}>
                    <div
                      onClick={() => toggleCategory(category)}
                      style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "12px", cursor: "pointer" }}
                    >
                      <span style={{ fontSize: "16px", fontWeight: "600", color: "#333" }}>{category}</span>
                      <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                        <span style={{ fontSize: "14px", fontWeight: "bold", color: getScoreColor(detail.score, detail.total) }}>
                          {detail.score}/{detail.total}
                        </span>
                        <span style={{ fontSize: "12px", padding: "4px 8px", borderRadius: "12px", background: getStatusColor(status) + "20", color: getStatusColor(status), fontWeight: "600" }}>
                          {status}
                        </span>
                        <span style={{ fontSize: "16px", color: "#666", transform: isExpanded ? "rotate(180deg)" : "rotate(0deg)" }}>▼</span>
                      </div>
                    </div>

                    {isExpanded && (
                      <div style={{ padding: "12px", borderTop: "1px solid #e0e0e0", background: "#fafafa" }}>
                        <p style={{ fontSize: "12px", color: "#6B7280", lineHeight: "1.4", margin: 0, whiteSpace: "pre-line" }}>
                          {config.evaluationCriteria[category]}
                        </p>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default InterviewResult;
