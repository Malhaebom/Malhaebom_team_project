import React, { useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import AOS from "aos";
import "aos/dist/aos.css";

export default function QuizList() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const BASE = import.meta.env.BASE_URL || "/";

  const quizType = Number(searchParams.get("quizType") ?? "0");

  const [brainTraining, setBrainTraining] = useState(null);
  const [brainTrainingArr, setBrainTrainingArr] = useState(null);
  const [title, setTitle] = useState("");

  useEffect(() => {
    AOS.init();
  }, []);

  // brainTraining.json + 각 타입 JSON을 로드 (Vue의 import들과 동일한 효과)
  useEffect(() => {
    (async () => {
      try { 
        const btRes = await fetch(`${BASE}autobiography/brainTraining.json`);
        const bt = await btRes.json();
        setBrainTraining(bt);

        const files = [
          "시공간파악.json",
          "기억집중.json",
          "문제해결능력.json",
          "계산능력.json",
          "알록달록.json",
          "언어능력.json",
          "음악과터치.json",
          "정보.json",
        ];
        const arr = await Promise.all(
          files.map((f) =>
            fetch(`${BASE}autobiography/brainTraining/${f}`).then((r) => r.json())
          )
        );
        setBrainTrainingArr(arr);

        // 제목: brainTraining의 key 순회에서 index === quizType 인 키
        const entry = Object.entries(bt).find(([, _], idx) => idx === quizType);
        setTitle(entry ? entry[0] : "");
      } catch (e) {
        console.error(e);
      }
    })();
  }, [BASE, quizType]);

  const goHome = () => (window.location.href = "/quiz/library");
  const goToQuizPlay = (qType, quizId) =>
    navigate(`/quiz/play?quizType=${qType}&quizId=${quizId}&qid=0`);

  const listData = useMemo(() => {
    if (!brainTrainingArr) return [];
    return brainTrainingArr[quizType] ?? [];
  }, [brainTrainingArr, quizType]);

  const bannerSuffix = useMemo(() => {
    if (!brainTraining) return "";
    const entry = Object.entries(brainTraining).find(([, _], idx) => idx === quizType);
    return entry ? entry[0] : "";
  }, [brainTraining, quizType]);

  return (
    <div className="content">
      <div className="wrap">
        <header>
          <div className="hd_inner">
            <div className="hd_tit">
              <div className="alert alert-dark text-center" role="alert">{title}</div>
            </div>
            <div className="hd_left">
              <a onClick={() => window.history.back()}><i className="xi-angle-left-min" /></a>
            </div>
            <div className="hd_right">
              <a onClick={goHome}><i className="xi-home-o" /></a>
            </div>
          </div>
        </header>

        <div className="inner">
          <div
            className="ct_theater ct_inner"
            data-aos="fade-up"
            data-aos-duration="1000"
          >
            {quizType !== 7 ? (
              listData.map((_, key) => (
                <div key={key}>
                  <div className="theater_flex">
                    <p className="tit">Level {key + 1}</p>
                    <div className="start">
                      <a onClick={() => goToQuizPlay(quizType, key)}>
                        <i className="xi-arrow-right" />
                      </a>
                    </div>
                  </div>
                  {bannerSuffix}을 길러봅시다.
                </div>
              ))
            ) : (
              listData.map((value, key) => (
                <div key={key}>
                  <div className="theater_flex">
                    <p className="tit">{value.title}</p>
                    <div className="start">
                      <a onClick={() => goToQuizPlay(quizType, key)}>
                        <i className="xi-arrow-right" />
                      </a>
                    </div>
                  </div>
                  {value?.question?.[0]?.title}
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
