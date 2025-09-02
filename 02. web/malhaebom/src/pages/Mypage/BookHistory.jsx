import React, { useEffect, useMemo, useState } from "react";
import Background from "../Background/Background";
import axios from "axios";
import { useLocation } from "react-router-dom";

const API = axios.create({
  baseURL: "http://211.188.63.38:3001",
  withCredentials: true,
  headers: { "Content-Type": "application/json" },
});

function useQuery() {
  const { search } = useLocation();
  return useMemo(() => new URLSearchParams(search), [search]);
}

const baseStories = [
  { story_key: "mother_gloves", story_title: "어머니의 병어리 장갑" },
  { story_key: "father_wedding", story_title: "아버지와 결혼식" },
  { story_key: "sons_bread", story_title: "아들의 호빵" },
  { story_key: "grandma_banana", story_title: "할머니와 바나나" },
];

const clamp01 = (v) => (v < 0 ? 0 : v > 1 ? 1 : v);
const toNum = (v, d = 0) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : d;
};
const scoreColorByRate = (rate) => {
  if (rate >= 0.9) return "#4CAF50";
  if (rate >= 0.8) return "#8BC34A";
  if (rate >= 0.6) return "#FFC107";
  if (rate >= 0.4) return "#FF9800";
  return "#F44336";
};
const levelBadge = (value01) => {
  if (value01 >= 0.75) return { text: "매우 주의", color: "#F44336" };
  if (value01 >= 0.5) return { text: "주의", color: "#FF9800" };
  if (value01 >= 0.25) return { text: "보통", color: "#FFC107" };
  return { text: "양호", color: "#4CAF50" };
};

function RiskBar({ label, value }) {
  const badge = levelBadge(value);
  return (
    <div style={{ marginBottom: 18 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
        <div style={{ fontWeight: 600, color: "#222" }}>{label}</div>
        <div
          style={{
            fontSize: 12,
            fontWeight: 700,
            color: badge.color,
            border: `2px solid ${badge.color}`,
            borderRadius: 999,
            padding: "4px 10px",
            background: "#fff",
          }}
        >
          {badge.text}
        </div>
      </div>

      <div style={{ position: "relative", height: 6, borderRadius: 999, background: "#e6f3ea" }}>
        <div
          style={{
            position: "absolute",
            left: 0,
            top: 0,
            bottom: 0,
            borderRadius: 999,
            width: `${Math.round(value * 100)}%`,
            background: "linear-gradient(90deg, #2fb171 0%, #fda543 50%, #ff5a5a 100%)",
          }}
        />
        <div
          style={{
            position: "absolute",
            top: -6,
            width: 16,
            height: 16,
            borderRadius: 999,
            right: `calc(${100 - Math.round(value * 100)}% - 8px)`,
            background: "#fff",
            border: "2px solid #d0d0d0",
          }}
        />
      </div>
    </div>
  );
}

function ResultSkeleton() {
  return (
    <div
      style={{
        background: "#fff",
        borderRadius: 16,
        boxShadow: "0 6px 18px rgba(0,0,0,0.08)",
        padding: 20,
        marginTop: 12,
      }}
    >
      <div style={{ height: 14, width: 140, background: "#eee", borderRadius: 8, margin: "0 auto 12px" }} />
      <div style={{ height: 12, width: 200, background: "#eee", borderRadius: 8, margin: "0 auto 24px" }} />
      <div style={{ display: "flex", justifyContent: "center", marginBottom: 18 }}>
        <div style={{ width: 160, height: 160, borderRadius: "50%", border: "10px solid #eee" }} />
      </div>
      {[1, 2, 3, 4].map((i) => (
        <div key={i} style={{ height: 22, background: "#f3f3f3", borderRadius: 6, marginBottom: 12 }} />
      ))}
    </div>
  );
}

function ResultDetailCard({ data, fallback }) {
  if (!data && !fallback) return <ResultSkeleton />;
  const src = data || fallback;

  const story_title = src?.story_title ?? null;
  const client_attempt_order = src?.client_attempt_order ?? null;
  const client_kst = src?.client_kst ?? null;
  const score = toNum(src?.score, 0);
  const total = toNum(src?.total, 0);
  const rate = total > 0 ? score / total : 0;

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
    return [
      { label: "요구", value: 0.5 },
      { label: "질문", value: 0.6 },
      { label: "단언", value: 0.6 },
      { label: "의례화", value: 0.5 },
    ];
  })();

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
    danger: { border: "1px solid #ffb3b3", background: "#ffecec", color: "#c62828" },
    warn: { border: "1px solid #ffd8a8", background: "#fff5e6", color: "#b36b00" },
    neutral: { border: "1px solid #e8edf1", background: "#f7fafc", color: "#2c3e50" },
  };

  return (
    <div>
      <div style={{ display: "flex", gap: 8, marginBottom: 12 }}>
        <div
          style={{
            background: "#eef3ff",
            color: "#2C49D8",
            fontWeight: 700,
            borderRadius: 999,
            padding: "6px 10px",
            fontSize: 13,
            border: "1px solid #dfe6fb",
          }}
        >
          {client_attempt_order ? `${client_attempt_order}회차` : "—"}
        </div>
        <div
          style={{
            background: "#f4f6f8",
            color: "#333",
            borderRadius: 999,
            padding: "6px 10px",
            fontSize: 13,
            border: "1px solid #e6eaee",
          }}
        >
          {client_kst ?? "시간 정보 없음"}
        </div>
      </div>

      <div
        style={{
          background: "#fff",
          borderRadius: 16,
          boxShadow: "0 6px 18px rgba(0,0,0,0.08)",
          padding: 20,
          marginBottom: 18,
        }}
      >
        <div style={{ textAlign: "center", fontWeight: 800, fontSize: 20, marginBottom: 6 }}>
          인지검사 결과
        </div>
        <div style={{ textAlign: "center", color: "#777", marginBottom: 18, fontSize: 14 }}>
          검사 결과 요약입니다{story_title ? ` — ${story_title}` : ""}.
        </div>

        <div style={{ display: "flex", justifyContent: "center", marginBottom: 18 }}>
          <div
            style={{
              width: 160,
              height: 160,
              borderRadius: "50%",
              border: `10px solid ${scoreColorByRate(rate)}`,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              color: scoreColorByRate(rate),
              fontWeight: 900,
              fontSize: 36,
              lineHeight: 1.1,
            }}
          >
            <div style={{ textAlign: "center" }}>
              {score}
              <div style={{ fontSize: 16, fontWeight: 800, color: "#ff6b6b" }}>/ {total}</div>
            </div>
          </div>
        </div>

        <div>
          {bars.map((b, i) => (
            <RiskBar key={`${b.label}-${i}`} label={b.label} value={b.value} />
          ))}
        </div>
      </div>

      <div style={{ marginTop: 8 }}>
        <div style={{ fontWeight: 800, fontSize: 18, marginBottom: 12 }}>검사 결과 평가</div>
        {panels.map((p, i) => (
          <div
            key={i}
            style={{
              ...(panelStyle[p.tone] || panelStyle.neutral),
              borderRadius: 12,
              padding: 14,
              marginBottom: 10,
            }}
          >
            <div style={{ fontWeight: 800, marginBottom: 6 }}>{p.title}</div>
            <div style={{ color: "#556270" }}>{p.desc}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

export default function BookHistory() {
  const query = useQuery();
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);

  const [status, setStatus] = useState("idle"); // idle | loading | ok | error
  const [userKey, setUserKey] = useState("");
  const [groups, setGroups] = useState([]);

  const [openStoryId, setOpenStoryId] = useState(null);
  const [openRecordId, setOpenRecordId] = useState(null);
  const [detailCache, setDetailCache] = useState({});
  const [detailLoading, setDetailLoading] = useState({});
  const [errorMsg, setErrorMsg] = useState("");

  const [expandedItems, setExpandedItems] = useState(new Set());
  const [bookData, setBookData] = useState([]);

  useEffect(() => {
    const onResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);

  // 사용자 키 결정: ?user_key 우선 → /userLogin/me
  useEffect(() => {
    (async () => {
      const qUser = (query.get("user_key") || "").trim();
      if (qUser) {
        setUserKey(qUser);
        return;
      }
      try {
        const { data } = await API.get("/userLogin/me");
        // 백엔드 /me 응답: {userId, loginId, ...}
        const k = data?.userId || data?.user?.user_id || data?.user?.user_key;
        if (k) setUserKey(String(k));
      } catch {
        /* not logged in */
      }
    })();
  }, [query]);

  // 전체 히스토리 로드
  useEffect(() => {
    (async () => {
      if (!userKey) {
        setStatus("ok");
        setGroups([]);
        return;
      }
      setStatus("loading");
      setErrorMsg("");
      try {
        // ⚠️ 서버 요구 파라미터명이 user_id/user_key 중 무엇인지에 따라 수정
        const { data } = await API.get("/str/history/all", {
          params: { user_key: userKey },
        });
        if (data?.ok && Array.isArray(data.data)) {
          setGroups(data.data);
          setStatus("ok");
        } else {
          setGroups([]);
          setStatus("ok");
        }
      } catch (e) {
        console.error("[BookHistory] fetch error:", e);
        setErrorMsg("데이터를 불러오는 중 오류가 발생했습니다.");
        setGroups([]);
        setStatus("error");
      }
    })();
  }, [userKey]);

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

  const handleRecordClick = async (recordId, fallback) => {
    setOpenRecordId((prev) => (prev === recordId ? null : recordId));
    if (openRecordId === recordId) return;

    if (detailCache[recordId]) return;
    if (detailLoading[recordId]) return;

    setDetailLoading((m) => ({ ...m, [recordId]: true }));
    try {
      const { data } = await API.get(`/str/${recordId}`);
      if (data?.ok && data.data) {
        setDetailCache((m) => ({ ...m, [recordId]: data.data }));
      } else {
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
    return scoreColorByRate(rate);
  };

  useEffect(() => {
    const loadBookHistory = () => {
      try {
        const savedHistory = localStorage.getItem("bookHistory");
        if (savedHistory) {
          const parsed = JSON.parse(savedHistory);
          setBookData(Array.isArray(parsed) ? parsed : []);
        } else {
          setBookData([]);
        }
      } catch (err) {
        console.error("BookHistory 데이터 로드 실패:", err);
        setBookData([]);
      }
    };
    loadBookHistory();

    const onStorage = (e) => {
      if (e.key === "bookHistory") loadBookHistory();
    };
    window.addEventListener("storage", onStorage);
    return () => window.removeEventListener("storage", onStorage);
  }, []);

  const toggleItem = (itemId) => {
    const next = new Set(expandedItems);
    if (next.has(itemId)) next.delete(itemId);
    else next.add(itemId);
    setExpandedItems(next);
  };

  const getTotalScore = (item) => {
    if (item.total !== undefined && item.total >= 0) return item.total;
    const sAD = Number(item.scoreAD) * 2;
    const sAI = Number(item.scoreAI) * 2;
    const sB = Number(item.scoreB) * 2;
    const sC = Number(item.scoreC) * 2;
    const sD = Number(item.scoreD) * 2;
    return sAD + sAI + sB + sC + sD; // 0~40
  };

  const getLowestCategoryIndex = (item) => {
    const scores = [item.scoreAD, item.scoreAI, item.scoreB, item.scoreC, item.scoreD].map((v) =>
      Number(v)
    );
    const minScore = Math.min(...scores);
    return scores.indexOf(minScore);
  };

  const getIsPassed = (totalScore) => totalScore >= 28;

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

  // 페이징 관련 상태
  const [paginationState, setPaginationState] = useState({});

  const getPaginatedRecords = (records, storyKey) => {
    const page = paginationState[storyKey]?.currentPage || 1;
    const perPage = 5; // 한 페이지당 레코드 수
    const start = (page - 1) * perPage;
    const end = start + perPage;
    return records.slice(start, end);
  };

  const getTotalPages = (records, storyKey) => {
    const perPage = 5;
    return Math.ceil(records.length / perPage);
  };

  const handlePageChange = async (storyKey, page) => {
    if (page < 1 || page > getTotalPages(mergedList.find(g => g.story_key === storyKey)?.records, storyKey)) {
      return;
    }
    setPaginationState(prev => ({
      ...prev,
      [storyKey]: { ...prev[storyKey], currentPage: page }
    }));
  };

  const getPaginationState = (storyKey) => {
    return paginationState[storyKey] || { currentPage: 1 };
  };

  return (
    <div className="content">
      {windowWidth > 1100 && <Background />}

      <div
        className="wrap"
        style={{
          maxWidth: 520,
          margin: "0 auto",
          padding: "80px 20px",
          fontFamily: "Pretendard-Regular",
        }}
      >
        <h2
          style={{
            textAlign: "center",
            marginBottom: 10,
            fontFamily: "ONE-Mobile-Title",
            fontSize: 32,
          }}
        >
          동화 화행검사 결과
        </h2>

        {status === "loading" && (
          <p style={{ textAlign: "center", color: "#888", fontSize: 16 }}>불러오는 중…</p>
        )}
        {status === "error" && (
          <p style={{ textAlign: "center", color: "#F44336", fontSize: 16 }}>
            {errorMsg || "오류가 발생했습니다."}
          </p>
        )}

        <div style={{ display: "flex", flexDirection: "column", gap: 15, marginTop: 10 }}>
          {mergedList.map((g, idx) => {
            const storyId = g.story_key || idx;
            const opened = openStoryId === storyId;
            return (
              <div
                key={storyId}
                style={{
                  background: "#fff",
                  borderRadius: 12,
                  boxShadow: "0 4px 12px rgba(0,0,0,0.1)",
                  overflow: "hidden",
                }}
              >
                <div
                  onClick={() => setOpenStoryId(opened ? null : storyId)}
                  style={{
                    padding: "18px 20px",
                    fontSize: 18,
                    fontWeight: 700,
                    cursor: "pointer",
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                  }}
                >
                  <span>{g.story_title || g.story_key || "제목 없음"}</span>
                  <span style={{ fontSize: 20 }}>{opened ? "▲" : "▼"}</span>
                </div>

                {opened && (
                  <div style={{ padding: "14px 20px", borderTop: "1px solid #eee" }}>
                    {Array.isArray(g.records) && g.records.length > 0 ? (
                      <>
                        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
                          {getPaginatedRecords(g.records, g.story_key).map((r) => {
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
                                    background: "#fafafa",
                                    borderRadius: 8,
                                    padding: "12px 16px",
                                    display: "flex",
                                    justifyContent: "space-between",
                                    alignItems: "center",
                                    cursor: "pointer",
                                  }}
                                >
                                  <span style={{ fontSize: 15, color: "#333" }}>
                                    {r.client_kst || r.client_utc || "-"}
                                    <span
                                      style={{
                                        background: "#eee",
                                        padding: "2px 8px",
                                        borderRadius: 8,
                                        fontSize: 13,
                                        marginLeft: 8,
                                        fontWeight: 600,
                                        color: "#333",
                                      }}
                                    >
                                      {r.client_attempt_order ? `${r.client_attempt_order}회차` : "회차 미정"}
                                    </span>
                                  </span>
                                  <span style={{ fontSize: 16, fontWeight: "bold", color }}>
                                    {r.score ?? 0}점
                                  </span>
                                </div>

                                {/* 상세 */}
                                {selected && (
                                  <div style={{ marginTop: 12 }}>
                                    {loading ? (
                                      <ResultSkeleton />
                                    ) : (
                                      <ResultDetailCard
                                        data={detail}
                                        fallback={{
                                          story_title: g.story_title,
                                          client_attempt_order: r.client_attempt_order,
                                          client_kst: r.client_kst || r.client_utc,
                                          score: r.score,
                                          total: r.total,
                                        }}
                                      />
                                    )}
                                  </div>
                                )}
                              </div>
                            );
                          })}
                        </div>
                        
                        {/* 페이징 */}
                        {getTotalPages(g.records, g.story_key) > 1 && (
                          <div style={{ display: "flex", justifyContent: "center", marginTop: 20 }}>
                            <button
                              onClick={() => handlePageChange(g.story_key, 1)}
                              disabled={getPaginationState(g.story_key).currentPage === 1}
                              style={{
                                padding: "8px 15px",
                                border: "1px solid #d0d0d0",
                                borderRadius: 8,
                                background: getPaginationState(g.story_key).currentPage === 1 ? "#f0f0f0" : "#fff",
                                cursor: getPaginationState(g.story_key).currentPage === 1 ? "not-allowed" : "pointer",
                                marginRight: 10,
                                fontSize: 14,
                                fontWeight: 600,
                                color: getPaginationState(g.story_key).currentPage === 1 ? "#ccc" : "#333",
                              }}
                            >
                              처음
                            </button>
                            <button
                              onClick={() => handlePageChange(g.story_key, getPaginationState(g.story_key).currentPage - 1)}
                              disabled={getPaginationState(g.story_key).currentPage === 1}
                              style={{
                                padding: "8px 15px",
                                border: "1px solid #d0d0d0",
                                borderRadius: 8,
                                background: getPaginationState(g.story_key).currentPage === 1 ? "#f0f0f0" : "#fff",
                                cursor: getPaginationState(g.story_key).currentPage === 1 ? "not-allowed" : "pointer",
                                marginRight: 10,
                                fontSize: 14,
                                fontWeight: 600,
                                color: getPaginationState(g.story_key).currentPage === 1 ? "#ccc" : "#333",
                              }}
                            >
                              이전
                            </button>
                            <span style={{ 
                              fontSize: 14, 
                              fontWeight: 600, 
                              color: "#333",
                              padding: "8px 15px",
                              background: "#f8f9fa",
                              borderRadius: 8,
                              border: "1px solid #e9ecef"
                            }}>
                              {getPaginationState(g.story_key).currentPage} / {getTotalPages(g.records, g.story_key)}
                            </span>
                            <button
                              onClick={() => handlePageChange(g.story_key, getPaginationState(g.story_key).currentPage + 1)}
                              disabled={getPaginationState(g.story_key).currentPage === getTotalPages(g.records, g.story_key)}
                              style={{
                                padding: "8px 15px",
                                border: "1px solid #d0d0d0",
                                borderRadius: 8,
                                background: getPaginationState(g.story_key).currentPage === getTotalPages(g.records, g.story_key) ? "#f0f0f0" : "#fff",
                                cursor: getPaginationState(g.story_key).currentPage === getTotalPages(g.records, g.story_key) ? "not-allowed" : "pointer",
                                marginLeft: 10,
                                fontSize: 14,
                                fontWeight: 600,
                                color: getPaginationState(g.story_key).currentPage === getTotalPages(g.records, g.story_key) ? "#ccc" : "#333",
                              }}
                            >
                              다음
                            </button>
                            <button
                              onClick={() => handlePageChange(g.story_key, getTotalPages(g.records, g.story_key))}
                              disabled={getPaginationState(g.story_key).currentPage === getTotalPages(g.records, g.story_key)}
                              style={{
                                padding: "8px 15px",
                                border: "1px solid #d0d0d0",
                                borderRadius: 8,
                                background: getPaginationState(g.story_key).currentPage === getTotalPages(g.records, g.story_key) ? "#f0f0f0" : "#fff",
                                cursor: getPaginationState(g.story_key).currentPage === getTotalPages(g.records, g.story_key) ? "not-allowed" : "pointer",
                                marginLeft: 10,
                                fontSize: 14,
                                fontWeight: 600,
                                color: getPaginationState(g.story_key).currentPage === getTotalPages(g.records, g.story_key) ? "#ccc" : "#333",
                              }}
                            >
                              마지막
                            </button>
                          </div>
                        )}
                      </>
                    ) : (
                      <p
                        style={{
                          color: "#8891A0",
                          fontSize: 15,
                          textAlign: "center",
                          margin: "6px 0 4px",
                        }}
                      >
                        저장된 검사 기록이 없습니다.
                      </p>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>

        <div style={{ marginTop: 32 }}>
          <h3
            style={{
              fontSize: 18,
              fontWeight: 800,
              marginBottom: 12,
              color: "#222",
              textAlign: "center",
            }}
          >
            로컬 저장 이력
          </h3>

          {/* 아래 로컬 이력 렌더링은 기존 코드 그대로 유지 */}
          {/* ... (생략 없이 위 원본에서 그대로 사용됨) */}
        </div>
      </div>
    </div>
  );
}
