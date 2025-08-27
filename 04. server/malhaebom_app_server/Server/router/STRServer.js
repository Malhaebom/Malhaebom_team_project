// src/Server/router/STRServer.js
const express = require("express");
const router = express.Router();

// 헬스체크 (선택)
router.get("/health", (req, res) => {
  res.json({ ok: true });
});

// Flutter에서 보낸 문자열 받기 (콘솔 출력 전용)
router.post("/attempt", (req, res) => {
  const { attemptTime } = req.body; // Flutter에서 보낼 key 이름과 맞춰야 함
  console.log("📥 [STR] 서버에서 받은 시도 시간:", attemptTime);

  // 확인용 응답
  res.json({ ok: true, received: attemptTime, message: "수신 완료" });
});

module.exports = router;
