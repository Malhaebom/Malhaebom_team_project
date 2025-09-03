// 02. web/malhaebom/src/lib/api.js
import axios from "axios";

const API = axios.create({
  baseURL: "/api",               // ← Nginx 프록시 (/api → 3001)
  withCredentials: true,         // ← HttpOnly 쿠키 전송
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
 * - 우선순위: data.user.user_key → data.user.phone → data.loginId → data.userId
 * - 성공 시 localStorage('user_key')에 캐시
 * - 실패 시 null 반환 (※ guest는 여기서 반환하지 않음)
 */
export async function getUserKeyFromSession() {
  try {
    // 캐시 우선
    const cached = localStorage.getItem("user_key");
    if (cached && cached !== "guest") return cached;

    const { data } = await API.get("/userLogin/me");
    const key =
      data?.user?.user_key ||
      data?.user?.phone ||
      data?.loginId ||
      data?.userId ||
      null;

    if (key) {
      const k = String(key).trim();
      if (k) {
        localStorage.setItem("user_key", k);
        return k;
      }
    }
  } catch (_e) {
    // 무시하고 null 반환
  }
  return null;
}

/**
 * user_key를 반드시 확보하려고 시도 (짧은 재시도 포함)
 * - 성공: 실제 키 문자열(guest 아님)
 * - 실패: null
 */
export async function ensureUserKey({ retries = 3, delayMs = 200 } = {}) {
  for (let i = 0; i <= retries; i++) {
    const k = await getUserKeyFromSession();
    if (k && k !== "guest") return k;
    if (i < retries) await new Promise((r) => setTimeout(r, delayMs));
  }
  return null;
}

export default API;
