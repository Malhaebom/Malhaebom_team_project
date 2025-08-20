import React, { useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import AOS from "aos";
import "aos/dist/aos.css";

export default function ExerciseDo() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const BASE = import.meta.env.BASE_URL || "/";

  const exerciseType = Number(searchParams.get("exerciseType") ?? "0");
  const eid = Number(searchParams.get("eid") ?? "0");

  const [exercise, setExercise] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    AOS.init();
  }, []);

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch(`${BASE}autobiography/exercise.json`);
        const json = await res.json();
        setExercise(json);
      } catch (e) {
        console.error(e);
        setExercise({});
      } finally {
        setLoading(false);
      }
    })();
  }, [BASE]);

  // 대상 운동 찾기 (Vue created 훅의 이중 루프와 동일)
  const { title, target } = useMemo(() => {
    if (!exercise) return { title: "", target: null };
    let ai = 0;
    for (const [aKey, aVal] of Object.entries(exercise)) {
      let bi = 0;
      for (const [bKey, bVal] of Object.entries(aVal)) {
        if (exerciseType === ai && eid === bi) {
          return {
            title: bKey,
            target: bVal, // { description, video }
          };
        }
        bi++;
      }
      ai++;
    }
    return { title: "", target: null };
  }, [exercise, exerciseType, eid]);

  const goHome = () => (window.location.href = "/");
  const finish = () => {
    if (confirm("피트니스 담당자와 연결하시겠습니까?")) {
      window.location.href = "https://lebengrida.modoo.at/?link=bgu7jziy";
    } else {
      window.history.go(-2);
    }
  };

  return (
    <div className="content">
      <div className="wrap">
        <header>
          <div className="hd_inner">
            <div className="hd_tit">신체단련</div>
            <div className="hd_left">
              <a onClick={() => window.history.back()}>
                <i className="xi-angle-left-min" />
              </a>
            </div>
            <div className="hd_right">
              <a onClick={goHome}>
                <i className="xi-home-o" />
              </a>
            </div>
          </div>
        </header>

        <div className="inner">
          <div className="ct_banner">{loading ? "로딩 중..." : title}</div>

          <div className="ct_inner">
            <div className="ct_video_tit">
              <i className="xi-check-square"></i>영상의 동작을 따라 운동을 해보아요.
            </div>

            <div className="ct_video" data-aos="fade-up" data-aos-duration="1000">
              {target?.video ? (
                <video className="container" style={{ width: "100%" }} controls src={`${BASE}autobiography/${target.video}`} />
              ) : (
                <div>영상이 없습니다.</div>
              )}
            </div>

            <div className="ct_question" data-aos="fade-up" data-aos-duration="2000">
              <div>
                <div className="tit">
                  <p>Q</p>이 운동은?
                </div>
                <div className="sub_tit">
                  <p>{target?.description ?? "설명이 없습니다."}</p>
                </div>
              </div>

              <div>
                <div className="tit">
                  <p>Q</p>어떻게 사용하나요?
                </div>
                <div className="sub_tit">
                  <p>
                    <i className="xi-play" />
                    동영상을 재생합니다.
                  </p>
                  <p>
                    <i className="xi-focus-frame" />
                    동영상을 전체 화면으로 보여줍니다.
                  </p>
                  <p>
                    <i className="xi-pause" />
                    동영상을 중지합니다.
                  </p>
                  <p className="bg">
                    <i className="xi-check-circle-o" />
                    운동 진행 전 적당한 스트레칭을 하길 바랍니다.
                  </p>
                </div>
              </div>

              <button type="button" onClick={finish}>
                운동종료
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
