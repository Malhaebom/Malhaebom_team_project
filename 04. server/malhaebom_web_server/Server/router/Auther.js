require("dotenv").config();

const express = require("express");
const router = express.Router();
const axios = require("axios");
const qs = require("querystring");
const mysql = require("mysql2/promise");
const jwt = require("jsonwebtoken");

/* =========================
 * 환경변수 적용
 * ========================= */
const SERVER_BASE_URL   = process.env.SERVER_BASE_URL   || "http://localhost:3001";
const FRONTEND_BASE_URL = process.env.FRONTEND_BASE_URL || "http://localhost:5173";
const JWT_SECRET        = process.env.JWT_SECRET        || "malhaebom_sns";
const COOKIE_NAME       = process.env.COOKIE_NAME       || "mb_access";
const NODE_ENV          = process.env.NODE_ENV || "development";
const IS_HTTPS          = SERVER_BASE_URL.startsWith("https://");

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
    secure  : IS_HTTPS || NODE_ENV === "production",
    sameSite: "lax",
    maxAge  : 7 * 24 * 60 * 60 * 1000,
    path    : "/",
  });
}

/**
 * 동일인 매칭 우선 → 있으면 INSERT 금지, 닉네임만 갱신
 */
async function upsertSNSUser({ sns_login_type, sns_user_id, sns_nick, email, provider_raw_id }) {
  const candidates = [
    sns_user_id,
    provider_raw_id,
    email,
    email ? `${sns_login_type}:${email}` : null,
    provider_raw_id ? `${sns_login_type}:${provider_raw_id}` : null,
  ].filter(Boolean);

  if (candidates.length) {
    const placeholders = candidates.map(() => "?").join(",");
    const [rows] = await pool.query(
      `
        SELECT sns_user_id
          FROM tb_sns_user
         WHERE sns_login_type = ?
           AND sns_user_id IN (${placeholders})
         LIMIT 1
      `,
      [sns_login_type, ...candidates]
    );

    if (rows.length) {
      const existingId = rows[0].sns_user_id;
      await pool.query(
        `UPDATE tb_sns_user
            SET sns_nick = ?
          WHERE sns_login_type = ? AND sns_user_id = ?`,
        [sns_nick, sns_login_type, existingId]
      );
      return existingId;
    }
  }

  const toSaveId = email || sns_user_id;
  await pool.query(
    `INSERT INTO tb_sns_user (sns_user_id, sns_nick, sns_login_type)
     VALUES (?, ?, ?)`,
    [toSaveId, sns_nick, sns_login_type]
  );

  return toSaveId;
}

const makeState = (prefix) =>
  `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

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

    const normalizedId = `kakao:${kakaoId}`;
    const savedId = await upsertSNSUser({
      sns_login_type: "kakao",
      sns_user_id   : normalizedId,
      sns_nick      : nickname,
      email,
      provider_raw_id: kakaoId,
    });

    const token = sign({ sub: savedId, typ: "sns" });
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
      scope        : "name nickname email"
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

    const normalizedId = `naver:${naverId}`;
    const savedId = await upsertSNSUser({
      sns_login_type: "naver",
      sns_user_id   : normalizedId,
      sns_nick      : nickname,
      email,
      provider_raw_id: naverId,
    });

    const token = sign({ sub: savedId, typ: "sns" });
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

    const normalizedId = `google:${googleId}`;
    const savedId = await upsertSNSUser({
      sns_login_type: "google",
      sns_user_id   : normalizedId,
      sns_nick      : nickname,
      email,
      provider_raw_id: googleId,
    });

    const token = sign({ sub: savedId, typ: "sns" });
    setAuthCookie(res, token);

    return res.redirect(`${FRONTEND_BASE_URL}/`);
  } catch (err) {
    console.error("[/auth/google/callback] error:", err.response?.data || err);
    return res.status(500).send("구글 로그인 실패");
  }
});

module.exports = router;
