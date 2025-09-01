// src/pages/BookHistory.jsx
import React, { useEffect, useMemo, useState } from "react";
import Background from "../Background/Background";
import axios from "axios";
import { useLocation } from "react-router-dom";

const API = axios.create({
  baseURL: "http://localhost:3001",
  withCredentials: true,
  headers: { "Content-Type": "application/json" },
});

function useQuery() {
  const { search } = useLocation();
  return useMemo(() => new URLSearchParams(search), [search]);
}

// ✅ DB가 비어있어도 보여줄 기본 동화 목록(실제 story_key에 맞게 수정 가능)
const baseStories = [
  { story_key: "mother_gloves",  story_title: "어머니의 병어리 장갑" },
  { story_key: "father_wedding", story_title: "아버지와 결혼식" },
  { story_key: "sons_bread",     story_title: "아들의 호빵" },
  { story_key: "grandma_banana", story_title: "할머니와 바나나" },
];

/* ===========================
 * 유틸
 * =========================== */
const clamp01 = (v) => (v < 0 ? 0 : v > 1 ? 1 : v);
const toNum = (v, d = 0) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : d;
};
const scoreColor = (rate) => {
  if (rate >= 0.9) return "#4CAF50";
  if (rate >= 0.8) return "#8BC34A";
  if (rate >= 0.6) return "#FFC107";
  if (rate >= 0.4) return "#FF9800";
  return "#F44336";
};
const levelBadge = (value01) => {
  if (value01 >= 0.75) return { text: "매우 주의", color: "#F44336" };
  if (value01 >= 0.5)  return { text: "주의",     color: "#FF9800" };
  if (value01 >= 0.25) return { text: "보통",     color: "#FFC107" };
  return { text: "양호", color: "#4CAF50" };
};

/* ===========================
 * 뷰 컴포넌트
 * =========================== */
function RiskBar({ label, value }) {
  const badge = levelBadge(value);
  return (
    <div style={{ marginBottom: 18 }}>
      <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center", marginBottom:8 }}>
        <div style={{ fontWeight: 600, color: "#222" }}>{label}</div>
        <div style={{
          fontSize: 12, fontWeight: 700, color: badge.color,
          border: `2px solid ${badge.color}`, borderRadius: 999,
          padding: "4px 10px", background: "#fff"
        }}>
          {badge.text}
        </div>
      </div>

      <div style={{ position:"relative", height:6, borderRadius:999, background:"#e6f3ea" }}>
        <div style={{
          position:"absolute", left:0, top:0, bottom:0, borderRadius:999,
          width:`${Math.round(value*100)}%`,
          background:"linear-gradient(90deg, #2fb171 0%, #fda543 50%, #ff5a5a 100%)"
        }}/>
        <div style={{
          position:"absolute", top:-6, width:16, height:16, borderRadius:999,
          right:`calc(${100 - Math.round(value*100)}% - 8px)`,
          background:"#fff", border:"2px solid #d0d0d0"
        }}/>
      </div>
    </div>
  );
}

function ResultSkeleton() {
  return (
    <div style={{
      background:"#fff", borderRadius:16, boxShadow:"0 6px 18px rgba(0,0,0,0.08)",
      padding:20, marginTop:12
    }}>
      <div style={{ height:14, width:140, background:"#eee", borderRadius:8, margin:"0 auto 12px" }}/>
      <div style={{ height:12, width:200, background:"#eee", borderRadius:8, margin:"0 auto 24px" }}/>
      <div style={{ display:"flex", justifyContent:"center", marginBottom:18 }}>
        <div style={{ width:160, height:160, borderRadius:"50%", border:"10px solid #eee" }}/>
      </div>
      {[1,2,3,4].map(i=>(
        <div key={i} style={{ height:22, background:"#f3f3f3", borderRadius:6, marginBottom:12 }}/>
      ))}
    </div>
  );
}

function ResultDetailCard({ data, fallback }) {
  // data가 아직 없을 때는 skeleton, 실패 시 fallback(요약 기반) 사용
  if (!data && !fallback) return <ResultSkeleton />;
  const src = data || fallback;

  const story_title = src?.story_title ?? null;
  const client_attempt_order = src?.client_attempt_order ?? null;
  const client_kst = src?.client_kst ?? null;
  const score = toNum(src?.score, 0);
  const total = toNum(src?.total, 0);
  const rate = total > 0 ? score / total : 0;

  // risk_bars (상세 성공 시: 서버 데이터 사용 / 실패 시: 표시용 기본값)
  const risk_bars_by_type = src?.risk_bars_by_type;
  const risk_bars = src?.risk_bars;
  const bars = (() => {
    if (risk_bars_by_type && typeof risk_bars_by_type === "object" && !Array.isArray(risk_bars_by_type)) {
      const labels = ["요구", "질문", "단언", "의례화"];
      return labels.map((k) => {
        let v = toNum(risk_bars_by_type[k], 0);
        if (v > 1) v = v / 100;
        return { label: k, value: clamp01(v) };
      });
    }
    if (Array.isArray(risk_bars)) {
      return risk_bars.map((it) => {
        let v = toNum(it.value, 0);
        if (v > 1) v = v / 100;
        return { label: it.label ?? "", value: clamp01(v) };
      });
    }
    // 실패/없음 → 임시 기본값
    return [
      { label: "요구",   value: 0.5 },
      { label: "질문",   value: 0.6 },
      { label: "단언",   value: 0.6 },
      { label: "의례화", value: 0.5 },
    ];
  })();

  // 평가 패널(간단 로직)
  const panels = (() => {
    const list = [];
    if (rate < 0.4) {
      list.push({ tone: "danger", title: "인지 기능 저하가 의심됩니다.", desc: "전문가와 상담을 권장합니다." });
    } else if (rate < 0.6) {
      list.push({ tone: "warn", title: "주의가 필요합니다.", desc: "추가 학습과 점검을 진행하세요." });
    }
    list.push({
      tone: "neutral",
      title: rate >= 0.6 ? "전반적으로 양호합니다." : "전반적으로 보통 수준입니다.",
      desc: "필요 시 추가 학습으로 안정적 이해를 유지하세요.",
    });
    return list;
  })();

  const panelStyle = {
    danger:  { border: "1px solid #ffb3b3", background: "#ffecec", color: "#c62828" },
    warn:    { border: "1px solid #ffd8a8", background: "#fff5e6", color: "#b36b00" },
    neutral: { border: "1px solid #e8edf1", background: "#f7fafc", color: "#2c3e50" },
  };

  return (
    <div>
      {/* 칩 */}
      <div style={{ display:"flex", gap:8, marginBottom:12 }}>
        <div style={{
          background:"#eef3ff", color:"#2C49D8", fontWeight:700, borderRadius:999,
          padding:"6px 10px", fontSize:13, border:"1px solid #dfe6fb"
        }}>
          {client_attempt_order ? `${client_attempt_order}회차` : "—"}
        </div>
        <div style={{
          background:"#f4f6f8", color:"#333", borderRadius:999,
          padding:"6px 10px", fontSize:13, border:"1px solid #e6eaee"
        }}>
          {client_kst ?? "시간 정보 없음"}
        </div>
      </div>

      <div style={{
        background:"#fff", borderRadius:16, boxShadow:"0 6px 18px rgba(0,0,0,0.08)",
        padding:20, marginBottom:18
      }}>
        <div style={{ textAlign:"center", fontWeight:800, fontSize:20, marginBottom:6 }}>
          인지검사 결과
        </div>
        <div style={{ textAlign:"center", color:"#777", marginBottom:18, fontSize:14 }}>
          검사 결과 요약입니다{story_title ? ` — ${story_title}` : ""}.
        </div>

        {/* 원형 점수 */}
        <div style={{ display:"flex", justifyContent:"center", marginBottom:18 }}>
          <div style={{
            width:160, height:160, borderRadius:"50%",
            border:`10px solid ${scoreColor(rate)}`,
            display:"flex", alignItems:"center", justifyContent:"center",
            color:scoreColor(rate), fontWeight:900, fontSize:36, lineHeight:1.1
          }}>
            <div style={{ textAlign:"center" }}>
              {score}
              <div style={{ fontSize:16, fontWeight:800, color:"#ff6b6b" }}>/ {total}</div>
            </div>
          </div>
        </div>

        {/* 4개 바 */}
        <div>
          {bars.map((b, i) => (
            <RiskBar key={`${b.label}-${i}`} label={b.label} value={b.value} />
          ))}
        </div>
      </div>

      {/* 평가 패널 */}
      <div style={{ marginTop:8 }}>
        <div style={{ fontWeight:800, fontSize:18, marginBottom:12 }}>검사 결과 평가</div>
        {panels.map((p, i) => (
          <div key={i} style={{ ...(panelStyle[p.tone] || panelStyle.neutral), borderRadius:12, padding:14, marginBottom:10 }}>
            <div style={{ fontWeight:800, marginBottom:6 }}>{p.title}</div>
            <div style={{ color:"#556270" }}>{p.desc}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ===========================
 * 페이지
 * =========================== */
export default function BookHistory() {
  const query = useQuery();
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);

  // 상태
  const [status, setStatus] = useState("idle"); // idle | loading | ok | error
  const [userKey, setUserKey] = useState("");
  const [groups, setGroups] = useState([]);                 // [{story_key, story_title, records: [...] }]
  const [openStoryId, setOpenStoryId] = useState(null);     // 열린 동화
  const [openRecordId, setOpenRecordId] = useState(null);   // 열린 레코드
  const [detailCache, setDetailCache] = useState({});       // { [id]: detail or null }
  const [detailLoading, setDetailLoading] = useState({});   // { [id]: true/false }
  const [errorMsg, setErrorMsg] = useState("");

  useEffect(() => {
    const onResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);

  // user_key 획득 (쿼리 → /userLogin/me). user_key 없어도 기본 목록은 먼저 보임.
  useEffect(() => {
    (async () => {
      const qUser = (query.get("user_key") || "").trim();
      if (qUser) { setUserKey(qUser); return; }
      try {
        const { data } = await API.get("/userLogin/me");
        const k = data?.user?.user_key;
        if (k) setUserKey(k);
      } catch (_) {}
    })();
  }, [query]);

  // 전체 히스토리 로드 (userKey 있을 때)
  useEffect(() => {
    (async () => {
      if (!userKey) { setStatus("ok"); setGroups([]); return; }
      setStatus("loading"); setErrorMsg("");
      try {
        const { data } = await API.get("/str/history/all", { params: { user_key: userKey } });
        if (data?.ok && Array.isArray(data.data)) {
          setGroups(data.data);
          setStatus("ok");
        } else {
          setGroups([]); setStatus("ok");
        }
      } catch (e) {
        console.error("[BookHistory] fetch error:", e);
        setErrorMsg("데이터를 불러오는 중 오류가 발생했습니다.");
        setGroups([]); setStatus("error");
      }
    })();
  }, [userKey]);

  // 기본 목록 + DB 결과 머지
  const mergedList = useMemo(() => {
    const map = new Map();
    groups.forEach((g) => map.set(g.story_key, g));
    return baseStories.map((b) => {
      const found = map.get(b.story_key);
      if (found) {
        return {
          story_key: b.story_key,
          story_title: found.story_title || b.story_title,
          records: Array.isArray(found.records) ? found.records : [],
        };
      }
      return { story_key: b.story_key, story_title: b.story_title, records: [] };
    });
  }, [groups]);

  // 레코드 클릭 → 로딩표시 → /str/:id → 캐시 → 표시
  const handleRecordClick = async (recordId, fallback) => {
    // 토글 동작
    setOpenRecordId((prev) => (prev === recordId ? null : recordId));
    if (openRecordId === recordId) return; // 닫는 동작이면 더 안 함

    if (detailCache[recordId]) return;     // 이미 있음
    if (detailLoading[recordId]) return;   // 가져오는 중

    setDetailLoading((m) => ({ ...m, [recordId]: true }));
    try {
      const { data } = await API.get(`/str/${recordId}`);
      if (data?.ok && data.data) {
        setDetailCache((m) => ({ ...m, [recordId]: data.data }));
      } else {
        // 실패/없음 → 요약 기반 fallback만 보여주도록 null 캐시
        setDetailCache((m) => ({ ...m, [recordId]: null }));
      }
    } catch (e) {
      console.error("[BookHistory] load detail error:", e);
      setDetailCache((m) => ({ ...m, [recordId]: null }));
    } finally {
      setDetailLoading((m) => ({ ...m, [recordId]: false }));
    }
  };

  const getScoreColor = (score, total) => {
    const rate = total > 0 ? score / total : 0;
    if (rate >= 0.9) return "#4CAF50";
    if (rate >= 0.8) return "#FFC107";
    return "#F44336";
  };

  return (
    <div className="content">
      {windowWidth > 1100 && <Background />}

      <div className="wrap" style={{ maxWidth:520, margin:"0 auto", padding:"80px 20px", fontFamily:"Pretendard-Regular" }}>
        <h2 style={{ textAlign:"center", marginBottom:"10px", fontFamily:"ONE-Mobile-Title", fontSize:"32px" }}>
          동화 화행검사 결과
        </h2>

        {status === "loading" && (
          <p style={{ textAlign:"center", color:"#888", fontSize:"16px" }}>불러오는 중…</p>
        )}
        {status === "error" && (
          <p style={{ textAlign:"center", color:"#F44336", fontSize:"16px" }}>
            {errorMsg || "오류가 발생했습니다."}
          </p>
        )}

        {["ok","loading","error","idle"].includes(status) && (
          <div style={{ display:"flex", flexDirection:"column", gap:"15px", marginTop:"10px" }}>
            {mergedList.map((g, idx) => {
              const storyId = g.story_key || idx;
              const opened = openStoryId === storyId;
              return (
                <div key={storyId} style={{ background:"#fff", borderRadius:"12px", boxShadow:"0 4px 12px rgba(0,0,0,0.1)", overflow:"hidden" }}>
                  {/* 헤더 */}
                  <div
                    onClick={() => setOpenStoryId(opened ? null : storyId)}
                    style={{ padding:"18px 20px", fontSize:"18px", fontWeight:700, cursor:"pointer", display:"flex", justifyContent:"space-between", alignItems:"center" }}
                  >
                    <span>{g.story_title || g.story_key || "제목 없음"}</span>
                    <span style={{ fontSize:"20px" }}>{opened ? "▲" : "▼"}</span>
                  </div>

                  {/* 바디 */}
                  {opened && (
                    <div style={{ padding:"14px 20px", borderTop:"1px solid #eee" }}>
                      {Array.isArray(g.records) && g.records.length > 0 ? (
                        <div style={{ display:"flex", flexDirection:"column", gap:"12px" }}>
                          {g.records.map((r) => {
                            const selected = openRecordId === r.id;
                            const color = getScoreColor(toNum(r.score), toNum(r.total));
                            const loading = !!detailLoading[r.id];
                            const detail = detailCache[r.id];
                            return (
                              <div key={r.id}>
                                {/* 요약 행 */}
                                <div
                                  onClick={() => handleRecordClick(r.id, r)}
                                  style={{
                                    background:"#fafafa", borderRadius:"8px", padding:"12px 16px",
                                    display:"flex", justifyContent:"space-between", alignItems:"center",
                                    cursor:"pointer"
                                  }}
                                >
                                  <span style={{ fontSize:"15px", color:"#333" }}>
                                    {r.client_kst || r.client_utc || "-"}
                                    <span style={{ background:"#eee", padding:"2px 8px", borderRadius:"8px", fontSize:"13px", marginLeft:"8px", fontWeight:600, color:"#333" }}>
                                      {r.client_attempt_order ? `${r.client_attempt_order}회차` : "회차 미정"}
                                    </span>
                                  </span>
                                  <span style={{ fontSize:"16px", fontWeight:"bold", color }}>
                                    {r.score ?? 0}점
                                  </span>
                                </div>

                                {/* 상세 */}
                                {selected && (
                                  <div style={{ marginTop:12 }}>
                                    {loading
                                      ? <ResultSkeleton/>
                                      : <ResultDetailCard
                                          data={detail}                 // 성공 시 상세
                                          fallback={{
                                            // 실패 시 최소 정보로라도 결과 카드 구성
                                            story_title: g.story_title,
                                            client_attempt_order: r.client_attempt_order,
                                            client_kst: r.client_kst || r.client_utc,
                                            score: r.score, total: r.total,
                                          }}
                                        />
                                    }
                                  </div>
                                )}
                              </div>
                            );
                          })}
                        </div>
                      ) : (
                        <p style={{ color:"#8891A0", fontSize:"15px", textAlign:"center", margin:"6px 0 4px" }}>
                          저장된 검사 기록이 없습니다.
                        </p>
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
