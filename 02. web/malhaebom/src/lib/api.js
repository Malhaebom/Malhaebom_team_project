// 02. web/malhaebom/src/lib/api.js
import axios from "axios";

const API = axios.create({
  baseURL: "/api",
  withCredentials: true,
  headers: { "Content-Type": "application/json" },
});

// ──────────────────────────────────────────────
// 공통: guest 키 판정 & 정리
// ──────────────────────────────────────────────
const isGuest = (v) => !!v && String(v).trim().toLowerCase() === "guest";
const cleanUserKey = (v) => {
  const s = String(v || "").trim();
  return s && !isGuest(s) ? s : ""; // guest면 빈 값으로
};

// 요청 인터셉터
API.interceptors.request.use((config) => {
  const method = (config.method || "get").toLowerCase();

  // 1) params.user_key가 guest면 제거
  if (config.params && typeof config.params === "object") {
    const uk = cleanUserKey(config.params.user_key);
    if (!uk) delete config.params.user_key;
    else config.params.user_key = uk;
  }

  // 2) 세션에 guest가 남아 있으면 제거, 유효하면 헤더 보조
  try {
    const cached = cleanUserKey(sessionStorage.getItem("user_key"));
    if (!cached) {
      sessionStorage.removeItem("user_key"); // guest 정리
    } else {
      // 쿠키 인증이 불안정한 환경 대비: 헤더로도 보조 전달
      config.headers["x-user-key"] = cached;
    }
  } catch {}

  // 3) 인증성 GET은 캐시 버스터
  if (method === "get") {
    const url = config.url || "";
    if (
      url.startsWith("/userLogin/me") ||
      url.startsWith("/auth/") ||
      url.startsWith("/userLogin/")
    ) {
      const params = new URLSearchParams(config.params || {});
      params.set("_t", Date.now().toString());
      config.params = Object.fromEntries(params);
    }
    config.headers["Cache-Control"] = "no-cache";
    config.headers["Pragma"] = "no-cache";
  }

  return config;
});

// 응답 인터셉터(로그)
API.interceptors.response.use(
  (res) => res,
  (err) => {
    const url = err?.config?.url;
    const status = err?.response?.status;
    const data = err?.response?.data;
    console.error("[API ERROR]", (err?.config?.method || "GET").toUpperCase(), url, status, data);
    return Promise.reject(err);
  }
);

// ──────────────────────────────────────────────
// user_key 유틸
// ──────────────────────────────────────────────
function getUserKeyFromUrl() {
  try {
    const url = new URL(window.location.href);
    const q = (url.searchParams.get("user_key") || "").trim();
    if (q && !isGuest(q)) return q;
  } catch (_e) {}
  return null;
}

function extractUserKeyFromMe(data) {
  if (!data?.ok || !data.isAuthed) return null;

  // 서버가 userKey를 주는 경우 우선
  const direct = cleanUserKey(data.userKey);
  if (direct) return direct;

  // 하위 호환: loginType/loginId 조합
  const loginType = String(data.loginType || "").trim();
  const loginId   = String(data.loginId || "").trim();
  if (!loginType || !loginId) return null;
  const key = loginType === "local" ? loginId : `${loginType}:${loginId}`;
  return cleanUserKey(key) || null;
}

export async function getUserKeyFromSession() {
  try {
    // 1) URL 우선
    const fromQuery = getUserKeyFromUrl();
    if (fromQuery) {
      sessionStorage.setItem("user_key", fromQuery);
      return fromQuery;
    }

    // 2) 세션 캐시
    const cached = cleanUserKey(sessionStorage.getItem("user_key"));
    if (cached) return cached;

    // 3) /me 호출
    const { data } = await API.get("/userLogin/me");
    const meKey = extractUserKeyFromMe(data);
    if (meKey) {
      sessionStorage.setItem("user_key", meKey);
      return meKey;
    }
  } catch (_e) {}

  return null;
}

export async function ensureUserKey({ retries = 3, delayMs = 200 } = {}) {
  for (let i = 0; i <= retries; i++) {
    const k = await getUserKeyFromSession();
    if (k) return k;
    if (i < retries && delayMs) await new Promise((r) => setTimeout(r, delayMs));
  }
  return null;
}

export default API;
