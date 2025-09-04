// File: Server/router/Auther.js
// SNS OAuth → DB upsert → 앱(딥링크) 복귀
// 기본은 302 리다이렉트(myapp://...)로 즉시 복귀
// 필요시 ENV로 HTML 브릿지 사용 가능(AUTH_BRIDGE_MODE=html)

"use strict";

const path = require("path");
require("dotenv").config({ path: path.join(__dirname, "..", ".env") });

const express = require("express");
const axios = require("axios");
const qs = require("querystring");
const crypto = require("crypto");
const jwt = require("jsonwebtoken");

// ✅ 공용 DB 풀(경로: Server/router/db.js)
const pool = require("./db");

const router = express.Router();

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
const APP_CALLBACK = (process.env.APP_CALLBACK || "myapp://auth/callback").replace(/\/?$/, "");

/* =========================
 * OAuth Redirect 경로
 * ========================= */
const GOOGLE_REDIRECT_PATH = process.env.GOOGLE_REDIRECT_PATH || "/auth/google/callback";
const KAKAO_REDIRECT_PATH  = process.env.KAKAO_REDIRECT_PATH  || "/auth/kakao/callback";
const NAVER_REDIRECT_PATH  = process.env.NAVER_REDIRECT_PATH  || "/auth/naver/callback";

/* =========================
 * Redirect Base 결정
 * ========================= */
const PUBLIC_BASE_URL = (process.env.PUBLIC_BASE_URL || "").replace(/\/$/, "");
function originFromReq(req) {
  try {
    const xfProto = (req.headers["x-forwarded-proto"] || "").toString().split(",")[0].trim();
    const xfHost  = (req.headers["x-forwarded-host"]  || "").toString().split(",")[0].trim();
    if (xfProto && xfHost) return `${xfProto}://${xfHost}`;
    const host = (req.headers.host || "").trim();
    if (host) return `http://${host}`;
  } catch (_) {}
  return null;
}
function getRedirectBase(req) {
  if (PUBLIC_BASE_URL) return PUBLIC_BASE_URL;
  const fromReq = originFromReq(req);
  if (fromReq) return fromReq.replace(/\/$/, "");
  return "http://localhost:4000"; // 최후 fallback
}
function buildRedirectUri(req, pathname) {
  if (/^https?:\/\//i.test(String(pathname || ""))) {
    return String(pathname);
  }
  return `${getRedirectBase(req)}${pathname}`;
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
 * 앱 리다이렉트 방식 선택
 *  - 기본: 302 (AUTH_BRIDGE_MODE != 'html')
 *  - HTML 브릿지: AUTH_BRIDGE_MODE=html 또는 ?html=1
 * ========================= */
const BRIDGE_MODE = (process.env.AUTH_BRIDGE_MODE || "302").toLowerCase();
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
      function go(){ try{window.location.replace(target);}catch(e){} }
      go();
      setTimeout(function(){
        try{ var a=document.createElement('a');a.setAttribute('href',target);a.click(); }catch(e){}
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

function buildAppUrl(params) {
  const q = new URLSearchParams({
    token: params.token || "",
    uid: String(params.uid || ""),
    login_id: params.login_id || "",
    login_type: params.login_type || "",
    nick: params.nick || "",
    user_key: `${params.login_type}:${params.login_id}`,
    sns_user_id: params.login_id || "",
    sns_login_type: params.login_type || "",
    sns_nick: params.nick || "",
    ok: "1",
    ts: String(Date.now()),
  });
  return `${APP_CALLBACK}?${q.toString()}`;
}

function redirectToApp(req, res, params) {
  const toUrl = buildAppUrl(params);
  const useHtml =
    BRIDGE_MODE === "html" ||
    String(req.query.html || "") === "1" ||
    String(req.headers["x-use-html-bridge"] || "") === "1";

  console.log("[AUTH] return to app", {
    uid: params.uid,
    login_id: params.login_id,
    login_type: params.login_type,
    token: maskToken(params.token),
    mode: useHtml ? "html" : "302",
  });

  if (useHtml) {
    res.status(200).setHeader("Content-Type", "text/html; charset=utf-8");
    return res.send(htmlBridge(toUrl));
  }
  // ✅ 권장: 302로 직접 myapp://... 이동 → flutter_web_auth_2가 즉시 resolve
  return res.redirect(toUrl);
}

function redirectError(req, res, msg) {
  const url = `${APP_CALLBACK}?error=${encodeURIComponent(msg)}&ts=${Date.now()}`;
  const useHtml =
    BRIDGE_MODE === "html" ||
    String(req.query.html || "") === "1" ||
    String(req.headers["x-use-html-bridge"] || "") === "1";

  if (useHtml) {
    res.setHeader("Content-Type", "text/html; charset=utf-8");
    return res.status(200).send(htmlBridge(url, "로그인 처리 중 오류"));
  }
  return res.redirect(url);
}

/* =========================
 * DB upsert/select
 * ========================= */
async function upsertAndGetUser({ login_id, login_type, nick }) {
  const conn = await pool.getConnection();
  try {
    await conn.execute(
      `INSERT INTO tb_user (login_id, login_type, nick, pwd)
       VALUES (?, ?, ?, NULL)
       ON DUPLICATE KEY UPDATE
         nick = IF(nick IS NULL OR nick = '', VALUES(nick), nick)`,
      [login_id, login_type, nick || ""]
    );

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
                             : redirectError(req, res, "Google code 없음");
    if (!state || !verifyAndDeleteState(GOOGLE_STATE, state)) {
      return debug ? res.status(400).json({ step:"state", error:"잘못된 state" })
                   : redirectError(req, res, "잘못된 state");
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
                   : redirectError(req, res, "Google 토큰 교환 실패");
    }
    const accessToken = tokenRes?.data?.access_token;
    if (!accessToken) {
      return debug ? res.status(500).json({ step:"token", error:"no access_token", tokenRes: tokenRes?.data })
                   : redirectError(req, res, "Google access token 없음");
    }

    let profileRes;
    try {
      profileRes = await axios.get("https://www.googleapis.com/oauth2/v2/userinfo", {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
    } catch (e) {
      const detail = e?.response?.data || e?.message;
      return debug ? res.status(500).json({ step:"profile", error:"profile fetch fail", detail })
                   : redirectError(req, res, "Google 프로필 조회 실패");
    }
    const data = profileRes.data || {};
    const email = String(data.email ?? "");
    const name  = String(data.name  ?? "");
    if (!email) {
      return debug ? res.status(400).json({ step:"profile", error:"구글 이메일 없음", data })
                   : redirectError(req, res, "구글 이메일 없음");
    }

    let user;
    try {
      user = await upsertAndGetUser({ login_id: email, login_type: "google", nick: name });
    } catch (e) {
      return debug ? res.status(500).json({ step:"db", error:"upsert/select fail", detail: e?.message || e })
                   : redirectError(req, res, "DB 처리 실패");
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

    return redirectToApp(req, res, {
      token, uid: user.uid, login_id: user.login_id, login_type: "google", nick: user.nick || name || ""
    });
  } catch (e) {
    console.error("Google error", e?.response?.data || e);
    return (String(req.query.debug || "") === "1")
      ? res.status(500).json({ step:"catchall", error:String(e?.message || e) })
      : redirectError(req, res, "Google 로그인 실패");
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
                             : redirectError(req, res, "Kakao code 없음");
    if (!state || !verifyAndDeleteState(KAKAO_STATE, state)) {
      return debug ? res.status(400).json({ step:"state", error:"잘못된 state" })
                   : redirectError(req, res, "잘못된 state");
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
                   : redirectError(req, res, "Kakao 토큰 교환 실패");
    }

    const accessToken = tokenRes.data.access_token;
    if (!accessToken) {
      return debug ? res.status(500).json({ step:"token", error:"no access_token", tokenRes: tokenRes?.data })
                   : redirectError(req, res, "Kakao access token 없음");
    }

    let profileRes;
    try {
      profileRes = await axios.get("https://kapi.kakao.com/v2/user/me", {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
    } catch (e) {
      const detail = e?.response?.data || e?.message;
      return debug ? res.status(500).json({ step:"profile", error:"profile fetch fail", detail })
                   : redirectError(req, res, "Kakao 프로필 조회 실패");
    }

    const acct = profileRes.data?.kakao_account || {};
    let email  = String(acct.email ?? "");
    const name = String(acct.profile?.nickname ?? "");
    if (!email) email = String(profileRes.data?.id ?? "");
    if (!email) {
      return debug ? res.status(400).json({ step:"profile", error:"카카오 아이디 없음", data: profileRes?.data })
                   : redirectError(req, res, "카카오 아이디 없음");
    }

    let user;
    try {
      user = await upsertAndGetUser({ login_id: email, login_type: "kakao", nick: name });
    } catch (e) {
      return debug ? res.status(500).json({ step:"db", error:"upsert/select fail", detail: e?.message || e })
                   : redirectError(req, res, "DB 처리 실패");
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

    return redirectToApp(req, res, {
      token, uid: user.uid, login_id: user.login_id, login_type: "kakao", nick: user.nick || name || ""
    });
  } catch (e) {
    console.error("Kakao error", e?.response?.data || e);
    return (String(req.query.debug || "") === "1")
      ? res.status(500).json({ step:"catchall", error:String(e?.message || e) })
      : redirectError(req, res, "카카오 로그인 실패");
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
                             : redirectError(req, res, "Naver code 없음");
    if (!state || !verifyAndDeleteState(NAVER_STATE, state)) {
      return debug ? res.status(400).json({ step:"state", error:"잘못된 state" })
                   : redirectError(req, res, "잘못된 state");
    }
    // 네이버는 redirect_uri를 토큰 교환에 직접 쓰지 않으므로 여기서는 계산만 참고
    // (보수적으로 유지)
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
                   : redirectError(req, res, "Naver 토큰 교환 실패");
    }

    const accessToken = tokenRes.data.access_token;
    if (!accessToken) {
      return debug ? res.status(500).json({ step:"token", error:"no access_token", tokenRes: tokenRes?.data })
                   : redirectError(req, res, "Naver access token 없음");
    }

    let profileRes;
    try {
      profileRes = await axios.get("https://openapi.naver.com/v1/nid/me", {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
    } catch (e) {
      const detail = e?.response?.data || e?.message;
      return debug ? res.status(500).json({ step:"profile", error:"profile fetch fail", detail })
                   : redirectError(req, res, "Naver 프로필 조회 실패");
    }

    const resp  = profileRes.data?.response || {};
    const email = String(resp.email ?? "");
    const name  = String(resp.name  ?? "");
    if (!email) {
      return debug ? res.status(400).json({ step:"profile", error:"네이버 이메일 없음", data: profileRes?.data })
                   : redirectError(req, res, "네이버 이메일 없음");
    }

    let user;
    try {
      user = await upsertAndGetUser({ login_id: email, login_type: "naver", nick: name });
    } catch (e) {
      return debug ? res.status(500).json({ step:"db", error:"upsert/select fail", detail: e?.message || e })
                   : redirectError(req, res, "DB 처리 실패");
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

    return redirectToApp(req, res, {
      token, uid: user.uid, login_id: user.login_id, login_type: "naver", nick: user.nick || name || ""
    });
  } catch (e) {
    console.error("Naver error", e?.response?.data || e);
    return (String(req.query.debug || "") === "1")
      ? res.status(500).json({ step:"catchall", error:String(e?.message || e) })
      : redirectError(req, res, "네이버 로그인 실패");
  }
});

/* =========================
 * (테스트) 강제 콜백 페이지
 * ========================= */
router.get("/test/callback", (_req, res) => {
  const q = new URLSearchParams({
    token: "TEST",
    login_id: "dev@example.com",
    login_type: "kakao",
    uid: "1",
    nick: "Dev",
    ok: "1",
    ts: String(Date.now()),
  });
  const toUrl = `${APP_CALLBACK}?${q.toString()}`;
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  return res.status(200).send(htmlBridge(toUrl, "앱으로 돌아가는 중(테스트)…"));
});

module.exports = router;
