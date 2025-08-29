// Server/router/JoinServer.js
const express = require("express");
const router = express.Router();
const mysql = require("mysql2/promise");
const bcrypt = require("bcrypt");

/* =========================
 * 하드코딩 DB
 * ========================= */
const DB_CONFIG = {
  host: "project-db-campus.smhrd.com",
  port: 3307,
  user: "campus_25SW_BD_p3_3",
  password: "smhrd3",
  database: "campus_25SW_BD_p3_3",
};
const pool = mysql.createPool({ ...DB_CONFIG, waitForConnections: true, connectionLimit: 10 });

/**
 * POST /userJoin/register
 * body: { user_id|phone, pwd, nick, birthyear|birth(YYYY-MM-DD), gender(male|female|M|F) }
 * - birth → YEAR만 저장
 * - gender → M/F 변환
 */
router.post("/register", async (req, res) => {
  try {
    const { user_id, phone, pwd, nick, birthyear, birth, gender } = req.body || {};

    const id = user_id || phone;
    if (!id || !pwd || !nick) {
      return res.status(400).json({ ok: false, msg: "필수 항목 누락" });
    }

    // 출생연도
    let byear = birthyear;
    if (!byear && birth) byear = String(birth).slice(0, 4);
    if (!byear) return res.status(400).json({ ok: false, msg: "출생연도(또는 생년월일)가 필요합니다." });

    // 성별
    let g = (gender || "").toUpperCase();
    if (g === "MALE") g = "M";
    if (g === "FEMALE") g = "F";
    if (!["M", "F"].includes(g)) return res.status(400).json({ ok: false, msg: "성별(M/F) 값이 필요합니다." });

    // 중복 확인
    const [dup] = await pool.query("SELECT user_id FROM tb_user WHERE user_id = ?", [id]);
    if (dup.length) return res.status(409).json({ ok: false, msg: "이미 존재하는 아이디(전화번호)입니다." });

    const hash = await bcrypt.hash(String(pwd), 10);
    await pool.query(
      "INSERT INTO tb_user (user_id, pwd, nick, birthyear, gender) VALUES (?, ?, ?, ?, ?)",
      [id, hash, nick, byear, g]
    );

    return res.json({ ok: true });
  } catch (err) {
    console.error("[/userJoin/register] error:", err);
    return res.status(500).json({ ok: false, msg: "회원가입 중 오류가 발생했습니다." });
  }
});

module.exports = router;
