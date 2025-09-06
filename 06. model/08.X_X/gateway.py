# gateway.py  (팀원 버전 → 프론트와 호환되도록 수정)
import os
import json
import time
import gc
from datetime import datetime
from typing import Optional, Dict, Any, List, Tuple

import numpy as np
import requests
import torch
import torchaudio
import librosa

from fastapi import FastAPI, UploadFile, File, Form, Query, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
from pydantic import BaseModel

# --- Pydantic 모델 (앱 전용, 내부에선 필요없지만 유지) ---
class ScoreDetail(BaseModel):
    response_time: float
    repetition: float
    avg_sentence_length: float
    appropriateness: float
    recall: float
    grammar: float

class InterviewResult(BaseModel):
    question: str
    answer: str
    scores: ScoreDetail

class InterviewSession(BaseModel):
    results: List[InterviewResult]

# ===== 설정 =====
ANALYSIS_SERVER_URL = os.environ.get("BACKEND_ANALYZE", "http://127.0.0.1:8000/analyze")  # MAIN.py
GATEWAY_PORT = int(os.environ.get("PORT", "4010"))  # ★ 프론트/NGINX와 맞춤

# ===== STT 세팅 (Whisper + 선택적 LoRA) =====
STT_MODEL_ID = "openai/whisper-small"
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"[gateway] Whisper device: {device}")
try:
    from transformers import WhisperProcessor, WhisperForConditionalGeneration
    stt_processor = WhisperProcessor.from_pretrained(STT_MODEL_ID)
    stt_model = WhisperForConditionalGeneration.from_pretrained(STT_MODEL_ID).to(device)

    # 선택적 LoRA 어댑터 로드
    try:
        from peft import PeftModel
        project_root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
        env_dir = os.environ.get("WHISPER_LORA_DIR", "").strip()
        finetune_end_dir = os.path.join(project_root, 'FINETUNE_END')
        checkpoint_dir = os.path.join(project_root, 'checkpoint-3096')

        adapter_dir = None
        if env_dir:
            adapter_dir = env_dir
        else:
            finetune_adapter = os.path.join(finetune_end_dir, 'adapter_model.safetensors')
            if os.path.isdir(finetune_end_dir) and os.path.isfile(finetune_adapter):
                adapter_dir = finetune_end_dir
            elif os.path.isdir(checkpoint_dir):
                adapter_dir = checkpoint_dir

        if adapter_dir and os.path.exists(adapter_dir):
            print(f"[gateway] Load LoRA adapter: {adapter_dir}")
            stt_model = PeftModel.from_pretrained(stt_model, adapter_dir)
        else:
            print("[gateway] LoRA adapter not found. Using base Whisper.")
    except Exception as e:
        print(f"[gateway] LoRA load skipped: {e}")

    print("[gateway] Whisper loaded")
except Exception as e:
    print(f"[gateway] Whisper load failed: {e}")
    stt_processor = None
    stt_model = None

# ===== 40점 매핑 =====
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

# ===== 인메모리 저장 (프런트 계약과 동일) =====
_attempt_latest: Dict[str, Dict[str, Any]] = {}
_attempt_list:   Dict[str, List[Dict[str, Any]]] = {}
_story_latest:   Dict[str, Dict[str, Any]] = {}

# 진행도 저장
_progress_store: Dict[str, Dict[str, Any]] = {}

def _k_user_title(user_key: str, title: Optional[str]) -> str:
    return f"{(user_key or 'guest').strip()}||{(title or '').strip()}"

def _session_key(user_key: str, title: Optional[str]) -> str:
    return _k_user_title(user_key, title)

# ===== Kanana 후처리 (옵션) =====
_kanana_enabled = os.environ.get("KANANA_POSTPROCESS", "0").strip() == "1"
_kanana_pipeline = None

def _load_kanana_if_needed():
    global _kanana_pipeline
    if not _kanana_enabled:
        return None
    if _kanana_pipeline is not None:
        return _kanana_pipeline
    try:
        from transformers import AutoModelForCausalLM, AutoTokenizer, pipeline
        model_id = os.environ.get("KANANA_MODEL", "kakaocorp/kanana-1.5-2.1b-base")
        tokenizer = AutoTokenizer.from_pretrained(model_id)
        model = AutoModelForCausalLM.from_pretrained(
            model_id,
            torch_dtype=torch.float32,
            low_cpu_mem_usage=True,
        )
        _kanana_pipeline = pipeline(task="text-generation", model=model, tokenizer=tokenizer)
    except Exception as e:
        print(f"[gateway] Kanana load failed (disabled): {e}")
        _kanana_pipeline = None
    return _kanana_pipeline

def postprocess_with_kanana(text: str) -> str:
    if not text or not _kanana_enabled:
        return text
    pipe = _load_kanana_if_needed()
    if not pipe:
        return text
    try:
        prompt = (
            "다음 한국어 발화를 의미를 바꾸지 않도록 정확한 문장으로 교정해 주세요.\n"
            "고유명사와 숫자는 그대로 보존하세요. 결과만 출력:\n"
            f"{text}"
        )
        out = pipe(
            prompt,
            max_new_tokens=min(max(32, int(len(text) * 1.2)), 256),
            do_sample=False,
            temperature=0.0,
            top_p=1.0,
            num_return_sequences=1,
        )
        generated = out[0]["generated_text"] if isinstance(out, list) and out else ""
        cleaned = generated.replace(prompt, "").strip()
        return cleaned or text
    except Exception as e:
        print(f"[gateway] Kanana postprocess failed: {e}")
        return text

# ---------- 유틸: STT ----------
async def run_stt(audio_file: UploadFile) -> Tuple[str, float]:
    """
    업로드된 오디오에서 한국어 음성 인식.
    반환: (transcription, duration_sec). 실패/무음이면 ("", 측정길이)
    """
    if not stt_model or not stt_processor:
        return ("", 0.0)

    allowed_extensions = ['.wav', '.mp3', '.m4a', '.webm', '.ogg']
    file_extension = os.path.splitext((audio_file.filename or "").lower())[1]
    if file_extension not in allowed_extensions:
        # 포맷이 생소해도 일단 시도
        pass

    audio_bytes = await audio_file.read()

    import tempfile, platform
    temp_file_path = None
    temp_file = None

    try:
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=file_extension or ".bin")
        temp_file.write(audio_bytes); temp_file.flush()
        temp_file_path = temp_file.name
        temp_file.close(); temp_file = None
        if platform.system() == "Windows":
            time.sleep(0.2)

        # torchaudio 우선
        try:
            waveform, sampling_rate = torchaudio.load(temp_file_path)
        except Exception as e:
            try:
                waveform_np, sampling_rate = librosa.load(temp_file_path, sr=None, mono=True)
                waveform = torch.tensor(waveform_np).unsqueeze(0)
            except Exception as librosa_error:
                print(f"[gateway] audio load failed: {e} / librosa: {librosa_error}")
                return ("", 0.0)

        if sampling_rate != 16000:
            resampler = torchaudio.transforms.Resample(orig_freq=sampling_rate, new_freq=16000)
            waveform = resampler(waveform)
            sampling_rate = 16000

        waveform_np = waveform.squeeze().numpy()

        # 무음/저에너지 트리밍
        try:
            trimmed, _ = librosa.effects.trim(waveform_np, top_db=30)
            waveform_np = trimmed if trimmed.size > 0 else waveform_np
        except Exception:
            pass

        duration_sec = len(waveform_np) / 16000.0 if waveform_np.size > 0 else 0.0
        rms = float(np.sqrt(np.mean(waveform_np**2))) if waveform_np.size > 0 else 0.0
        if duration_sec < 1.0 or rms < 0.005:  # ★ 1.0초 기준으로 통일
            return ("", float(duration_sec))

        try:
            input_features = stt_processor(waveform_np, sampling_rate=16000, return_tensors="pt").input_features.to(device)
            forced_decoder_ids = stt_processor.get_decoder_prompt_ids(language="ko", task="transcribe")
            predicted_ids = stt_model.generate(
                input_features,
                forced_decoder_ids=forced_decoder_ids,
                do_sample=False,
                num_beams=1,
                max_new_tokens=128,
            )
            transcription = stt_processor.batch_decode(predicted_ids, skip_special_tokens=True)[0].strip()
        except Exception as gen_err:
            print(f"[gateway] STT decode failed: {gen_err}")
            transcription = ""

        if transcription and len(transcription) < 5:
            transcription = ""

        if transcription:
            transcription = postprocess_with_kanana(transcription)

        # 흔한 방송 환각 필터
        if transcription:
            lower = transcription
            bl = ["MBC 뉴스", "KBS 뉴스", "SBS 뉴스", "YTN 뉴스", "연합뉴스", "뉴스데스크"]
            if any(p in lower for p in bl):
                transcription = ""
            elif len(lower) <= 50 and ("뉴스" in lower and ("입니다" in lower or "마칩니다" in lower)):
                transcription = ""

        return (transcription, float(duration_sec))

    except Exception as e:
        print(f"[gateway] STT exception: {e}")
        return ("", 0.0)
    finally:
        if temp_file_path:
            try:
                gc.collect()
                if os.path.exists(temp_file_path):
                    try:
                        os.unlink(temp_file_path)
                        # print(f"[gateway] temp removed: {temp_file_path}")
                    except (OSError, PermissionError) as del_err:
                        print(f"[gateway] temp remove warn: {del_err}")
            except Exception as cleanup_err:
                print(f"[gateway] temp cleanup warn: {cleanup_err}")

# ===== FastAPI =====
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("[gateway] startup")
    yield
    print("[gateway] shutdown")

app = FastAPI(lifespan=lifespan, title="malhaebom-gateway", version="1.3.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Nginx 같은 오리진 프록시 전제
    allow_headers=["*"],
    allow_methods=["*"],
)

# ---------- 헬스체크 ----------
@app.get("/healthz")
def healthz():
    return {"ok": True, "backend": ANALYSIS_SERVER_URL}

# ---------- 내부 공통 로직: 분석 호출 & 진행도 반영 ----------
def _map_details_to_ko(details: Dict[str, Any]) -> Dict[str, int]:
    out: Dict[str, int] = {}
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
            out[ko] = iv
    if not out:
        for ko, maxv in MAX_PER_KEY.items():
            out[ko] = 0
    return out

def _ensure_session(user_key: str, title: str, total_lines: Optional[int]) -> Dict[str, Any]:
    key = _session_key(user_key, title)
    sess = _progress_store.setdefault(key, {"total": int(total_lines or 25), "items": {}, "updatedAt": None})
    if total_lines:
        sess["total"] = int(total_lines)
    return sess

def _fmt_scores_line(scores_map: Dict[str, int]) -> str:
    # "반응 시간:3/4, 반복어 비율:4/4, ..." 형태
    parts = []
    for ko, maxv in MAX_PER_KEY.items():
        parts.append(f"{ko}:{int(scores_map.get(ko, 0))}/{maxv}")
    return ", ".join(parts)

def _log_details(ctx: str, idx: int, qid: int, user_key: str, title: str,
                 transcript: str, audio_dur: float,
                 raw_details: Dict[str, Any], mapped_scores: Dict[str, int],
                 total: Optional[int] = None):
    # 전사는 너무 길면 자름
    t = (transcript or "").strip()
    if len(t) > 120:
        t = t[:120] + "…"
    total_disp = f"/{total}" if total else ""
    print(
        f"[gateway][{ctx}] idx={idx}{total_disp} qid={qid} user={user_key} "
        f"title={title} dur={audio_dur:.2f}s",
        flush=True,
    )
    print(f"[gateway][{ctx}] transcript: {t}", flush=True)
    try:
        print(f"[gateway][{ctx}] scores(raw): {json.dumps(raw_details or {}, ensure_ascii=False)}", flush=True)
    except Exception:
        print(f"[gateway][{ctx}] scores(raw): {raw_details}", flush=True)
    print(f"[gateway][{ctx}] scores(mapped): {_fmt_scores_line(mapped_scores)}", flush=True)

# ---------- 프런트 호환: 업로드 분석 엔드포인트 ----------
@app.post("/ir/analyze")
async def ir_analyze(
    audio: UploadFile = File(...),
    prompt: str = Form(...),
    interviewTitle: Optional[str] = Form(None),
    transcript: Optional[str] = Form(None),
    question_id: Optional[str] = Form(None),  # 호환
    userKey: Optional[str] = Query(None, alias="userKey"),
    lineNumber: Optional[int] = Query(None),
    totalLines: Optional[int] = Query(None),
    questionId: Optional[int] = Query(None),
    x_user_key: Optional[str] = Header(None),  # x-user-key 헤더
):
    # userKey/title/idx/qid 해석
    user_key = (userKey or x_user_key or "guest").strip()
    title = (interviewTitle or "인지 능력 검사").strip()

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

    # STT or transcript
    if transcript and transcript.strip():
        stt_text = transcript.strip()
        audio_dur = 0.0
    else:
        stt_text, audio_dur = await run_stt(audio)

    # 백엔드 분석 호출
    payload = {
        "question_text": prompt,
        "answer_text": stt_text or "",
        "response_time": 0.0,
        "audio_duration": float(round(audio_dur, 3)),
    }
    try:
        r = requests.post(ANALYSIS_SERVER_URL, json=payload, timeout=120)
        r.raise_for_status()
        backend = r.json()
    except Exception as e:
        print(f"[gateway] backend analyze fail: {e}")
        backend = {"final_score": 0, "details": {}, "answer_text": stt_text or ""}

    raw_details = backend.get("details") or backend.get("scores") or {}
    scores_map = _map_details_to_ko(raw_details)

    # 진행도 저장
    sess = _ensure_session(user_key, title, totalLines)
    sess["items"][idx] = {
        "scores": scores_map,
        "ts": datetime.utcnow().isoformat() + "Z",
        "ok": bool(stt_text),
        "idx": idx,
        "qid": qid,
    }
    sess["updatedAt"] = datetime.utcnow().isoformat() + "Z"

    # ✅ 항상 상세 로그 출력 (STT 성공/실패 무관)
    _log_details(
        ctx="analyze",
        idx=idx,
        qid=qid,
        user_key=user_key,
        title=title,
        transcript=backend.get("answer_text", stt_text or ""),
        audio_dur=audio_dur,
        raw_details=raw_details,
        mapped_scores=scores_map,
        total=sess.get("total"),
    )

    print(f"[gateway] saved idx={idx:02d} (qid={qid}) user={user_key} title={title} "
          f"count={len(sess['items'])}/{sess['total']} ok={bool(stt_text)} dur={audio_dur:.2f}s")

    return {
        "ok": True,
        "scores": scores_map,
        "totalMax": 40,
        "transcript": backend.get("answer_text", stt_text or ""),
        "userKey": user_key,
        "lineNumber": idx,
        "totalLines": int(sess["total"]),
        "questionId": qid,
    }

# 진행도 조회
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

# 최종 결과
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

# 시도 저장/조회 (호환)
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

# ---------- (선택) 기존 팀원 엔드포인트 유지하되 내부 공용 로직 재사용 ----------
@app.post("/process-audio")
async def process_audio_pipeline(
    audio_file: UploadFile = File(...),
    question_text: str = Form(...),
    response_time: float = Form(0.0),
    audio_duration: float = Form(0.0),
):
    """
    앱/테스트에서 쓰던 기존 엔드포인트. 내부적으로 동일한 분석 호출 후 결과 반환.
    진행도 저장은 하지 않음(호환 유지를 위해 간단 응답만).
    """
    start_time = time.time()
    try:
        txt, dur = await run_stt(audio_file)
        if not txt:
            zero_scores = {"response_time": 0, "repetition": 0, "avg_sentence_length": 0,
                           "appropriateness": 0, "recall": 0, "grammar": 0}
            return {"scores": zero_scores, "final_score": 0, "answer_text": ""}

        payload = {
            "question_text": question_text,
            "answer_text": txt,
            "response_time": response_time,
            "audio_duration": dur or audio_duration or 0.0,
        }
        try:
            r = requests.post(ANALYSIS_SERVER_URL, json=payload, timeout=120)
            r.raise_for_status()
            final_result = r.json()
        except Exception as net_err:
            print(f"[gateway] analyze via /process-audio failed: {net_err}")
            zero_scores = {"response_time": 0, "repetition": 0, "avg_sentence_length": 0,
                           "appropriateness": 0, "recall": 0, "grammar": 0}
            final_result = {"scores": zero_scores, "final_score": 0, "answer_text": txt}
        # ✅ 로그 출력
        raw_details = final_result.get("details") or final_result.get("scores") or {}
        mapped = _map_details_to_ko(raw_details)
        _log_details(
            ctx="process-audio",
            idx=0, qid=0, user_key="(legacy)", title="(legacy)",
            transcript=final_result.get("answer_text", txt or ""),
            audio_dur=dur or audio_duration or 0.0,
            raw_details=raw_details,
            mapped_scores=mapped,
        )
        return final_result
    except Exception as e:
        print(f"[gateway] /process-audio exception: {e}")
        zero_scores = {"response_time": 0, "repetition": 0, "avg_sentence_length": 0,
                       "appropriateness": 0, "recall": 0, "grammar": 0}
        return {"scores": zero_scores, "final_score": 0, "answer_text": ""}

# ---- (선택) 질문 리소스: 필요 시 유지, 하드코딩 경로는 제거/정리 권장 ----
@app.get("/questions")
def get_questions_info():
    return {"ok": True, "note": "Use backend /questions from MAIN.py if needed."}

# ---- 실행 ----
if __name__ == "__main__":
    import uvicorn
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", GATEWAY_PORT))
    print(f"[gateway] run on http://{host}:{port}  (backend={ANALYSIS_SERVER_URL})")
    uvicorn.run(app, host=host, port=port, reload=True)
