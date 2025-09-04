import React, { useEffect, useMemo, useState } from "react";
import Background from "../Background/Background";
import API, { ensureUserKey } from "../../lib/api.js";

const DEBUG = true;
window.__BH_VERSION__ = "BookHistory@v3.1";

/** 표준 슬러그/제목 */
const baseStories = [
  { story_key: "mother_gloves",  story_title: "어머니의 벙어리 장갑" },
  { story_key: "father_wedding", story_title: "아버지와 결혼식" },
  { story_key: "sons_bread",     story_title: "아들의 호빵" },
  { story_key: "grandma_banana", story_title: "할머니와 바나나" },
  { story_key: "kkong_boribap",  story_title: "꽁당 보리밥" }, // ← 변경
];

/* ────────── 유틸 ────────── */
function parseSqlUtc(s){
  if(!s) return null;
  const m = String(s).match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})$/);
  if(!m) return null;
  const [,Y,M,D,h,m2,s2] = m;
  const dt = new Date(Date.UTC(+Y,+M-1,+D,+h,+m2,+s2));
  return isNaN(dt.getTime())?null:dt;
}

// 화면 표시는 'YYYY년 MM월 DD일 HH:MM'
function formatKstLabel(dtUtc){
  if(!dtUtc) return "";
  const k = new Date(dtUtc.getTime()+9*60*60*1000);
  const pad=n=>String(n).padStart(2,"0");
  return `${k.getFullYear()}년 ${pad(k.getMonth()+1)}월 ${pad(k.getDate())}일 ${pad(k.getHours())}:${pad(k.getMinutes())}`;
}

function normalizeScores({ by_category, by_type, risk_bars, risk_bars_by_type }){
  const getCorrect=(obj,key)=> (obj?.[key] && obj[key].correct!=null)?Number(obj[key].correct)||0:null;
  const fromRatio=r=> (Number.isFinite(+r)&&r>=0&&r<=1)?Math.round((1-Number(r))*4):null;
  const fromPoints=p=> (Number.isFinite(+p)&&p>=0&&p<=8&&p%2===0)?Math.round(Number(p)/2):null;

  const A  = getCorrect(by_type,"직접화행") ?? fromRatio(risk_bars_by_type?.["직접화행"]) ?? fromPoints(risk_bars?.A)  ?? 0;
  const AI = getCorrect(by_type,"간접화행") ?? fromRatio(risk_bars_by_type?.["간접화행"]) ?? fromPoints(risk_bars?.AI) ?? 0;
  const B  = getCorrect(by_category,"B")   ?? getCorrect(by_category,"질문") ?? fromRatio(risk_bars?.["질문"]) ?? fromPoints(risk_bars?.B) ?? 0;
  const C  = getCorrect(by_category,"C")   ?? getCorrect(by_category,"단언") ?? fromRatio(risk_bars?.["단언"]) ?? fromPoints(risk_bars?.C) ?? 0;
  const D  = getCorrect(by_category,"D")   ?? getCorrect(by_category,"의례화") ?? fromRatio(risk_bars?.["의례화"]) ?? fromPoints(risk_bars?.D) ?? 0;

  return { scoreAD:A, scoreAI:AI, scoreB:B, scoreC:C, scoreD:D };
}

function rowToCardData(row){
  let displayTime = "";
  const rawKst = (row?.client_kst||"").trim();
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

  const scores = normalizeScores({
    by_category: row?.by_category||{},
    by_type: row?.by_type||{},
    risk_bars: row?.risk_bars||{},
    risk_bars_by_type: row?.risk_bars_by_type||{},
  });
  return {
    id: row.id,
    client_attempt_order: row.client_attempt_order,
    client_kst: displayTime,
    story_title: row.story_title,
    scores,
  };
}

/* ────────── 메인 ────────── */
export default function BookHistory(){
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  const [openStoryId, setOpenStoryId] = useState(null);
  const [openRecordId, setOpenRecordId] = useState(null);

  const [groups, setGroups] = useState([]);       // 서버 응답 원본(슬러그 key)
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

        const cfg = key ? { params:{ user_key:key }, headers:{ "x-user-key":key } } : {};
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

  // 서버가 슬러그로 보내주므로 단순 병합
  const mergedStories = useMemo(()=>{
    const map = new Map(groups.map(g => [g.story_key, g])); // g.story_key = slug
    const ordered = baseStories.map(b => ({
      story_key: b.story_key,
      story_title: b.story_title,
      records: (map.get(b.story_key)?.records || []).map(rowToCardData),
    }));
    for (const [slug, g] of map.entries()){
      if (!baseStories.some(b=>b.story_key===slug)){
        ordered.push({
          story_key: slug,
          story_title: g.story_title || slug,
          records: (g.records || []).map(rowToCardData),
        });
      }
    }
    // 회차/최신순 정렬
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
