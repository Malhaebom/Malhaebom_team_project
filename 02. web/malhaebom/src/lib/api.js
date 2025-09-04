// 02. web/malhaebom/src/lib/api.js
import axios from "axios";

const API = axios.create({
  baseURL: "/api",               // ← Nginx 프록시 (/api → 3001)
  withCredentials: true,         // ← HttpOnly 쿠키 전송
  headers: { "Content-Type": "application/json" },
});

// ─────────────────────────────────────────────────────────────
// 요청 인터셉터: /me 등 인증성 GET 요청 캐시 무력화 + 보조 헤더
// ─────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────
// 응답 인터셉터: 에러 로깅
// ─────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────
// user_key 확보 유틸
// 규칙:
//  1) URL 쿼리 ?user_key= 가 있으면 그것을 우선 사용(단, 'guest'는 무시)
//  2) 세션 캐시(sessionStorage 'user_key') 사용
//  3) /userLogin/me 호출 → data.userKey 또는 (loginType:loginId) 조합
//     - local이면 그냥 loginId
//     - sns면 `${loginType}:${loginId}`
//  4) 'guest'는 절대 반환하지 않음
//  5) 성공 시 sessionStorage('user_key')에 캐시
// ─────────────────────────────────────────────────────────────

/** 쿼리에서 user_key를 읽음(없거나 'guest'면 null) */
function getUserKeyFromUrl() {
  try {
    const url = new URL(window.location.href);
    const q = (url.searchParams.get("user_key") || "").trim();
    if (q && q !== "guest") return q;
  } catch (_e) {}
  return null;
}

/** /userLogin/me 응답에서 userKey 계산 */
function extractUserKeyFromMe(data) {
  if (!data?.ok || !data.isAuthed) return null;

  // 서버가 userKey를 직접 내려주는 경우(권장)
  const direct = (data.userKey || "").trim();
  if (direct && direct !== "guest") return direct;

  // 하위 호환: loginType/loginId 조합
  const loginType = (data.loginType || "").trim();   // 'local' | 'kakao' | 'naver' | 'google' ...
  const loginId   = (data.loginId || "").trim();
  if (!loginType || !loginId) return null;

  return loginType === "local" ? loginId : `${loginType}:${loginId}`;
}

/**
 * 현재 로그인 세션으로부터 user_key를 가져온다.
 * - 우선순위: URL ?user_key= → sessionStorage → /userLogin/me
 * - 성공 시 sessionStorage('user_key') 캐시
 * - 실패 시 null 반환 (※ 'guest'는 절대 반환하지 않음)
 */
export async function getUserKeyFromSession() {
  try {
    // 1) URL 쿼리 우선
    const fromQuery = getUserKeyFromUrl();
    if (fromQuery) {
      sessionStorage.setItem("user_key", fromQuery);
      return fromQuery;
    }

    // 2) 세션 캐시
    const cached = (sessionStorage.getItem("user_key") || "").trim();
    if (cached && cached !== "guest") return cached;

    // 3) /me 호출
    const { data } = await API.get("/userLogin/me");
    const meKey = extractUserKeyFromMe(data);
    if (meKey && meKey !== "guest") {
      sessionStorage.setItem("user_key", meKey);
      return meKey;
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
    if (i < retries && delayMs) await new Promise((r) => setTimeout(r, delayMs));
  }
  return null;
}

export default API;
