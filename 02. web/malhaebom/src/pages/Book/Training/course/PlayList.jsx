import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import useQuery from "../../../../hooks/useQuery.js";
import Header from "../../../../components/Header.jsx";
import AOS from "aos";
import Background from "../../../Background/Background";
import Pagination from "../../../../components/Pagination.jsx";

export default function PlayList() {
  const query = useQuery();
  const bookId = Number(query.get("bookId") ?? "0");
  const navigate = useNavigate();

  const [fairytales, setFairytales] = useState(null);
  const [title, setTitle] = useState("");
  const [speech, setSpeech] = useState(null);
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  
  // 페이징 관련 상태
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage] = useState(5);

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

  // 페이징 관련 함수들
  const totalPages = Math.ceil((speech?.length || 0) / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const endIndex = startIndex + itemsPerPage;
  const currentData = speech?.slice(startIndex, endIndex) || [];

  // 현재 페이지의 데이터를 5개로 맞추기 (빈 항목 추가)
  const getCurrentPageData = () => {
    const data = [...currentData];
    
    // 5개 미만이면 빈 항목들을 추가
    while (data.length < itemsPerPage) {
      data.push(null);
    }
    
    return data;
  };

  const handlePageChange = (page) => {
    setCurrentPage(page);
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
             style={{
               display: "flex",
               flexDirection: "column",
               minHeight: "calc(100vh - 200px)" // 최소 높이 설정
             }}
           >
            {Array.isArray(speech) && speech.length > 0 ? (
              getCurrentPageData().map((item, index) => (
                <div
                  key={index}
                  style={{
                    cursor: item ? "pointer" : "default",
                    padding: "20px",
                    backgroundColor: "#ffffff",
                    borderRadius: "10px",
                    marginBottom: "20px",
                    boxShadow: item ? "0 2px 8px rgba(0,0,0,0.1)" : "none",
                    transition: "all 0.2s ease",
                    border: "1px solid #e1e1e1",
                    minHeight: "auto",
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "flex-start",
                    opacity: item ? 1 : 0,
                    wordBreak: "keep-all",
                    lineHeight: "1.3"
                  }}
                  onClick={() => item && goToStartPlay(startIndex + index)}
                  onMouseEnter={(e) => {
                    if (item) {
                      e.currentTarget.style.boxShadow = "0 4px 12px rgba(0,0,0,0.15)";
                      e.currentTarget.style.transform = "translateY(-2px)";
                    }
                  }}
                  onMouseLeave={(e) => {
                    if (item) {
                      e.currentTarget.style.boxShadow = "0 2px 8px rgba(0,0,0,0.1)";
                      e.currentTarget.style.transform = "translateY(0)";
                    }
                  }}
                >
                  <div
                    style={{
                      display: "flex",
                      justifyContent: "flex-start",
                      alignItems: "flex-start",
                      width: "100%",
                      flexDirection: "column",
                      gap: "8px"
                    }}
                  >
                                         <span style={{ 
                       color: "#333333", 
                       fontWeight: "bold", 
                       fontSize: "18px",
                       fontFamily: "GmarketSans"
                     }}>
                       문항 {startIndex + index + 1}
                     </span>
                    {item && (
                      <p style={{
                        color: "#7d7d7d",
                        fontSize: "16px",
                        fontFamily: "GmarketSans",
                        margin: "0",
                        lineHeight: "1.4",
                        textAlign: "left"
                      }}>
                        {item.speechText || "대화 내용을 불러올 수 없습니다."}
                      </p>
                    )}
                  </div>
                </div>
              ))
            ) : (
              <div style={{
                textAlign: "center",
                padding: "40px 20px",
                color: "#7d7d7d",
                fontSize: "16px",
                fontFamily: "GmarketSans",
                backgroundColor: "#ffffff",
                borderRadius: "10px",
                border: "1px solid #e1e1e1",
                boxShadow: "0 2px 8px rgba(0,0,0,0.1)"
              }}>
                {Array.isArray(speech) ? "동화연극하기 항목이 없습니다." : "로딩 중..."}
              </div>
                         )}

             {/* 페이징 네비게이션 */}
             <div style={{ 
               marginTop: "auto", 
               paddingTop: "20px",
               border: "1px solid #ffffff",
               borderRadius: "8px",
               padding: "20px",
               backgroundColor: "transparent"
             }}>
               <Pagination
                 currentPage={currentPage}
                 totalPages={totalPages}
                 onPageChange={handlePageChange}
                 itemsPerPage={itemsPerPage}
               />
             </div>
           </div>
        </div>
      </div>
    </div>
  );
}
