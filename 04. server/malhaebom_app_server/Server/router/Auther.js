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
 * JWT
 * ========================= */
const JWT_SECRET = process.env.JWT_SECRET || "malhaebom_sns";
function signJWT(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: "7d" });
}

/* =========================
 * 모바일 앱 콜백 URI (flutter_web_auth_2)
 * ========================= */
const APP_CALLBACK = process.env.APP_CALLBACK || "myapp://auth/callback";

/* =========================
 * 공개 베이스 URL + 리다이렉트 경로
 * ========================= */
const PUBLIC_BASE_URL = (process.env.PUBLIC_BASE_URL || "").replace(/\/+$/, "");
const GOOGLE_REDIRECT_PATH = process.env.GOOGLE_REDIRECT_PATH || "/auth/google/callback";
const KAKAO_REDIRECT_PATH  = process.env.KAKAO_REDIRECT_PATH  || "/auth/kakao/callback";
const NAVER_REDIRECT_PATH  = process.env.NAVER_REDIRECT_PATH  || "/auth/naver/callback";

function assertEnv(v, name) {
  if (!v) console.error(`[ENV MISSING] ${name} not set`);
}

// OAuth 설정값
const GOOGLE = {
  client_id: process.env.GOOGLE_CLIENT_ID,
  client_secret: process.env.GOOGLE_CLIENT_SECRET,
};
const KAKAO = {
  client_id: process.env.KAKAO_CLIENT_ID,
  client_secret: process.env.KAKAO_CLIENT_SECRET || "",
};
const NAVER = {
  client_id: process.env.NAVER_CLIENT_ID,
  client_secret: process.env.NAVER_CLIENT_SECRET,
};

assertEnv(GOOGLE.client_id, "GOOGLE_CLIENT_ID");
assertEnv(GOOGLE.client_secret, "GOOGLE_CLIENT_SECRET");
assertEnv(KAKAO.client_id, "KAKAO_CLIENT_ID");
assertEnv(NAVER.client_id, "NAVER_CLIENT_ID");
assertEnv(NAVER.client_secret, "NAVER_CLIENT_SECRET");

if (!PUBLIC_BASE_URL) {
  console.warn("[ENV NOTICE] PUBLIC_BASE_URL not set. Will infer from request host or fallback to http://localhost:4000");
}

/* =========================
 * 요청 호스트 캐시
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
 * ========================= */
function buildRedirectUri(path) {
  const base = PUBLIC_BASE_URL || reqHostCache || "http://localhost:4000";
  return base.replace(/\/+$/, "") + path;
}

/* =========================
 * CSRF state 저장소 (5분 TTL)
 * ========================= */
const STATE_TTL_MS = 5 * 60 * 1000;
const GOOGLE_STATE = new Map();
const KAKAO_STATE  = new Map();
const NAVER_STATE  = new Map();

function saveState(store, state) { store.set(state, Date.now()); }
function verifyAndDeleteState(store, state) {
  const ts = store.get(state);
  store.delete(state);
  if (!ts) return false;
  return Date.now() - ts < STATE_TTL_MS;
}

/* =========================
 * 앱 리다이렉트용 HTML 브리지
 * ========================= */
function htmlBridge(toUrl, title = "앱으로 돌아가는 중…", btnLabel = "앱으로 돌아가기", hint = "자동 전환되지 않으면 버튼을 눌러 주세요.") {
  return `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1" />
  <title>${title}</title>
  <style>
    body{font-family:system-ui,-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;padding:24px;line-height:1.5}
    .box{max-width:520px;margin:24px auto;padding:20px;border:1px solid #eee;border-radius:12px}
    .btn{display:inline-block;margin-top:12px;padding:10px 14px;border-radius:8px;background:#344CB7;color:#fff;text-decoration:none}
    .muted{color:#666;font-size:14px}
  </style>
  <script>
    (function(){
      var target = ${JSON.stringify(toUrl)};
      try { window.location.replace(target); } catch(e) {}
      setTimeout(function(){
        var hint = document.getElementById('hint');
        if (hint) hint.style.display = 'block';
      }, 800);
    })();
  </script>
</head>
<body>
  <div class="box">
    <h3>${title}</h3>
    <p class="muted">${hint}</p>
    <a class="btn" href="${toUrl}">${btnLabel}</a>
    <p id="hint" class="muted" style="display:none;margin-top:8px;">버튼이 작동하지 않으면 브라우저 탭을 닫아 주세요.</p>
  </div>
</body>
</html>`;
}

function redirectToApp(res, { token, uid, login_id, login_type, nick }) {
  const url =
    APP_CALLBACK +
    `?token=${encodeURIComponent(token)}` +
    `&uid=${encodeURIComponent(String(uid))}` +
    `&login_id=${encodeURIComponent(login_id)}` +
    `&login_type=${encodeURIComponent(login_type)}` +
    `&nick=${encodeURIComponent(nick ?? "")}`;

  const html = htmlBridge(url, "앱으로 돌아가는 중…", "앱으로 돌아가기");
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  return res.status(200).send(html);
}

function redirectError(res, msg) {
  const url = APP_CALLBACK + `?error=${encodeURIComponent(msg)}`;
  const html = htmlBridge(url, "로그인 처리 중 오류", "앱으로 돌아가기", "자동 전환되지 않으면 버튼을 눌러 주세요.");
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  return res.status(200).send(html);
}

/* =========================
 * DB: SNS 사용자 UPSERT → tb_user
 *  - 입력: login_id, login_type, nick(가능하면)
 *  - 출력: { uid, login_id, login_type, nick }
 * ========================= */
async function upsertAndGetUser({ login_id, login_type, nick }) {
  const conn = await pool.getConnection();
  try {
    // 닉네임은 기존이 비어있을 때만 보완
    const sql = `
      INSERT INTO tb_user (login_id, login_type, nick, pwd)
      VALUES (?, ?, ?, NULL)
      ON DUPLICATE KEY UPDATE
        nick = IF(nick IS NULL OR nick = '', VALUES(nick), nick)
    `;
    await conn.execute(sql, [login_id, login_type, nick || ""]);

    const [rows] = await conn.execute(
      "SELECT user_id AS uid, login_id, login_type, nick FROM tb_user WHERE login_id = ? AND login_type = ? LIMIT 1",
      [login_id, login_type]
    );
    if (!rows.length) throw new Error("UPSERT succeeded but SELECT returned no row");
    return rows[0];
  } finally {
    conn.release();
  }
}

/* =========================
 * Helper: reauth 플래그
 * ========================= */
function getReauthFlags(req) {
  const reauth = String(req.query.reauth || "") === "1";
  return { reauth };
}

/* =========================
 * 1) Google 로그인
 * ========================= */
router.get("/google", (req, res) => {
  const state = crypto.randomBytes(16).toString("hex");
  GOOGLE_STATE.set(state, Date.now());

  const { reauth } = getReauthFlags(req);
  const redirect_uri = buildRedirectUri(GOOGLE_REDIRECT_PATH);
  console.log("[GOOGLE] redirect_uri:", redirect_uri);

  const prompt = reauth ? "select_account consent" : "select_account";

  const url =
    "https://accounts.google.com/o/oauth2/v2/auth?" +
    qs.stringify({
      client_id: GOOGLE.client_id,
      redirect_uri,
      response_type: "code",
      scope: "profile email",
      prompt,
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
    const email = String(data.email ?? "");
    const name  = String(data.name  ?? "");
    if (!email) return redirectError(res, "구글 이메일 없음");

    const user = await upsertAndGetUser({
      login_id: email,
      login_type: "google",
      nick: name,
    });

    const token = signJWT({
      uid: user.uid,
      login_id: user.login_id,
      login_type: "google",
      nick: user.nick || name || "",
    });

    return redirectToApp(res, {
      token,
      uid: user.uid,
      login_id: user.login_id,
      login_type: "google",
      nick: user.nick || name || "",
    });
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
  KAKAO_STATE.set(state, Date.now());

  const { reauth } = getReauthFlags(req);
  const redirect_uri = buildRedirectUri(KAKAO_REDIRECT_PATH);
  console.log("[KAKAO] redirect_uri:", redirect_uri);

  const params = {
    client_id: KAKAO.client_id,
    redirect_uri,
    response_type: "code",
    scope: "profile_nickname account_email",
    state,
  };

  if (reauth) params.prompt = "login";

  const url = "https://kauth.kakao.com/oauth/authorize?" + qs.stringify(params);
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
    let email  = String(acct.email ?? "");
    const name = String(acct.profile?.nickname ?? "");
    if (!email) email = String(profileRes.data?.id ?? "");
    if (!email) return redirectError(res, "카카오 아이디 없음");

    const user = await upsertAndGetUser({
      login_id: email,
      login_type: "kakao",
      nick: name,
    });

    const token = signJWT({
      uid: user.uid,
      login_id: user.login_id,
      login_type: "kakao",
      nick: user.nick || name || "",
    });

    return redirectToApp(res, {
      token,
      uid: user.uid,
      login_id: user.login_id,
      login_type: "kakao",
      nick: user.nick || name || "",
    });
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
  NAVER_STATE.set(state, Date.now());

  const { reauth } = getReauthFlags(req);
  const redirect_uri = buildRedirectUri(NAVER_REDIRECT_PATH);
  console.log("[NAVER] redirect_uri:", redirect_uri);

  const params = {
    client_id: NAVER.client_id,
    response_type: "code",
    redirect_uri,
    state,
  };

  if (reauth) params.auth_type = "reprompt";

  const url = "https://nid.naver.com/oauth2.0/authorize?" + qs.stringify(params);
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

    const resp  = profileRes.data?.response || {};
    const email = String(resp.email ?? "");
    const name  = String(resp.name  ?? "");
    if (!email) return redirectError(res, "네이버 이메일 없음");

    const user = await upsertAndGetUser({
      login_id: email,
      login_type: "naver",
      nick: name,
    });

    const token = signJWT({
      uid: user.uid,
      login_id: user.login_id,
      login_type: "naver",
      nick: user.nick || name || "",
    });

    return redirectToApp(res, {
      token,
      uid: user.uid,
      login_id: user.login_id,
      login_type: "naver",
      nick: user.nick || name || "",
    });
  } catch (e) {
    console.error("Naver error", e?.response?.data || e);
    return redirectError(res, "Naver 로그인 실패");
  }
});

module.exports = router;
