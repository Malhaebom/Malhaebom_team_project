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
    // 원본: /book/training?bookId=...
    window.location.href = `/book/training?bookId=${bookId}`;
  };

  const goToStartWork = (idx) => {
    // 원본과 동일하게 workId만 전달 (bookId는 localStorage에 이미 저장)
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
                <div key={idx}>
                  <div className="theater_flex">
                    <p className="tit">문항 {idx + 1}</p>
                    <div className="start">
                      <a onClick={() => goToStartWork(idx)}>
                        <i className="xi-arrow-right" />
                      </a>
                    </div>
                  </div>
                  <p>{v?.title}</p>
                </div>
              ))
            ) : (
              <p>로딩 중...</p>
            )}
          </div>
        </div>
      </div>

      {/* 우측 상단 홈 이동 아이콘 동작 유지 필요 시, Header 컴포넌트 수정 or 별도 버튼 배치 가능 */}
    </div>
  );
}
