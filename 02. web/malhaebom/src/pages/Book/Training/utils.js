// src/pages/Book/Training/utils.js

export function getSearchParam(name) {
  const sp = new URLSearchParams(window.location.search);
  return sp.get(name);
}

export function pickTargetFairytale(fairytale, bookIdStr) {
  if (!fairytale) return null;
  const arr = Object.values(fairytale);
  const idx = Number(bookIdStr ?? 0);
  return arr[idx] || null;
}

// 점수: sessionStorage 사용
const KEYS = ['scoreAD', 'scoreAI', 'scoreB', 'scoreC', 'scoreD'];

export function resetScores() {
  KEYS.forEach(k => sessionStorage.setItem(k, '0'));
}
export function incrScore(key) {
  const v = Number(sessionStorage.getItem(key) || '0');
  sessionStorage.setItem(key, String(v + 1));
}
export function getScores() {
  return {
    scoreAD: Number(sessionStorage.getItem('scoreAD') || '0'),
    scoreAI: Number(sessionStorage.getItem('scoreAI') || '0'),
    scoreB: Number(sessionStorage.getItem('scoreB') || '0'),
    scoreC: Number(sessionStorage.getItem('scoreC') || '0'),
    scoreD: Number(sessionStorage.getItem('scoreD') || '0'),
  };
}

// 문제 번호(1~20) → 점수 버킷
export function scoreBucketByQuestionNumber(qNum1Based) {
  if (qNum1Based <= 4) return 'scoreAD';
  if (qNum1Based <= 8) return 'scoreAI';
  if (qNum1Based <= 12) return 'scoreB';
  if (qNum1Based <= 16) return 'scoreC';
  return 'scoreD';
}
