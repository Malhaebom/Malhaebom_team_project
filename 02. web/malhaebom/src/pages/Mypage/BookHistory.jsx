// 02.web/malhaebom/src/pages/BookHistory.jsx
import React, { useEffect, useMemo, useState } from "react";
import Background from "../Background/Background";
import API, { ensureUserKey } from "../../lib/api.js";

const DEBUG = true;
window.__BH_VERSION__ = "BookHistory@v3.7";

// ====== 서버와 동일한 정규화 ======
function nspace(s){ return String(s||"").replace(/\s+/g," ").trim(); }
function ntitle(s){
  let x = nspace(s);
  x = x.replaceAll("병어리","벙어리");
  x = x.replaceAll("어머니와","어머니의");
  x = x.replaceAll("벙어리장갑","벙어리 장갑");
  x = x.replaceAll("꽁당보리밥","꽁당 보리밥");
  x = x.replaceAll("할머니와바나나","할머니와 바나나");
  return x;
}
function normalizeKoTitleCore(s=""){ return ntitle(s).replace(/\s+/g,""); }
const baseStories = [
  { story_key: "mother_gloves",  story_title: "어머니의 벙어리 장갑" },
  { story_key: "father_wedding", story_title: "아버지와 결혼식" },
  { story_key: "sons_bread",     story_title: "아들의 호빵" },
  { story_key: "grandma_banana", story_title: "할머니와 바나나" },
  { story_key: "kkong_boribap",  story_title: "꽁당 보리밥" },
];
const TITLE_TO_SLUG = new Map(baseStories.map(b => [ntitle(b.story_title), b.story_key]));
const SLUG_TO_TITLE = new Map(baseStories.map(b => [b.story_key, b.story_title]));
const KOCORE_TO_SLUG = new Map(baseStories.map(b => [normalizeKoTitleCore(b.story_title), b.story_key]));
const LEGACY_SLUG_MAP = new Map([
  ["kkongdang_boribap","kkong_boribap"],
  ["kkong boribap","kkong_boribap"],
  ["kkongboribap","kkong_boribap"],
]);
function toSlugFromAny(story_key_or_title, story_title_fallback=""){
  const raw = String(story_key_or_title || "").trim();
  const fall = String(story_title_fallback || "").trim();
  if (LEGACY_SLUG_MAP.has(raw)) return LEGACY_SLUG_MAP.get(raw);
  if (SLUG_TO_TITLE.has(raw)) return raw;
  const title = ntitle(raw || fall);
  const exact = TITLE_TO_SLUG.get(title);
  if (exact) return exact;
  const core = normalizeKoTitleCore(title);
  const byCore = KOCORE_TO_SLUG.get(core);
  if (byCore) return byCore;
  return nspace(raw || fall || "story");
}
function parseSqlUtc(s){
  if(!s) return null;
  const m = String(s).match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})$/);
  if(!m) return null;
  const [,Y,M,D,h,m2,s2] = m;
  const dt = new Date(Date.UTC(+Y,+M-1,+D,+h,+m2,+s2));
  return isNaN(dt.getTime())?null:dt;
}
function formatKstLabel(dtUtc){
  if(!dtUtc) return "";
  const k = new Date(dtUtc.getTime()+9*60*60*1000);
  const pad=n=>String(n).padStart(2,"0");
  return `${k.getFullYear()}년 ${pad(k.getMonth()+1)}월 ${pad(k.getDate())}일 ${pad(k.getHours())}:${pad(k.getMinutes())}`;
}
function parseMaybeJSON(v, fallback={}) {
  if (v == null) return fallback;
  if (typeof v === "object") return v;
  if (typeof v === "string") {
    try {
      const t = v.trim();
      if (!t) return fallback;
      const once = JSON.parse(t);
      if (typeof once === "string") {
        try { return JSON.parse(once); } catch { return fallback; }
      }
      return once ?? fallback;
    } catch { return fallback; }
  }
  try {
    if (typeof Buffer !== "undefined" && Buffer.isBuffer(v)) {
      const s = v.toString("utf8");
      return s ? parseMaybeJSON(s, fallback) : fallback;
    }
  } catch {}
  return fallback;
}
function normalizeScores({ by_category, by_type, risk_bars, risk_bars_by_type, fallbackScore = null, fallbackTotal = 40 }){
  const num = (v) => (v==null || v==="" || isNaN(Number(v)) ? null : Number(v));
  const read = (obj, key) => {
    if (!obj) return null;
    const v = obj[key];
    if (v == null) return null;
    if (typeof v === "number") return v;
    if (typeof v === "string") return num(v);
    if (typeof v === "object") {
      if (v.correct != null && !isNaN(Number(v.correct))) return Number(v.correct);
      if (v.value   != null && !isNaN(Number(v.value)))   return Number(v.value);
    }
    return null;
  };
  const fromRatio  = (r) => (num(r)!=null ? Math.round((1-Number(r))*4) : null);
  const fromPoints = (p) => (num(p)!=null ? Math.round(Number(p)/2) : null);
  const clamp04 = (x)=> Math.max(0, Math.min(4, Number.isFinite(+x)? +x : 0));

  const A  = fromPoints(read(risk_bars,"A"))  ?? read(by_category,"A")  ?? read(by_type,"직접화행") ?? fromRatio(risk_bars_by_type?.["직접화행"]) ?? 0;
  const AI = fromPoints(read(risk_bars,"AI")) ?? read(by_category,"AI") ?? read(by_type,"간접화행") ?? fromRatio(risk_bars_by_type?.["간접화행"]) ?? 0;
  const B  = fromPoints(read(risk_bars,"B"))  ?? read(by_category,"B")  ?? read(by_category,"질문") ?? fromRatio(risk_bars?.["질문"]) ?? 0;
  const C  = fromPoints(read(risk_bars,"C"))  ?? read(by_category,"C")  ?? read(by_category,"단언") ?? fromRatio(risk_bars?.["단언"]) ?? 0;
  const D  = fromPoints(read(risk_bars,"D"))  ?? read(by_category,"D")  ?? read(by_category,"의례화") ?? fromRatio(risk_bars?.["의례화"]) ?? 0;

  const sAD = clamp04(A)*2, sAI = clamp04(AI)*2, sB = clamp04(B)*2, sC = clamp04(C)*2, sD = clamp04(D)*2;
  const partsSum = sAD + sAI + sB + sC + sD;

  return {
    scoreAD: A, scoreAI: AI, scoreB: B, scoreC: C, scoreD: D,
    partsSum,
    fallbackScore: (num(fallbackScore) ?? null),
    fallbackTotal: (num(fallbackTotal) ?? 40),
  };
}
function rowToCardData(row){
  let displayTime = "";
  const rawKst = row?.client_kst && typeof row.client_kst.trim === "function" ? row.client_kst.trim() : (row?.client_kst || "");
  if (rawKst) {
    if (rawKst.includes("T")) {
      const d = new Date(rawKst);
      displayTime = isNaN(d.getTime()) ? rawKst : formatKstLabel(d);
    } else {
      displayTime = rawKst;
    }
  } else {
    displayTime = formatKstLabel(parseSqlUtc(row?.client_utc||""));
  }
  const by_category       = parseMaybeJSON(row?.by_category, {});
  const by_type           = parseMaybeJSON(row?.by_type, {});
  const risk_bars         = parseMaybeJSON(row?.risk_bars, {});
  const risk_bars_by_type = parseMaybeJSON(row?.risk_bars_by_type, {});

  const scores = normalizeScores({
    by_category, by_type, risk_bars, risk_bars_by_type,
    fallbackScore: row?.score, fallbackTotal: row?.total,
  });

  return {
    id: row.id,
    client_attempt_order: row.client_attempt_order,
    client_kst: displayTime,
    story_title: row.story_title,
    scores,
  };
}

function ResultDetailCard({ data }) {
  if (!data) return null;
  const { scoreAD, scoreAI, scoreB, scoreC, scoreD, partsSum, fallbackScore, fallbackTotal } = data.scores;
  const sAD = Number(scoreAD)*2, sAI = Number(scoreAI)*2, sB = Number(scoreB)*2, sC = Number(scoreC)*2, sD = Number(scoreD)*2;

  const computedTotal = partsSum;
  const total = (computedTotal > 0) ? computedTotal : Number(fallbackScore || 0);
  const denom = (computedTotal > 0) ? 40 : Number(fallbackTotal || 40);
  const passCut = Math.round(denom * 0.7);
  const isPassed = total >= passCut;

  const okOpinion = "당신은 모든 영역(직접화행, 간접화행, 질문화행, 단언화행, 의례화화행)에 좋은 점수를 얻었습니다. 현재는 인지기능 정상입니다.\n하지만 유지하기 위해서 꾸준한 학습과 교육을 통한 관리가 필요합니다.";
  const opinions_result=[
    "당신은 직접화행의 점수가 낮습니다.\n기본적인 대화의 문장인식 즉 문장에 내포된 의미에 대한 이해력이 부족하고 동화에 있는 인물들이 나누는 대화들에 대한 인지능력이 조금 부족해 보입니다.\n선생님과의 프로그램을 통한 동화 인물들에 대한 학습으로 점수를 올릴 수 있습니다.",
    "당신은 간접화행의 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 대화에 대한 이해력이 부족하고 동화책 내용의 간접적 질문에 대한 듣기의 인지능력이 조금 부족해보입니다.\n선생님과의 프로그램을 통한 대화 응용능력 학습으로 점수를 올릴 수 있습니다.",
    "당신은 질문화행 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 인물들이 대화에서 주고 받는 정보에 대한 판단에 대한 인지능력이 부족해보입니다.\n선생님과의 프로그램을 통한 대화정보파악학습으로 점수를 올릴수 있습니다.",
    "당신은 단언화행의 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 동화에서 대화하는 인물들의 말에 대한 의도파악과 관련하여 인지능력이 부족해보입니다.\n선생님과의 프로그램을 통해 인물대사 의도파악학습으로 점수를 올릴 수 있습니다.",
    "당신은 의례화화행 점수가 낮습니다.\n기본 대화에 대한 인식이 떨어져서 동화에서 인물들이 상황에 맞는 자신의 감정을 표현하는 말에 대한 인지능력이 부족해보입니다.\n선생님과의 프로그램을 통해  인물들의 상황 및 정서 파악 학습으로 점수를 올릴 수 있습니다.",
  ];
  const opinions_guide=["A-요구(직접)가 부족합니다.","A-요구(간접)가 부족합니다.","B-질문이 부족합니다.","C-단언이 부족습니다.","D-의례화가 부족합니다."];

  const showBreakdown = (computedTotal > 0);
  const arr=[sAD,sAI,sB,sC,sD];
  const minScore=Math.min(...arr);
  const lowIndex=arr.indexOf(minScore);

  return (
    <div style={{background:"#fff",borderRadius:10,padding:20,marginTop:12,marginBottom:12,boxShadow:"0 6px 18px rgba(0,0,0,0.08)"}}>
      <div style={{marginBottom:20}}>
        <div className="tit">총점</div>
        <div style={{margin:"0 auto",textAlign:"center",borderRadius:10,backgroundColor:"white",padding:"20px 0",fontSize:18,fontWeight:700}}>
          {total} / {denom}
        </div>
      </div>
      <div style={{marginBottom:20}}>
        <div className="tit">인지능력</div>
        <div style={{margin:"0 auto",textAlign:"center",borderRadius:10,backgroundColor:"white",padding:"20px 0"}}>
          <img src={isPassed?"/drawable/speech_clear.png":"/drawable/speech_fail.png"} style={{width:"15%"}} alt="result"/>
        </div>
      </div>
      <div>
        <div className="tit">검사 결과 평가</div>
        <div style={{padding:"12px 0",lineHeight:1.6,whiteSpace:"pre-line"}}>
          {showBreakdown ? (isPassed ? okOpinion : opinions_result[lowIndex])
                         : "세부 영역 점수 데이터가 없어 총점 기준으로만 표시합니다."}
        </div>
        {showBreakdown && !isPassed && (
          <div style={{fontWeight:700,marginTop:6}}>{opinions_guide[lowIndex]}</div>
        )}
      </div>
    </div>
  );
}

function BookHistory(){
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  const [openStoryId, setOpenStoryId] = useState(null);
  const [openRecordId, setOpenRecordId] = useState(null);
  const [groups, setGroups] = useState([]);
  const [loading, setLoading] = useState(true);
  const [usedUserKey, setUsedUserKey] = useState("");

  useEffect(()=>{
    const onResize=()=>setWindowWidth(window.innerWidth);
    window.addEventListener("resize", onResize);
    return ()=>window.removeEventListener("resize", onResize);
  },[]);

  useEffect(()=>{
    (async ()=>{
      try{
        setLoading(true);
        const key = await ensureUserKey({ retries:2, delayMs:150 });
        setUsedUserKey(key || "(cookie only)");

        const cfg = key
          ? { params:{ user_key:key, _t: Date.now() }, headers:{ "x-user-key":key } }
          : { params:{ _t: Date.now() } };

        const { data } = await API.get("/str/history/all", cfg);

        if (DEBUG){
          console.groupCollapsed("%c[BookHistory] /str/history/all response","color:#0a0");
          console.log("status", data?.ok, "groups#", data?.data?.length);
          console.log("data", data);
          console.groupEnd();
          window.__STR_HISTORY_RAW__ = data;
        }

        setGroups(data?.ok ? (data.data || []) : []);
      }catch(e){
        console.error("history/all 에러:", e);
        setGroups([]);
      }finally{
        setLoading(false);
      }
    })();
  },[]);

  // 서버에서 넘어온 story_key를 다시 안전 정규화(보수적)
  const mergedStories = useMemo(()=>{
    const map = new Map(
      (groups||[]).map(g => {
        const slug = toSlugFromAny(g.story_key || "", g.story_title || "");
        const title = (g.story_title || SLUG_TO_TITLE.get(slug) || slug).trim();
        return [slug, { story_key: slug, story_title: title, records: (g.records||[]).map(rowToCardData) }];
      })
    );
    const ordered = baseStories.map(b => ({
      story_key: b.story_key,
      story_title: b.story_title,
      records: (map.get(b.story_key)?.records || []),
    }));
    for (const [slug, g] of map.entries()){
      if (!baseStories.some(b=>b.story_key===slug)){
        ordered.push({ story_key: slug, story_title: g.story_title || slug, records: g.records || [] });
      }
    }
    // 회차/최신순
    for (const it of ordered){
      it.records.sort((a,b)=>{
        const ao = Number(a.client_attempt_order||0);
        const bo = Number(b.client_attempt_order||0);
        if (ao!==bo) return bo-ao;
        return String(b.id).localeCompare(String(a.id));
      });
    }
    if (DEBUG){
      console.groupCollapsed("%c[BookHistory] mergedStories","color:#0aa");
      console.log("groups(raw)", groups);
      console.log("ordered(final)", ordered);
      console.groupEnd();
      window.__STR_HISTORY__ = { groups, ordered };
    }
    return ordered;
  },[groups]);

  return (
    <div className="content">
      {windowWidth > 1100 && <Background />}

      <div className="wrap" style={{maxWidth:520, margin:"0 auto", padding:"80px 20px"}}>
        <h2 style={{ textAlign:"center", marginBottom:10, fontSize:32 }}>동화 화행검사 결과</h2>

        {DEBUG && (
          <div style={{ background:"#F3F4F6", border:"1px solid #E5E7EB", borderRadius:8, padding:"8px 10px", marginBottom:12, color:"#374151", fontSize:13 }}>
            <div><b>DEBUG</b> version: {window.__BH_VERSION__}</div>
            <div>userKey: {usedUserKey}</div>
            <div>groups#: {groups?.length || 0}</div>
          </div>
        )}

        {loading ? (
          <div style={{ textAlign:"center", padding:"40px 0", color:"#666" }}>불러오는 중...</div>
        ) : (
          <div style={{ display:"flex", flexDirection:"column", gap:15, marginTop:10 }}>
            {mergedStories.map((b, idx)=>{
              const storyId = b.story_key || idx;
              const opened = openStoryId === storyId;
              const records = b.records || [];
              return (
                <div key={storyId} style={{ background:"#fff", borderRadius:12, boxShadow:"0 4px 12px rgba(0,0,0,0.1)", overflow:"hidden" }}>
                  <div
                    onClick={()=>{ setOpenStoryId(opened?null:storyId); setOpenRecordId(null); }}
                    style={{ padding:"18px 20px", fontSize:18, fontWeight:700, cursor:"pointer", display:"flex", justifyContent:"space-between", alignItems:"center" }}
                  >
                    <span>{b.story_title}</span>
                    <span style={{ fontSize:20 }}>{opened ? "▲" : "▼"}</span>
                  </div>

                  {opened && (
                    <div style={{ padding:"14px 20px", borderTop:"1px solid #eee" }}>
                      {records.length===0 ? (
                        <div style={{ color:"#888", padding:"8px 0" }}>아직 결과가 없습니다.</div>
                      ) : (
                        records.map(r=>{
                          const selected = openRecordId===r.id;
                          return (
                            <div key={r.id}>
                              <div
                                onClick={()=>setOpenRecordId(selected?null:r.id)}
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

export default BookHistory;
