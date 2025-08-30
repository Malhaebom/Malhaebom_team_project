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

  // 페이징 네비게이션 렌더링
  const renderPagination = () => {
    if (totalPages <= 1) return null;

    return (
      <div style={{
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        marginTop: "30px",
        marginBottom: "20px",
        gap: "12px"
      }}>
        {/* 이전 페이지 버튼 */}
        <button
          onClick={() => currentPage > 1 && handlePageChange(currentPage - 1)}
          disabled={currentPage === 1}
          style={{
            padding: "8px 12px",
            border: "none",
            backgroundColor: currentPage === 1 ? "#f5f5f5" : "#e0e0e0",
            borderRadius: "5px",
            cursor: currentPage === 1 ? "not-allowed" : "pointer",
            fontSize: "16px",
            fontWeight: "bold",
            color: currentPage === 1 ? "#bdbdbd" : "#666",
            transition: "all 0.2s ease",
            minWidth: "44px",
            height: "44px",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            boxShadow: "0px 0px 10px rgba(0, 0, 0, 0.1)"
          }}
          onMouseEnter={(e) => {
            if (currentPage > 1) {
              e.target.style.backgroundColor = "#488eca";
              e.target.style.color = "#fff";
              e.target.style.boxShadow = "0px 0px 15px rgba(0, 0, 0, 0.2)";
            }
          }}
          onMouseLeave={(e) => {
            if (currentPage > 1) {
              e.target.style.backgroundColor = "#e0e0e0";
              e.target.style.color = "#666";
              e.target.style.boxShadow = "0px 0px 10px rgba(0, 0, 0, 0.1)";
            }
          }}
        >
          ‹
        </button>

        {/* 현재 페이지 번호 */}
        <div style={{
          padding: "8px 16px",
          border: "1px solid #fff",
          backgroundColor: "#fff",
          borderRadius: "5px",
          fontSize: "16px",
          fontWeight: "bold",
          color: "#333",
          minWidth: "50px",
          height: "44px",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          boxShadow: "0px 2px 8px rgba(0, 0, 0, 0.1)"
        }}>
          {currentPage}
        </div>

        {/* 다음 페이지 버튼 */}
        <button
          onClick={() => currentPage < totalPages && handlePageChange(currentPage + 1)}
          disabled={currentPage === totalPages}
          style={{
            padding: "8px 12px",
            border: "none",
            backgroundColor: currentPage === totalPages ? "#f5f5f5" : "#e0e0e0",
            borderRadius: "5px",
            cursor: currentPage === totalPages ? "not-allowed" : "pointer",
            fontSize: "16px",
            fontWeight: "bold",
            color: currentPage === totalPages ? "#bdbdbd" : "#666",
            transition: "all 0.2s ease",
            minWidth: "44px",
            height: "44px",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            boxShadow: "0px 0px 10px rgba(0, 0, 0, 0.1)"
          }}
          onMouseEnter={(e) => {
            if (currentPage < totalPages) {
              e.target.style.backgroundColor = "#488eca";
              e.target.style.color = "#fff";
              e.target.style.boxShadow = "0px 0px 15px rgba(0, 0, 0, 0.2)";
            }
          }}
          onMouseLeave={(e) => {
            if (currentPage < totalPages) {
              e.target.style.backgroundColor = "#e0e0e0";
              e.target.style.color = "#666";
              e.target.style.boxShadow = "0px 0px 10px rgba(0, 0, 0, 0.1)";
            }
          }}
        >
          ›
        </button>
      </div>
    );
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
              maxWidth: "520px",
              margin: "0 auto",
              padding: "20px"
            }}
          >
            {/* 타이틀 */}
            <h2
              style={{
                textAlign: "center",
                marginBottom: "30px",
                fontFamily: "ONE-Mobile-Title",
                fontSize: "28px",
                color: "#333"
              }}
            >
              동화연극하기
            </h2>

            {Array.isArray(speech) && speech.length > 0 ? (
              <div style={{ display: "flex", flexDirection: "column", gap: "15px" }}>
                {getCurrentPageData().map((item, index) => (
                  <div
                    key={index}
                    style={{
                      background: item ? "#fff" : "#fff",
                      borderRadius: "12px",
                      boxShadow: item ? "0 4px 12px rgba(0,0,0,0.1)" : "none",
                      overflow: "hidden",
                      opacity: item ? 1 : 0,
                      border: item ? "none" : "1px solid #fff",
                      height: item ? "auto" : "80px",
                      minHeight: item ? "80px" : "80px",
                      cursor: item ? "pointer" : "default",
                      transition: "all 0.3s ease"
                    }}
                    onClick={() => item && goToStartPlay(startIndex + index)}
                    onMouseEnter={(e) => {
                      if (item) {
                        e.target.style.transform = "translateY(-2px)";
                        e.target.style.boxShadow = "0 6px 20px rgba(0,0,0,0.15)";
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (item) {
                        e.target.style.transform = "translateY(0)";
                        e.target.style.boxShadow = "0 4px 12px rgba(0,0,0,0.1)";
                      }
                    }}
                  >
                    {item && (
                      <div style={{
                        padding: "20px",
                        display: "flex",
                        justifyContent: "space-between",
                        alignItems: "center"
                      }}>
                        <div style={{ 
                          display: "flex", 
                          alignItems: "center", 
                          gap: "15px",
                          flex: 1
                        }}>
                          {/* 아이콘 */}
                          <div style={{
                            width: "40px",
                            height: "40px",
                            borderRadius: "50%",
                            backgroundColor: "#488eca",
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "center",
                            color: "white",
                            fontSize: "18px",
                            fontWeight: "bold",
                            fontFamily: "GmarketSans"
                          }}>
                            {startIndex + index + 1}
                          </div>
                          
                          <div style={{ flex: 1 }}>
                            <div style={{
                              fontSize: "16px",
                              fontWeight: "bold",
                              color: "#333",
                              marginBottom: "8px",
                              fontFamily: "GmarketSans"
                            }}>
                              {item.title}
                            </div>
                            <div style={{
                              fontSize: "14px",
                              color: "#666",
                              lineHeight: "1.4",
                              fontFamily: "GmarketSans"
                            }}>
                              {item.speechText}
                            </div>
                          </div>
                        </div>
                        
                        {/* 화살표 아이콘 */}
                        <div style={{
                          fontSize: "20px",
                          color: "#488eca",
                          marginLeft: "10px"
                        }}>
                          →
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            ) : (
              <div style={{
                textAlign: "center",
                padding: "40px 20px",
                color: "#888",
                fontSize: "16px",
                fontFamily: "GmarketSans"
              }}>
                {Array.isArray(speech) ? "동화연극하기 항목이 없습니다." : "로딩 중..."}
              </div>
            )}

            {/* 페이징 네비게이션 */}
            {renderPagination()}
          </div>
        </div>
      </div>
    </div>
  );
}
