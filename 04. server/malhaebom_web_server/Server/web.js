// Server/web.js
require("dotenv").config();

const express = require("express");
const cors = require("cors");
const cookieParser = require("cookie-parser");

const app = express();

/* =========================
 * 서버 설정
 * ========================= */
const HOST = process.env.HOST || "0.0.0.0";
const PORT = Number(process.env.PORT || 3001); // 통일: PORT 사용

// 공개 오리진
const SERVER_BASE_URL   = process.env.SERVER_BASE_URL   || "http://211.188.63.38:3001"; // API 서버(이 서버)
const FRONTEND_BASE_URL = process.env.FRONTEND_BASE_URL || "http://211.188.63.38:5137"; // Vite dev 서버

/* =========================
 * 미들웨어
 * ========================= */
const ALLOWED_ORIGINS = [
  SERVER_BASE_URL,
  FRONTEND_BASE_URL,
];

app.use(
  cors({
    origin: (origin, cb) => {
      if (!origin) return cb(null, true);
      if (ALLOWED_ORIGINS.includes(origin)) return cb(null, true);
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
// 프록시(Nginx/ALB) 뒤라면 쿠키/프로토콜 판별 위해 활성화 권장
// app.set("trust proxy", 1);

/* =========================
 * 라우터
 * ========================= */
const LoginServer = require("./router/LoginServer");
const JoinServer  = require("./router/JoinServer");
const Auther      = require("./router/Auther");       // ← 파일명/변수명 통일
const W_STRServer = require("./router/W_STRServer");  // 기존 라우터

app.use("/userLogin", LoginServer);
app.use("/userJoin",  JoinServer);
app.use("/auth",      Auther);
app.use("/str",       W_STRServer);

/* =========================
 * 기본/헬스체크
 * ========================= */
app.get("/health", (req, res) =>
  res.json({ ok: true, server: SERVER_BASE_URL, frontend: FRONTEND_BASE_URL })
);

/* =========================
 * 서버 시작
 * ========================= */
app.listen(PORT, HOST, () => {
  console.log(`[web.js] Listening on ${SERVER_BASE_URL} (bind ${HOST}:${PORT})`);
  console.log(`[web.js] Allowed origins: ${ALLOWED_ORIGINS.join(", ")}`);
});
