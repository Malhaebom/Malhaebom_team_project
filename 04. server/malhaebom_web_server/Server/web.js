// Server/web.js
require("dotenv").config();

const express = require("express");
const cors = require("cors");
const cookieParser = require("cookie-parser");
const url = require("url");

const app = express();

/* =========================
 * 서버 설정
 * ========================= */
const HOST = process.env.HOST || "0.0.0.0";
const PORT = Number(process.env.PORT || 3001);

const SERVER_BASE_URL = process.env.SERVER_BASE_URL || "http://127.0.0.1:3001";
const FRONTEND_BASE_URL = process.env.FRONTEND_BASE_URL || process.env.PUBLIC_BASE_URL || "https://malhaebom.smhrd.com";
const DEV_FRONT_URL = process.env.DEV_FRONT_URL || "";
const TRUST_PROXY       = Number(process.env.TRUST_PROXY || 1);

/* =========================
 * CORS 허용 목록
 * ========================= */
const csv = (s) => (s || "").split(",").map(x => x.trim()).filter(Boolean);
const envOrigins = csv(process.env.CORS_ORIGINS);

const rawAllowed = Array.from(new Set([
  SERVER_BASE_URL,
  FRONTEND_BASE_URL,
  DEV_FRONT_URL,
  ...envOrigins,
].filter(Boolean)));

const allowedHosts = new Set(
  rawAllowed.map(o => {
    try { return new url.URL(o).host; } catch { return null; }
  }).filter(Boolean)
);
const allowedOrigins = new Set(rawAllowed);

const corsMiddleware = cors({
  origin: (origin, cb) => {
    if (!origin) return cb(null, true); // 서버-서버/health 등
    try {
      const u = new url.URL(origin);
      if (allowedOrigins.has(origin)) return cb(null, true); // 완전 일치
      if (allowedHosts.has(u.host))  return cb(null, true); // 같은 host면 포트 달라도 허용
    } catch {}
    console.warn("[CORS] blocked origin:", origin);
    return cb(new Error("Not allowed by CORS"), false);
  },
  credentials: true,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH", "HEAD"],
  maxAge: 86400,             // 프리플라이트 캐시(1일)
  optionsSuccessStatus: 204, // 구형 브라우저 대응
});

app.use(corsMiddleware);
app.options(/.*/, corsMiddleware);

app.disable("x-powered-by");
app.use(express.json({ limit: "1mb" }));
app.use(cookieParser());

// 프록시 뒤(예: Nginx)라면 신뢰 설정 (쿠키 secure와 리다이렉트 판단에 필요)
app.set("trust proxy", TRUST_PROXY);

/* =========================
 * 라우터
 * ========================= */
const LoginServer = require("./router/LoginServer");
const JoinServer = require("./router/JoinServer");
const Auther = require("./router/Auther");
const W_STRServer = require("./router/W_STRServer");
const W_IRServer = requier("./router/W_IRServer")

// 레거시 경로
app.use("/userLogin", LoginServer);
app.use("/userJoin", JoinServer);
app.use("/auth", Auther);
app.use("/str", W_STRServer);
app.use("/ir", W_IRServer);

// 프론트는 /api만 호출
app.use("/api/userLogin", LoginServer);
app.use("/api/userJoin", JoinServer);
app.use("/api/auth", Auther);
app.use("/api/str", W_STRServer);
app.use("/api/ir", W_IRServer);

/* =========================
 * 헬스체크
 * ========================= */
app.get(["/health", "/api/health"], (req, res) =>
  res.json({
    ok: true,
    server: SERVER_BASE_URL,
    frontend: FRONTEND_BASE_URL,
    origin: req.get("origin") || null,
    allowedOrigins: Array.from(allowedOrigins),
  })
);

/* =========================
 * 서버 시작
 * ========================= */
app.listen(PORT, HOST, () => {
  console.log(`[web.js] Listening on ${SERVER_BASE_URL} (bind ${HOST}:${PORT})`);
  console.log(`[web.js] Allowed origins:`, Array.from(allowedOrigins).join(", "));
  console.log(`[web.js] Allowed hosts:`, Array.from(allowedHosts).join(", "));
});
