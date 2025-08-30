import React from 'react';

const ScoreCircle = ({ score, total, size = 140 }) => {
  const bigFontSize = size * 0.40;
  const smallFontSize = size * 0.20;
  const borderWidth = size * 0.057; // 8/140 비율

  return (
    <div
      style={{
        width: `${size}px`,
        height: `${size}px`,
        position: 'relative',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      {/* 원형 배경 */}
      <div
        style={{
          width: `${size}px`,
          height: `${size}px`,
          borderRadius: '50%',
          border: `${borderWidth}px solid #EF4444`,
          backgroundColor: 'white',
          position: 'absolute',
          top: 0,
          left: 0,
        }}
      />
      
      {/* 점수 텍스트 */}
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1,
        }}
      >
        <span
          style={{
            fontSize: `${bigFontSize}px`,
            fontWeight: '900',
            color: '#EF4444',
            lineHeight: 1.0,
            fontFamily: 'GmarketSans',
          }}
        >
          {score}
        </span>
        <span
          style={{
            fontSize: `${smallFontSize}px`,
            fontWeight: '800',
            color: '#EF4444',
            lineHeight: 1.0,
            fontFamily: 'GmarketSans',
          }}
        >
          /{total}
        </span>
      </div>
    </div>
  );
};

export default ScoreCircle;
