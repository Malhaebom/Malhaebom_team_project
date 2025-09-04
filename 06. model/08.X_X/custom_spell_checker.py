# custom_spell_checker.py
import requests
import json
import time

# 다음 맞춤법 검사기에서 사용하는 API 주소입니다.
DAUM_SPELL_CHECK_URL = 'https://dic.daum.net/grammar_checker.do'

def check_spelling(text):
    """
    다음(Daum) 맞춤법 검사기 API를 사용하여 맞춤법 오류 개수를 반환합니다.
    """
    if not text or not text.strip():
        return 0

    try:
        # API에 요청을 보냅니다. 타임아웃을 5초로 설정합니다.
        response = requests.post(DAUM_SPELL_CHECK_URL, data={'sentence': text}, timeout=5)
        
        # 요청이 성공했는지 확인합니다.
        if response.status_code != 200:
            print(f"[알림] 맞춤법 검사 API 요청 실패 (상태 코드: {response.status_code})")
            return 0

        # 응답받은 HTML에서 오류 정보가 담긴 JSON 부분을 추출합니다.
        html = response.text
        start_idx = html.find('data-data=') + len('data-data=')
        end_idx = html.find('></script>', start_idx)
        
        json_string = html[start_idx:end_idx].strip().replace("'", '"')
        
        # --- ✨ 여기가 추가된 안전장치입니다! ---
        # 추출된 문자열이 비어있는지 확인합니다.
        if not json_string:
            # print("[알림] 맞춤법 검사 결과가 비어있습니다. 오류 없음으로 처리합니다.")
            return 0
        # -----------------------------------------
            
        data = json.loads(json_string)
        
        error_count = len(data.get('errInfo', []))
        
        return error_count

    except requests.exceptions.RequestException as e:
        print(f"[알림] 맞춤법 검사 API 네트워크 오류: {e}")
        return 0
    except Exception as e:
        print(f"[알림] 맞춤법 검사 중 예외 발생: {e}")
        return 0

# 이 파일을 직접 실행하여 테스트해볼 수 있습니다.
if __name__ == '__main__':
    test_sentence_1 = "아버지가방에들어가신다"
    test_sentence_2 = "오늘 날씨가 참 조내요."
    test_sentence_3 = "안녕하세요, 만나서 반갑습니다."

    errors1 = check_spelling(test_sentence_1)
    time.sleep(1) 
    errors2 = check_spelling(test_sentence_2)
    time.sleep(1)
    errors3 = check_spelling(test_sentence_3)

    print(f"문장: '{test_sentence_1}', 오류 개수: {errors1}")
    print(f"문장: '{test_sentence_2}', 오류 개수: {errors2}")
    print(f"문장: '{test_sentence_3}', 오류 개수: {errors3}")
