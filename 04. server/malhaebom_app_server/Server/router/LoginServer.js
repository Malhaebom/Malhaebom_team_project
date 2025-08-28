// File: src/Server/router/LoginServer.js
require("dotenv").config();

const express = require("express");
// ✅ Promise API 사용 (중요): 콜백 API가 아님
const mysql = require("mysql2/promise");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");

const router = express.Router();

/* =========================
 * DB 설정 (.env 우선, 없으면 기본값)
 * =========================
 * 예시 .env:
 * DB_HOST=project-db-campus.smhrd.com
 * DB_PORT=3307
 * DB_USER=campus_25SW_BD_p3_3
 * DB_PASSWORD=smhrd3
 * DB_NAME=campus_25SW_BD_p3_3
 * JWT_SECRET=malhaebom
 * JWT_EXPIRES_IN=7d
 */
const DB_CONFIG = {
  host: process.env.DB_HOST || "project-db-campus.smhrd.com",
  port: Number(process.env.DB_PORT || 3307),
  user: process.env.DB_USER || "campus_25SW_BD_p3_3",
  password: process.env.DB_PASSWORD || "smhrd3",
  database: process.env.DB_NAME || "campus_25SW_BD_p3_3",

  // ---- 연결 안정화 옵션 ----
  connectTimeout: 10000,        // 연결 시도 10초
  enableKeepAlive: true,        // TCP keep-alive
  keepAliveInitialDelay: 10000, // 10초 후 첫 keep-alive
  multipleStatements: false,
  timezone: "Z",
};

const pool = mysql.createPool({
  ...DB_CONFIG,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

// --- 풀의 연결 이벤트(세션 설정) ---
// 주의: 여기서 전달되는 conn은 "콜백 기반 커넥션"이므로 Promise 래퍼를 붙여 사용
pool.on?.("connection", (conn /* callback connection */) => {
  // ✅ 반드시 conn.promise()로 래핑해서 Promise API 사용
  conn
    .promise()
    .query("SET SESSION wait_timeout=28800, interactive_timeout=28800")
    .catch(() => {});
});

// --- 주기적 ping으로 유휴 연결 끊김 예방 ---
// pool은 mysql2/promise 이므로 pool.query는 Promise를 반환 -> await 가능
const PING_INTERVAL_MS = 30 * 1000;
setInterval(async () => {
  try {
    await pool.query("SELECT 1");
  } catch (e) {
    console.warn("[DB] keepalive ping failed:", e?.code || e?.message);
  }
}, PING_INTERVAL_MS);

// --- 재시도 래퍼: 일시 네트워크 오류/ECONNRESET 시 재시도 ---
async function execWithRetry(sql, params = [], { tries = 3, label = "" } = {}) {
  let lastErr;
  for (let i = 1; i <= tries; i++) {
    try {
      const [rows] = await pool.execute(sql, params);
      return rows;
    } catch (err) {
      lastErr = err;
      const transient =
        err?.code === "ECONNRESET" ||
        err?.code === "PROTOCOL_CONNECTION_LOST" ||
        err?.code === "ETIMEDOUT";
      console.warn(
        `[DB] query failed${label ? " (" + label + ")" : ""}, try ${i}/${tries}:`,
        err?.code || err?.message
      );
      if (!transient || i === tries) break;
      // 짧게 대기 후 재시도 (지수 백오프)
      await new Promise((r) => setTimeout(r, 300 * i));
    }
  }
  throw lastErr;
}

/* =========================
 * JWT 설정
 * ========================= */
const JWT_SECRET = process.env.JWT_SECRET || "malhaebom";
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "7d";

function sign(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
}

function auth(req, res, next) {
  const h = req.headers.authorization || "";
  const token = h.startsWith("Bearer ") ? h.slice(7) : null;
  if (!token) return res.status(401).json({ message: "토큰 필요" });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ message: "유효하지 않은 토큰" });
  }
}

/* =========================
 * 테이블: tb_user
 *  - user_id  (PK, 전화번호)
 *  - pwd      (해시 저장)
 *  - nick
 *  - birthyear (YEAR)
 *  - gender   (CHAR(1))
 * ========================= */

/* 회원가입 */
router.post("/register", async (req, res) => {
  try {
    let { user_id, pwd, nick, birthyear, gender } = req.body;
    if (!user_id || !pwd || !nick || !birthyear || !gender) {
      return res
        .status(400)
        .json({ message: "모든 필드(user_id, pwd, nick, birthyear, gender)가 필요합니다." });
    }

    // YEAR 타입은 4자리 숫자 필요
    birthyear = Number(birthyear);
    if (!Number.isInteger(birthyear) || birthyear < 1900 || birthyear > 2100) {
      return res.status(400).json({ message: "birthyear는 4자리 연도여야 합니다." });
    }

    // 비밀번호 해시
    const hash = await bcrypt.hash(pwd, 12);

    await execWithRetry(
      `
      INSERT INTO tb_user (user_id, pwd, nick, birthyear, gender)
      VALUES (?, ?, ?, ?, ?)
      `,
      [user_id, hash, nick, birthyear, gender],
      { label: "register insert" }
    );

    res.status(201).json({ message: "회원가입 성공" });
  } catch (e) {
    if (e?.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ message: "이미 존재하는 user_id(전화번호)입니다." });
    }
    console.error("[/register] error:", e);
    res.status(500).json({ message: "서버 오류", code: e?.code || "" });
  }
});

/* 로그인 */
router.post("/login", async (req, res) => {
  try {
    const { user_id, pwd } = req.body;
    if (!user_id || !pwd) {
      return res.status(400).json({ message: "user_id, pwd가 필요합니다." });
    }

    const rows = await execWithRetry(
      "SELECT * FROM tb_user WHERE user_id = ? LIMIT 1",
      [user_id],
      { label: "login select" }
    );
    if (!rows.length) {
      return res.status(401).json({ message: "아이디 또는 비밀번호 오류" });
    }

    const user = rows[0];
    const ok = await bcrypt.compare(pwd, user.pwd);
    if (!ok) {
      return res.status(401).json({ message: "아이디 또는 비밀번호 오류" });
    }

    const token = sign({ id: user.user_id, nick: user.nick });

    return res.json({
      token,
      user: {
        user_id: user.user_id,
        nick: user.nick,
        birthyear: user.birthyear,
        gender: user.gender,
      },
    });
  } catch (err) {
    console.error("[/login] error:", err);
    return res.status(500).json({ message: "서버 오류", code: err?.code || "" });
  }
});

/* 내 정보 조회 (JWT 필요) */
router.get("/me", auth, async (req, res) => {
  try {
    const userId = req.user.id;
    const rows = await execWithRetry(
      "SELECT user_id, nick, birthyear, gender FROM tb_user WHERE user_id = ? LIMIT 1",
      [userId],
      { label: "me select" }
    );
    if (!rows.length) return res.status(404).json({ message: "사용자 없음" });
    return res.json({ user: rows[0] });
  } catch (err) {
    console.error("[/me] error:", err);
    return res.status(500).json({ message: "서버 오류", code: err?.code || "" });
  }
});

/* 비밀번호 변경 (옵션) */
/*
router.post("/change-password", auth, async (req, res) => {
  try {
    const { old_pwd, new_pwd } = req.body;
    if (!old_pwd || !new_pwd) {
      return res.status(400).json({ message: "old_pwd, new_pwd가 필요합니다." });
    }

    const userId = req.user.id;
    const rows = await execWithRetry(
      "SELECT pwd FROM tb_user WHERE user_id = ? LIMIT 1",
      [userId],
      { label: "change-password select" }
    );
    if (!rows.length) return res.status(404).json({ message: "사용자 없음" });

    const ok = await bcrypt.compare(old_pwd, rows[0].pwd);
    if (!ok) return res.status(401).json({ message: "기존 비밀번호가 일치하지 않습니다." });

    const hash = await bcrypt.hash(new_pwd, 12);
    await execWithRetry(
      "UPDATE tb_user SET pwd = ? WHERE user_id = ?",
      [hash, userId],
      { label: "change-password update" }
    );

    return res.json({ message: "비밀번호 변경 완료" });
  } catch (err) {
    console.error("[/change-password] error:", err);
    return res.status(500).json({ message: "서버 오류", code: err?.code || "" });
  }
});
*/

/* 헬스체크 (선택) */
router.get("/healthz", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ ok: false, code: e?.code || e?.message });
  }
});

module.exports = router;
