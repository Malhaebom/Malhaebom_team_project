// 02. web/malhaebom/src/lib/api.js
import axios from "axios";

const API = axios.create({
  baseURL: "/api",               // ← 무조건 /api (Nginx가 /api → 3001 로 프록시)
  withCredentials: true,         // ← HttpOnly 쿠키 전송 필수
  headers: { "Content-Type": "application/json" },
});

// GET 인증성 엔드포인트 캐시 무력화 + 보조 헤더
API.interceptors.request.use((config) => {
  const method = (config.method || "get").toLowerCase();
  if (method === "get") {
    const url = config.url || "";

    // 인증 상태 관련 엔드포인트는 캐시 버스터 파라미터 부착
    if (
      url.startsWith("/userLogin/me") ||
      url.startsWith("/auth/") ||
      url.startsWith("/userLogin/")
    ) {
      const params = new URLSearchParams(config.params || {});
      params.set("_t", Date.now().toString());
      config.params = Object.fromEntries(params);
    }

    // 보조: 일부 캐시 우회
    config.headers["Cache-Control"] = "no-cache";
    config.headers["Pragma"] = "no-cache";
  }
  return config;
});

// 에러 로깅
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

function methodOf(cfg) {
  return (cfg?.method || "get").toUpperCase();
}

/**
 * 현재 로그인 세션으로부터 user_key를 가져온다.
 * - 우선순위: loginId(이메일/로그인ID) → userId → 'guest'
 * - 저장/조회 모두 이 값을 사용하면 DB 키가 일치한다.
 */
export async function getUserKeyFromSession() {
  try {
    const { data } = await API.get("/userLogin/me");
    if (data?.ok && data?.isAuthed) {
      return (data.loginId || data.userId || "guest").toString().trim();
    }
  } catch (_e) {
    // 무시하고 guest 반환
  }
  return "guest";
}

export default API;
