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

app.use(
  cors({
    origin: (origin, cb) => {
      if (!origin) return cb(null, true); // 서버-서버 호출 등
      try {
        const u = new url.URL(origin);
        if (allowedOrigins.has(origin)) return cb(null, true); // 완전 일치
        if (allowedHosts.has(u.host)) return cb(null, true); // 같은 host면 포트 달라도 허용
      } catch { }
      console.warn("[CORS] blocked origin:", origin);
      return cb(new Error("Not allowed by CORS"), false);
    },
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: [
      "Content-Type",
      "Authorization",
      "x-user-key",
      "x-login-id",
      "x-user-id",
      "x-sns-user-id",
      "x-sns-login-type",
      "x-phone",
      "x-phone-number",
      "X-Requested-With",
      "Accept"
    ],
  })
);

app.use(express.json());
app.use(cookieParser());

// 프록시 뒤(예: Nginx)라면 신뢰 설정 (쿠키 secure와 리다이렉트 판단에 필요)
app.set("trust proxy", 1);

/* =========================
 * 라우터
 * ========================= */
const LoginServer = require("./router/LoginServer");
const JoinServer = require("./router/JoinServer");
const Auther = require("./router/Auther");
const W_STRServer = require("./router/W_STRServer");

// 레거시 경로
app.use("/userLogin", LoginServer);
app.use("/userJoin", JoinServer);
app.use("/auth", Auther);
app.use("/str", W_STRServer);

// 프론트는 /api만 호출
app.use("/api/userLogin", LoginServer);
app.use("/api/userJoin", JoinServer);
app.use("/api/auth", Auther);
app.use("/api/str", W_STRServer);

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
