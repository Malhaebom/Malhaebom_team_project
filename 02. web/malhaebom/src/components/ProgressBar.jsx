import React from 'react';

const ProgressBar = ({ current, total }) => {
  if (!total || total <= 0) return null;

  const progressPercentage = (current / total) * 100;

  return (
    <div style={{
      display: "flex",
      alignItems: "center",
      gap: "12px",
      padding: "20px",
      marginTop: "20px"
    }}>
      {/* 현재 페이지 원형 배지 */}
      <div style={{
        width: "44px",
        height: "44px",
        borderRadius: "50%",
        backgroundColor: "#344CB7",
        color: "white",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontSize: "18px",
        fontWeight: "900",
        fontFamily: "GmarketSans"
      }}>
        {current}
      </div>

      {/* 진행률 바 */}
      <div style={{
        flex: 1,
        height: "6px",
        backgroundColor: "#E5E7EB",
        borderRadius: "3px",
        position: "relative"
      }}>
        <div style={{
          width: `${progressPercentage}%`,
          height: "100%",
          backgroundColor: "#344CB7",
          borderRadius: "3px",
          transition: "width 0.3s ease"
        }} />
      </div>

      {/* 전체 페이지 원형 배지 */}
      <div style={{
        width: "44px",
        height: "44px",
        borderRadius: "50%",
        backgroundColor: "#DFE3EA",
        color: "#9CA3AF",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontSize: "18px",
        fontWeight: "700",
        fontFamily: "GmarketSans"
      }}>
        {total}
      </div>
    </div>
  );
};

export default ProgressBar;
