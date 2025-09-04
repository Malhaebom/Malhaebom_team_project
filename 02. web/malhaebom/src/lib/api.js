// 02.web/malhaebom/src/lib/api.js
import axios from "axios";

const API = axios.create({
  baseURL: "/api",
  withCredentials: true,
  headers: { "Content-Type": "application/json" },
});

// GET 인증 엔드포인트 캐시 무력화 + 보조 헤더
API.interceptors.request.use((config) => {
  const method = (config.method || "get").toLowerCase();
  if (method === "get") {
    const url = config.url || "";
    if (
      url.startsWith("/userLogin/me") ||
      url.startsWith("/auth/") ||
      url.startsWith("/userLogin/") ||
      url.startsWith("/str/")
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

API.interceptors.response.use(
  (res) => res,
  (err) => {
    const url = err?.config?.url;
    const method = (err?.config?.method || "GET").toUpperCase();
    const status = err?.response?.status;
    const data = err?.response?.data;
    console.error("[API ERROR]", method, url, status, data || err?.message);
    return Promise.reject(err);
  }
);

// === user_key 유틸 ===
function getUserKeyFromUrl() {
  try {
    const url = new URL(window.location.href);
    const q = (url.searchParams.get("user_key") || "").trim();
    if (q && q.toLowerCase() !== "guest") return q;
  } catch (_e) {}
  return null;
}

async function getKeyFromWhoAmI() {
  try {
    const { data } = await API.get("/str/whoami");
    const k = (data?.identity?.user_key || data?.used || "").trim();
    if (k && k.toLowerCase() !== "guest") return k;
  } catch (_e) {}
  return null;
}

function extractUserKeyFromMe(data) {
  if (!data?.ok || !data.isAuthed) return null;
  const direct = (data.userKey || "").trim();
  if (direct && direct.toLowerCase() !== "guest") return direct;
  const loginType = (data.loginType || "").trim();
  const loginId   = (data.loginId || "").trim();
  if (!loginType || !loginId) return null;
  return loginType === "local" ? `local:${loginId}` : `${loginType}:${loginId}`;
}

export async function getUserKeyFromSession() {
  // 1) URL
  const fromQuery = getUserKeyFromUrl();
  if (fromQuery) {
    sessionStorage.setItem("user_key", fromQuery);
    return fromQuery;
  }
  // 2) whoami
  const who = await getKeyFromWhoAmI();
  if (who && who.toLowerCase() !== "guest") {
    const cached = (sessionStorage.getItem("user_key") || "").trim();
    if (who !== cached) sessionStorage.setItem("user_key", who);
    return who;
  }
  // 3) 캐시
  const cached = (sessionStorage.getItem("user_key") || "").trim();
  if (cached && cached.toLowerCase() !== "guest") return cached;
  // 4) 구(me)
  try {
    const { data } = await API.get("/userLogin/me");
    const meKey = extractUserKeyFromMe(data);
    if (meKey && meKey.toLowerCase() !== "guest") {
      sessionStorage.setItem("user_key", meKey);
      return meKey;
    }
  } catch (_e) {}
  return null;
}

export async function ensureUserKey({ retries = 3, delayMs = 200 } = {}) {
  for (let i = 0; i <= retries; i++) {
    const k = await getUserKeyFromSession();
    if (k && k.toLowerCase() !== "guest") return k;
    if (i < retries && delayMs) await new Promise((r) => setTimeout(r, delayMs));
  }
  return null;
}

export default API;
