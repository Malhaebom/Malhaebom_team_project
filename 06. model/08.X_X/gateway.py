import os
import json
from datetime import datetime
from typing import Optional, Dict, Any, List, Tuple

import numpy as np
import requests
import torch
import torchaudio
import librosa

from fastapi import FastAPI, UploadFile, File, Form, Query, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

# ===== 설정 =====
ANALYSIS_SERVER_URL = os.environ.get("BACKEND_ANALYZE", "http://127.0.0.1:8000/analyze")  # MAIN.py
GATEWAY_PORT = int(os.environ.get("PORT", "4010"))

# ===== STT 세팅 (Whisper) =====
STT_MODEL_ID = "openai/whisper-small"
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"[gateway] Whisper device: {device}")
try:
    from transformers import WhisperProcessor, WhisperForConditionalGeneration
    stt_processor = WhisperProcessor.from_pretrained(STT_MODEL_ID)
    stt_model = WhisperForConditionalGeneration.from_pretrained(STT_MODEL_ID).to(device)
    print("[gateway] Whisper loaded")
except Exception as e:
    print(f"[gateway] Whisper load failed: {e}")
    stt_processor = None
    stt_model = None

# ===== 앱이 쓰는 40점 체계 매핑 =====
MAX_PER_KEY: Dict[str, int] = {
    "반응 시간": 4,
    "반복어 비율": 4,
    "평균 문장 길이": 4,
    "화행 적절성": 12,
    "회상어 점수": 8,
    "문법 완성도": 8,
}
EN2KO: Dict[str, str] = {
    "response_time": "반응 시간",
    "repetition": "반복어 비율",
    "avg_sentence_length": "평균 문장 길이",
    "appropriateness": "화행 적절성",
    "recall": "회상어 점수",
    "grammar": "문법 완성도",
}

# ===== 인메모리 저장 =====
_attempt_latest: Dict[str, Dict[str, Any]] = {}
_attempt_list:   Dict[str, List[Dict[str, Any]]] = {}
_story_latest:   Dict[str, Dict[str, Any]] = {}

# 진행도 저장:
# key -> {
#   "total": int,
#   "items": {
#       idx(int 1..N): {"scores": {...}, "ts": ISO, "ok": bool, "idx": int, "qid": int}
#   },
#   "updatedAt": ISO
# }
_progress_store: Dict[str, Dict[str, Any]] = {}

def _k_user_title(user_key: str, title: Optional[str]) -> str:
    return f"{(user_key or 'guest').strip()}||{(title or '').strip()}"

def _session_key(user_key: str, title: Optional[str]) -> str:
    return _k_user_title(user_key, title)

# ===== FastAPI =====
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("[gateway] startup")
    yield
    print("[gateway] shutdown")

app = FastAPI(lifespan=lifespan, title="malhaebom-gateway", version="1.2.2")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_headers=["*"],
    allow_methods=["*"],
)

# ---------- 유틸: STT ----------
async def run_stt(audio: UploadFile) -> Tuple[str, float]:
    """업로드된 오디오에서 한국어 음성 인식. 실패/무음이면 빈 문자열. 리턴: (text, raw_duration_sec)"""
    if not stt_model or not stt_processor:
        return ("", 0.0)

    allowed_ext = [".wav", ".mp3", ".m4a", ".webm", ".ogg"]
    ext = os.path.splitext((audio.filename or "").lower())[1]
    if ext not in allowed_ext:
        pass

    audio_bytes = await audio.read()
    import tempfile
    with tempfile.NamedTemporaryFile(delete=False, suffix=ext or ".bin") as tmp:
        tmp.write(audio_bytes)
        temp_path = tmp.name

    try:
        try:
            waveform, sr = torchaudio.load(temp_path)
        except Exception:
            samples, sr = librosa.load(temp_path, sr=None, mono=True)
            waveform = torch.tensor(samples).unsqueeze(0)
    finally:
        try:
            os.unlink(temp_path)
        except Exception:
            pass

    # 원본 길이(초) — 트리밍 전
    raw_dur = float(waveform.shape[-1]) / float(sr) if sr else 0.0

    if sr != 16000:
        resampler = torchaudio.transforms.Resample(orig_freq=sr, new_freq=16000)
        waveform = resampler(waveform)
        sr = 16000

    arr = waveform.squeeze().numpy()

    # 무음/저에너지 구간 트리밍(인식 품질용)
    try:
        trimmed, _ = librosa.effects.trim(arr, top_db=30)
        arr = trimmed if trimmed.size > 0 else arr
    except Exception:
        pass

    # 인식 가능성 체크
    rms = float(np.sqrt(np.mean(arr ** 2))) if arr.size > 0 else 0.0
    if raw_dur < 1.2 or rms < 0.005:
        return ("", raw_dur)

    try:
        feats = stt_processor(arr, sampling_rate=16000, return_tensors="pt").input_features.to(device)
        forced = stt_processor.get_decoder_prompt_ids(language="ko", task="transcribe")
        ids = stt_model.generate(
            feats,
            forced_decoder_ids=forced,
            do_sample=False,
            num_beams=1,
            max_new_tokens=128,
        )
        txt = stt_processor.batch_decode(ids, skip_special_tokens=True)[0].strip()
    except Exception:
        txt = ""

    if txt and len(txt) < 5:
        txt = ""
    return (txt, raw_dur)

# ---------- 헬스체크 ----------
@app.get("/healthz")
def healthz():
    return {"ok": True, "backend": ANALYSIS_SERVER_URL}

# ---------- 앱이 사용하는 엔드포인트들 ----------

# 1) 분석 업로드 + 진행도 반영 (0점 처리 포함)
@app.post("/ir/analyze")
async def ir_analyze(
    audio: UploadFile = File(...),
    prompt: str = Form(...),
    interviewTitle: Optional[str] = Form(None),
    transcript: Optional[str] = Form(None),
    question_id: Optional[str] = Form(None),
    userKey: Optional[str] = Query(None, alias="userKey"),
    lineNumber: Optional[int] = Query(None),
    totalLines: Optional[int] = Query(None),
    questionId: Optional[int] = Query(None),
    x_user_key: Optional[str] = Header(None),  # x-user-key 매핑 OK
):
    # userKey 결정(쿼리 > 헤더 > guest)
    user_key = (userKey or x_user_key or "guest").strip()
    title = (interviewTitle or "인지 능력 검사").strip()

    # idx & qid 결정
    try:
        idx = int(lineNumber or 0)
    except Exception:
        idx = 0
    if idx <= 0:
        raise HTTPException(status_code=400, detail="lineNumber (1..N) required")

    try:
        qid = int(questionId or (int(question_id) if question_id else 0) or idx)
    except Exception:
        qid = idx

    # 1) STT (또는 transcript 사용)
    if transcript is not None and transcript.strip():
        stt_text = transcript.strip()
        audio_dur = 0.0
    else:
        stt_text, audio_dur = await run_stt(audio)

    # 2) 백엔드 분석 호출 — ★ qid/idx/user/title/audio_duration 같이 전달
    payload = {
        "qid": qid,
        "idx": idx,
        "user_key": user_key,
        "title": title,
        "question_text": prompt,
        "answer_text": stt_text or "",
        "response_time": 0.0,
        "audio_duration": float(round(audio_dur, 3)),
    }
    try:
        r = requests.post(ANALYSIS_SERVER_URL, json=payload, timeout=60)
        r.raise_for_status()
        backend = r.json()
    except Exception as e:
        print(f"[gateway] backend analyze fail: {e}")
        backend = {"final_score": 0, "details": {}, "answer_text": stt_text or ""}

    # 3) 점수 맵 (없으면 0점)
    scores_map: Dict[str, int] = {}
    details = backend.get("details") or backend.get("scores") or {}
    if isinstance(details, dict):
        for k_en, v in details.items():
            ko = EN2KO.get(k_en, k_en)
            maxv = MAX_PER_KEY.get(ko, 0)
            try:
                iv = int(round(float(v)))
            except Exception:
                iv = 0
            if maxv > 0:
                iv = max(0, min(iv, maxv))
            scores_map[ko] = iv

    if not scores_map:
        for ko, maxv in MAX_PER_KEY.items():
            scores_map[ko] = 0

    # 4) 진행도 저장 — idx를 키로 사용
    key = _session_key(user_key, title)
    sess = _progress_store.setdefault(key, {"total": int(totalLines or 25), "items": {}, "updatedAt": None})
    sess["total"] = int(totalLines or sess.get("total") or 25)
    sess["items"][idx] = {
        "scores": scores_map,
        "ts": datetime.utcnow().isoformat() + "Z",
        "ok": bool(stt_text),   # stt 없으면 False (0점)
        "idx": idx,
        "qid": qid,
    }
    sess["updatedAt"] = datetime.utcnow().isoformat() + "Z"

    got = sorted(int(v.get("idx", k)) for k, v in sess["items"].items())
    print(f"[gateway] saved idx={idx:02d} (qid={qid}) user={user_key} title={title} "
          f"count={len(got)}/{sess['total']} ok={bool(stt_text)} dur={audio_dur:.2f}s")

    return {
        "ok": True,
        "scores": scores_map,
        "totalMax": 40,
        "transcript": backend.get("answer_text", stt_text or ""),
        "userKey": user_key,
        "lineNumber": idx,
        "totalLines": sess["total"],
        "questionId": qid,
    }

# 2) 진행도 조회
@app.get("/ir/progress")
def ir_progress(
    userKey: Optional[str] = Query(None, alias="userKey"),
    title: Optional[str] = Query(None),
    x_user_key: Optional[str] = Header(None),
):
    user_key = (userKey or x_user_key or "guest").strip()
    title = (title or "인지 능력 검사").strip()
    key = _session_key(user_key, title)
    sess = _progress_store.get(key)
    if not sess:
        return {"ok": True, "total": 25, "received": 0, "pending": list(range(1, 26)), "done": False}

    total = int(sess.get("total") or 25)
    items = sess.get("items") or {}
    got_idx = sorted(int(v.get("idx", k)) for k, v in items.items())
    pending = [i for i in range(1, total + 1) if i not in got_idx]
    done = len(got_idx) >= total

    return {
        "ok": True,
        "total": total,
        "received": len(got_idx),
        "pending": pending,
        "updatedAt": sess.get("updatedAt"),
        "done": done,
    }

# 3) 최종 결과
@app.get("/ir/result")
def ir_result(
    userKey: Optional[str] = Query(None, alias="userKey"),
    title: Optional[str] = Query(None),
    force: Optional[int] = Query(0),
    x_user_key: Optional[str] = Header(None),
):
    user_key = (userKey or x_user_key or "guest").strip()
    title = (title or "인지 능력 검사").strip()
    key = _session_key(user_key, title)
    sess = _progress_store.get(key)
    if not sess:
        return {"ok": False, "error": "no session"}

    total_expected = int(sess.get("total") or 25)
    items = sess.get("items") or {}

    got_idx = set(int(v.get("idx", k)) for k, v in items.items())
    missing = [i for i in range(1, total_expected + 1) if i not in got_idx]

    if missing and not force:
        return {
            "ok": False,
            "done": False,
            "received": len(got_idx),
            "expected": total_expected,
            "pending": missing,
            "updatedAt": sess.get("updatedAt"),
        }

    if missing and force:
        zero_map = {k: 0 for k in MAX_PER_KEY.keys()}
        now_iso = datetime.utcnow().isoformat() + "Z"
        for idx in missing:
            items[idx] = {"scores": dict(zero_map), "ts": now_iso, "ok": False, "idx": idx, "qid": 0}
        sess["items"] = items
        sess["updatedAt"] = now_iso
        got_idx = set(int(v.get("idx", k)) for k, v in items.items())

    acc_correct = {k: 0 for k in MAX_PER_KEY.keys()}
    acc_total   = {k: 0 for k in MAX_PER_KEY.keys()}
    for it in items.values():
        for ko, maxv in MAX_PER_KEY.items():
            c = int(it["scores"].get(ko, 0))
            acc_correct[ko] += c
            acc_total[ko]   += maxv

    byCategory, score_sum = {}, 0
    total_norm = sum(MAX_PER_KEY.values())  # 40
    for ko, maxv in MAX_PER_KEY.items():
        c_acc, t_acc = acc_correct[ko], acc_total[ko]
        ratio = (c_acc / t_acc) if t_acc > 0 else 0.0
        norm = int(round(ratio * maxv))
        byCategory[ko] = {"correct": norm, "total": maxv}
        score_sum += norm

    return {
        "ok": True,
        "done": True,
        "total": total_norm,
        "score": score_sum,
        "byCategory": byCategory,
        "byType": {},
        "received": len(got_idx),
        "expected": total_expected,
        "pending": [],
        "updatedAt": sess.get("updatedAt"),
    }

# ---- 시도 저장/조회 API ----
@app.get("/ir/latest")
def ir_latest(
    userKey: Optional[str] = Query(None, alias="userKey"),
    title: Optional[str] = Query(None),
    x_user_key: Optional[str] = Header(None),
):
    user_key = (userKey or x_user_key or "guest").strip()
    key = _k_user_title(user_key, title)
    latest = _attempt_latest.get(key)
    return {"ok": True, "latest": latest}

@app.post("/ir/attempt")
def ir_attempt(
    body: Dict[str, Any],
    userKey: Optional[str] = Query(None, alias="userKey"),
    x_user_key: Optional[str] = Header(None),
):
    user_key = (body.get("userKey") or userKey or x_user_key or "guest").strip()
    title = (body.get("interviewTitle") or "").strip()
    key = _k_user_title(user_key, title)

    ord_in = body.get("clientAttemptOrder") or body.get("attemptOrder") or 1
    saved = {
        "userKey": user_key,
        "title": title,
        "clientAttemptOrder": int(ord_in),
        "attemptTime": body.get("attemptTime"),
        "clientKst": body.get("clientKst"),
        "score": body.get("score"),
        "total": body.get("total"),
    }
    _attempt_latest[key] = saved
    _attempt_list.setdefault(key, [])
    _attempt_list[key].insert(0, {**saved, "savedAt": datetime.utcnow().isoformat() + "Z"})
    return {"ok": True, "saved": saved}

@app.get("/ir/attempt/list")
def ir_attempt_list(
    userKey: Optional[str] = Query(None, alias="userKey"),
    title: Optional[str] = Query(None),
    limit: int = Query(30),
    x_user_key: Optional[str] = Header(None),
):
    user_key = (userKey or x_user_key or "guest").strip()
    key = _k_user_title(user_key, title)
    items = _attempt_list.get(key, [])
    return {"ok": True, "list": items[:max(1, limit)]}

# ---- 동화 API ----
@app.get("/str/latest")
def str_latest(
    storyKey: Optional[str] = Query(None),
    userKey: Optional[str] = Query(None, alias="userKey"),
    x_user_key: Optional[str] = Header(None),
):
    if not storyKey:
        return {"ok": True, "latest": None}
    # story는 user키 영향 안 줌. 그대로 저장/조회
    latest = _story_latest.get(storyKey)
    return {"ok": True, "latest": latest}

@app.post("/str/attempt")
def str_attempt(body: Dict[str, Any]):
    story_key = (body.get("storyKey") or "").strip()
    if not story_key:
        return {"ok": False, "error": "storyKey required"}
    saved = {**body, "savedAt": datetime.utcnow().isoformat() + "Z"}
    _story_latest[story_key] = saved
    return {"ok": True, "saved": saved}

# ---- 실행 ----
if __name__ == "__main__":
    import uvicorn
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", GATEWAY_PORT))
    print(f"[gateway] run on http://{host}:{port}  (backend={ANALYSIS_SERVER_URL})")
    uvicorn.run(app, host=host, port=port, reload=True)
