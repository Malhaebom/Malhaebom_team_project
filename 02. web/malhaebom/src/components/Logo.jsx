import React from "react";
import { useNavigate } from "react-router-dom";

const Logo = ({ src, alt, className, style, children }) => {
  const navigate = useNavigate();
  
  const handleClick = () => {
    navigate('/');
  };

  // children이 있으면 텍스트 로고, 없으면 이미지 로고
  if (children) {
    return (
      <h1 
        className={className}
        style={{ ...style, cursor: 'pointer' }}
        onClick={handleClick}
      >
        {children}
      </h1>
    );
  }

  return (
    <img 
      src={src} 
      alt={alt} 
      className={className}
      style={{ ...style, cursor: 'pointer' }}
      onClick={handleClick}
    />
  );
};

export default Logo;
