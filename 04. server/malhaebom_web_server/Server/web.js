// Server/web.js
const express = require("express");
const cors = require("cors");
const cookieParser = require("cookie-parser");

const app = express();

/* =========================
 * 하드코딩 설정
 * ========================= */
const PORT = 3001;
const FRONTEND_BASE_URL = "http://localhost:5173";

/* =========================
 * 미들웨어
 * ========================= */
app.use(
  cors({
    origin: [FRONTEND_BASE_URL, "http://127.0.0.1:5173", "http://localhost:5173"],
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
app.get("/health", (req, res) => res.json({ ok: true }));

/* =========================
 * 서버 시작
 * ========================= */
app.listen(PORT, () => {
  console.log(`[web.js] Listening on http://localhost:${PORT}`);
});
