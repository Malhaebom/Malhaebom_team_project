require("dotenv").config();

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const compression = require("compression");
const cookieParser = require("cookie-parser");
const { createProxyMiddleware } = require("http-proxy-middleware");

// ✅ 라우터
const loginRouter = require("./router/LoginServer.js");
const joinRouter  = require("./router/JoinServer.js");
const strRouter   = require("./router/STRServer.js");
const irRouter    = require("./router/IRServer.js");
const authRouter  = require("./router/Auther.js");

const app = express();

/* =========================
 * 서버/오리진 설정 (.env 사용)
 * ========================= */
const HOST = process.env.HOST || "0.0.0.0";
const PORT = Number(process.env.PORT || 4000);

const SERVER_ORIGIN   = process.env.SERVER_ORIGIN   || `http://localhost:${PORT}`;
const PUBLIC_BASE_URL = process.env.PUBLIC_BASE_URL || `http://localhost:${PORT}`;

const ALLOWED_ORIGINS = (process.env.CORS_ORIGINS || "")
  .split(",")
  .map(s => s.trim())
  .filter(Boolean);

const GW_TARGET = process.env.GW_TARGET || "http://127.0.0.1:4010";
const FORCE_CANONICAL_REDIRECT = String(process.env.FORCE_CANONICAL_REDIRECT || "0") === "1";

// 프록시 신뢰
app.set("trust proxy", true);

/* =========================
 * 보안/성능/파서
 * ========================= */
app.use(helmet({ contentSecurityPolicy: false }));
app.use(compression());
app.use(cookieParser());
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

/* =========================
 * CORS
 * ========================= */
function corsOrigin(origin, cb) {
  if (!origin) return cb(null, true);
  if (ALLOWED_ORIGINS.includes(origin)) return cb(null, true);
  const msg = `[CORS] blocked origin: ${origin}`;
  console.warn(msg);
  return cb(new Error(msg), false);
}
const corsOptions = {
  origin: corsOrigin,
  credentials: true,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: [
    "Content-Type",
    "Authorization",
    "x-requested-with",
    "x-user-id",
    "x-sns-user-id",
    "x-sns-login-type",
    "x-login-id",
    "x-login-type",
    "x-user-key",
  ],
  maxAge: 86400,
};
app.use(cors(corsOptions));
app.options(/.*/, cors(corsOptions));

/* =========================
 * (선택) 도메인/프로토콜 강제 리다이렉트
 * ========================= */
if (FORCE_CANONICAL_REDIRECT && PUBLIC_BASE_URL) {
  try {
    const target = new URL(PUBLIC_BASE_URL);
    const FORCE_HOST = target.host;
    const FORCE_PROTO = target.protocol.replace(":", "");

    app.use((req, res, next) => {
      const xfProto = (req.headers["x-forwarded-proto"] || "").toString().split(",")[0].trim();
      const xfHost  = (req.headers["x-forwarded-host"]  || "").toString().split(",")[0].trim();
      const scheme = xfProto || req.protocol;
      const host   = xfHost || req.headers.host || "";

      if (scheme !== FORCE_PROTO || host !== FORCE_HOST) {
        return res.redirect(308, `${target.origin}${req.originalUrl}`);
      }
      next();
    });
    console.log(`[BOOT] Canonical redirect ON → ${PUBLIC_BASE_URL}`);
  } catch (_) {
    console.warn("[BOOT] Canonical redirect OFF (PUBLIC_BASE_URL parse failed)");
  }
}

/* =========================
 * 요청 로깅 (외부 시점)
 * ========================= */
app.use((req, _res, next) => {
  const xfProto = (req.headers["x-forwarded-proto"] || "").toString().split(",")[0].trim();
  const xfHost  = (req.headers["x-forwarded-host"]  || "").toString().split(",")[0].trim();
  const ip = (req.headers["x-forwarded-for"] || req.ip || "").toString().split(",")[0].trim();
  const scheme = xfProto || req.protocol;
  const host   = xfHost || req.headers.host;
  const full   = `${scheme}://${host}${req.originalUrl}`;
  console.log(`[REQ] ${req.method} ${full} ← ${ip}`);
  next();
});

/* =========================
 * 헬스체크 & 메타
 * ========================= */
app.get("/ping", (_req, res) => res.send("pong"));
app.get("/auth/meta", (_req, res) => {
  const base = PUBLIC_BASE_URL;
  const abs  = (s) => /^https?:\/\//i.test(String(s || ""));
  const join = (p) => (abs(p) ? p : `${base}${p}`);

  res.json({
    ok: true,
    meta: {
      publicBaseUrl: base,
      serverOrigin: SERVER_ORIGIN,
      // 이 값들로 최종 redirect_uri가 어떻게 잡히는지 확인 가능
      googleRedirect: join(process.env.GOOGLE_REDIRECT_PATH || "/auth/google/callback"),
      kakaoRedirect:  join(process.env.KAKAO_REDIRECT_PATH  || "/auth/kakao/callback"),
      naverRedirect:  join(process.env.NAVER_REDIRECT_PATH  || "/auth/naver/callback"),
      appCallback: process.env.APP_CALLBACK || "myapp://auth/callback",
      corsAllowed: ALLOWED_ORIGINS,
    },
  });
});

/* =========================
 * /gw 프록시 (→ 내부 게이트웨이)
 * ========================= */
app.use(
  "/gw",
  createProxyMiddleware({
    target: GW_TARGET,
    changeOrigin: true,
    pathRewrite: { "^/gw": "" },
    xfwd: true,
    logLevel: "warn",
    proxyTimeout: 120000,
    timeout: 120000,
    onProxyReq(_proxyReq, req) {
      console.log(`[GW] ${req.method} ${req.originalUrl} -> ${GW_TARGET}`);
    },
    onError(err, req, res) {
      console.error("[GW] proxy error:", err?.message);
      if (!res.headersSent) {
        res.status(502).json({ ok: false, error: "BadGateway", message: "gateway proxy error" });
      }
    },
  })
);

/* =========================
 * 라우터
 * ========================= */
app.use("/userLogin", loginRouter);
app.use("/userJoin",  joinRouter);
app.use("/str",       strRouter);
app.use("/ir",        irRouter);
app.use("/auth",      authRouter);

/* =========================
 * 404 / 에러 핸들러
 * ========================= */
app.use((req, res) => {
  res.status(404).json({ ok: false, message: "Not Found", path: req.originalUrl });
});
app.use((err, _req, res, _next) => {
  const status = err.status || 500;
  const code = err.code || err.name || "ServerError";
  console.error("[ERROR]", code, err.stack || err);
  res.status(status).json({ ok: false, error: code, message: err.message || "Internal Server Error" });
});

/* =========================
 * 서버 시작
 * ========================= */
app.listen(PORT, HOST, () => {
  console.log(`API running at ${SERVER_ORIGIN} (bind ${HOST}:${PORT})`);
  console.log(`Health check: ${SERVER_ORIGIN}/ping`);
  console.log(`OAuth redirect base: ${PUBLIC_BASE_URL}`);
  console.log(`CORS allowed: ${ALLOWED_ORIGINS.join(", ") || "(empty -> use corsOrigin logic)"}`);
  console.log(`GW proxy → ${GW_TARGET} (mount: /gw)`);
});

process.on("SIGINT", () => {
  console.log("SIGINT received. Server shutting down.");
  process.exit(0);
});
