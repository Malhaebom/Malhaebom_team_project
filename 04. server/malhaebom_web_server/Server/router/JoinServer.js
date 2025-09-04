// Server/router/JoinServer.js
const express = require("express");
const router = express.Router();
const bcrypt = require("bcrypt");
const pool = require("./db");

router.post("/register", async (req, res) => {
  try {
    const { login_id, pwd, nick, birthyear, birth, gender } = req.body || {};
    if (!login_id || !pwd || !nick) {
      return res.status(400).json({ ok: false, msg: "필수 항목 누락" });
    }

    let byear = birthyear;
    if (!byear && birth) byear = String(birth).slice(0, 4);
    if (!byear) return res.status(400).json({ ok: false, msg: "출생연도 필요" });

    let g = (gender || "").toUpperCase();
    if (g === "MALE") g = "M";
    if (g === "FEMALE") g = "F";
    if (!["M", "F"].includes(g)) return res.status(400).json({ ok: false, msg: "성별(M/F) 값 필요" });

    const [dup] = await pool.query(
      `SELECT user_id FROM tb_user WHERE login_id = ? AND login_type = 'local' LIMIT 1`,
      [login_id]
    );
    if (dup.length) return res.status(409).json({ ok: false, msg: "이미 존재하는 아이디" });

    const hash = await bcrypt.hash(String(pwd), 10);
    await pool.query(
      `INSERT INTO tb_user (login_id, login_type, pwd, nick, birthyear, gender)
       VALUES (?, 'local', ?, ?, ?, ?)`,
      [login_id, hash, nick, byear, g]
    );

    return res.json({ ok: true });
  } catch (err) {
    console.error("[/userJoin/register] error:", err);
    return res.status(500).json({ ok: false, msg: "회원가입 중 오류 발생" });
  }
});

module.exports = router;
