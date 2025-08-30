import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import useQuery from "../../../../hooks/useQuery.js";
import Header from "../../../../components/Header.jsx";
import AOS from "aos";
import Background from "../../../Background/Background";

export default function PlayList() {
  const query = useQuery();
  const bookId = Number(query.get("bookId") ?? "0");
  const navigate = useNavigate();

  const [fairytales, setFairytales] = useState(null);
  const [title, setTitle] = useState("");
  const [speech, setSpeech] = useState(null);
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);

  // AOS
  useEffect(() => {
    AOS.init();
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  // 1) fairytale.json 로드
  useEffect(() => {
    fetch(`/autobiography/fairytale.json`)
      .then((r) => {
        if (!r.ok) throw new Error("fairytale.json 로드 실패");
        return r.json();
      })
      .then((json) => setFairytales(json))
      .catch((e) => {
        console.error(e);
        setFairytales({});
      });
  }, []);

  // 2) bookId로 대상 동화/제목 찾기 + speech JSON 경로 로드
  useEffect(() => {
    if (!fairytales) return;
    const entries = Object.entries(fairytales);
    const found = entries.find(([, v]) => Number(v?.id) === bookId);
    if (!found) {
      setTitle("동화");
      return;
    }
    const [bookTitle, value] = found;
    setTitle(bookTitle);

    if (value?.speech) {
      localStorage.setItem("speechPath", value.speech);
      localStorage.setItem("bookTitle", bookTitle);

      fetch(`/autobiography/${value.speech}`)
        .then((r) => {
          if (!r.ok) throw new Error("speech JSON 로드 실패");
          return r.json();
        })
        .then((json) => setSpeech(json))
        .catch((e) => {
          console.error(e);
          setSpeech([]);
        });
    }
  }, [fairytales, bookId]);

  const goHome = () => {
    location.href = `/book/training?bookId=${bookId}`;
  };

  const goToStartPlay = (speechId) => {
    navigate(`/book/training/course/play/start?speechId=${speechId}`);
  };

  return (
    <div className="content">
      {/* 브라우저 1100px 이상일 때만 Background 렌더링 */}
      {windowWidth > 1100 && <Background />}
      <div className="wrap">
        <Header title={title} />
        <div className="inner">
          <div
            className="ct_theater ct_inner"
            data-aos="fade-up"
            data-aos-duration="1000"
          >
            {Array.isArray(speech) ? (
              speech.map((item, idx) => (
                                 <div
                   key={idx}
                   onClick={() => goToStartPlay(idx)}
                   style={{
                     cursor: "pointer",
                     padding: "12px 16px",
                     backgroundColor: "#ffffff",
                     borderRadius: "8px",
                     marginBottom: "8px",
                     boxShadow: "0 1px 3px rgba(0,0,0,0.1)",
                     transition: "all 0.2s ease",
                     border: "1px solid #e0e0e0",
                     minHeight: "50px",
                     display: "flex",
                     alignItems: "center"
                   }}
                   onMouseEnter={(e) => {
                     e.currentTarget.style.backgroundColor = "#f8f9fa";
                     e.currentTarget.style.boxShadow = "0 2px 6px rgba(0,0,0,0.15)";
                   }}
                   onMouseLeave={(e) => {
                     e.currentTarget.style.backgroundColor = "#ffffff";
                     e.currentTarget.style.boxShadow = "0 1px 3px rgba(0,0,0,0.1)";
                   }}
                 >
                   <div
                     style={{
                       display: "flex",
                       justifyContent: "space-between",
                       alignItems: "center",
                       width: "100%"
                     }}
                   >
                     <div style={{ 
                       display: "flex", 
                       alignItems: "center", 
                       justifyContent: "flex-start",
                       flex: 1
                     }}>
                       <span style={{ 
                         color: "#488eca", 
                         fontWeight: "bold", 
                         fontSize: "16px",
                         fontFamily: "GmarketSans"
                       }}>
                         동화연극하기{idx + 1}
                       </span>
                     </div>
                     <div style={{ 
                       display: "flex", 
                       alignItems: "center", 
                       justifyContent: "flex-end",
                       color: "#ff6b35",
                       fontSize: "14px",
                       fontWeight: "bold",
                       fontFamily: "GmarketSans"
                     }}>
                       <span>2025-01-15 14:30</span>
                     </div>
                   </div>
                 </div>
              ))
            ) : (
              <p>로딩 중...</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
