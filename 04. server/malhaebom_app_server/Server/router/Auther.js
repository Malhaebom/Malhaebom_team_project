// File: src/Server/router/Auther.js
require("dotenv").config();

const express = require("express");
const axios = require("axios");
const qs = require("querystring");
const mysql = require("mysql2/promise");
const crypto = require("crypto");
const jwt = require("jsonwebtoken");

const router = express.Router();

/* =========================
 * DB 설정 (.env 사용)
 * ========================= */
const DB_CONFIG = {
  host: process.env.DB_HOST || "project-db-campus.smhrd.com",
  port: Number(process.env.DB_PORT || 3307),
  user: process.env.DB_USER || "campus_25SW_BD_p3_3",
  password: process.env.DB_PASSWORD || "smhrd3",
  database: process.env.DB_NAME || "campus_25SW_BD_p3_3",
};

const pool = mysql.createPool({
  ...DB_CONFIG,
  waitForConnections: true,
  connectionLimit: 10,
});

/* =========================
 * JWT (앱에서 쓰기 위함)
 * ========================= */
const JWT_SECRET = process.env.JWT_SECRET || "malhaebom_sns";
const sign = (payload) => jwt.sign(payload, JWT_SECRET, { expiresIn: "7d" });

/* =========================
 * 모바일 앱 콜백 URI (flutter_web_auth_2)
 * 예: myapp://auth/callback
 * ========================= */
const APP_CALLBACK = process.env.APP_CALLBACK || "myapp://auth/callback";

/* =========================
 * 공개 베이스 URL + 리다이렉트 경로
 * - ADB reverse 사용할 땐: PUBLIC_BASE_URL = "http://localhost:4000"
 * - ngrok 등 HTTPS 터널 사용 시: "https://<서브도메인>.ngrok-free.app"
 * ========================= */
const PUBLIC_BASE_URL = (process.env.PUBLIC_BASE_URL || "").replace(/\/+$/, "");
const GOOGLE_REDIRECT_PATH = process.env.GOOGLE_REDIRECT_PATH || "/auth/google/callback";
const KAKAO_REDIRECT_PATH  = process.env.KAKAO_REDIRECT_PATH  || "/auth/kakao/callback";
const NAVER_REDIRECT_PATH  = process.env.NAVER_REDIRECT_PATH  || "/auth/naver/callback";

function assertEnv(v, name) {
  if (!v) console.error(`[ENV MISSING] ${name} not set`);
}

// OAuth 설정값 (client_id/secret)
const GOOGLE = {
  client_id: process.env.GOOGLE_CLIENT_ID,
  client_secret: process.env.GOOGLE_CLIENT_SECRET,
};
const KAKAO = {
  client_id: process.env.KAKAO_CLIENT_ID,
  client_secret: process.env.KAKAO_CLIENT_SECRET || "", // 선택
};
const NAVER = {
  client_id: process.env.NAVER_CLIENT_ID,
  client_secret: process.env.NAVER_CLIENT_SECRET,
};

// 필수 env 경고
assertEnv(GOOGLE.client_id, "GOOGLE_CLIENT_ID");
assertEnv(GOOGLE.client_secret, "GOOGLE_CLIENT_SECRET");
assertEnv(KAKAO.client_id, "KAKAO_CLIENT_ID");
assertEnv(NAVER.client_id, "NAVER_CLIENT_ID");
assertEnv(NAVER.client_secret, "NAVER_CLIENT_SECRET");
// PUBLIC_BASE_URL은 아래 buildRedirectUri에서 자동 보완되지만 명시 권장
if (!PUBLIC_BASE_URL) {
  console.warn("[ENV NOTICE] PUBLIC_BASE_URL not set. Will infer from request host or fallback to http://localhost:4000");
}

/* =========================
 * 요청 호스트 캐시 (개발 편의)
 * ========================= */
let reqHostCache = "";
router.use((req, _res, next) => {
  const proto = req.headers["x-forwarded-proto"] || req.protocol || "http";
  const host  = req.get("host");
  if (proto && host) {
    reqHostCache = `${proto}://${host}`;
  }
  next();
});

/* =========================
 * redirect_uri 구성기
 * 우선순위: PUBLIC_BASE_URL > 요청 Host > http://localhost:4000
 * ========================= */
function buildRedirectUri(path) {
  const base =
    PUBLIC_BASE_URL ||
    reqHostCache ||
    "http://localhost:4000";
  return base.replace(/\/+$/, "") + path;
}

/* =========================
 * CSRF state 저장소 (5분 TTL)
 * ========================= */
const STATE_TTL_MS = 5 * 60 * 1000;
const GOOGLE_STATE = new Map();
const KAKAO_STATE  = new Map();
const NAVER_STATE  = new Map();

function saveState(store, state) {
  store.set(state, Date.now());
}
function verifyAndDeleteState(store, state) {
  const ts = store.get(state);
  store.delete(state);
  if (!ts) return false;
  return Date.now() - ts < STATE_TTL_MS;
}

/* =========================
 * 공통: 앱으로 리다이렉트
 * ========================= */
function redirectToApp(res, { token, sns_user_id, sns_nick, sns_login_type }) {
  const url =
    APP_CALLBACK +
    `?token=${encodeURIComponent(token)}` +
    `&sns_user_id=${encodeURIComponent(sns_user_id)}` +
    `&sns_nick=${encodeURIComponent(sns_nick ?? "")}` +
    `&sns_login_type=${encodeURIComponent(sns_login_type)}`;
  return res.redirect(url);
}

/* =========================
 * 공통: 에러 리다이렉트
 * ========================= */
function redirectError(res, msg) {
  const url = APP_CALLBACK + `?error=${encodeURIComponent(msg)}`;
  return res.redirect(url);
}

/* =========================
 * DB: SNS 사용자 없으면 INSERT
 * ========================= */
async function ensureSnsUser({ sns_user_id, sns_nick, sns_login_type }) {
  const [[exists]] = await pool.execute(
    "SELECT 1 FROM tb_sns_user WHERE sns_user_id = ? LIMIT 1",
    [sns_user_id]
  );
  if (!exists) {
    await pool.execute(
      "INSERT INTO tb_sns_user (sns_user_id, sns_nick, sns_login_type) VALUES (?, ?, ?)",
      [sns_user_id, sns_nick ?? "", sns_login_type]
    );
  }
}

/* =========================
 * 1) Google 로그인
 * - 구글 콘솔 Authorized redirect URIs:
 *   http://localhost:4000/auth/google/callback  (ADB reverse)
 *   또는
 *   https://<ngrok>/auth/google/callback       (터널 사용)
 * ========================= */
router.get("/google", (req, res) => {
  const state = crypto.randomBytes(16).toString("hex");
  saveState(GOOGLE_STATE, state);

  const redirect_uri = buildRedirectUri(GOOGLE_REDIRECT_PATH);

  const url =
    "https://accounts.google.com/o/oauth2/v2/auth?" +
    qs.stringify({
      client_id: GOOGLE.client_id,
      redirect_uri,
      response_type: "code",
      scope: "profile email",
      prompt: "select_account",
      access_type: "offline",
      state,
    });
  res.redirect(url);
});

router.get("/google/callback", async (req, res) => {
  try {
    const { code, state } = req.query;
    if (!code)  return redirectError(res, "Google code 없음");
    if (!state || !verifyAndDeleteState(GOOGLE_STATE, state)) {
      return redirectError(res, "잘못된 state");
    }

    const redirect_uri = buildRedirectUri(GOOGLE_REDIRECT_PATH);

    const tokenRes = await axios.post(
      "https://oauth2.googleapis.com/token",
      qs.stringify({
        code,
        client_id: GOOGLE.client_id,
        client_secret: GOOGLE.client_secret,
        redirect_uri,
        grant_type: "authorization_code",
      }),
      { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
    );

    const accessToken = tokenRes.data.access_token;
    if (!accessToken) return redirectError(res, "Google access token 없음");

    const profileRes = await axios.get(
      "https://www.googleapis.com/oauth2/v2/userinfo",
      { headers: { Authorization: `Bearer ${accessToken}` } }
    );

    const data = profileRes.data || {};
    const sns_user_id = String(data.email ?? "");
    const sns_nick = String(data.name ?? "");
    const sns_login_type = "google";

    if (!sns_user_id) return redirectError(res, "구글 이메일 없음");

    await ensureSnsUser({ sns_user_id, sns_nick, sns_login_type });

    const token = sign({ id: sns_user_id, nick: sns_nick, type: sns_login_type });
    return redirectToApp(res, { token, sns_user_id, sns_nick, sns_login_type });
  } catch (e) {
    console.error("Google error", e?.response?.data || e);
    return redirectError(res, "Google 로그인 실패");
  }
});

/* =========================
 * 2) Kakao 로그인
 * ========================= */
router.get("/kakao", (req, res) => {
  const state = crypto.randomBytes(16).toString("hex");
  saveState(KAKAO_STATE, state);

  const redirect_uri = buildRedirectUri(KAKAO_REDIRECT_PATH);

  const url =
    "https://kauth.kakao.com/oauth/authorize?" +
    qs.stringify({
      client_id: KAKAO.client_id,
      redirect_uri,
      response_type: "code",
      scope: "profile_nickname account_email",
      state,
    });
  res.redirect(url);
});

router.get("/kakao/callback", async (req, res) => {
  try {
    const { code, state } = req.query;
    if (!code)  return redirectError(res, "Kakao code 없음");
    if (!state || !verifyAndDeleteState(KAKAO_STATE, state)) {
      return redirectError(res, "잘못된 state");
    }

    const redirect_uri = buildRedirectUri(KAKAO_REDIRECT_PATH);

    const body = {
      grant_type: "authorization_code",
      client_id: KAKAO.client_id,
      redirect_uri,
      code,
    };
    if (KAKAO.client_secret) body.client_secret = KAKAO.client_secret;

    const tokenRes = await axios.post(
      "https://kauth.kakao.com/oauth/token",
      qs.stringify(body),
      { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
    );

    const accessToken = tokenRes.data.access_token;
    if (!accessToken) return redirectError(res, "Kakao access token 없음");

    const profileRes = await axios.get("https://kapi.kakao.com/v2/user/me", {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    const acct = profileRes.data?.kakao_account || {};
    let  sns_user_id   = String(acct.email ?? "");
    const sns_nick      = String(acct.profile?.nickname ?? "");
    const sns_login_type = "kakao";

    // 이메일 미동의 계정은 id 사용
    if (!sns_user_id) sns_user_id = String(profileRes.data?.id ?? "");
    if (!sns_user_id) return redirectError(res, "카카오 아이디 없음");

    await ensureSnsUser({ sns_user_id, sns_nick, sns_login_type });

    const token = sign({ id: sns_user_id, nick: sns_nick, type: sns_login_type });
    return redirectToApp(res, { token, sns_user_id, sns_nick, sns_login_type });
  } catch (e) {
    console.error("Kakao error", e?.response?.data || e);
    return redirectError(res, "Kakao 로그인 실패");
  }
});

/* =========================
 * 3) Naver 로그인
 * ========================= */
router.get("/naver", (req, res) => {
  const state = crypto.randomBytes(16).toString("hex");
  saveState(NAVER_STATE, state);

  const redirect_uri = buildRedirectUri(NAVER_REDIRECT_PATH);

  const url =
    "https://nid.naver.com/oauth2.0/authorize?" +
    qs.stringify({
      client_id: NAVER.client_id,
      response_type: "code",
      redirect_uri,
      state,
    });
  res.redirect(url);
});

router.get("/naver/callback", async (req, res) => {
  try {
    const { code, state } = req.query;
    if (!code)  return redirectError(res, "Naver code 없음");
    if (!state || !verifyAndDeleteState(NAVER_STATE, state)) {
      return redirectError(res, "잘못된 state");
    }

    const redirect_uri = buildRedirectUri(NAVER_REDIRECT_PATH);

    const tokenRes = await axios.get("https://nid.naver.com/oauth2.0/token", {
      params: {
        grant_type: "authorization_code",
        client_id: NAVER.client_id,
        client_secret: NAVER.client_secret,
        code,
        state,
      },
    });

    const accessToken = tokenRes.data.access_token;
    if (!accessToken) return redirectError(res, "Naver access token 없음");

    const profileRes = await axios.get("https://openapi.naver.com/v1/nid/me", {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    const resp = profileRes.data?.response || {};
    const sns_user_id   = String(resp.email ?? "");
    const sns_nick      = String(resp.name  ?? "");
    const sns_login_type = "naver";

    if (!sns_user_id) return redirectError(res, "네이버 이메일 없음");

    await ensureSnsUser({ sns_user_id, sns_nick, sns_login_type });

    const token = sign({ id: sns_user_id, nick: sns_nick, type: sns_login_type });
    return redirectToApp(res, { token, sns_user_id, sns_nick, sns_login_type });
  } catch (e) {
    console.error("Naver error", e?.response?.data || e);
    return redirectError(res, "Naver 로그인 실패");
  }
});

module.exports = router;
