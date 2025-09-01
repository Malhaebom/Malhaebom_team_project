// File: src/Server/app.js
require("dotenv").config();
const express = require("express");
const cors = require("cors");
const path = require("path");

// ✅ 기존/다른 라우터들
const loginRouter = require("./router/LoginServer.js");
const joinRouter  = require("./router/JoinServer.js");
const strRouter   = require("./router/STRServer.js");
const irRouter    = require("./router/IRServer.js");
const authRouter  = require("./router/Auther.js");

const app = express();
const PORT = Number(process.env.PORT || 4000);

// 프록시 신뢰(ngrok 등일 때 https 감지에 필요)
app.set("trust proxy", true);

/* =========================
 *  CORS (수정된 부분)
 * ========================= */
const corsOptions = {
  // 필요 시 특정 도메인 배열로 제한 가능: origin: ['https://app.example.com']
  origin: true,                 // 들어오는 Origin 그대로 허용
  credentials: true,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: [
    "Content-Type",
    "Authorization",
    "x-user-id",
    "x-sns-user-id",
    "x-sns-login-type",
    "x-login-id",
    "x-login-type",
    "x-user-key"
  ],
  // exposedHeaders: [],
};
app.use(cors(corsOptions));
// ⛔️ Express 5에서는 "*" 문자열 금지 → 정규식으로 전체 경로 매칭
app.options(/.*/, cors(corsOptions));

// Body parsers
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 전역 요청 로거
app.use((req, _res, next) => {
  const ip = req.headers["x-forwarded-for"] || req.ip;
  console.log(
    `[${new Date().toISOString()}] ${req.method} ${req.originalUrl} from ${ip}`
  );
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
// app.use("/static", express.static(path.join(__dirname, "public")));

app.listen(PORT, "0.0.0.0", () => {
  console.log(`API running at http://0.0.0.0:${PORT}`);
  console.log(`Try: http://localhost:${PORT}/ping`);
});

// (선택) 종료 시 정리
process.on("SIGINT", () => {
  console.log("SIGINT received. Server shutting down.");
  process.exit(0);
});
