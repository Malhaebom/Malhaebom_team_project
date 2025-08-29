import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import useQuery from "../../../../hooks/useQuery";
import Header from "../../../../components/Header";
import AOS from "aos";
import "aos/dist/aos.css";
import Background from "../../../Background/Background";

export default function Read() {
  const query = useQuery();
  const navigate = useNavigate();
  const bookId = Number(query.get("bookId") ?? "0");

  const q_how_to_use = "어떻게 사용하나요?";
  const how_to_use_1 = "동영상을 전체 화면으로 보여줍니다.";
  const how_to_use_2 = "동영상을 재생합니다.";
  const how_to_use_3 = "동영상을 중지합니다.";
  const tips_story_training_video = "영상을 보고 다양한 활동을 해 봐요.";
  const q_finish_story = "동화를 모두 들었나요?";
  const story_training_how_to_use_extra = "동화를 모두 시청하면 화행검사를 진행합니다.";
  const finish_story_message =
    "동화 시청을 완료하신 분은 화행검사를 진행할 수 있습니다. 화행검사를 진행하시겠습니까?";
  const button_goto_exam = "예, 검사를 진행합니다.";
  const button_no_exam = "아니오, 검사를 진행하지 않습니다.";

  const [title, setTitle] = useState("동화");
  const [videoSource, setVideoSource] = useState("");

  const [windowWidth, setWindowWidth] = useState(window.innerWidth); // 브라우저 너비 상태

  const BASE = import.meta.env.BASE_URL || "/";

  useEffect(() => {
    AOS.init();
  }, []);

  // 브라우저 리사이즈 감지
  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  useEffect(() => {
    fetch(`${BASE}autobiography/fairytale.json`)
      .then((r) => {
        if (!r.ok) throw new Error("fairytale.json 로드 실패");
        return r.json();
      })
      .then((json) => {
        const entries = Object.entries(json);
        const found = entries.find(([, v]) => Number(v?.id) === bookId);
        if (!found) {
          alert("해당 동화를 찾을 수 없습니다.");
          return;
        }
        const [bookTitle, value] = found;
        setTitle(bookTitle);
        if (value?.video) {
          setVideoSource(`${BASE}autobiography/${value.video}`);
        } else {
          alert("비디오를 불러오던 중 에러가 발생했습니다.");
        }
      })
      .catch((e) => {
        console.error(e);
        alert("동화 정보를 불러오지 못했습니다.");
      });
  }, [bookId, BASE]);

  const gotoExam = () => {
    navigate(`/book/training/course/exam?bookId=${bookId}`);
  };

  const noExam = () => {
    window.location.href = `/book/training?bookId=${bookId}`;
  };

  return (
    <div className="content">
      {/* 브라우저 너비 1100 이상일 때만 Background 렌더링 */}
      {windowWidth > 1100 && <Background />}

      <div id="app" className="wrap">
        <Header title={title} />
        <div className="inner">
          <div className="ct_banner">{tips_story_training_video}</div>

          <div className="ct_inner">
            <div className="ct_video" data-aos="fade-up" data-aos-duration="1000">
              <video controls src={videoSource} style={{ width: "100%" }} />
            </div>

            <div
              className="ct_question"
              id="last"
              data-aos="fade-up"
              data-aos-duration="2000"
            >
              <div>
                <div className="tit">
                  <p>Q</p>
                  {q_how_to_use}
                </div>
                <div className="sub_tit">
                  <p>
                    <i className="xi-play"></i>
                    {how_to_use_2}
                  </p>
                  <p>
                    <i className="xi-focus-frame"></i>
                    {how_to_use_1}
                  </p>
                  <p>
                    <i className="xi-pause"></i>
                    {how_to_use_3}
                  </p>
                  <p className="bg">
                    <i className="xi-check-circle-o"></i>
                    {story_training_how_to_use_extra}
                  </p>
                </div>
              </div>

              <div>
                <div className="tit">
                  <p>Q</p>
                  {q_finish_story}
                </div>
                <div className="sub_tit">
                  <p>{finish_story_message}</p>
                </div>
              </div>

              <button className="question_bt" type="button" onClick={gotoExam}>
                {button_goto_exam}
              </button>
              <button className="question_bt" type="button" id="last" onClick={noExam}>
                {button_no_exam}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
