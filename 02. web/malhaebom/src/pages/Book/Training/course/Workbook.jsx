// src/pages/book/training/course/Workbook.jsx
import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import useQuery from "../../../../hooks/useQuery";
import Header from "../../../../components/Header";
import AOS from "aos";
import "aos/dist/aos.css";
import Background from "../../../Background/Background";
import Pagination from "../../../../components/Pagination.jsx";

export default function Workbook() {
  const query = useQuery();
  const navigate = useNavigate();
  const bookId = Number(query.get("bookId") ?? "0");

  const [title, setTitle] = useState("동화");
  const [work, setWork] = useState(null);
  const [windowWidth, setWindowWidth] = useState(window.innerWidth); // 브라우저 너비 감지
  const [completionTimes, setCompletionTimes] = useState({});
  
  // 페이징 관련 상태
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage] = useState(10);

  const BASE = import.meta.env.BASE_URL || "/";

  // 브라우저 너비 감지
  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  useEffect(() => {
    AOS.init();
  }, []);

  // fairytale.json → bookId 탐색 → workbook JSON fetch
  useEffect(() => {
    fetch(`${BASE}autobiography/fairytale.json`)
      .then((r) => {
        if (!r.ok) throw new Error("fairytale.json 로드 실패");
        return r.json();
      })
      .then((json) => {
        const entries = Object.entries(json); // [ [key, value], ... ]
        const found = entries.find(([, v]) => Number(v?.id) === bookId);
        if (!found) {
          alert("해당 동화를 찾을 수 없습니다.");
          return;
        }
        const [bookTitle, v] = found;
        setTitle(bookTitle);

        if (!v?.workbook) {
          alert("워크북 경로가 없습니다.");
          return;
        }

        // 다음 화면에서 사용
        localStorage.setItem("bookId", String(bookId));
        localStorage.setItem("bookTitle", bookTitle);
        if (v?.workbookImgPath) {
          localStorage.setItem("workbookImgPath", v.workbookImgPath);
        } else {
          localStorage.removeItem("workbookImgPath");
        }
        localStorage.setItem("workbookPath", v.workbook);

        // 워크북 완료 시간 불러오기
        const completionTimesKey = `workbookCompletionTimes_${v.workbook}`;
        const savedTimes = JSON.parse(localStorage.getItem(completionTimesKey) || '{}');
        setCompletionTimes(savedTimes);

        return fetch(`${BASE}autobiography/${v.workbook}`);
      })
      .then((r) => (r ? r.json() : null))
      .then((json) => {
        if (json) setWork(json);
      })
      .catch((e) => {
        console.error(e);
        setWork([]);
      });
  }, [bookId, BASE]);

  const goHome = () => {
    window.location.href = `/book/training?bookId=${bookId}`;
  };

  const goToStartWork = (idx) => {
    navigate(`/book/training/course/workbook/start?workId=${idx}`);
  };

  // 페이징 관련 함수들
  const totalPages = Math.ceil((work?.length || 0) / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const endIndex = startIndex + itemsPerPage;
  const currentData = work?.slice(startIndex, endIndex) || [];

  // 현재 페이지의 데이터를 10개로 맞추기 (빈 항목 추가)
  const getCurrentPageData = () => {
    const data = [...currentData];
    
    // 10개 미만이면 빈 항목들을 추가
    while (data.length < itemsPerPage) {
      data.push(null);
    }
    
    return data;
  };

  const handlePageChange = (page) => {
    setCurrentPage(page);
  };

  // 완료 시간 포맷팅 함수
  const formatCompletionTime = (workId) => {
    const completionTime = completionTimes[workId];
    if (!completionTime) {
      return "미완료";
    }
    
    try {
      const date = new Date(completionTime);
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      const hours = String(date.getHours()).padStart(2, '0');
      const minutes = String(date.getMinutes()).padStart(2, '0');
      
      return `${year}-${month}-${day} ${hours}:${minutes}`;
    } catch (error) {
      return "미완료";
    }
  };

  return (
    <div className="content">
      {/* 일정 너비 이상일 때만 배경 표시 */}
      {windowWidth > 1100 && <Background />}

      <div
        className="wrap"
        style={{
          maxWidth: "520px",
          margin: "0 auto",
          padding: "0px 20px",
          fontFamily: "Pretendard-Regular",
        }}
      >
        <Header title={title} />

        <div className="inner">
          <div
            className="ct_theater ct_inner"
            data-aos="fade-up"
            data-aos-duration="1000"
          >
            {Array.isArray(work) && work.length > 0 ? (
              getCurrentPageData().map((item, index) => (
                <div
                  key={index}
                                     style={{
                     cursor: item ? "pointer" : "default",
                     padding: "16px 20px",
                     backgroundColor: item ? "#ffffff" : "transparent",
                     borderRadius: "8px",
                     marginBottom: "12px",
                     boxShadow: item ? "0 1px 3px rgba(0,0,0,0.1)" : "none",
                     transition: "all 0.2s ease",
                     border: item ? "1px solid #ffffff" : "1px solid transparent",
                     minHeight: "65px",
                     height: "65px",
                     display: "flex",
                     alignItems: "center",
                     opacity: item ? 1 : 0
                   }}
                  onClick={() => item && goToStartWork(startIndex + index)}
                  onMouseEnter={(e) => {
                    if (item) {
                      e.currentTarget.style.boxShadow = "0 2px 6px rgba(0,0,0,0.15)";
                    }
                  }}
                  onMouseLeave={(e) => {
                    if (item) {
                      e.currentTarget.style.boxShadow = "0 1px 3px rgba(0,0,0,0.1)";
                    }
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
                         color: item ? "#488eca" : "#cccccc", 
                         fontWeight: "bold", 
                         fontSize: "16px",
                         fontFamily: "GmarketSans"
                       }}>
                         문항 {startIndex + index + 1}
                       </span>
                     </div>
                    <div style={{ 
                      display: "flex", 
                      alignItems: "center", 
                      justifyContent: "flex-end",
                      color: item ? (completionTimes[startIndex + index] ? "#ff6b35" : "#999999") : "#cccccc",
                      fontSize: "14px",
                      fontWeight: "bold",
                      fontFamily: "GmarketSans"
                    }}>
                      <span>{item ? formatCompletionTime(startIndex + index) : ""}</span>
                    </div>
                  </div>
                </div>
              ))
            ) : (
              <div style={{
                textAlign: "center",
                padding: "40px 20px",
                color: "#888",
                fontSize: "16px",
                fontFamily: "GmarketSans"
              }}>
                {Array.isArray(work) ? "워크북 항목이 없습니다." : "로딩 중..."}
              </div>
            )}

            {/* 페이징 네비게이션 */}
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
  );
}
