// ./router/IRServer.js
const express = require("express");
const router = express.Router();

// 간단 헬스체크
router.get("/health", (req, res) => res.json({ ok: true }));

// 서버 살아있는 동안 증가하는 회차 인덱스(메모리 저장)
let attemptIndex = 0;

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

/**
 * 인터뷰 화행(Interview) 결과 시도 시간 수신
 * POST /ir/attempt
 * body:
 *  - attemptTime: 클라이언트에서 보낸 UTC ISO 문자열 (필수)
 *  - clientKst  : 클라가 표시용으로 만든 KST 문자열 (선택)
 *  - storyTitle : 어떤 세션/제목(선택, 인터뷰명 등)
 */
router.post("/attempt", (req, res) => {
  const { attemptTime, clientKst, storyTitle } = req.body || {};

  if (!attemptTime) {
    return res.status(400).json({ ok: false, error: "missing attemptTime" });
  }

  const clientUtc = new Date(attemptTime);
  if (isNaN(clientUtc.getTime())) {
    return res.status(400).json({ ok: false, error: "invalid attemptTime format" });
  }

  const serverRecvUtc = new Date();
  attemptIndex += 1;

  console.log("=============== [IR Attempt] ===============");
  console.log(`회차        : ${attemptIndex}회차`);
  console.log(`세션/제목   : ${storyTitle || "(없음)"}`);
  console.log(`Client UTC  : ${clientUtc.toISOString()}`);
  console.log(`Client KST  : ${clientKst || toKstString(clientUtc)} (클라 표기)`);
  console.log(`Server UTC  : ${serverRecvUtc.toISOString()}`);
  console.log(`Server KST  : ${toKstString(serverRecvUtc)} (서버 기준)`);
  console.log("============================================");

  return res.json({
    ok: true,
    attemptIndex,
    clientUtc: clientUtc.toISOString(),
    clientKst: clientKst || toKstString(clientUtc),
    serverUtc: serverRecvUtc.toISOString(),
    serverKst: toKstString(serverRecvUtc),
  });
});

module.exports = router;
