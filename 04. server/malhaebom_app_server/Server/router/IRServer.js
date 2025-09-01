// File: src/Server/router/IRServer.js
require("dotenv").config();

const express = require("express");
const router = express.Router();

// 간단 헬스체크
router.get("/health", (_req, res) => res.json({ ok: true }));

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

  // 숫자 필드 보정
  const nScore = Number(score ?? 0);
  const nTotal = Number(total ?? 0);
  if (!Number.isFinite(nScore) || !Number.isFinite(nTotal) || nScore < 0 || nTotal < 0) {
    return res.status(400).json({ ok: false, error: "invalid score/total" });
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
    score: nScore,
    total: nTotal,

    clientUtc: clientUtc.toISOString(),
    clientKst: clientKst || toKstString(clientUtc),
    serverUtc: serverRecvUtc.toISOString(),
    serverKst: toKstString(serverRecvUtc),

    byCategory: byCategory || {},
    byType: byType || {},
    riskBars: computedRiskBars,
    riskBarsByType: computedRiskBarsByType,
  };

  attempts.unshift(saved);
  // 최근 200개만 유지
  if (attempts.length > 200) attempts.length = 200;

  // 로그
  console.log("=============== [IR Attempt] ===============");
  console.log(`서버 회차    : ${attemptIndex}회차`);
  console.log(`클라 회차    : ${attemptOrder ?? "(미전달)"}`);
  console.log(`제목         : ${interviewTitle || "(없음)"}`);
  console.log(`점수/총점    : ${saved.score}/${saved.total}`);
  console.log(`Client KST   : ${saved.clientKst}`);
  console.log(`riskBars     :`, computedRiskBars);
  console.log("============================================");

  return res.json({ ok: true, attemptIndex, saved });
});

/** 최근 시도 n개 조회 (메모리, 디버그용) */
router.get("/attempts", (req, res) => {
  const n = Math.min(Math.max(parseInt(String(req.query.limit || "30"), 10) || 30, 1), 200);
  res.json({ ok: true, list: attempts.slice(0, n) });
});

/** (주의) 메모리 기록 초기화 (디버그용) */
router.post("/reset", (_req, res) => {
  attempts.length = 0;
  attemptIndex = 0;
  res.json({ ok: true, message: "reset done" });
});

module.exports = router;
