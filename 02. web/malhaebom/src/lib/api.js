// 02. web/malhaebom/src/lib/api.js
import axios from "axios";

const API = axios.create({
  baseURL: "/",                 // 운영: 같은 호스트(80) → Nginx 프록시가 3001로 전달
  withCredentials: true,
  headers: { "Content-Type": "application/json" },
});

export default API;