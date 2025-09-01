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
  const [recordingTimes, setRecordingTimes] = useState({});
  
  // 페이징 관련 상태
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage] = useState(8);

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

      // 녹음 완료 시간 불러오기
      const recordingTimesKey = `recordingTimes_${value.speech}`;
      const savedTimes = JSON.parse(localStorage.getItem(recordingTimesKey) || '{}');
      setRecordingTimes(savedTimes);

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

  // 현재 페이지의 데이터를 8개로 맞추기 (빈 항목 추가)
  const getCurrentPageData = () => {
    const data = [...currentData];
    
    // 8개 미만이면 빈 항목들을 추가
    while (data.length < itemsPerPage) {
      data.push(null);
    }
    
    return data;
  };

  const handlePageChange = (page) => {
    setCurrentPage(page);
  };

  // 녹음 완료 시간 포맷팅 함수
  const formatRecordingTime = (speechId) => {
    const completionTime = recordingTimes[speechId];
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
            {Array.isArray(speech) && speech.length > 0 ? (
              getCurrentPageData().map((item, index) => (
                                                  <div
                   key={index}
                   style={{
                     cursor: item ? "pointer" : "default",
                     padding: "16px 20px",
                     backgroundColor: "#ffffff",
                     borderRadius: "8px",
                     marginBottom: "12px",
                     boxShadow: item ? "0 1px 3px rgba(0,0,0,0.1)" : "none",
                     transition: "all 0.2s ease",
                     border: "1px solid #ffffff",
                     minHeight: "65px",
                     display: "flex",
                     alignItems: "center",
                     opacity: item ? 1 : 0
                   }}
                   onClick={() => item && goToStartPlay(startIndex + index)}
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
                          color: "#488eca", 
                          fontWeight: "bold", 
                          fontSize: "16px",
                          fontFamily: "GmarketSans"
                        }}>
                          동화연극하기{startIndex + index + 1}
                        </span>
                     </div>
                                           <div style={{ 
                        display: "flex", 
                        alignItems: "center", 
                        justifyContent: "flex-end",
                        color: recordingTimes[startIndex + index] ? "#ff6b35" : "#999999",
                        fontSize: "14px",
                        fontWeight: "bold",
                        fontFamily: "GmarketSans"
                      }}>
                        <span>{formatRecordingTime(startIndex + index)}</span>
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
                 {Array.isArray(speech) ? "동화연극하기 항목이 없습니다." : "로딩 중..."}
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
