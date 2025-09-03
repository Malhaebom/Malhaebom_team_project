// 02. web/malhaebom/src/lib/api.js
import axios from "axios";

const API = axios.create({
  baseURL: "/api",            // 🔴 핵심: 운영에선 무조건 /api 로
  withCredentials: true,
  headers: { "Content-Type": "application/json" },
});

export default API;