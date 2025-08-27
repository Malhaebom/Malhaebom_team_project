import React from "react";
import Background from "../Background/Background";

const BookHistory = () => {
  const bookData = [
    { id: 1, date: "2025-08-01", score: 85 },
    { id: 2, date: "2025-08-12", score: 92 },
  ];

  const getScoreColor = (score) => {
    if (score >= 90) return "#4CAF50";
    if (score >= 80) return "#FFC107";
    return "#F44336";
  };

  return (
    <div className="content">
      {/* 공통 배경 */}
      <Background />

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
          동화 화행검사 결과
        </h2>

        {bookData.length > 0 ? (
          <div style={{ display: "flex", flexDirection: "column", gap: "15px" }}>
            {bookData.map((item) => (
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
                }}
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
    </div>
  );
};

export default BookHistory;
