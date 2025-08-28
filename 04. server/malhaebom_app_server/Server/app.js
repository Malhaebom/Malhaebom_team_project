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

// CORS / Body
app.use(cors({ origin: "*" }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 전역 요청 로거(요청이 오면 무조건 한 줄 찍힘)
app.use((req, _res, next) => {
  const ip = req.headers["x-forwarded-for"] || req.ip;
  console.log(
    `[${new Date().toISOString()}] ${req.method} ${req.originalUrl} from ${ip}`
  );
  next();
});

// 헬스체크
app.get("/ping", (_req, res) => res.send("pong"));

// 라우터 마운트 (경로 정확히 유지)
app.use("/userLogin", loginRouter);
app.use("/userJoin",  joinRouter);
app.use("/str",       strRouter); // 동화 화행(Story)
app.use("/ir",        irRouter);  // 인터뷰 화행(Interview)
app.use("/auth",      authRouter); // ★ SNS OAuth

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
