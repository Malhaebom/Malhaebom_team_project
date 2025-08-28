import React from "react";

export default function Header({ title, showBack = true, showHome = true }) {
  return (
    <header>
      <div className="hd_inner">
        <div className="hd_tit" role="alert">
          {title}
        </div>
        {showBack && (
          <div className="hd_left">
            <a onClick={() => window.history.back()}>
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
