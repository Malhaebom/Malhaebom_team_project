class UserViewModel {
  String login(String id, String password) {
    final Map<String, String> mockUserData = {"01012345678": "qwer1234"};
    final isNumeric = RegExp(r'^\d+$').hasMatch(id);

    if (id.isEmpty || password.isEmpty) {
      return "NULL_ERROR";
    } else if (!isNumeric) {
      return "NUMERIC_ERROR"; // 전화번호에 숫자 외 다른 문자 포함 시
    } else if (!mockUserData.containsKey(id)) {
      return "ID_ERROR"; // 아이디 정보 없음
    } else if (password != mockUserData[id]) {
      return "PASSWORD_ERROR"; // 비밀번호 불일치
    }
    return "LOGIN_SUCCESS";
  }
}
