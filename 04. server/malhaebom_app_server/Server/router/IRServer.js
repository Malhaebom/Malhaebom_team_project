const express = require("express");
const router = express.Router();

// 간단 헬스체크
router.get("/health", (req, res) => res.json({ ok: true }));

// 서버 살아있는 동안 증가하는 회차 인덱스(메모리 저장)
let attemptIndex = 0;
// 최근 시도 메모리 저장(임시)
const attempts = [];

// UTC → KST 보기 좋은 문자열로 변환
function toKstString(dateUtc) {
  const kst = new Date(dateUtc.getTime() + 9 * 60 * 60 * 1000);
  const y  = kst.getUTCFullYear();
  const m  = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const d  = String(kst.getUTCDate()).padStart(2, "0");
  const hh = String(kst.getUTCHours()).padStart(2, "0");
  const mm = String(kst.getUTCMinutes()).padStart(2, "0");
  return `${y}년 ${m}월 ${d}일 ${hh}:${mm}`;
}

function computeRiskBars(by) {
  if (!by || typeof by !== "object") return {};
  const out = {};
  for (const k of Object.keys(by)) {
    const v = by[k] || {};
    const correct = Number(v.correct || 0);
    const total   = Number(v.total   || 0);
    out[k] = total > 0 ? 1 - correct / total : 0.5; // 0(양호)~1(위험)
  }
  return out;
}

/**
 * 인터뷰 화행(Interview) 결과 수신
 * (앱에서 API_BASE + /ir/attempt 로 호출)
 */
router.post("/attempt", (req, res) => {
  const {
    attemptTime,          // ISO UTC (필수)
    clientKst,            // 보기용 KST 문자열(선택)
    interviewTitle,       // 인터뷰 제목(선택)
    attemptOrder,         // 클라 기준 회차(선택)
    score, total,         // 총점/총문항
    byCategory, byType,   // {key: {correct,total}}
    riskBars,             // {key: 0~1} (선택 - 없으면 서버 계산)
    riskBarsByType,       // {key: 0~1} (선택)
  } = req.body || {};

  if (!attemptTime) {
    return res.status(400).json({ ok: false, error: "missing attemptTime" });
  }

  const clientUtc = new Date(attemptTime);
  if (isNaN(clientUtc.getTime())) {
    return res.status(400).json({ ok: false, error: "invalid attemptTime format" });
  }

  const serverRecvUtc = new Date();
  attemptIndex += 1;

  // 서버에서 보정 계산
  const computedRiskBars       = riskBars       || computeRiskBars(byCategory);
  const computedRiskBarsByType = riskBarsByType || computeRiskBars(byType);

  const saved = {
    id: attemptIndex,
    interviewTitle: interviewTitle || null,
    clientAttemptOrder: attemptOrder ?? null,
    score: Number(score ?? 0),
    total: Number(total ?? 0),

    clientUtc: clientUtc.toISOString(),
    clientKst: clientKst || toKstString(clientUtc),
    serverUtc: serverRecvUtc.toISOString(),
    serverKst: toKstString(serverRecvUtc),

    byCategory: byCategory || {},
    byType: byType || {},
    riskBars: computedRiskBars,
    riskBarsByType: computedRiskBarsByType,
  };

  attempts.push(saved);

  // 로그
  console.log("=============== [IR Attempt] ===============");
  console.log(`서버 회차    : ${attemptIndex}회차`);
  console.log(`클라 회차    : ${attemptOrder ?? "(미전달)"}`);
  console.log(`제목         : ${interviewTitle || "(없음)"}`);
  console.log(`점수/총점    : ${saved.score}/${saved.total}`);
  // console.log(`Client UTC   : ${saved.clientUtc}`);
  console.log(`Client KST   : ${saved.clientKst} (클라 표기)`);
  // console.log(`Server UTC   : ${saved.serverUtc}`);
  // console.log(`Server KST   : ${saved.serverKst} (서버 기준)`);
  console.log(`riskBars     :`, computedRiskBars);
  console.log("============================================");

  return res.json({ ok: true, attemptIndex, saved });
});

module.exports = router;
