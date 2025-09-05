"use strict";

const path = require("path");
require("dotenv").config({ path: path.join(__dirname, "..", ".env") });

const express = require("express");
const axios = require("axios");
const qs = require("querystring");
const crypto = require("crypto");
const jwt = require("jsonwebtoken");

// ✅ 공용 DB 풀 (router/db.js)
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
 * 앱 콜백 (딥링크) — 반드시 스킴 고정
 * ========================= */
const APP_CALLBACK = (process.env.APP_CALLBACK || "myapp://auth/callback").replace(/\/?$/, "");

/* =========================
 * OAuth Redirect 경로 (.env)
 * ========================= */
const GOOGLE_REDIRECT_PATH = process.env.GOOGLE_REDIRECT_PATH || "/auth/google/callback";
const KAKAO_REDIRECT_PATH  = process.env.KAKAO_REDIRECT_PATH  || "/auth/kakao/callback";
const NAVER_REDIRECT_PATH  = process.env.NAVER_REDIRECT_PATH  || "/auth/naver/callback";

/* =========================
 * Google은 절대 URL(HTTPS)로 고정
 * ========================= */
const PUBLIC_BASE_URL = (process.env.PUBLIC_BASE_URL || "").replace(/\/$/, "");
const GOOGLE_REDIRECT_ABS = (() => {
  const p = String(process.env.GOOGLE_REDIRECT_PATH || "");
  if (/^https?:\/\//i.test(p)) return p;
  return process.env.GOOGLE_REDIRECT_ABS || "https://malhaebom.smhrd.com/auth/google/callback";
})();

/* =========================
 * 유틸
 * ========================= */
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
  return "http://localhost:4000";
}
function buildRedirectUri(req, pathname) {
  if (/^https?:\/\//i.test(String(pathname || ""))) return String(pathname);
  return `${getRedirectBase(req)}${pathname}`;
}

/* =========================
 * OAuth 클라이언트
 * ========================= */
const GOOGLE = {
  client_id: process.env.GOOGLE_CLIENT_ID,
  client_secret: process.env.GOOGLE_CLIENT_SECRET,
};
const KAKAO = { client_id: process.env.KAKAO_CLIENT_ID, client_secret: process.env.KAKAO_CLIENT_SECRET || "" };
const NAVER = { client_id: process.env.NAVER_CLIENT_ID, client_secret: process.env.NAVER_CLIENT_SECRET };

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
 * Stateless state (JWT)
 * ========================= */
const STATE_TTL_SEC = 10 * 60; // 10분
function makeState(provider) {
  const payload = {
    typ: "oauth_state",
    p: provider,                               // provider
    n: crypto.randomBytes(8).toString("hex"),  // nonce
  };
  return jwt.sign(payload, JWT_SECRET, { expiresIn: STATE_TTL_SEC + "s" });
}
function verifyStateJWT(state, provider) {
  try {
    const p = jwt.verify(state, JWT_SECRET);
    return p?.typ === "oauth_state" && p?.p === provider;
  } catch (_) {
    return false;
  }
}

/* =========================
 * 앱으로 보내기: ★항상 스킴(myapp://)으로 302★
 * ========================= */
function buildQueryForApp(params) {
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
    ok: params.ok === "0" ? "0" : "1",
    ts: String(Date.now()),
  });
  return q.toString();
}
function redirectToApp(_req, res, params) {
  const schemeUrl = `${APP_CALLBACK}?${buildQueryForApp(params)}`;
  console.log("[AUTH] return to app (scheme-only)", {
    to: schemeUrl.split("?")[0],
    uid: params.uid,
    login_id: params.login_id,
    login_type: params.login_type,
    token: maskToken(params.token),
  });
  res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
  return res.redirect(302, schemeUrl);
}
function redirectError(_req, res, msg) {
  const schemeUrl = `${APP_CALLBACK}?${new URLSearchParams({ error: msg, ts: String(Date.now()) }).toString()}`;
  console.log("[AUTH] error return (scheme-only)", { error: msg });
  res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
  return res.redirect(302, schemeUrl);
}

/* =========================
 * 진단용 엔드포인트
 * ========================= */
router.get("/__mode__", (req, res) => {
  res.json({
    mode: "scheme-only",
    appCallback: APP_CALLBACK,
    file: __filename,
  });
});

/* =========================
 * 안전핀: /auth/google* 는 http 로 들어오면 https로 308
 * ========================= */
router.use(["/google", "/google/callback"], (req, res, next) => {
  const host  = String(req.headers["x-forwarded-host"]  || req.headers.host || "").split(",")[0].trim();
  const proto = String(req.headers["x-forwarded-proto"] || req.protocol      || "").split(",")[0].trim();
  if (host === "malhaebom.smhrd.com" && proto !== "https") {
    return res.redirect(308, `https://${host}${req.originalUrl}`);
  }
  next();
});

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
  const state = makeState("google");
  const { reauth } = getReauthFlags(req);
  const redirect_uri = GOOGLE_REDIRECT_ABS; // 절대 URL
  const prompt = reauth ? "select_account consent" : "select_account";

  console.log("[GOOGLE] auth start", { redirect_uri });

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
    if (!state || !verifyStateJWT(String(state), "google")) {
      return debug ? res.status(400).json({ step:"state", error:"잘못된 state" })
                   : redirectError(req, res, "잘못된 state");
    }

    const redirect_uri = GOOGLE_REDIRECT_ABS;
    console.log("[GOOGLE] token redirect_uri =", redirect_uri);

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
  const state = makeState("kakao");
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
    if (!state || !verifyStateJWT(String(state), "kakao")) {
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
  const state = makeState("naver");
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
    if (!state || !verifyStateJWT(String(state), "naver")) {
      return debug ? res.status(400).json({ step:"state", error:"잘못된 state" })
                   : redirectError(req, res, "잘못된 state");
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
 * (테스트) 강제 콜백 페이지 — 302로 앱 열림
 * ========================= */
router.get("/test/callback", (_req, res) => {
  const params = {
    token: "TEST",
    login_id: "dev@example.com",
    login_type: "kakao",
    uid: "1",
    nick: "Dev",
    ok: "1",
  };
  return redirectToApp(_req, res, params);
});

module.exports = router;
