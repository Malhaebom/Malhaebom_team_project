// src/Server/router/Auther.js
require("dotenv").config();

const express = require("express");
const axios = require("axios");
const qs = require("querystring");
const crypto = require("crypto");
const jwt = require("jsonwebtoken");
const pool = require("../lib/db"); // 공용 풀 사용

const router = express.Router();

/* =========================
 * 고정 공개 ORIGIN (요청/ENV 무시)
 * ========================= */
const FIXED_ORIGIN = "http://211.188.63.38:4000";

/* =========================
 * JWT
 * ========================= */
const JWT_SECRET = process.env.JWT_SECRET || "malhaebom_sns";
function signJWT(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: "7d" });
}
function maskToken(t) {
  const s = String(t || "");
  if (s.length <= 12) return s;
  return s.slice(0, 12) + "...";
}

/* =========================
 * 앱 콜백 (딥링크)
 * ========================= */
const APP_CALLBACK = process.env.APP_CALLBACK || "myapp://auth/callback";

/* =========================
 * OAuth Redirect 경로
 * ========================= */
const GOOGLE_REDIRECT_PATH = process.env.GOOGLE_REDIRECT_PATH || "/auth/google/callback";
const KAKAO_REDIRECT_PATH  = process.env.KAKAO_REDIRECT_PATH  || "/auth/kakao/callback";
const NAVER_REDIRECT_PATH  = process.env.NAVER_REDIRECT_PATH  || "/auth/naver/callback";

/* =========================
 * Redirect Base (고정)
 * ========================= */
function getRedirectBase(_req) {
  // 요청/환경을 보지 않고 항상 고정 IP 사용
  return FIXED_ORIGIN;
}
function buildRedirectUri(req, path) {
  return `${getRedirectBase(req)}${path}`;
}

/* =========================
 * OAuth 클라이언트
 * ========================= */
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

// 필수 env 체크
for (const [k, v] of Object.entries({
  GOOGLE_CLIENT_ID: GOOGLE.client_id,
  GOOGLE_CLIENT_SECRET: GOOGLE.client_secret,
  KAKAO_CLIENT_ID: KAKAO.client_id,
  NAVER_CLIENT_ID: NAVER.client_id,
  NAVER_CLIENT_SECRET: NAVER.client_secret,
})) {
  if (!v) console.error(`[ENV MISSING] ${k}`);
}

/* =========================
 * CSRF state 저장소
 * ========================= */
const STATE_TTL_MS = 10 * 60 * 1000;
const GOOGLE_STATE = new Map();
const KAKAO_STATE  = new Map();
const NAVER_STATE  = new Map();
function saveState(store, state) { store.set(state, Date.now()); }
function verifyAndDeleteState(store, state) {
  const ts = store.get(state);
  store.delete(state);
  return !!(ts && Date.now() - ts < STATE_TTL_MS);
}

/* =========================
 * 앱 리다이렉트 (302 + HTML 폴백)
 * ========================= */
function htmlBridge(toUrl, title = "앱으로 돌아가는 중…", btnLabel = "앱으로 돌아가기", hint = "자동 전환되지 않으면 버튼을 눌러 주세요.") {
  return `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8" />
  <meta http-equiv="refresh" content="0;url=${toUrl}">
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>${title}</title>
  <style>
    body{font-family:system-ui,-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;padding:24px;line-height:1.5}
    .box{max-width:520px;margin:24px auto;padding:20px;border:1px solid #eee;border-radius:12px}
    .btn{display:inline-block;margin-top:12px;padding:10px 14px;border-radius:8px;background:#344CB7;color:#fff;text-decoration:none}
    .muted{color:#666;font-size:14px}
  </style>
  <script>
    (function(){
      var target=${JSON.stringify(toUrl)};
      try{window.location.replace(target);}catch(e){}
      setTimeout(function(){
        try{var a=document.createElement('a');a.setAttribute('href',target);a.click();}catch(e){}
        var hint=document.getElementById('hint'); if(hint) hint.style.display='block';
      },500);
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
  const user_key = `${login_type}:${login_id}`;
  const toUrl =
    APP_CALLBACK +
    `?token=${encodeURIComponent(token)}` +
    `&uid=${encodeURIComponent(String(uid))}` +
    `&login_id=${encodeURIComponent(login_id)}` +
    `&login_type=${encodeURIComponent(login_type)}` +
    `&nick=${encodeURIComponent(nick ?? "")}` +
    `&user_key=${encodeURIComponent(user_key)}` +
    `&sns_user_id=${encodeURIComponent(login_id)}` +
    `&sns_login_type=${encodeURIComponent(login_type)}` +
    `&sns_nick=${encodeURIComponent(nick ?? "")}`;

  console.log("[AUTH] 302 -> app", {
    uid, login_id, login_type, user_key, token: maskToken(token)
  });

  res.setHeader("Location", toUrl);
  res.status(302);
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  return res.send(htmlBridge(toUrl));
}

function redirectError(res, msg) {
  const url = APP_CALLBACK + `?error=${encodeURIComponent(msg)}`;
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  return res.status(200).send(htmlBridge(url, "로그인 처리 중 오류"));
}

/* =========================
 * DB upsert/select
 * ========================= */
async function upsertAndGetUser({ login_id, login_type, nick }) {
  const conn = await pool.getConnection();
  try {
    await conn.execute(`
      INSERT INTO tb_user (login_id, login_type, nick, pwd)
      VALUES (?, ?, ?, NULL)
      ON DUPLICATE KEY UPDATE
        nick = IF(nick IS NULL OR nick = '', VALUES(nick), nick)
    `, [login_id, login_type, nick || ""]);

    const [rows] = await conn.execute(
      "SELECT user_id AS uid, login_id, login_type, nick FROM tb_user WHERE login_id = ? AND login_type = ? LIMIT 1",
      [login_id, login_type]
    );
    if (!rows.length) throw new Error("UPSERT ok but SELECT empty");
    return rows[0];
  } finally {
    conn.release();
  }
}

/* =========================
 * Helper
 * ========================= */
function getReauthFlags(req) {
  const reauth = String(req.query.reauth || "") === "1";
  return { reauth };
}

/* =========================
 * Google
 * ========================= */
router.get("/google", (req, res) => {
  const state = crypto.randomBytes(16).toString("hex");
  saveState(GOOGLE_STATE, state);

  const { reauth } = getReauthFlags(req);
  const redirect_uri = buildRedirectUri(req, GOOGLE_REDIRECT_PATH);
  const prompt = reauth ? "select_account consent" : "select_account";

  const url = "https://accounts.google.com/o/oauth2/v2/auth?" + qs.stringify({
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
  const debug = String(req.query.debug || "") === "1";
  try {
    const { code, state } = req.query;
    if (!code)  return debug ? res.status(400).json({ step:"callback", error:"Google code 없음" })
                             : redirectError(res, "Google code 없음");
    if (!state || !verifyAndDeleteState(GOOGLE_STATE, state)) {
      return debug ? res.status(400).json({ step:"state", error:"잘못된 state" })
                   : redirectError(res, "잘못된 state");
    }
    const redirect_uri = buildRedirectUri(req, GOOGLE_REDIRECT_PATH);

    let tokenRes;
    try {
      tokenRes = await axios.post(
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
    } catch (e) {
      const detail = e?.response?.data || e?.message;
      return debug ? res.status(500).json({ step:"token", error:"token exchange fail", detail, redirect_uri })
                   : redirectError(res, "Google 토큰 교환 실패");
    }
    const accessToken = tokenRes?.data?.access_token;
    if (!accessToken) {
      return debug ? res.status(500).json({ step:"token", error:"no access_token", tokenRes: tokenRes?.data })
                   : redirectError(res, "Google access token 없음");
    }

    let profileRes;
    try {
      profileRes = await axios.get("https://www.googleapis.com/oauth2/v2/userinfo", {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
    } catch (e) {
      const detail = e?.response?.data || e?.message;
      return debug ? res.status(500).json({ step:"profile", error:"profile fetch fail", detail })
                   : redirectError(res, "Google 프로필 조회 실패");
    }
    const data = profileRes.data || {};
    const email = String(data.email ?? "");
    const name  = String(data.name  ?? "");
    if (!email) {
      return debug ? res.status(400).json({ step:"profile", error:"구글 이메일 없음", data })
                   : redirectError(res, "구글 이메일 없음");
    }

    let user;
    try {
      user = await upsertAndGetUser({ login_id: email, login_type: "google", nick: name });
    } catch (e) {
      return debug ? res.status(500).json({ step:"db", error:"upsert/select fail", detail: e?.message || e })
                   : redirectError(res, "DB 처리 실패");
    }

    const token = signJWT({
      uid: user.uid,
      login_id: user.login_id,
      login_type: "google",
      nick: user.nick || name || "",
    });

    if (debug) {
      return res.json({
        step: "done",
        redirect_uri,
        user,
        outParams: { uid: user.uid, login_id: user.login_id, login_type: "google", token_len: String(token || "").length },
      });
    }

    return redirectToApp(res, {
      token, uid: user.uid, login_id: user.login_id, login_type: "google", nick: user.nick || name || ""
    });
  } catch (e) {
    console.error("Google error", e?.response?.data || e);
    return (String(req.query.debug || "") === "1")
      ? res.status(500).json({ step:"catchall", error:String(e?.message || e) })
      : redirectError(res, "Google 로그인 실패");
  }
});

/* =========================
 * Kakao
 * ========================= */
router.get("/kakao", (req, res) => {
  const state = crypto.randomBytes(16).toString("hex");
  saveState(KAKAO_STATE, state);

  const { reauth } = getReauthFlags(req);
  const redirect_uri = buildRedirectUri(req, KAKAO_REDIRECT_PATH);

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
  const debug = String(req.query.debug || "") === "1";
  try {
    const { code, state } = req.query;
    if (!code)  return debug ? res.status(400).json({ step:"callback", error:"Kakao code 없음" })
                             : redirectError(res, "Kakao code 없음");
    if (!state || !verifyAndDeleteState(KAKAO_STATE, state)) {
      return debug ? res.status(400).json({ step:"state", error:"잘못된 state" })
                   : redirectError(res, "잘못된 state");
    }
    const redirect_uri = buildRedirectUri(req, KAKAO_REDIRECT_PATH);

    const body = {
      grant_type: "authorization_code",
      client_id: KAKAO.client_id,
      redirect_uri,
      code,
    };
    if (KAKAO.client_secret) body.client_secret = KAKAO.client_secret;

    let tokenRes;
    try {
      tokenRes = await axios.post(
        "https://kauth.kakao.com/oauth/token",
        qs.stringify(body),
        { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
      );
    } catch (e) {
      const detail = e?.response?.data || e?.message;
      return debug ? res.status(500).json({ step:"token", error:"token exchange fail", detail, redirect_uri })
                   : redirectError(res, "Kakao 토큰 교환 실패");
    }

    const accessToken = tokenRes.data.access_token;
    if (!accessToken) {
      return debug ? res.status(500).json({ step:"token", error:"no access_token", tokenRes: tokenRes?.data })
                   : redirectError(res, "Kakao access token 없음");
    }

    let profileRes;
    try {
      profileRes = await axios.get("https://kapi.kakao.com/v2/user/me", {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
    } catch (e) {
      const detail = e?.response?.data || e?.message;
      return debug ? res.status(500).json({ step:"profile", error:"profile fetch fail", detail })
                   : redirectError(res, "Kakao 프로필 조회 실패");
    }

    const acct = profileRes.data?.kakao_account || {};
    let email  = String(acct.email ?? "");
    const name = String(acct.profile?.nickname ?? "");
    if (!email) email = String(profileRes.data?.id ?? "");
    if (!email) {
      return debug ? res.status(400).json({ step:"profile", error:"카카오 아이디 없음", data: profileRes?.data })
                   : redirectError(res, "카카오 아이디 없음");
    }

    let user;
    try {
      user = await upsertAndGetUser({ login_id: email, login_type: "kakao", nick: name });
    } catch (e) {
      return debug ? res.status(500).json({ step:"db", error:"upsert/select fail", detail: e?.message || e })
                   : redirectError(res, "DB 처리 실패");
    }

    const token = signJWT({
      uid: user.uid,
      login_id: user.login_id,
      login_type: "kakao",
      nick: user.nick || name || "",
    });

    if (debug) {
      return res.json({
        step: "done",
        redirect_uri,
        user,
        outParams: { uid: user.uid, login_id: user.login_id, login_type: "kakao", token_len: String(token || "").length },
      });
    }

    return redirectToApp(res, {
      token, uid: user.uid, login_id: user.login_id, login_type: "kakao", nick: user.nick || name || ""
    });
  } catch (e) {
    console.error("Kakao error", e?.response?.data || e);
    return (String(req.query.debug || "") === "1")
      ? res.status(500).json({ step:"catchall", error:String(e?.message || e) })
      : redirectError(res, "카카오 로그인 실패");
  }
});

/* =========================
 * Naver
 * ========================= */
router.get("/naver", (req, res) => {
  const state = crypto.randomBytes(16).toString("hex");
  saveState(NAVER_STATE, state);

  const { reauth } = getReauthFlags(req);
  const redirect_uri = buildRedirectUri(req, NAVER_REDIRECT_PATH);

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
  const debug = String(req.query.debug || "") === "1";
  try {
    const { code, state } = req.query;
    if (!code)  return debug ? res.status(400).json({ step:"callback", error:"Naver code 없음" })
                             : redirectError(res, "Naver code 없음");
    if (!state || !verifyAndDeleteState(NAVER_STATE, state)) {
      return debug ? res.status(400).json({ step:"state", error:"잘못된 state" })
                   : redirectError(res, "잘못된 state");
    }
    const redirect_uri = buildRedirectUri(req, NAVER_REDIRECT_PATH);

    let tokenRes;
    try {
      tokenRes = await axios.get("https://nid.naver.com/oauth2.0/token", {
        params: {
          grant_type: "authorization_code",
          client_id: NAVER.client_id,
          client_secret: NAVER.client_secret,
          code,
          state,
        },
      });
    } catch (e) {
      const detail = e?.response?.data || e?.message;
      return debug ? res.status(500).json({ step:"token", error:"token exchange fail", detail, redirect_uri })
                   : redirectError(res, "Naver 토큰 교환 실패");
    }

    const accessToken = tokenRes.data.access_token;
    if (!accessToken) {
      return debug ? res.status(500).json({ step:"token", error:"no access_token", tokenRes: tokenRes?.data })
                   : redirectError(res, "Naver access token 없음");
    }

    let profileRes;
    try {
      profileRes = await axios.get("https://openapi.naver.com/v1/nid/me", {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
    } catch (e) {
      const detail = e?.response?.data || e?.message;
      return debug ? res.status(500).json({ step:"profile", error:"profile fetch fail", detail })
                   : redirectError(res, "Naver 프로필 조회 실패");
    }

    const resp  = profileRes.data?.response || {};
    const email = String(resp.email ?? "");
    const name  = String(resp.name  ?? "");
    if (!email) {
      return debug ? res.status(400).json({ step:"profile", error:"네이버 이메일 없음", data: profileRes?.data })
                   : redirectError(res, "네이버 이메일 없음");
    }

    let user;
    try {
      user = await upsertAndGetUser({ login_id: email, login_type: "naver", nick: name });
    } catch (e) {
      return debug ? res.status(500).json({ step:"db", error:"upsert/select fail", detail: e?.message || e })
                   : redirectError(res, "DB 처리 실패");
    }

    const token = signJWT({
      uid: user.uid,
      login_id: user.login_id,
      login_type: "naver",
      nick: user.nick || name || "",
    });

    if (debug) {
      return res.json({
        step: "done",
        redirect_uri,
        user,
        outParams: { uid: user.uid, login_id: user.login_id, login_type: "naver", token_len: String(token || "").length },
      });
    }

    return redirectToApp(res, {
      token, uid: user.uid, login_id: user.login_id, login_type: "naver", nick: user.nick || name || ""
    });
  } catch (e) {
    console.error("Naver error", e?.response?.data || e);
    return (String(req.query.debug || "") === "1")
      ? res.status(500).json({ step:"catchall", error:String(e?.message || e) })
      : redirectError(res, "네이버 로그인 실패");
  }
});

module.exports = router;
