// src/pages/Interview/ProgressBar.jsx
import React from "react";

export default function ProgressBar({ current, total }) {
  if (!total || total <= 0) return null;

  return (
    <div
      style={{
        width: "100%",        // 부모(.wrap) 폭에 맞춤
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        marginTop: 20,        // 위쪽 여백
      }}
    >
      {/* 현재 질문 번호 */}
      <span
        style={{
          width: 30,
          height: 30,
          borderRadius: "50%",
          border: "2px solid #3f51b5",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          color: "#3f51b5",
          fontWeight: "bold",
        }}
      >
        {current}
      </span>

      {/* 진행 바 */}
      <div
        style={{
          flex: 1,
          height: 8,
          background: "#ccc",
          margin: "0 10px",
          borderRadius: 4,
          position: "relative",
        }}
      >
        <div
          style={{
            width: `${(current / total) * 100}%`,
            height: "100%",
            background: "#3f51b5",
            borderRadius: 4,
            transition: "width 0.3s ease",
          }}
        />
      </div>

      {/* 전체 질문 개수 */}
      <span
        style={{
          width: 30,
          height: 30,
          borderRadius: "50%",
          border: "2px solid #ccc",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          color: "#999",
          fontWeight: "bold",
        }}
      >
        {total}
      </span>
    </div>
  );
}
