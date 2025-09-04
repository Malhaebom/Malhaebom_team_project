require("dotenv").config();

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const compression = require("compression");
const cookieParser = require("cookie-parser");
const { createProxyMiddleware } = require("http-proxy-middleware"); // ★ 프록시 미들웨어

// ✅ 라우터
const loginRouter = require("./router/LoginServer.js");
const joinRouter  = require("./router/JoinServer.js");
const strRouter   = require("./router/STRServer.js");
const irRouter    = require("./router/IRServer.js");
const authRouter  = require("./router/Auther.js");

const app = express();

/* =========================
 * 고정 서버/오리진 설정
 * ========================= */
// 바인드/포트는 환경변수 없으면 0.0.0.0:4000
const HOST = process.env.HOST || "0.0.0.0";
const PORT = Number(process.env.PORT || 4000);

// ★ 여기서 서버 공개 오리진을 "고정"합니다.
const FIXED_ORIGIN = "http://211.188.63.38:4000";

// SERVER_ORIGIN / PUBLIC_BASE_URL 을 고정값으로 덮어씁니다.
const SERVER_ORIGIN = FIXED_ORIGIN;
const PUBLIC_BASE_URL = FIXED_ORIGIN;

// ★ 게이트웨이 파이썬 서버(내부) 주소 — 기본 127.0.0.1:4100
const GW_TARGET = process.env.GW_TARGET || "http://127.0.0.1:4010";

// 프록시 신뢰(로드밸런서/ngrok 뒤에서 HTTPS 감지)
app.set("trust proxy", true);

// 보안/성능
app.use(helmet({ contentSecurityPolicy: false }));
app.use(compression());
app.use(cookieParser());

// 파서
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

/* =========================
 * CORS: 이 서버만 허용(+로컬 개발용)
 * ========================= */
const ALLOWED_ORIGINS = [
  FIXED_ORIGIN,             // 운영 공개 IP:PORT
  "http://localhost:5173",  // 로컬 개발(원하면 삭제)
  "http://127.0.0.1:5173",
  "http://localhost:3000",
  "http://127.0.0.1:3000",
];

function corsOrigin(origin, cb) {
  if (!origin) return cb(null, true); // 앱/스크립트/curl 등
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
 * 요청 로깅(외부 URL 기준)
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
  res.json({
    ok: true,
    meta: {
      publicBaseUrl: PUBLIC_BASE_URL,
      serverOrigin: SERVER_ORIGIN,
      googleRedirect: `${PUBLIC_BASE_URL}${process.env.GOOGLE_REDIRECT_PATH || "/auth/google/callback"}`,
      kakaoRedirect:  `${PUBLIC_BASE_URL}${process.env.KAKAO_REDIRECT_PATH  || "/auth/kakao/callback"}`,
      naverRedirect:  `${PUBLIC_BASE_URL}${process.env.NAVER_REDIRECT_PATH  || "/auth/naver/callback"}`,
      appCallback: process.env.APP_CALLBACK || "myapp://auth/callback",
      corsAllowed: ALLOWED_ORIGINS,
    },
  });
});

/* =========================
 * /gw 프록시 (→ 127.0.0.1:4010)
 * ========================= */
// 반드시 라우터보다 "위"에 두세요(404 전에 매칭되도록)
app.use(
  "/gw",
  createProxyMiddleware({
    target: GW_TARGET,              // 내부 게이트웨이
    changeOrigin: true,
    pathRewrite: { "^/gw": "" },    // /gw/ir/analyze → /ir/analyze
    xfwd: true,                     // X-Forwarded-* 헤더 추가
    logLevel: "warn",
    proxyTimeout: 120000,           // 게이트웨이 응답 대기(120s)
    timeout: 120000,                // 소켓 타임아웃(120s)
    onProxyReq(proxyReq, req) {
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
 * 라우터 마운트
 * ========================= */
app.use("/userLogin", loginRouter);
app.use("/userJoin",  joinRouter);
app.use("/str",       strRouter); // 동화(Story)
app.use("/ir",        irRouter);  // 인터뷰(Interview)
app.use("/auth",      authRouter); // OAuth

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
  console.log(`CORS allowed: ${ALLOWED_ORIGINS.join(", ")}`);
  console.log(`GW proxy → ${GW_TARGET} (mount: /gw)`);
});

process.on("SIGINT", () => {
  console.log("SIGINT received. Server shutting down.");
  process.exit(0);
});
