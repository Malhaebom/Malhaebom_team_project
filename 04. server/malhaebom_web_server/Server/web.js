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
const SERVER_BASE_URL   = process.env.SERVER_BASE_URL   || "http://211.188.63.38:3001"; // 이 서버
const FRONTEND_BASE_URL = process.env.FRONTEND_BASE_URL || "http://211.188.63.38";      // 운영: 80포트(IP 또는 도메인)
const DEV_FRONT_URL     = process.env.DEV_FRONT_URL     || "http://211.188.63.38:5137"; // 개발 vite (원하면 삭제)

/* =========================
 * CORS 허용 목록
 * ========================= */
const rawAllowed = [
  SERVER_BASE_URL,
  FRONTEND_BASE_URL,
  DEV_FRONT_URL,
  "http://localhost:5173", // 로컬 개발 필요 시
].filter(Boolean);

// 같은 호스트/다른 포트 허용을 위해 호스트 단위 화이트리스트 구성(선택)
const allowedHosts = new Set(
  rawAllowed
    .map(o => {
      try { return new url.URL(o).host; } catch (e) { return null; }
    })
    .filter(Boolean)
);

// 원본 문자열 그대로도 허용(정확 매칭)
const allowedOrigins = new Set(rawAllowed);

/* =========================
 * 미들웨어
 * ========================= */
app.use(
  cors({
    origin: (origin, cb) => {
      if (!origin) return cb(null, true); // 서버-서버 호출 등
      try {
        const u = new url.URL(origin);
        // 1) 정확히 등록된 origin 허용
        if (allowedOrigins.has(origin)) return cb(null, true);
        // 2) 같은 host면 포트가 달라도 허용 (선택)
        if (allowedHosts.has(u.host)) return cb(null, true);
      } catch (e) {}
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

app.use("/userLogin", LoginServer);
app.use("/userJoin",  JoinServer);
app.use("/auth",      Auther);
app.use("/str",       W_STRServer);

/* =========================
 * 헬스체크
 * ========================= */
app.get("/health", (req, res) =>
  res.json({
    ok: true,
    server: SERVER_BASE_URL,
    frontend: FRONTEND_BASE_URL,
    origin: req.get("origin") || null,
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
