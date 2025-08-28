import React from "react";

// 즉시 실행되는 테스트 코드
console.log("📄 Header.jsx 파일 로드됨");
alert("Header.jsx 파일이 로드되었습니다!");

export default function Header({ title, showBack = true, showHome = true, onBackClick }) {
  console.log("🏷️ Header 컴포넌트 렌더링:", { title, showBack, showHome, hasOnBackClick: !!onBackClick });
  alert("Header 컴포넌트가 렌더링되었습니다!");
  
  const handleBackClick = () => {
    console.log("⬅️ Header 뒤로가기 버튼 클릭됨");
    alert("Header 뒤로가기 버튼이 클릭되었습니다!");
    if (onBackClick) {
      // 커스텀 뒤로가기 함수가 있으면 호출
      console.log("🔄 커스텀 뒤로가기 함수 호출");
      onBackClick();
    } else {
      // 기본 뒤로가기 동작
      console.log("🔄 기본 뒤로가기 실행");
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
