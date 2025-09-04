// Server/router/Auther.js
const path = require("path");
require("dotenv").config({ path: path.join(__dirname, "..", ".env") });

const express = require("express");
const router = express.Router();
const axios = require("axios");
const qs = require("querystring");
const mysql = require("mysql2/promise");
const jwt = require("jsonwebtoken");

/* =========================
 * 환경변수
 * ========================= */
const SERVER_BASE_URL   = process.env.SERVER_BASE_URL   || "http://127.0.0.1:3001";
const FRONTEND_BASE_URL = process.env.FRONTEND_BASE_URL || process.env.PUBLIC_BASE_URL || "https://malhaebom.smhrd.com";
const PUBLIC_BASE_URL   = process.env.PUBLIC_BASE_URL   || FRONTEND_BASE_URL;
const JWT_SECRET        = process.env.JWT_SECRET        || "malhaebom_sns";
const COOKIE_NAME       = process.env.COOKIE_NAME       || "mb_access";

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
  redirect_uri : process.env.KAKAO_REDIRECT_URI || `${PUBLIC_BASE_URL}/api/auth/kakao/callback`,
};
const NAVER = {
  client_id    : process.env.NAVER_CLIENT_ID || "",
  client_secret: process.env.NAVER_CLIENT_SECRET || "",
  redirect_uri : process.env.NAVER_REDIRECT_URI || `${PUBLIC_BASE_URL}/api/auth/naver/callback`,
};
const GOOGLE = {
  client_id    : process.env.GOOGLE_CLIENT_ID || "",
  client_secret: process.env.GOOGLE_CLIENT_SECRET || "",
  redirect_uri : process.env.GOOGLE_REDIRECT_URI || `${PUBLIC_BASE_URL}/api/auth/google/callback`,
};

/* =========================
 * 유틸
 * ========================= */
function sign(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: "7d" });
}
function isSecureReq(req) {
  return !!(req?.secure || String(req?.headers?.["x-forwarded-proto"] || "").toLowerCase() === "https");
}
function setAuthCookie(req, res, token) {
  res.cookie(COOKIE_NAME, token, {
    httpOnly: true,
    secure  : isSecureReq(req),
    sameSite: "lax",
    maxAge  : 7 * 24 * 60 * 60 * 1000,
    path    : "/",
  });
}
const makeState = (prefix) =>
  `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

function buildLoginKeyOrThrow(provider, rawId, email) {
  if (email) return String(email).toLowerCase();
  if (rawId)  return `${provider}:${String(rawId)}`;
  throw new Error("SNS 사용자 식별자 없음 (rawId/email 둘 다 없음)");
}

async function upsertSNSUser({ provider, providerRawId, email, nick }) {
  const emailKey = email ? String(email).toLowerCase() : null;
  const pidKey   = `${provider}:${String(providerRawId || "")}`;

  if (emailKey) {
    const [byEmail] = await pool.query(
      `SELECT user_id, nick FROM tb_user
        WHERE login_id = ? AND login_type = ?
        LIMIT 1`,
      [emailKey, provider]
    );
    if (byEmail.length) {
      const uid = byEmail[0].user_id;
      if (nick && nick !== byEmail[0].nick) {
        await pool.query(`UPDATE tb_user SET nick = ? WHERE user_id = ?`, [nick, uid]);
      }
      return uid;
    }
  }

  const [byPid] = await pool.query(
    `SELECT user_id, nick, login_id FROM tb_user
      WHERE login_id = ? AND login_type = ?
      LIMIT 1`,
    [pidKey, provider]
  );
  if (byPid.length) {
    const uid = byPid[0].user_id;

    if (emailKey && byPid[0].login_id !== emailKey) {
      const [dup] = await pool.query(
        `SELECT user_id FROM tb_user
          WHERE login_id = ? AND login_type = ?
          LIMIT 1`,
        [emailKey, provider]
      );
      if (!dup.length) {
        await pool.query(
          `UPDATE tb_user SET login_id = ? WHERE user_id = ?`,
          [emailKey, uid]
        );
      }
    }

    if (nick && nick !== byPid[0].nick) {
      await pool.query(`UPDATE tb_user SET nick = ? WHERE user_id = ?`, [nick, uid]);
    }
    return uid;
  }

  const login_id = emailKey || pidKey;
  const [ins] = await pool.query(
    `INSERT INTO tb_user (login_id, login_type, pwd, nick, birthyear, gender)
     VALUES (?, ?, NULL, ?, NULL, NULL)`,
    [login_id, provider, nick || `${provider}_${String(providerRawId || email || "").slice(0, 6)}`]
  );
  return ins.insertId;
}

/* Kakao */
router.get("/kakao", (req, res) => {
  if (!KAKAO.client_id || !KAKAO.redirect_uri) {
    return res.status(500).send("카카오 설정 누락");
  }
  const state = makeState("kakao");
  const authUrl =
    "https://kauth.kakao.com/oauth/authorize?" +
    qs.stringify({
      client_id    : KAKAO.client_id,
      redirect_uri : KAKAO.redirect_uri,
      response_type: "code",
      scope        : "profile_nickname account_email",
      prompt       : "select_account",
      state,
    });
  return res.redirect(authUrl);
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
    setAuthCookie(req, res, token);

    return res.redirect(`${FRONTEND_BASE_URL}/`);
  } catch (err) {
    console.error("[/auth/kakao/callback] error:", err.response?.data || err);
    return res.status(500).send("카카오 로그인 실패");
  }
});

/* Naver */
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
    setAuthCookie(req, res, token);

    return res.redirect(`${FRONTEND_BASE_URL}/`);
  } catch (err) {
    console.error("[/auth/naver/callback] error:", err.response?.data || err);
    return res.status(500).send("네이버 로그인 실패");
  }
});

/* Google */
router.get("/google", (req, res) => {
  const url =
    "https://accounts.google.com/o/oauth2/v2/auth?" +
    qs.stringify({
      client_id             : GOOGLE.client_id,
      redirect_uri          : GOOGLE.redirect_uri,
      response_type         : "code",
      scope                 : "openid email profile",
      access_type           : "online",
      include_granted_scopes: "true",
      prompt                : "consent",
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
    setAuthCookie(req, res, token);

    return res.redirect(`${FRONTEND_BASE_URL}/`);
  } catch (err) {
    console.error("[/auth/google/callback] error:", err.response?.data || err);
    return res.status(500).send("구글 로그인 실패");
  }
});

module.exports = router;
