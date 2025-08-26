import React, { useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams, useLocation } from "react-router-dom";
import AOS from "aos";
import "aos/dist/aos.css";

export default function QuizPlay() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const location = useLocation();
  const BASE = import.meta.env.BASE_URL || "/";

  const quizType = Number(searchParams.get("quizType") ?? 0);
  const passedQuizTitle = location.state?.quizTitle || "퀴즈"; // QuizList에서 넘어온 제목

  const [brainTrainingArr, setBrainTrainingArr] = useState(null);
  const [currentTopicArr, setCurrentTopicArr] = useState([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [progress, setProgress] = useState(0);
  const [submitDataArr, setSubmitDataArr] = useState([]);
  const [answerDataArr, setAnswerDataArr] = useState([]);
  const [cnt, setCnt] = useState(0);

  useEffect(() => { AOS.init(); }, []);

  useEffect(() => {
    (async () => {
      try {
        const files = [
          "시공간파악.json",
          "기억집중.json",
          "문제해결능력.json",
          "계산능력.json",
          "언어능력.json",
          "음악과터치.json"
        ];
        const arr = await Promise.all(
          files.map(f => fetch(`${BASE}autobiography/brainTraining/${f}`).then(r => r.json()))
        );
        setBrainTrainingArr(arr);
      } catch (e) { console.error(e); }
    })();
  }, [BASE]);

  useEffect(() => {
    if (!brainTrainingArr) return;
    setCurrentTopicArr(brainTrainingArr[quizType] ?? []);
    setCurrentIndex(0);
    setSubmitDataArr([]);
    setAnswerDataArr([]);
    setProgress(0);
    setCnt(0);
  }, [brainTrainingArr, quizType]);

  const current = useMemo(() => currentTopicArr[currentIndex] ?? null, [currentTopicArr, currentIndex]);

  const goHome = () => (window.location.href = "/");
  const goBack = () => window.history.back();

  const goResult = (submitArr, answerArr) => {
  navigate("/quiz/result", {
    state: {
      submitDataArr: submitArr,
      answerDataArr: answerArr,
      currentTopicArr,
      quizType,
      quizTitle: passedQuizTitle, // ✅ 여기 반드시 전달
    },
  });
};

  const SubmitType0 = (submitData) => {
    if (!current) return;
    const answerData = Number(current?.question?.[0]?.answer ?? -1);
    const newSubmitArr = [...submitDataArr, submitData];
    const newAnswerArr = [...answerDataArr, answerData];

    setSubmitDataArr(newSubmitArr);
    setAnswerDataArr(newAnswerArr);

    if (currentIndex + 1 < currentTopicArr.length) setCurrentIndex(currentIndex + 1);
    else goResult(newSubmitArr, newAnswerArr);
  };

  const SubmitType2 = (submitData) => {
    if (!current) return;
    const maxIndex = current.question.length;
    const newSubmitArr = [...submitDataArr, submitData];
    const newAnswerArr = [...answerDataArr, current.question[submitDataArr.length].answer];

    setSubmitDataArr(newSubmitArr);
    setAnswerDataArr(newAnswerArr);
    setProgress((newSubmitArr.length / maxIndex) * 100);

    if (newSubmitArr.length === maxIndex) {
      if (currentIndex + 1 < currentTopicArr.length) {
        setCurrentIndex(currentIndex + 1);
        setProgress(0);
        setSubmitDataArr([]);
        setAnswerDataArr([]);
      } else goResult(newSubmitArr, newAnswerArr);
    }
  };

  const CountUpType3 = () => setCnt(c => c + 1);
  const PlaySoundType3 = () => {
    const audio = document.querySelector(".soundType3");
    if (audio) { audio.load(); audio.play(); }
  };
  const SubmitType3 = () => {
    if (!current) return;
    const answer = Number(current?.question?.[0]?.answer ?? -1);
    const newSubmitArr = [...submitDataArr, cnt];
    const newAnswerArr = [...answerDataArr, answer];

    setSubmitDataArr(newSubmitArr);
    setAnswerDataArr(newAnswerArr);

    if (currentIndex + 1 < currentTopicArr.length) { setCurrentIndex(currentIndex + 1); setCnt(0); }
    else goResult(newSubmitArr, newAnswerArr);
  };

  if (!current) return (
    <div className="content"><div className="wrap"><header><div className="hd_inner"><div className="hd_tit">두뇌 단련</div></div></header><div className="inner">로딩 중...</div></div></div>
  );

  const type = current.type;

  return (
    <div className="content">
      <div className="wrap">
        <header>
          <div className="hd_inner">
            <div className="hd_tit">
              <div className="alert alert-dark text-center" role="alert">두뇌 단련</div>
            </div>
            <div className="hd_left"><a onClick={goBack}><i className="xi-angle-left-min" /></a></div>
            <div className="hd_right"><a onClick={goHome}><i className="xi-home-o" /></a></div>
          </div>
        </header>
        <div className="inner">
          <div className="ct_inner">
            <div className="ct_brain" data-aos="fade-up" data-aos-duration="1000">
              <div className="ct_tit">{current.question?.[0]?.title}</div>
              {type === 0 && (
                <>
                  <div className="ct_img">
                    <img src={`${BASE}autobiography/brainTraining/${current.question[0].image}`} style={{ width: "100%", borderRadius: 10 }} />
                  </div>
                  <div className="bt_flex bt_flex_4">
                    {current.question[0].question?.map((text, idx) => (
                      <button key={idx} className="question_bt" type="button" onClick={() => SubmitType0(idx)}>{text}</button>
                    ))}
                  </div>
                </>
              )}
              {type === 1 && (
                <>
                  <div className="ct_img">
                    <img src={`${BASE}autobiography/brainTraining/${current.question[0].image}`} style={{ width: "100%", borderRadius: 10 }} />
                  </div>
                  <div className="bt_flex bt_flex_2">
                    <button className="question_bt" type="button" onClick={() => SubmitType0(0)}>O</button>
                    <button className="question_bt" type="button" onClick={() => SubmitType0(1)}>X</button>
                  </div>
                </>
              )}
              {type === 2 && (
                <>
                  <div className="ct_img">
                    <img src={`${BASE}autobiography/brainTraining/${current.question[submitDataArr.length].image}`} style={{ width: "100%", borderRadius: 10 }} />
                  </div>
                  <progress id="progressbar" value={progress} min="0" max="100" style={{ width: "100%" }} />
                  <div className="bt_flex bt_flex_2">
                    <button className="question_bt" type="button" onClick={() => SubmitType2(0)}>왼쪽</button>
                    <button className="question_bt bt_color" type="button" onClick={() => SubmitType2(1)}>오른쪽</button>
                  </div>
                </>
              )}
              {type === 3 && (
                <>
                  <div className="ct_tit_sub">[ 실제로 노래를 부르며 터치해 보세요 ]</div>
                  <div className="ct_img">
                    <img src={`${BASE}autobiography/brainTraining/${current.question[0].image}`} style={{ width: "100%", borderRadius: 10 }} />
                    <audio className="soundType3">
                      <source src={`${BASE}autobiography/brainTraining/${current.question[0].sound}`} type="audio/mpeg" />
                    </audio>
                  </div>
                  <div className="bt_ bt_touch">
                    <button className="bt_color" type="button" onClick={CountUpType3}>{cnt}번</button>
                    <div className="bt_flex bt_flex_2">
                      <button type="button" onClick={PlaySoundType3}>노래 재생하기</button>
                      <button type="button" onClick={SubmitType3}>제출하기</button>
                    </div>
                  </div>
                </>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
