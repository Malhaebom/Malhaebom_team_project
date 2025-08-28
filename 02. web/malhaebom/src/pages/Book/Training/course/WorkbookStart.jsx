// src/pages/book/training/course/WorkbookStart.jsx
import React, { useEffect, useMemo, useState } from "react";
import useQuery from "../../../../hooks/useQuery";
import Header from "../../../../components/Header";
import AOS from "aos";
import "aos/dist/aos.css";
import Background from "../../../Background/Background";

export default function WorkbookStart() {
  const query = useQuery();
  const workId = Number(query.get("workId") ?? "0");

  const BASE = import.meta.env.BASE_URL || "/";

  const [bookTitle, setBookTitle] = useState("동화");
  const [bookId, setBookId] = useState(0);
  const [work, setWork] = useState(null);
  const [imgBase, setImgBase] = useState(""); // /autobiography/<workbookImgPath>
  const [selectedIdx, setSelectedIdx] = useState(-1); // submitData 대체
  const [windowWidth, setWindowWidth] = useState(window.innerWidth); // 브라우저 너비 상태

  // 브라우저창 너비 감지
  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  useEffect(() => {
    AOS.init();
  }, []);

  // localStorage에서 메타 읽기 + workbook JSON 로드
  useEffect(() => {
    const _bookId = Number(localStorage.getItem("bookId") ?? "0");
    const _bookTitle = localStorage.getItem("bookTitle") || "동화";
    const workbookPath = localStorage.getItem("workbookPath");
    const workbookImgPath = localStorage.getItem("workbookImgPath") || "";

    setBookId(_bookId);
    setBookTitle(_bookTitle);
    setImgBase(`${BASE}autobiography/${workbookImgPath}`);

    if (!workbookPath) {
      alert("워크북 경로가 없습니다. 목록으로 이동합니다.");
      window.history.back();
      return;
    }

    fetch(`${BASE}autobiography/${workbookPath}`)
      .then((r) => {
        if (!r.ok) throw new Error("workbook JSON 로드 실패");
        return r.json();
      })
      .then((json) => setWork(json))
      .catch((e) => {
        console.error(e);
        alert("워크북 데이터를 불러오지 못했습니다.");
      });
  }, [BASE]);

  const current = useMemo(() => {
    if (!Array.isArray(work)) return null;
    return work[workId];
  }, [work, workId]);

  const imgStyle = (idx) => ({
    borderRadius: "10px",
    width: "100%",
    ...(selectedIdx === idx ? { border: "inset 2px", borderColor: "purple" } : {}),
  });

  const selected = (idx) => {
    setSelectedIdx(idx);
  };

  const submit = () => {
    if (!current) return;
    const answer = Number(current.answer);
    const submitData = Number(selectedIdx);

    if (submitData === -1) {
      alert("답안을 선택해주세요!");
      return;
    }

    if (answer === submitData) {
      if (confirm("정답입니다! 다른문제도 도전해볼까요?")) {
        window.history.back();
      } else {
        window.location.href = `/book/training?bookId=${bookId}`;
      }
    } else {
      if (confirm("오답입니다! 한번 더 생각해볼까요?")) {
        setSelectedIdx(-1);
      } else {
        window.history.back();
      }
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
        <Header title={bookTitle} />

        <div className="inner">
          <div className="ct_banner">{current?.title ?? "로딩 중..."}</div>
          <div className="ct_inner">
            <div className="ct_imgflex" data-aos="fade-up" data-aos-duration="1000">
              {[0, 1, 2, 3].map((i) => (
                <div className="ct_img" key={i} onClick={() => selected(i)}>
                  {current?.list?.[i] ? (
                    <img id={`img${i}`} src={`${imgBase}${current.list[i]}`} style={imgStyle(i)} />
                  ) : (
                    <div style={{ padding: 12 }}>이미지 없음</div>
                  )}
                </div>
              ))}

              <button className="question_bt" type="button" onClick={submit}>
                답안 제출
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
