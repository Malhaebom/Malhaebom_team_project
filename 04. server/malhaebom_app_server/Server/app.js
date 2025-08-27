const express = require("express");
const cors = require("cors");
require('dotenv').config();

// ✅ 기존 라우터들
const loginRouter = require("./router/LoginServer.js");
const joinRouter  = require("./router/JoinServer.js");
const strRouter   = require("./router/STRServer.js");

// ✅ 새로 추가: 인터뷰 화행(IR) 라우터
const irRouter    = require("./router/IRServer.js");
const authRouter = require("./router/Auther.js");

const app = express();

app.use(cors({ origin: "*" }));
app.use(express.json());


// 라우터 마운트
app.use("/userLogin", loginRouter);
app.use("/userJoin",  joinRouter);
app.use("/str",       strRouter); // 동화 화행(Story) 유지
app.use("/ir",        irRouter);  // ✅ 인터뷰 화행(Interview) 추가
app.use("/auth", authRouter);

const PORT = 4000;
app.listen(PORT, () => {
  console.log(`API running at http://localhost:${PORT}`);
});
