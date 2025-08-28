import React from "react";

export default function Header({ title, showBack = true, showHome = true, onBackClick }) {
  const handleBackClick = () => {
    // 마이크 정리 함수가 있으면 먼저 실행
    if (onBackClick) {
      onBackClick();
      // 마이크 정리가 완료될 시간을 주기 위해 약간의 지연
      setTimeout(() => {
        window.history.back();
      }, 100);
    } else {
      // 마이크 정리 함수가 없으면 바로 뒤로가기
      window.history.back();
    }
  };

  return (
    <header>
      <div className="hd_inner">
        <div className="hd_tit" role="alert">
          {title}
        </div>
        {showBack && (
          <div className="hd_left">
            <a onClick={handleBackClick}>
              <i className="xi-angle-left-min"></i>
            </a>
          </div>
        )}
        {showHome && (
          <div className="hd_right">
            <a onClick={() => (location.href = "/")}>
              <i className="xi-home-o"></i>
            </a>
          </div>
        )}
      </div>
    </header>
  );
}
