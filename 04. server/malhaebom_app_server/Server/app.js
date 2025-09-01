// File: src/Server/app.js
require("dotenv").config();
const express = require("express");
const cors = require("cors");
const path = require("path");

// ✅ 라우터
const loginRouter = require("./router/LoginServer.js");
const joinRouter  = require("./router/JoinServer.js");
const strRouter   = require("./router/STRServer.js");
const irRouter    = require("./router/IRServer.js");
const authRouter  = require("./router/Auther.js");

const app = express();

const HOST = process.env.HOST || "0.0.0.0";
const PORT = Number(process.env.PORT || 4000);
const SERVER_ORIGIN = (process.env.SERVER_ORIGIN || "http://211.188.63.38:4000").replace(/\/$/, "");

// 프록시 신뢰(ngrok/로드밸런서 뒤에서 https 감지)
app.set("trust proxy", true);

/* =========================
 *  CORS (화이트리스트 + 동적)
 * ========================= */
const envList = (process.env.CORS_ORIGINS || "")
  .split(",").map(s => s.trim()).filter(Boolean);
const defaultAllowed = [
  "http://localhost:5173",
  "http://127.0.0.1:5173",
  "http://localhost:3000",
  "http://127.0.0.1:3000",
  "http://211.188.63.38:4000",
];
const ALLOWED_ORIGINS = Array.from(new Set([...defaultAllowed, ...envList]));

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
    "x-user-key"
  ],
};
app.use(cors(corsOptions));
app.options(/.*/, cors(corsOptions));

// Body parsers
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// 전역 요청 로거(실제 외부 URL로 표시)
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

// 헬스체크
app.get("/ping", (_req, res) => res.send("pong"));

// 라우터 마운트
app.use("/userLogin", loginRouter);
app.use("/userJoin",  joinRouter);
app.use("/str",       strRouter); // 동화 화행(Story)
app.use("/ir",        irRouter);  // 인터뷰 화행(Interview)
app.use("/auth",      authRouter); // SNS OAuth

// 정적 파일(필요시)
// app.use("/static", express.static(path.join(__dirname, "public"), { maxAge: "1h", immutable: true }));

// 404
app.use((req, res) => {
  res.status(404).json({ ok: false, message: "Not Found", path: req.originalUrl });
});

// 에러 핸들러
app.use((err, _req, res, _next) => {
  const status = err.status || 500;
  const code = err.code || err.name || "ServerError";
  console.error("[ERROR]", code, err.stack || err);
  res.status(status).json({ ok: false, error: code, message: err.message || "Internal Server Error" });
});

app.listen(PORT, HOST, () => {
  console.log(`API running at ${SERVER_ORIGIN} (bind ${HOST}:${PORT})`);
  console.log(`Allowed CORS origins: ${ALLOWED_ORIGINS.join(", ") || "(none)"}`);
  console.log(`Health check: ${SERVER_ORIGIN}/ping`);
});

process.on("SIGINT", () => {
  console.log("SIGINT received. Server shutting down.");
  process.exit(0);
});
