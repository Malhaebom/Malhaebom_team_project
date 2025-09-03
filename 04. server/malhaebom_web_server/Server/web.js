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

// 운영/개발 베이스 URL
const SERVER_BASE_URL   = process.env.SERVER_BASE_URL   || "http://127.0.0.1:3001";  // 이 서버(백엔드)
const FRONTEND_BASE_URL = process.env.FRONTEND_BASE_URL || process.env.PUBLIC_BASE_URL || "https://malhaebom.smhrd.com";      // 프론트(80, Nginx)
const DEV_FRONT_URL     = process.env.DEV_FRONT_URL     || "";                          // 개발 vite (선택)

/* =========================
 * CORS 허용 목록
 * ========================= */
const csv = (s) => (s || "").split(",").map(x => x.trim()).filter(Boolean);

const envOrigins = csv(process.env.CORS_ORIGINS); // 예: "http://211.188.63.38,http://211.188.63.38:5173"

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

app.use(
  cors({
    origin: (origin, cb) => {
      if (!origin) return cb(null, true); // 서버-서버 호출 등
      try {
        const u = new url.URL(origin);
        if (allowedOrigins.has(origin)) return cb(null, true); // 1) 완전 일치
        if (allowedHosts.has(u.host))   return cb(null, true); // 2) 같은 host면 포트 달라도 허용
      } catch {}
      console.warn("[CORS] blocked origin:", origin);
      return cb(new Error("Not allowed by CORS"), false);
    },
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

app.use(express.json());
app.use(cookieParser());

// 프록시 뒤(예: Nginx)라면 신뢰 설정 (쿠키/리다이렉트에 필요)
app.set("trust proxy", 1);

/* =========================
 * 라우터
 * ========================= */
const LoginServer = require("./router/LoginServer");
const JoinServer  = require("./router/JoinServer");
const Auther      = require("./router/Auther");
const W_STRServer = require("./router/W_STRServer");

// ✅ 기존 경로 유지 (레거시/직접호출 호환)
app.use("/userLogin", LoginServer);
app.use("/userJoin",  JoinServer);
app.use("/auth",      Auther);
app.use("/str",       W_STRServer);

// ✅ 새로운 권장 경로: /api 프리픽스 (프론트는 항상 /api만 호출)
app.use("/api/userLogin", LoginServer);
app.use("/api/userJoin",  JoinServer);
app.use("/api/auth",      Auther);
app.use("/api/str",       W_STRServer);

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
