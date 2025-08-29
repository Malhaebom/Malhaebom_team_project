import React, { useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import AOS from "aos";
import "aos/dist/aos.css";

export default function ExerciseList() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const BASE = import.meta.env.BASE_URL || "/";

  // 쿼리 파라미터: exerciseType (-1 = 전체)
  const initialType = Number(searchParams.get("exerciseType") ?? "-1");
  const [exerciseType, setExerciseType] = useState(initialType);

  const [exercise, setExercise] = useState(null); // 전체 JSON (object)
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    AOS.init();
  }, []);

  // 기본 파라미터 강제(-1) — 원본 beforeMount와 동일 동작
  useEffect(() => {
    if (!searchParams.get("exerciseType")) {
      setSearchParams({ exerciseType: "-1" }, { replace: true });
      setExerciseType(-1);
    }
  }, [searchParams, setSearchParams]);

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

  // 선택 변경 → 쿼리 반영 + 상태 갱신
  const onChangeSelect = (e) => {
    const val = Number(e.target.value);
    setExerciseType(val);
    setSearchParams({ exerciseType: String(val) });
  };

  const goToExerciseDo = (typeIdx, eid) => {
    navigate(`/exercise/do?exerciseType=${typeIdx}&eid=${eid}`);
  };

  const goHome = () => (window.location.href = "/");

  // 렌더링용 리스트 만들기 (Vue의 중첩 v-for 로직 대응)
  const flatList = useMemo(() => {
    if (!exercise) return [];
    const out = [];
    let ai = 0;
    for (const [aKey, aVal] of Object.entries(exercise)) {
      let bi = 0;
      for (const [bKey, bVal] of Object.entries(aVal)) {
        // exerciseType 필터: -1(전체) 또는 타입 일치
        if (exerciseType === -1 || exerciseType === ai) {
          out.push({
            typeIdx: ai,
            eid: bi,
            title: bKey,
            description: bVal?.description ?? "",
          });
        }
        bi++;
      }
      ai++;
    }
    return out;
  }, [exercise, exerciseType]);

  return (
    <div className="content">
      <div className="wrap">
        <header>
          <div className="hd_inner">
            <div className="hd_tit">신체단련</div>
            <div className="hd_left">
              <a onClick={goHome}>
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
          <select className="select" value={exerciseType} onChange={onChangeSelect}>
            <option disabled value={-99}>
              분류를 선택해 주세요
            </option>
            <option value={-1}>전체</option>
            <option value={0}>운동전 스트레칭</option>
            <option value={1}>유산소 운동</option>
            <option value={2}>근력 운동</option>
            <option value={3}>운동후 스트레칭</option>
          </select>

          <div className="ct_body ct_inner" data-aos="fade-up" data-aos-duration="1000">
            {loading && <p>로딩 중...</p>}
            {!loading &&
              flatList.map((item, idx) => (
                <div key={`${item.typeIdx}-${item.eid}-${idx}`}>
                  <div className="tit">{item.title}</div>
                  <p>{item.description}</p>
                  <button type="button" onClick={() => goToExerciseDo(item.typeIdx, item.eid)}>
                    시작하기
                  </button>
                </div>
              ))}
            {!loading && flatList.length === 0 && <p>목록이 없습니다.</p>}
          </div>
        </div>
      </div>
    </div>
  );
}
