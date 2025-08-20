import React, { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import useQuery from "../../../../hooks/useQuery.js";
import Header from "../../../../components/Header.jsx";
import AOS from "aos";


export default function PlayList() {
  const query = useQuery();
  const bookId = Number(query.get("bookId") ?? "0");
  const navigate = useNavigate();

  const [fairytales, setFairytales] = useState(null);
  const [title, setTitle] = useState("");
  const [speech, setSpeech] = useState(null);

  // AOS
  useEffect(() => {
    AOS.init();
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
    const entries = Object.entries(fairytales); // [ [key, value], ... ]
    const found = entries.find(([, v]) => Number(v?.id) === bookId);
    if (!found) {
      setTitle("동화");
      return;
    }
    const [bookTitle, value] = found;
    setTitle(bookTitle);
    // speech 경로 저장(다음 화면에서 쓸 수도 있어서)
    if (value?.speech) {
      localStorage.setItem("speechPath", value.speech);
      localStorage.setItem("bookTitle", bookTitle);
      // speech JSON 로드
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
                <div key={idx}>
                  <div className="theater_flex">
                    <p className="tit">{item?.title}</p>
                    <div className="start">
                      <a onClick={() => goToStartPlay(idx)}>
                        <i className="xi-arrow-right"></i>
                      </a>
                    </div>
                  </div>
                  <p>{item?.speechText}</p>
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
