// 02. web/malhaebom/src/lib/api.js
import axios from "axios";

const API = axios.create({
  baseURL: "/api",               // ← 무조건 /api
  withCredentials: true,         // ← HttpOnly 쿠키 전송 필수
  headers: { "Content-Type": "application/json" },
});

// ✅ GET 요청 중 인증 상태와 관련된 엔드포인트는 캐시 무력화 파라미터를 자동으로 부착
API.interceptors.request.use((config) => {
  const method = (config.method || "get").toLowerCase();
  if (method === "get") {
    const url = config.url || "";
    // /userLogin/me 등 인증 확인 요청은 캐시 방지 파라미터 부착
    if (url.startsWith("/userLogin/me") || url.startsWith("/auth/") || url.startsWith("/userLogin/")) {
      const params = new URLSearchParams(config.params || {});
      params.set("_t", Date.now().toString()); // 캐시 버스터
      config.params = Object.fromEntries(params);
    }
    // (보조) 일부 환경에서 요청 헤더로도 캐시 방지 도움
    config.headers["Cache-Control"] = "no-cache";
    config.headers["Pragma"] = "no-cache";
  }
  return config;
});

// (선택) 에러 로깅: 어디서 실패했는지 보이게
API.interceptors.response.use(
  (res) => res,
  (err) => {
    const url = err?.config?.url;
    const status = err?.response?.status;
    const data = err?.response?.data;
    console.error("[API ERROR]", methodOf(err?.config), url, status, data);
    return Promise.reject(err);
  }
);

function methodOf(cfg) { return (cfg?.method || "get").toUpperCase(); }

export default API;
