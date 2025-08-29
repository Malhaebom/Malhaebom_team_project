// src/pages/Background/Background.jsx
import React from "react";
import Logo from "../../components/Logo.jsx";

const Background = () => {
  return (
    <div className="background">
      <div className="logo_bg">
        <Logo src="/img/logo-bg.png" alt="로고" />
        <p>
          말로 피어나는 추억의 꽃,<br />
          <strong>말해봄과 함께하세요.</strong>
        </p>
      </div>
      <div className="character">
        <img src="/img/Character-bg.png" alt="캐릭터" />
      </div>
    </div>
  );
};

export default Background;
