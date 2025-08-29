const express = require("express");
const router = express.Router();

// 헬스체크
router.get("/health", (req, res) => res.json({ ok: true }));

// 전체 글로벌 id 증가용
let globalId = 0;

// 동화책별 시도 기록: Map<storyKey, Array<attempt>>
const attemptsByStory = new Map();

// 제목 정규화(공백 정리, 앞뒤 trim)
function normalizeTitle(s) {
  return String(s || "")
    .replace(/\s+/g, " ")
    .trim();
}

// UTC → KST 보기 좋은 문자열
function toKstString(dateUtc) {
  const kst = new Date(dateUtc.getTime() + 9 * 60 * 60 * 1000);
  const y  = kst.getUTCFullYear();
  const m  = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const d  = String(kst.getUTCDate()).padStart(2, "0");
  const hh = String(kst.getUTCHours()).padStart(2, "0");
  const mm = String(kst.getUTCMinutes()).padStart(2, "0");
  return `${y}년 ${m}월 ${d}일 ${hh}:${mm}`;
}

// {k:{correct,total}} -> {k: risk 0~1}
function computeRiskBars(by) {
  if (!by || typeof by !== "object") return {};
  const out = {};
  for (const k of Object.keys(by)) {
    const v = by[k] || {};
    const correct = Number(v.correct || 0);
    const total   = Number(v.total   || 0);
    out[k] = total > 0 ? 1 - correct / total : 0.5;
  }
  return out;
}

/**
 * 동화(Story) 결과 수신
 * 클라: POST /str/attempt
 */
router.post("/attempt", (req, res) => {
  const {
    storyTitle,           // 원본 제목(표시용)
    storyKey,             // 정규화된 제목(키용) - 선택(없으면 서버가 만듦)
    attemptOrder,         // 클라 기준 "해당 동화" 회차
    attemptTime,          // ISO UTC
    clientKst,            // 표시용 KST 문자열
    score, total,         // 총점/총문항
    byCategory, byType,   // {key:{correct,total}}
    riskBars,             // 선택: {key:0~1}
    riskBarsByType,       // 선택: {key:0~1}
  } = req.body || {};

  if (!attemptTime) {
    return res.status(400).json({ ok:false, error:"missing attemptTime" });
  }
  const clientUtc = new Date(attemptTime);
  if (isNaN(clientUtc.getTime())) {
    return res.status(400).json({ ok:false, error:"invalid attemptTime format" });
  }

  const key = normalizeTitle(storyKey || storyTitle || "동화");
  const serverUtc = new Date();

  // 책별 배열 준비
  if (!attemptsByStory.has(key)) attemptsByStory.set(key, []);
  const arr = attemptsByStory.get(key);

  // 서버가 보정 계산
  const rbCat  = riskBars       || computeRiskBars(byCategory);
  const rbType = riskBarsByType || computeRiskBars(byType);

  // 저장 객체
  globalId += 1;
  const saved = {
    id: globalId,
    storyTitle: storyTitle || null,
    storyKey: key,
    clientAttemptOrder: attemptOrder ?? null,        // 클라 기준 회차(동화별)
    serverAttemptOrder: arr.length + 1,              // 서버가 부여한 동화별 회차
    score: Number(score ?? 0),
    total: Number(total ?? 0),

    clientUtc: clientUtc.toISOString(),
    clientKst: clientKst || toKstString(clientUtc),
    serverUtc: serverUtc.toISOString(),
    serverKst: toKstString(serverUtc),

    byCategory: byCategory || {},
    byType: byType || {},
    riskBars: rbCat,
    riskBarsByType: rbType,
  };

  arr.push(saved);

  // 로그
  console.log("=============== [STR Attempt] ===============");
  console.log(`동화 키      : ${key}`);
  console.log(`표시 제목    : ${storyTitle || "(없음)"}`);
  console.log(`클라 회차    : ${attemptOrder ?? "(미전달)"}`);
  console.log(`서버 회차    : ${saved.serverAttemptOrder}`);
  console.log(`점수/총점    : ${saved.score}/${saved.total}`);
  // console.log(`Client UTC   : ${saved.clientUtc}`);
  console.log(`Client KST   : ${saved.clientKst}`);
  // console.log(`Server UTC   : ${saved.serverUtc}`);
  // console.log(`Server KST   : ${saved.serverKst}`);
  console.log(`riskBars(cat):`, rbCat);
  console.log("=============================================");

  return res.json({ ok:true, saved });
});

module.exports = router;
