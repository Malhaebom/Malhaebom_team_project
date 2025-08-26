import React from "react";

const History = () => {
  // 임시 더미 데이터
  const historyData = [
    { id: 1, date: "2025-08-01", score: 85 },
    { id: 2, date: "2025-08-10", score: 90 },
    { id: 3, date: "2025-08-20", score: 88 },
  ];

  // 점수에 따른 색상
  const getScoreColor = (score) => {
    if (score >= 90) return "#4CAF50"; // 초록
    if (score >= 80) return "#FFC107"; // 노랑
    return "#F44336"; // 빨강
  };

  return (
    <div
      style={{
        maxWidth: "520px",
        margin: "0 auto",
        padding: "80px 20px",
        fontFamily: "Pretendard-Regular",
      }}
    >
      <h2
        style={{
          textAlign: "center",
          marginBottom: "30px",
          fontFamily: "ONE-Mobile-Title",
          fontSize: "32px",
        }}
      >
        이력 관리
      </h2>

      {historyData.length > 0 ? (
        <div style={{ display: "flex", flexDirection: "column", gap: "15px" }}>
          {historyData.map((item) => (
            <div
              key={item.id}
              style={{
                background: "#fff",
                borderRadius: "12px",
                padding: "20px",
                boxShadow: "0 4px 12px rgba(0,0,0,0.1)",
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                transition: "transform 0.2s",
                cursor: "pointer",
              }}
              onMouseEnter={(e) => (e.currentTarget.style.transform = "scale(1.02)")}
              onMouseLeave={(e) => (e.currentTarget.style.transform = "scale(1)")}
            >
              <span style={{ fontSize: "18px", color: "#333" }}>{item.date}</span>
              <span
                style={{
                  fontSize: "18px",
                  fontWeight: "bold",
                  color: getScoreColor(item.score),
                }}
              >
                {item.score}점
              </span>
            </div>
          ))}
        </div>
      ) : (
        <p style={{ textAlign: "center", color: "#888", fontSize: "16px" }}>
          아직 검사 이력이 없습니다.
        </p>
      )}
    </div>
  );
};

export default History;
