==========================================
🚀 Malhaebom 팀 프로젝트 - 초보자용 실행 가이드
==========================================

📁 프로젝트 위치: C:\TEST_TEAM_VER\Malhaebom_team_project

## 🎯 이 프로젝트는 무엇인가요?

**인터뷰 인지판단 시스템**입니다!
- 사용자가 음성으로 인터뷰 질문에 답변
- AI가 자동으로 분석해서 점수 매김 (40점 만점)
- Flutter 앱과 웹에서 모두 사용 가능

## ⚠️ 중요! 실행 전 확인사항

### 1. **Python이 설치되어 있나요?**
```bash
# 명령 프롬프트에서 확인
python --version
# Python 3.8 이상이 나와야 합니다
```

### 2. **Flutter가 설치되어 있나요?**
```bash
# 명령 프롬프트에서 확인
flutter --version
# Flutter 버전이 나와야 합니다
```

## 🚀 단계별 실행 방법 (초보자용)

### **1단계: Python 가상환경 만들기**
```bash
# 1. 명령 프롬프트 열기 (Windows + R → cmd)
# 2. 프로젝트 폴더로 이동
cd C:\TEST_TEAM_VER\Malhaebom_team_project

# 3. 가상환경 만들기
python -m venv venv

# 4. 가상환경 활성화
venv\Scripts\activate

# 5. 성공하면 (venv)가 앞에 나타납니다
(venv) C:\TEST_TEAM_VER\Malhaebom_team_project>
```

### **2단계: 필요한 라이브러리 설치**
```bash
# 1. 08.X_X 폴더로 이동
cd 08.X_X

# 2. 라이브러리 설치 (시간이 좀 걸립니다)
pip install uvicorn fastapi python-multipart
pip install torch torchaudio transformers sentencepiece
pip install librosa sentence-transformers scikit-learn
pip install konlpy kss requests

# 3. 설치 완료 확인
pip list
```

### **3단계: 서버 실행하기 (순서 중요!)**

#### **터미널 1: 분석 서버**
```bash
# 1. 새 명령 프롬프트 창 열기
# 2. 가상환경 활성화
cd C:\TEST_TEAM_VER\Malhaebom_team_project
venv\Scripts\activate

# 3. 08.X_X 폴더로 이동
cd 08.X_X

# 4. 분석 서버 실행 (8000 포트)
uvicorn MAIN:app --host 127.0.0.1 --port 8000 --reload

# 5. 성공하면 이런 메시지가 나옵니다:
# INFO:     Uvicorn running on http://127.0.0.1:8000
```

#### **터미널 2: 게이트웨이 서버**
```bash
# 1. 또 다른 새 명령 프롬프트 창 열기
# 2. 가상환경 활성화
cd C:\TEST_TEAM_VER\Malhaebom_team_project
venv\Scripts\activate

# 3. 08.X_X 폴더로 이동
cd 08.X_X

# 4. 게이트웨이 서버 실행 (4000 포트)
uvicorn gateway:app --host 0.0.0.0 --port 4000 --reload

# 5. 성공하면 이런 메시지가 나옵니다:
# INFO:     Uvicorn running on http://0.0.0.0:4000
```

### **4단계: Flutter 앱 실행하기**
```bash
# 1. 새 명령 프롬프트 창 열기
# 2. Flutter 앱 폴더로 이동
cd C:\TEST_TEAM_VER\Malhaebom_team_project\03. app\malhaebom

# 3. 의존성 설치
flutter pub get

# 4. 앱 실행 (에뮬레이터나 실제 기기 연결 필요)
flutter run
```

## 🔧 문제 해결 가이드

### **문제 1: "Could not import module 'gateway'" 오류**
**원인**: 08.X_X 폴더에서 실행하지 않음
**해결**: 반드시 `cd 08.X_X` 후 실행

### **문제 2: 포트가 이미 사용 중**
**원인**: 다른 프로그램이 해당 포트 사용
**해결**: 
```bash
# 포트 사용 확인
netstat -ano | findstr :4000
netstat -ano | findstr :8000

# 해당 프로세스 종료 (PID는 위 명령어로 확인)
taskkill /PID [프로세스ID] /F
```

### **문제 3: 라이브러리 설치 실패**
**원인**: 인터넷 연결 문제 또는 권한 문제
**해결**:
```bash
# 관리자 권한으로 명령 프롬프트 실행
# 또는 pip 업그레이드
python -m pip install --upgrade pip
```

### **문제 4: Flutter 앱이 서버에 연결 안됨**
**원인**: 서버가 실행되지 않음 또는 IP 주소 문제
**해결**:
1. 서버 2개가 모두 실행 중인지 확인
2. 에뮬레이터: `http://10.0.2.2:4000`
3. 실제 기기: `http://[PC_IP]:4000`

## 📱 앱 사용 방법

### **Flutter 앱에서:**
1. 앱 실행
2. 인터뷰 페이지로 이동
3. "녹음 시작" 버튼 클릭
4. 질문에 답변 (최대 30초)
5. "녹음 끝내기" 버튼 클릭
6. 자동으로 점수 계산 후 결과 페이지로 이동

### **웹에서 (선택사항):**
```bash
# 새 명령 프롬프트에서
cd C:\TEST_TEAM_VER\Malhaebom_team_project\02. web\malhaebom
npm install
npm run dev
```

## ✅ 성공 확인 방법

### **서버 정상 실행 확인:**
1. **분석 서버**: 브라우저에서 `http://127.0.0.1:8000` 접속
2. **게이트웨이**: 브라우저에서 `http://127.0.0.1:4000` 접속
3. 각각 "FastAPI" 페이지가 나와야 함

### **Flutter 앱 연결 확인:**
1. 앱에서 "녹음 끝내기" 클릭
2. Flutter 콘솔에 🚨 로그 메시지 출력
3. 결과 페이지로 이동

## 🆘 여전히 안 될 때

### **1. 모든 서버 중지 후 재시작**
```bash
# 모든 명령 프롬프트 창 닫기
# 새로 열어서 다시 시도
```

### **2. 컴퓨터 재시작**
- 가끔 포트 충돌이 해결됩니다

### **3. 방화벽 확인**
- Windows 방화벽에서 4000, 8000 포트 허용

### **4. 안티바이러스 확인**
- 일부 안티바이러스가 포트를 차단할 수 있습니다

## 📞 도움 요청 시 필요한 정보

문제가 발생하면 다음 정보를 함께 알려주세요:
1. **오류 메시지**: 정확한 오류 내용
2. **실행 단계**: 어느 단계에서 문제 발생
3. **환경 정보**: Python 버전, Flutter 버전
4. **시도한 해결책**: 이미 시도한 방법들

## 🎉 성공하면 이렇게 됩니다!

1. **Flutter 앱**: 음성 녹음 → 자동 분석 → 점수 결과
2. **총점**: 40점 만점 중 N점
3. **세부 점수**: 반응시간, 반복어, 문장길이, 화행적절성, 회상성, 문법

**행운을 빕니다! 🍀**

---
*작성일: 2025년 1월*
*버전: v1.0*
*대상: 초보자*
