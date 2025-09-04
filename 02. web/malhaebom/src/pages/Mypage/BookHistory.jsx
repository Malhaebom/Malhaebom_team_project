// 02. web/malhaebom/src/pages/Mypage/BookHistory.jsx
import React, { useEffect, useMemo, useState } from "react";
import Background from "../Background/Background";
import API, { ensureUserKey } from "../../lib/api.js";

const baseStories = [
  { story_key: "mother_gloves",     story_title: "어머니의 병어리 장갑" },
  { story_key: "father_wedding",    story_title: "아버지와 결혼식" },
  { story_key: "sons_bread",        story_title: "아들의 호빵" },
  { story_key: "grandma_banana",    story_title: "할머니와 바나나" },
  { story_key: "kkongdang_boribap", story_title: "꽁당 보리밥" },
];

function toKstString(utcStr) {
  try {
    if (!utcStr) return "";
    // 'YYYY-MM-DD HH:mm:ss' → 'YYYY-MM-DDTHH:mm:ssZ'
    const iso = utcStr.includes("T") ? utcStr : utcStr.replace(" ", "T") + "Z";
    const d = new Date(iso);
    if (isNaN(d.getTime())) return utcStr;
    const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
    const pad = (n) => String(n).padStart(2, "0");
    return `${kst.getFullYear()}-${pad(kst.getMonth() + 1)}-${pad(kst.getDate())} ${pad(kst.getHours())}:${pad(kst.getMinutes())}:${pad(kst.getSeconds())}`;
  } catch {
    return utcStr || "";
  }
}

function rowToCardData(row) {
  const rb = row?.risk_bars || {};
  const bc = row?.by_category || {};

  const toInt = (v, d = 0) => {
    const n = Number(v);
    return Number.isFinite(n) ? n : d;
  };
  
  // 앱/웹 호환: rb 값이
  // - 앱: risk 0~1 → correct = round((1 - risk)*4)
  // - 웹(구): 0~8(=correct*2) → correct = round(val/2)
  const fromRiskBar = (val) => {
    const n = Number(val);
    if (!Number.isFinite(n) || n < 0) return null;
    if (n <= 1.5) { // risk(0~1)로 판단
      return Math.round((1 - Math.max(0, Math.min(1, n))) * 4);
    }
    // 0~8 점수(=correct*2)
    return Math.round(n / 2);
  };

  let scoreAD = fromRiskBar(rb.A);
  let scoreAI = fromRiskBar(rb.AI);
  let scoreB  = fromRiskBar(rb.B);
  let scoreC  = fromRiskBar(rb.C);
  let scoreD  = fromRiskBar(rb.D);

  if (scoreAD === null && bc.A?.correct != null)  scoreAD = toInt(bc.A.correct, 0);
  if (scoreAI === null && bc.AI?.correct != null) scoreAI = toInt(bc.AI.correct, 0);
  if (scoreB  === null && bc.B?.correct != null)  scoreB  = toInt(bc.B.correct, 0);
  if (scoreC  === null && bc.C?.correct != null)  scoreC  = toInt(bc.C.correct, 0);
  if (scoreD  === null && bc.D?.correct != null)  scoreD  = toInt(bc.D.correct, 0);

  scoreAD = toInt(scoreAD, 0);
  scoreAI = toInt(scoreAI, 0);
  scoreB  = toInt(scoreB, 0);
  scoreC  = toInt(scoreC, 0);
  scoreD  = toInt(scoreD, 0);

  const client_kst = row?.client_kst || "";
  const displayTime = client_kst?.trim()
    ? client_kst
    : toKstString(row?.client_utc || "");

  return {
    id: row.id,
    client_attempt_order: row.client_attempt_order,
    client_kst: displayTime,
    story_title: row.story_title,
    scores: { scoreAD, scoreAI, scoreB, scoreC, scoreD },
  };
}

function ResultDetailCard({ data }) {
  if (!data) return null;

  const { scoreAD, scoreAI, scoreB, scoreC, scoreD } = data.scores;

  const sAD = Number(scoreAD) * 2;
  const sAI = Number(scoreAI) * 2;
  const sB  = Number(scoreB)  * 2;
  const sC  = Number(scoreC)  * 2;
  const sD  = Number(scoreD)  * 2;

  const arr = [sAD, sAI, sB, sC, sD];
  const total = arr.reduce((a, b) => a + b, 0);
  const minScore = Math.min(...arr);
  const lowIndex = arr.indexOf(minScore);
  const isPassed = total >= 28;

  const okOpinion =
    "당신은 모든 영역(직접화행, 간접화행, 질문화행, 단언화행, 의례화화행)에 좋은 점수를 얻었습니다. 현재는 인지기능 정상입니다.\n하지만 유지하기 위해서 꾸준한 학습과 교육을 통한 관리가 필요합니다.";

  const opinions_result = [
    "당신은 직접화행의 점수가 낮습니다.\n기본적인 대화의 문장인식 즉 문장에 내포된 의미에 대한 이해력이 부족하고 동화에 있는 인물들이 나누는 대화들에 대한 인지능력이 조금 부족해 보입니다.\n선생님과의 프로그램을 통한 동화 인물들에 대한 학습으로 점수를 올릴 수 있습니다.",
    "당신은 간접화행의 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 대화에 대한 이해력이 부족하고 동화책 내용의 간접적 질문에 대한 듣기의 인지능력이 조금 부족해보입니다.\n선생님과의 프로그램을 통한 대화 응용능력 학습으로 점수를 올릴 수 있습니다.",
    "당신은 질문화행 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 인물들이 대화에서 주고 받는 정보에 대한 판단에 대한 인지능력이 부족해보입니다.\n선생님과의 프로그램을 통한 대화정보파악학습으로 점수를 올릴수 있습니다.",
    "당신은 단언화행의 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 동화에서 대화하는 인물들의 말에 대한 의도파악과 관련하여 인지능력이 부족해보입니다.\n선생님과의 프로그램을 통해 인물대사 의도파악학습으로 점수를 올릴 수 있습니다.",
    "당신은 의례화화행 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 동화에서 인물들이 상황에 맞는 자신의 감정을 표현하는 말에 대한 인지능력이 부족해보입니다.\n선생님과의 프로그램을 통해  인물들의 상황 및 정서 파악 학습으로 점수를 올릴 수 있습니다.",
  ];

  const opinions_guide = [
    "A-요구(직접)가 부족합니다.",
    "A-요구(간접)가 부족합니다.",
    "B-질문이 부족합니다.",
    "C-단언이 부족합니다.",
    "D-의례화가 부족합니다.",
  ];

  return (
    <div style={{ background: "#fff", borderRadius: "10px", padding: "20px", marginTop: 12, marginBottom: 12, boxShadow: "0 6px 18px rgba(0,0,0,0.08)" }}>
      <div style={{ marginBottom: 20 }}>
        <div className="tit">총점</div>
        <div style={{ margin: "0 auto", textAlign: "center", borderRadius: "10px", backgroundColor: "white", padding: "20px 0", fontSize: 18, fontWeight: 700 }}>
          {total} / 40
        </div>
      </div>

      <div style={{ marginBottom: 20 }}>
        <div className="tit">인지능력</div>
        <div style={{ margin: "0 auto", textAlign: "center", borderRadius: "10px", backgroundColor: "white", padding: "20px 0" }}>
          <img src={isPassed ? "/drawable/speech_clear.png" : "/drawable/speech_fail.png"} style={{ width: "15%" }} />
        </div>
      </div>

      <div>
        <div className="tit">검사 결과 평가</div>
        <div style={{ padding: "12px 0", lineHeight: 1.6, whiteSpace: "pre-line" }}>
          {isPassed ? okOpinion : opinions_result[lowIndex]}
        </div>
        {!isPassed && <div style={{ fontWeight: 700, marginTop: 6 }}>{opinions_guide[lowIndex]}</div>}
      </div>
    </div>
  );
}

export default function BookHistory() {
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  const [openStoryId, setOpenStoryId] = useState(null);
  const [openRecordId, setOpenRecordId] = useState(null);

  const query = new URLSearchParams(window.location.search);
  const userKeyFromQuery = (query.get("user_key") || "").trim();

  const [groups, setGroups] = useState([]);
  const [loading, setLoading] = useState(true);

  const mergedStories = useMemo(() => {
    const map = new Map(groups.map(g => [g.story_key, g]));
    const ordered = baseStories.map(b => {
      const g = map.get(b.story_key);
      return {
        story_key: b.story_key,
        story_title: g?.story_title || b.story_title,
        records: (g?.records || []).map(rowToCardData),
      };
    });
    for (const [k, g] of map.entries()) {
      const exists = baseStories.some(b => b.story_key === k);
      if (!exists) {
        ordered.push({
          story_key: g.story_key,
          story_title: g.story_title || g.story_key,
          records: (g.records || []).map(rowToCardData),
        });
      }
    }
    return ordered;
  }, [groups]);

  useEffect(() => {
    const onResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);

  useEffect(() => {
    (async () => {
      try {
        setLoading(true);

        // user_key 확보
        let userKey = userKeyFromQuery && userKeyFromQuery !== "guest"
          ? userKeyFromQuery
          : await ensureUserKey({ retries: 2, delayMs: 150 });

        if (!userKey) {
          setGroups([]);
          setLoading(false);
          return;
        }

        // 항상 params + 헤더로 user_key 명시 (쿠키 의존 최소화)
        const { data } = await API.get(`/str/history/all`, {
          params: { user_key: userKey },
          headers: { "x-user-key": userKey },
        });

        if (data?.ok) {
          setGroups(data.data || []);
        } else {
          console.error("history/all 실패:", data);
          setGroups([]);
        }
      } catch (err) {
        console.error("history/all 에러:", err);
        setGroups([]);
      } finally {
        setLoading(false);
      }
    })();
  }, [userKeyFromQuery]);

  return (
    <div className="content">
      {windowWidth > 1100 && <Background />}

      <div className="wrap" style={{ maxWidth: 520, margin: "0 auto", padding: "80px 20px", fontFamily: "Pretendard-Regular" }}>
        <h2 style={{ textAlign: "center", marginBottom: 10, fontFamily: "ONE-Mobile-Title", fontSize: 32 }}>
          동화 화행검사 결과
        </h2>

        {loading ? (
          <div style={{ textAlign: "center", padding: "40px 0", color: "#666" }}>
            불러오는 중...
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: 15, marginTop: 10 }}>
            {mergedStories.map((b, idx) => {
              const storyId = b.story_key || idx;
              const opened = openStoryId === storyId;
              const records = b.records || [];

              return (
                <div key={storyId} style={{ background: "#fff", borderRadius: 12, boxShadow: "0 4px 12px rgba(0,0,0,0.1)", overflow: "hidden" }}>
                  <div
                    onClick={() => {
                      setOpenStoryId(opened ? null : storyId);
                      setOpenRecordId(null);
                    }}
                    style={{ padding: "18px 20px", fontSize: 18, fontWeight: 700, cursor: "pointer", display: "flex", justifyContent: "space-between", alignItems: "center" }}
                  >
                    <span>{b.story_title}</span>
                    <span style={{ fontSize: 20 }}>{opened ? "▲" : "▼"}</span>
                  </div>

                  {opened && (
                    <div style={{ padding: "14px 20px", borderTop: "1px solid #eee" }}>
                      {records.length === 0 ? (
                        <div style={{ color: "#888", padding: "8px 0" }}>
                          아직 결과가 없습니다.
                        </div>
                      ) : (
                        records.map((r) => {
                          const selected = openRecordId === r.id;
                          return (
                            <div key={r.id}>
                              <div
                                onClick={() => setOpenRecordId(selected ? null : r.id)}
                                style={{ background: "#fafafa", borderRadius: 8, padding: "12px 16px", display: "flex", justifyContent: "space-between", alignItems: "center", cursor: "pointer" }}
                              >
                                <span style={{ fontSize: 15, color: "#333" }}>
                                  {r.client_kst || ""}
                                  <span style={{ background: "#eee", padding: "2px 8px", borderRadius: 8, fontSize: 13, marginLeft: 8, fontWeight: 600, color: "#333" }}>
                                    {r.client_attempt_order ?? "?"}회차
                                  </span>
                                </span>
                              </div>

                              {selected && (
                                <div style={{ marginTop: 12 }}>
                                  <ResultDetailCard data={r} />
                                </div>
                              )}
                            </div>
                          );
                        })
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
