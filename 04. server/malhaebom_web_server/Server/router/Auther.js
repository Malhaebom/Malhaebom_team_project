// Server/router/Auther.js
// Google / Kakao / Naver OAuth (tb_user 단일 테이블 사용)
require("dotenv").config();

const express = require("express");
const router = express.Router();
const axios = require("axios");
const qs = require("querystring");
const mysql = require("mysql2/promise");
const jwt = require("jsonwebtoken");

/* =========================
 * 환경변수
 * ========================= */
const SERVER_BASE_URL   = process.env.SERVER_BASE_URL   || "http://211.188.63.38:3001";
const FRONTEND_BASE_URL = process.env.FRONTEND_BASE_URL || "http://211.188.63.38:5137";
const JWT_SECRET        = process.env.JWT_SECRET        || "malhaebom_sns";
const COOKIE_NAME       = process.env.COOKIE_NAME       || "mb_access";

// ⚠️ HTTP 환경에서 secure 쿠키가 막히지 않도록: HTTPS일 때만 true
const USE_SECURE_COOKIE = /^https:\/\//i.test(SERVER_BASE_URL);

/* =========================
 * DB 풀
 * ========================= */
const DB_CONFIG = {
  host    : process.env.DB_HOST     || "project-db-campus.smhrd.com",
  port    : Number(process.env.DB_PORT || 3307),
  user    : process.env.DB_USER     || "campus_25SW_BD_p3_3",
  password: process.env.DB_PASSWORD || "smhrd3",
  database: process.env.DB_NAME     || "campus_25SW_BD_p3_3",
};
const pool = mysql.createPool({
  ...DB_CONFIG,
  waitForConnections: true,
  connectionLimit  : 10,
});

/* =========================
 * OAuth 설정
 * ========================= */
const KAKAO = {
  client_id    : process.env.KAKAO_CLIENT_ID || "",
  client_secret: process.env.KAKAO_CLIENT_SECRET || "",
  redirect_uri : process.env.KAKAO_REDIRECT_URI || `${SERVER_BASE_URL}/auth/kakao/callback`,
};
const NAVER = {
  client_id    : process.env.NAVER_CLIENT_ID || "",
  client_secret: process.env.NAVER_CLIENT_SECRET || "",
  redirect_uri : process.env.NAVER_REDIRECT_URI || `${SERVER_BASE_URL}/auth/naver/callback`,
};
const GOOGLE = {
  client_id    : process.env.GOOGLE_CLIENT_ID || "",
  client_secret: process.env.GOOGLE_CLIENT_SECRET || "",
  redirect_uri : process.env.GOOGLE_REDIRECT_URI || `${SERVER_BASE_URL}/auth/google/callback`,
};

/* =========================
 * 유틸
 * ========================= */
function sign(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: "7d" });
}
function setAuthCookie(res, token) {
  res.cookie(COOKIE_NAME, token, {
    httpOnly: true,
    secure  : USE_SECURE_COOKIE, // HTTPS일 때만 true
    sameSite: "lax",
    maxAge  : 7 * 24 * 60 * 60 * 1000,
    path    : "/",
  });
}
const makeState = (prefix) =>
  `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

/**
 * SNS 사용자 upsert (tb_user)
 * - login_type: 'google' | 'kakao' | 'naver'
 * - login_id  : 공급자 원시 ID(권장) or email(fallback)
 * - 반환: user_id(pk)
 */
async function upsertSNSUser({ provider, providerRawId, email, nick }) {
  let login_id = String(providerRawId || "").trim();
  if (!login_id && email) login_id = String(email).trim();
  if (!login_id) throw new Error("SNS 사용자 식별자 없음");

  const [rows] = await pool.query(
    `SELECT user_id, nick
       FROM tb_user
      WHERE login_id = ? AND login_type = ?
      LIMIT 1`,
    [login_id, provider]
  );

  if (rows.length) {
    const uid = rows[0].user_id;
    if (nick && nick !== rows[0].nick) {
      await pool.query(`UPDATE tb_user SET nick = ? WHERE user_id = ?`, [nick, uid]);
    }
    return uid;
  }

  const [ins] = await pool.query(
    `INSERT INTO tb_user (login_id, login_type, pwd, nick, birthyear, gender)
     VALUES (?, ?, NULL, ?, NULL, NULL)`,
    [login_id, provider, nick || `${provider}_${login_id.slice(0, 6)}`]
  );
  return ins.insertId;
}

/* =========================
 * Kakao
 * ========================= */
router.get("/kakao", (req, res) => {
  const state = makeState("kakao");
  const url =
    "https://kauth.kakao.com/oauth/authorize?" +
    qs.stringify({
      client_id    : KAKAO.client_id,
      redirect_uri : KAKAO.redirect_uri,
      response_type: "code",
      scope        : "profile_nickname account_email",
      prompt       : "select_account",
      state,
    });
  return res.redirect(url);
});

router.get("/kakao/callback", async (req, res) => {
  try {
    const { code } = req.query;
    if (!code) return res.status(400).send("code가 없습니다.");

    const tokenRes = await axios.post(
      "https://kauth.kakao.com/oauth/token",
      qs.stringify({
        grant_type   : "authorization_code",
        client_id    : KAKAO.client_id,
        client_secret: KAKAO.client_secret || undefined,
        redirect_uri : KAKAO.redirect_uri,
        code,
      }),
      { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
    );
    const access_token = tokenRes.data.access_token;

    const meRes = await axios.get("https://kapi.kakao.com/v2/user/me", {
      headers: { Authorization: `Bearer ${access_token}` },
    });

    const kakaoId  = String(meRes.data.id);
    const acc      = meRes.data.kakao_account || {};
    const profile  = acc.profile || {};
    const email    = acc.email || null;
    const nickname = profile.nickname || (email ? email.split("@")[0] : `kakao_${kakaoId}`);

    const uid = await upsertSNSUser({
      provider: "kakao",
      providerRawId: kakaoId,
      email,
      nick: nickname,
    });

    const token = sign({ uid, typ: "kakao" });
    setAuthCookie(res, token);

    return res.redirect(`${FRONTEND_BASE_URL}/`);
  } catch (err) {
    console.error("[/auth/kakao/callback] error:", err.response?.data || err);
    return res.status(500).send("카카오 로그인 실패");
  }
});

/* =========================
 * Naver
 * ========================= */
router.get("/naver", (req, res) => {
  const state = makeState("naver");
  const url =
    "https://nid.naver.com/oauth2.0/authorize?" +
    qs.stringify({
      response_type: "code",
      client_id    : NAVER.client_id,
      redirect_uri : NAVER.redirect_uri,
      state,
      auth_type    : "reprompt",
      scope        : "name nickname email",
    });
  return res.redirect(url);
});

router.get("/naver/callback", async (req, res) => {
  try {
    const { code, state } = req.query;
    if (!code) return res.status(400).send("code가 없습니다.");

    const tokenRes = await axios.get("https://nid.naver.com/oauth2.0/token", {
      params: {
        grant_type   : "authorization_code",
        client_id    : NAVER.client_id,
        client_secret: NAVER.client_secret,
        code,
        state,
      },
    });
    const access_token = tokenRes.data.access_token;

    const meRes = await axios.get("https://openapi.naver.com/v1/nid/me", {
      headers: { Authorization: `Bearer ${access_token}` },
    });

    const resp     = meRes.data.response || {};
    const naverId  = String(resp.id);
    const email    = resp.email || null;
    const nickname = resp.name || resp.nickname || (email ? email.split("@")[0] : `naver_${naverId}`);

    const uid = await upsertSNSUser({
      provider: "naver",
      providerRawId: naverId,
      email,
      nick: nickname,
    });

    const token = sign({ uid, typ: "naver" });
    setAuthCookie(res, token);

    return res.redirect(`${FRONTEND_BASE_URL}/`);
  } catch (err) {
    console.error("[/auth/naver/callback] error:", err.response?.data || err);
    return res.status(500).send("네이버 로그인 실패");
  }
});

/* =========================
 * Google
 * ========================= */
router.get("/google", (req, res) => {
  const url =
    "https://accounts.google.com/o/oauth2/v2/auth?" +
    qs.stringify({
      client_id            : GOOGLE.client_id,
      redirect_uri         : GOOGLE.redirect_uri,
      response_type        : "code",
      scope                : "openid email profile",
      access_type          : "online",
      include_granted_scopes: "true",
      prompt               : "consent",
    });
  return res.redirect(url);
});

router.get("/google/callback", async (req, res) => {
  try {
    const { code } = req.query;
    if (!code) return res.status(400).send("code가 없습니다.");

    const tokenRes = await axios.post(
      "https://oauth2.googleapis.com/token",
      qs.stringify({
        code,
        client_id    : GOOGLE.client_id,
        client_secret: GOOGLE.client_secret,
        redirect_uri : GOOGLE.redirect_uri,
        grant_type   : "authorization_code",
      }),
      { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
    );
    const access_token = tokenRes.data.access_token;

    const meRes = await axios.get("https://www.googleapis.com/oauth2/v2/userinfo", {
      headers: { Authorization: `Bearer ${access_token}` },
    });

    const gUser    = meRes.data;
    const googleId = String(gUser.id);
    const email    = gUser.email || null;
    const nickname = gUser.name || (email ? email.split("@")[0] : `google_${googleId}`);

    const uid = await upsertSNSUser({
      provider: "google",
      providerRawId: googleId,
      email,
      nick: nickname,
    });

    const token = sign({ uid, typ: "google" });
    setAuthCookie(res, token);

    return res.redirect(`${FRONTEND_BASE_URL}/`);
  } catch (err) {
    console.error("[/auth/google/callback] error:", err.response?.data || err);
    return res.status(500).send("구글 로그인 실패");
  }
});

module.exports = router;
