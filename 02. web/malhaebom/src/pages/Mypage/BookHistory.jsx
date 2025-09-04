import React, { useEffect, useMemo, useState } from "react";
import Background from "../Background/Background";
import API, { ensureUserKey } from "../../lib/api.js";

const DEBUG = true;

/** 표준 목록(표시 제목은 여기 기준) */
const baseStories = [
  { story_key: "mother_gloves",     story_title: "어머니의 벙어리 장갑" },
  { story_key: "father_wedding",    story_title: "아버지와 결혼식" },
  { story_key: "sons_bread",        story_title: "아들의 호빵" },
  { story_key: "grandma_banana",    story_title: "할머니와 바나나" },
  { story_key: "kkongdang_boribap", story_title: "꽁당 보리밥" },
];

/* ─────────── 유틸 ─────────── */
function normalizeSpace(s) {
  return String(s || "").replace(/\s+/g, " ").trim();
}
function normalizeKoreanTitle(s) {
  let x = normalizeSpace(s);
  x = x.replaceAll("병어리", "벙어리");
  x = x.replaceAll("어머니와", "어머니의");
  x = x.replaceAll("벙어리장갑", "벙어리 장갑");
  x = x.replaceAll("꽁당보리밥", "꽁당 보리밥");
  x = x.replaceAll("할머니와바나나", "할머니와 바나나");
  return normalizeSpace(x);
}
const titleToSlugBase = new Map(
  baseStories.map((b) => [normalizeKoreanTitle(b.story_title), b.story_key])
);
function toSlugFromAny(story_key_or_title, story_title_fallback = "") {
  const slugToTitle = new Map(baseStories.map((b) => [b.story_key, b.story_title]));
  const raw = normalizeSpace(story_key_or_title);
  if (slugToTitle.has(raw)) return raw; // 이미 슬러그

  const t1 = normalizeKoreanTitle(raw);
  const t2 = normalizeKoreanTitle(story_title_fallback);
  return titleToSlugBase.get(t1) || titleToSlugBase.get(t2) || raw;
}
function parseSqlUtc(s) {
  if (!s) return null;
  const m = String(s).match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})$/);
  if (!m) return null;
  const [, Y, M, D, h, m2, s2] = m;
  const dt = new Date(Date.UTC(+Y, +M - 1, +D, +h, +m2, +s2));
  return isNaN(dt.getTime()) ? null : dt;
}
function formatKst(dtUtc) {
  if (!dtUtc) return "";
  const k = new Date(dtUtc.getTime() + 9 * 60 * 60 * 1000);
  const pad = (n) => String(n).padStart(2, "0");
  return `${k.getFullYear()}-${pad(k.getMonth() + 1)}-${pad(k.getDate())} ${pad(k.getHours())}:${pad(k.getMinutes())}:${pad(k.getSeconds())}`;
}
function normalizeScores({ by_category, by_type, risk_bars, risk_bars_by_type }) {
  const getCorrect = (obj, key) => {
    const v = obj?.[key];
    if (v && typeof v === "object" && v.correct != null) return Number(v.correct) || 0;
    return null;
  };
  const fromRatio = (ratio) => {
    const r = Number(ratio);
    if (!Number.isFinite(r)) return null;
    if (r >= 0 && r <= 1) return Math.round((1 - r) * 4);
    return null;
  };
  const fromPoints = (p) => {
    const n = Number(p);
    if (!Number.isFinite(n)) return null;
    if (n >= 0 && n <= 8 && n % 2 === 0) return Math.round(n / 2);
    return null;
  };

  const A  = getCorrect(by_type, "직접화행") ?? fromRatio(risk_bars_by_type?.["직접화행"]) ?? fromPoints(risk_bars?.A)  ?? 0;
  const AI = getCorrect(by_type, "간접화행") ?? fromRatio(risk_bars_by_type?.["간접화행"]) ?? fromPoints(risk_bars?.AI) ?? 0;
  const B  = getCorrect(by_category, "B")   ?? getCorrect(by_category, "질문") ?? fromRatio(risk_bars?.["질문"]) ?? fromPoints(risk_bars?.B) ?? 0;
  const C  = getCorrect(by_category, "C")   ?? getCorrect(by_category, "단언") ?? fromRatio(risk_bars?.["단언"]) ?? fromPoints(risk_bars?.C) ?? 0;
  const D  = getCorrect(by_category, "D")   ?? getCorrect(by_category, "의례화") ?? fromRatio(risk_bars?.["의례화"]) ?? fromPoints(risk_bars?.D) ?? 0;

  return { scoreAD: A, scoreAI: AI, scoreB: B, scoreC: C, scoreD: D };
}
function rowToCardData(row) {
  const displayTime =
    (row?.client_kst || "").trim() ||
    formatKst(parseSqlUtc(row?.client_utc || ""));

  const scores = normalizeScores({
    by_category: row?.by_category || {},
    by_type: row?.by_type || {},
    risk_bars: row?.risk_bars || {},
    risk_bars_by_type: row?.risk_bars_by_type || {},
  });

  return {
    id: row.id,
    client_attempt_order: row.client_attempt_order,
    client_kst: displayTime,
    story_title: row.story_title,
    scores,
  };
}

/* ─────────── 상세 카드 ─────────── */
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
    <div style={{ background:"#fff", borderRadius:10, padding:20, marginTop:12, marginBottom:12, boxShadow:"0 6px 18px rgba(0,0,0,0.08)" }}>
      <div style={{ marginBottom: 20 }}>
        <div className="tit">총점</div>
        <div style={{ margin:"0 auto", textAlign:"center", borderRadius:10, backgroundColor:"white", padding:"20px 0", fontSize:18, fontWeight:700 }}>
          {total} / 40
        </div>
      </div>
      <div style={{ marginBottom: 20 }}>
        <div className="tit">인지능력</div>
        <div style={{ margin:"0 auto", textAlign:"center", borderRadius:10, backgroundColor:"white", padding:"20px 0" }}>
          <img src={isPassed ? "/drawable/speech_clear.png" : "/drawable/speech_fail.png"} style={{ width:"15%" }} />
        </div>
      </div>
      <div>
        <div className="tit">검사 결과 평가</div>
        <div style={{ padding:"12px 0", lineHeight:1.6, whiteSpace:"pre-line" }}>
          {isPassed ? okOpinion : opinions_result[lowIndex]}
        </div>
        {!isPassed && <div style={{ fontWeight:700, marginTop:6 }}>{opinions_guide[lowIndex]}</div>}
      </div>
    </div>
  );
}

/* ─────────── 메인 컴포넌트 ─────────── */
export default function BookHistory() {
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  const [openStoryId, setOpenStoryId] = useState(null);
  const [openRecordId, setOpenRecordId] = useState(null);

  const query = new URLSearchParams(window.location.search);
  const rawQ = (query.get("user_key") || "").trim();
  const userKeyFromQuery = rawQ && rawQ !== "guest" ? rawQ : "";

  const [groups, setGroups] = useState([]);
  const [loading, setLoading] = useState(true);

  const mergedStories = useMemo(() => {
    const slugToTitle = new Map(baseStories.map((b) => [b.story_key, b.story_title]));
    const merging = new Map();

    for (const g of groups) {
      const slug = toSlugFromAny(g.story_key, g.story_title);

      if (!merging.has(slug)) {
        merging.set(slug, {
          story_key: slug,
          story_title: slugToTitle.get(slug) || normalizeKoreanTitle(g.story_title || slug),
          records: [],
        });
      }
      const holder = merging.get(slug);
      for (const r of (g.records || [])) holder.records.push(rowToCardData(r));
    }

    const ordered = baseStories.map((b) => ({
      story_key: b.story_key,
      story_title: b.story_title,
      records: merging.get(b.story_key)?.records || [],
    }));
    for (const [slug, g] of merging.entries()) {
      if (!baseStories.some((b) => b.story_key === slug)) ordered.push(g);
    }

    for (const it of ordered) {
      it.records.sort((a, b) => {
        const ao = Number(a.client_attempt_order || 0);
        const bo = Number(b.client_attempt_order || 0);
        if (ao !== bo) return bo - ao;
        return String(b.id).localeCompare(String(a.id));
      });
    }

    if (DEBUG) {
      console.groupCollapsed("%c[BookHistory] mergedStories", "color:#0aa");
      console.log("groups(raw)", groups);
      console.log("ordered(final)", ordered);
      console.groupEnd();
      window.__STR_HISTORY__ = { groups, ordered };
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

        let userKey = userKeyFromQuery || (await ensureUserKey({ retries: 2, delayMs: 150 }));
        if (DEBUG) console.log("[BookHistory] userKey resolved =", userKey);

        // 디버그 변수는 무조건 박자(조기 리턴이어도)
        window.__STR_HISTORY_RAW__ = { stage: "userKey", userKey };

        if (!userKey || userKey === "guest") {
          setGroups([]);
          setLoading(false);
          window.__STR_HISTORY_RAW__ = { stage: "no-userkey", userKey };
          return;
        }

        const cfg = { params: { user_key: userKey }, headers: { "x-user-key": userKey } };
        if (DEBUG) console.log("[BookHistory] GET /str/history/all", cfg);

        const { data } = await API.get(`/str/history/all`, cfg);

        if (DEBUG) {
          console.groupCollapsed("%c[BookHistory] /str/history/all response", "color:#0a0");
          console.log("status", data?.ok, "groups#", data?.data?.length);
          console.log("data", data);
          console.groupEnd();
        }
        // 성공/실패 상관없이 원본을 전역으로
        window.__STR_HISTORY_RAW__ = data;

        if (data?.ok) setGroups(data.data || []);
        else setGroups([]);
      } catch (err) {
        console.error("history/all 에러:", err);
        setGroups([]);
        window.__STR_HISTORY_RAW__ = { stage: "error", error: String(err?.message || err) };
      } finally {
        setLoading(false);
      }
    })();
  }, [userKeyFromQuery]);

  return (
    <div className="content">
      {windowWidth > 1100 && <Background />}
      <div className="wrap" style={{ maxWidth:520, margin:"0 auto", padding:"80px 20px", fontFamily:"Pretendard-Regular" }}>
        <h2 style={{ textAlign:"center", marginBottom:10, fontFamily:"ONE-Mobile-Title", fontSize:32 }}>
          동화 화행검사 결과
        </h2>

        {loading ? (
          <div style={{ textAlign:"center", padding:"40px 0", color:"#666" }}>불러오는 중...</div>
        ) : (
          <div style={{ display:"flex", flexDirection:"column", gap:15, marginTop:10 }}>
            {mergedStories.map((b, idx) => {
              const storyId = b.story_key || idx;
              const opened = openStoryId === storyId;
              const records = b.records || [];
              return (
                <div key={storyId} style={{ background:"#fff", borderRadius:12, boxShadow:"0 4px 12px rgba(0,0,0,0.1)", overflow:"hidden" }}>
                  <div
                    onClick={() => { setOpenStoryId(opened ? null : storyId); setOpenRecordId(null); }}
                    style={{ padding:"18px 20px", fontSize:18, fontWeight:700, cursor:"pointer", display:"flex", justifyContent:"space-between", alignItems:"center" }}
                  >
                    <span>{b.story_title}</span>
                    <span style={{ fontSize:20 }}>{opened ? "▲" : "▼"}</span>
                  </div>

                  {opened && (
                    <div style={{ padding:"14px 20px", borderTop:"1px solid #eee" }}>
                      {records.length === 0 ? (
                        <div style={{ color:"#888", padding:"8px 0" }}>아직 결과가 없습니다.</div>
                      ) : (
                        records.map((r) => {
                          const selected = openRecordId === r.id;
                          return (
                            <div key={r.id}>
                              <div
                                onClick={() => setOpenRecordId(selected ? null : r.id)}
                                style={{ background:"#fafafa", borderRadius:8, padding:"12px 16px", display:"flex", justifyContent:"space-between", alignItems:"center", cursor:"pointer" }}
                              >
                                <span style={{ fontSize:15, color:"#333" }}>
                                  {r.client_kst || ""}
                                  <span style={{ background:"#eee", padding:"2px 8px", borderRadius:8, fontSize:13, marginLeft:8, fontWeight:600, color:"#333" }}>
                                    {r.client_attempt_order ?? "?"}회차
                                  </span>
                                </span>
                              </div>
                              {selected && <div style={{ marginTop:12 }}><ResultDetailCard data={r} /></div>}
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
