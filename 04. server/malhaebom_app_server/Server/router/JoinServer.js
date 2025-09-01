// File: src/Server/router/JoinServer.js
require("dotenv").config();

const express = require("express");
const bcrypt = require("bcrypt");
// ✅ 공용 DB 풀만 사용
const pool = require("./db");

const router = express.Router();

/* =========================
 * 유효성 검사
 * ========================= */
function isValidYear(v) {
  const y = Number(v);
  return Number.isInteger(y) && y >= 1900 && y <= 2100;
}
function nonEmpty(v, maxLen = 255) {
  return typeof v === "string" && v.trim().length > 0 && v.length <= maxLen;
}
function isGender1(v) {
  return typeof v === "string" && /^[MF]$/.test(v);
}

/* =========================
 * (선택) 로그인ID 중복 체크
 *  GET /userJoin/exists/login_id?login_id=01012341234
 * ========================= */
router.get("/exists/login_id", async (req, res) => {
  try {
    const login_id = (req.query.login_id ?? "").trim();
    if (!nonEmpty(login_id, 100)) {
      return res.status(400).json({ ok: false, message: "login_id 형식 오류" });
    }
    const [rows] = await pool.execute(
      "SELECT 1 FROM tb_user WHERE login_id = ? AND login_type='local' LIMIT 1",
      [login_id]
    );
    return res.json({ ok: true, exists: rows.length > 0 });
  } catch (e) {
    console.error("[/join/exists/login_id] error:", e);
    return res.status(500).json({ ok: false, message: "서버 오류" });
  }
});

/* =========================
 * (선택) 닉네임 중복 체크
 * ========================= */
router.get("/exists/nick", async (req, res) => {
  try {
    const nick = (req.query.nick ?? "").trim();
    if (!nonEmpty(nick, 50)) {
      return res.status(400).json({ ok: false, message: "nick 형식 오류(1~50자)" });
    }
    const [rows] = await pool.execute(
      "SELECT 1 FROM tb_user WHERE nick = ? LIMIT 1",
      [nick]
    );
    return res.json({ ok: true, exists: rows.length > 0 });
  } catch (e) {
    console.error("[/join/exists/nick] error:", e);
    return res.status(500).json({ ok: false, message: "서버 오류" });
  }
});

/* =========================
 * 회원가입 (local)
 *  POST /userJoin/register
 *  body: { user_id(or login_id), pwd, nick, birthyear, gender }
 * ========================= */
router.post("/register", async (req, res) => {
  try {
    // 호환: user_id(전화번호)로도 받음 → login_id로 매핑
    let {
      user_id,        // legacy
      login_id,       // new
      pwd,
      nick,
      birthyear,
      gender,
    } = req.body ?? {};

    login_id = (login_id ?? user_id ?? "").trim();

    // 1) 필수 체크
    if (!login_id || !pwd || !nick || !birthyear || !gender) {
      return res
        .status(400)
        .json({ message: "모든 필드(login_id, pwd, nick, birthyear, gender)가 필요합니다." });
    }

    // 2) 형식 검증
    if (!nonEmpty(login_id, 100)) {
      return res.status(400).json({ message: "login_id 형식 오류" });
    }
    if (!nonEmpty(pwd, 255)) {
      return res.status(400).json({ message: "pwd 형식 오류" });
    }
    if (!nonEmpty(nick, 50)) {
      return res.status(400).json({ message: "nick 형식 오류(1~50자)" });
    }
    if (!isValidYear(birthyear)) {
      return res.status(400).json({ message: "birthyear는 4자리 연도(1900~2100)여야 합니다." });
    }
    if (!isGender1(gender)) {
      return res.status(400).json({ message: "gender는 'M' 또는 'F' 여야 합니다." });
    }

    // 3) 중복 검사 (login_id, login_type='local')
    const [dups] = await pool.execute(
      "SELECT 1 FROM tb_user WHERE login_id = ? AND login_type='local' LIMIT 1",
      [login_id]
    );
    if (dups.length > 0) {
      return res.status(409).json({ message: "이미 존재하는 login_id 입니다." });
    }

    // 4) 비밀번호 해시
    const hash = await bcrypt.hash(pwd, 12);

    // 5) INSERT
    const sql = `
      INSERT INTO tb_user (login_id, login_type, pwd, nick, birthyear, gender)
      VALUES (?, 'local', ?, ?, ?, ?)
    `;
    await pool.execute(sql, [login_id, hash, nick.trim(), Number(birthyear), gender]);

    return res.status(201).json({ message: "회원가입 성공" });
  } catch (e) {
    if (e.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ message: "이미 존재하는 login_id 입니다." });
    }
    console.error("[/join/register] error:", e);
    return res.status(500).json({ message: "서버 오류" });
  }
});

module.exports = router;
