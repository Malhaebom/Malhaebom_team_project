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
const PORT = Number(process.env.WEB_PORT || 3001);

// ✅ 고정 운영 Origin (API 서버: 4000, Web 서버: 3001)
const WEB_ORIGIN = "http://211.188.63.38:3001";
const API_ORIGIN = "http://211.188.63.38:4000";

/* =========================
 * 미들웨어
 * ========================= */
const ALLOWED_ORIGINS = [
  WEB_ORIGIN,
  API_ORIGIN,
  "http://localhost:5173",
  "http://127.0.0.1:5173",
  "http://localhost:3000",
  "http://127.0.0.1:3000",
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

/* =========================
 * 라우터
 * ========================= */
const LoginServer = require("./router/LoginServer");
const JoinServer = require("./router/JoinServer");
const Auther = require("./router/Auther");
const W_STRServer = require("./router/W_STRServer");

app.use("/userLogin", LoginServer);
app.use("/userJoin", JoinServer);
app.use("/auth", Auther);
app.use("/str", W_STRServer);

/* =========================
 * 기본/헬스체크
 * ========================= */
app.get("/health", (req, res) =>
  res.json({ ok: true, server: WEB_ORIGIN })
);

/* =========================
 * 서버 시작
 * ========================= */
app.listen(PORT, HOST, () => {
  console.log(`[web.js] Listening on ${WEB_ORIGIN} (bind ${HOST}:${PORT})`);
  console.log(`[web.js] Allowed origins: ${ALLOWED_ORIGINS.join(", ")}`);
});
