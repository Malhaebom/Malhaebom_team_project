import React, { useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams, useLocation } from "react-router-dom";
import AOS from "aos";
import "aos/dist/aos.css";

export default function QuizPlay() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const location = useLocation();
  const BASE = import.meta.env.BASE_URL || "/";

  const state = location.state ?? {};
  const retryIndex = state.retryIndex ?? 0;
  const initialSubmitArr = state.submitDataArr ?? [];
  const initialAnswerArr = state.answerDataArr ?? [];

  const files = [
    "시공간파악.json",
    "기억집중.json",
    "문제해결능력.json",
    "계산능력.json",
    "언어능력.json",
    "음악과터치.json"
  ];

  const quizType = (() => {
    const q = searchParams.get("quizType");
    const n = Number(q);
    return !isNaN(n) && n >= 0 && n < files.length ? n : 0;
  })();

  const quizFileName = files[quizType] ?? "퀴즈.json";
  const passedQuizTitle = quizFileName.replace(".json", "");

  const [brainTrainingArr, setBrainTrainingArr] = useState(null);
  const [currentTopicArr, setCurrentTopicArr] = useState([]);
  const [currentIndex, setCurrentIndex] = useState(retryIndex);
  const [progress, setProgress] = useState(0);
  const [submitDataArr, setSubmitDataArr] = useState([...initialSubmitArr]);
  const [answerDataArr, setAnswerDataArr] = useState([...initialAnswerArr]);
  const [cnt, setCnt] = useState(0);

  useEffect(() => { AOS.init(); }, []);

  useEffect(() => {
    (async () => {
      try {
        const arr = await Promise.all(
          files.map(f => fetch(`${BASE}autobiography/brainTraining/${f}`).then(r => r.json()))
        );
        setBrainTrainingArr(arr);
      } catch (e) { console.error(e); }
    })();
  }, [BASE]);

  useEffect(() => {
    if (!brainTrainingArr) return;
    const topicArr = brainTrainingArr[quizType] ?? [];
    setCurrentTopicArr(topicArr);

    setCurrentIndex(retryIndex);
    setProgress(0);
    setCnt(0);
  }, [brainTrainingArr, quizType, retryIndex]);

  const current = useMemo(() => currentTopicArr[currentIndex] ?? null, [currentTopicArr, currentIndex]);

  const goHome = () => navigate("/");
  const goBack = () => window.history.back();

  const goResult = (submitArr, answerArr) => {
    navigate("/quiz/result", {
      state: {
        submitDataArr: submitArr,
        answerDataArr: answerArr,
        quizType,
        quizTitle: passedQuizTitle,
        questionArr: currentTopicArr,
      },
    });
  };

  // Type 0 제출
  const SubmitType0 = (submitData) => {
    if (!current) return;
    const answerData = Number(current?.question?.[0]?.answer ?? -1);
    const newSubmitArr = [...submitDataArr];
    const newAnswerArr = [...answerDataArr];
    newSubmitArr[currentIndex] = submitData;
    newAnswerArr[currentIndex] = answerData;
    setSubmitDataArr(newSubmitArr);
    setAnswerDataArr(newAnswerArr);

    if (currentIndex + 1 < currentTopicArr.length) setCurrentIndex(currentIndex + 1);
    else goResult(newSubmitArr, newAnswerArr);
  };

  // Type 2 제출
  const SubmitType2 = (submitData) => {
    if (!current) return;
    const maxIndex = current.question.length;
    const newSubmitArr = [...submitDataArr];
    const newAnswerArr = [...answerDataArr];
    newSubmitArr[currentIndex] = submitData;
    newAnswerArr[currentIndex] = current.question[submitDataArr.length].answer;
    setSubmitDataArr(newSubmitArr);
    setAnswerDataArr(newAnswerArr);
    setProgress(((currentIndex + 1) / maxIndex) * 100);

    if (currentIndex + 1 < currentTopicArr.length) {
      setCurrentIndex(currentIndex + 1);
    } else {
      goResult(newSubmitArr, newAnswerArr);
    }
  };

  // Type 3 카운트
  const CountUpType3 = () => setCnt(c => c + 1);
  const PlaySoundType3 = () => {
    const audio = document.querySelector(".soundType3");
    if (audio) { audio.load(); audio.play(); }
  };

  const SubmitType3 = () => {
    if (!current) return;
    const answer = Number(current?.question?.[0]?.answer ?? -1);
    const newSubmitArr = [...submitDataArr];
    const newAnswerArr = [...answerDataArr];
    newSubmitArr[currentIndex] = cnt;
    newAnswerArr[currentIndex] = answer;
    setSubmitDataArr(newSubmitArr);
    setAnswerDataArr(newAnswerArr);

    if (currentIndex + 1 < currentTopicArr.length) {
      setCurrentIndex(currentIndex + 1);
      setCnt(0);
    } else {
      goResult(newSubmitArr, newAnswerArr);
    }
  };

  if (!current) return (
    <div className="content">
      <div className="wrap">
        <header>
          <div className="hd_inner">
            <div className="hd_tit">두뇌 단련</div>
          </div>
        </header>
        <div className="inner">로딩 중...</div>
      </div>
    </div>
  );

  const type = current.type;

  return (
    <div className="content">
      <div className="wrap">
        <header>
          <div className="hd_inner">
            <div className="hd_tit">
              <div className="alert alert-dark text-center">{passedQuizTitle}</div>
            </div>
            <div className="hd_left"><a onClick={goBack}><i className="xi-angle-left-min" /></a></div>
            <div className="hd_right"><a onClick={goHome}><i className="xi-home-o" /></a></div>
          </div>
        </header>

        <div className="inner">
          <div className="ct_inner">
            <div className="ct_brain" data-aos="fade-up" data-aos-duration="1000">
              <div className="ct_tit">{current.question?.[0]?.title}</div>

              {/* Type 0 */}
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

              {/* Type 1 */}
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

              {/* Type 2 */}
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

              {/* Type 3 */}
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
