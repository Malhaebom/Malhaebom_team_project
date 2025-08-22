// src/pages/book/training/course/Workbook.jsx
import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import useQuery from "../../../../hooks/useQuery";
import Header from "../../../../components/Header";
import AOS from "aos";
import "aos/dist/aos.css";

export default function Workbook() {
  const query = useQuery();
  const navigate = useNavigate();
  const bookId = Number(query.get("bookId") ?? "0");

  const [title, setTitle] = useState("동화");
  const [work, setWork] = useState(null);

  const BASE = import.meta.env.BASE_URL || "/";

  useEffect(() => {
    AOS.init();
  }, []);

  // fairytale.json → 해당 bookId 탐색 → workbookPath 로드 → workbook JSON fetch
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

        // 다음 화면에서 쓰므로 저장
        localStorage.setItem("bookId", String(bookId));
        localStorage.setItem("bookTitle", bookTitle);
        if (v?.workbookImgPath) {
          localStorage.setItem("workbookImgPath", v.workbookImgPath);
        } else {
          localStorage.removeItem("workbookImgPath");
        }
        localStorage.setItem("workbookPath", v.workbook);

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

  return (
    <div className="content">
      <div className="wrap">
        <Header title={title} />
        <div className="inner">
          <div
            className="ct_theater ct_inner"
            data-aos="fade-up"
            data-aos-duration="1000"
          >
            {Array.isArray(work) ? (
              work.map((v, idx) => (
                <div
                  key={idx}
                  onClick={() => goToStartWork(idx)}
                  style={{
                    cursor: "pointer",
                    padding: "12px",
                    border: "1px solid #ddd",
                    borderRadius: "8px",
                    marginBottom: "12px",
                    transition: "background-color 0.2s ease",
                  }}
                  onMouseEnter={(e) =>
                    (e.currentTarget.style.backgroundColor = "#ecececff")
                  }
                  onMouseLeave={(e) =>
                    (e.currentTarget.style.backgroundColor = "transparent")
                  }
                >
                  <div
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                    }}
                  >
                    <p style={{ fontWeight: "bold", margin: 0 }}>
                      문항 {idx + 1}
                    </p>
                  </div>
                  <p style={{ marginTop: "8px" }}>{v?.title}</p>
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
