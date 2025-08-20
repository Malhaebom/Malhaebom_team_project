class UserModel {
  final String? name;
  final String? birthDate;
  final String? phoneNumber;
  final String? password;
  final Map<String, dynamic>? guardianInfo;
  /* 
    {
        "guardianName" : "보호자 이름",
        "guardianPhoneNumber" : "보호자 전화번호(숫자)",
    }
  */
  final String? instructorId;
  final String? gender;
  final Map<String, dynamic>? agreement; // 동의 목록
  /*
    {
      "termsAndConditions" : true,
      "privacyPolicy" : true,
      "sensitiveInfoCollection" : true,
      "thirdPartyInfoSharing" : true,
    }
  */

  /* 생성자 */
  UserModel({
    this.name,
    this.birthDate,
    this.phoneNumber,
    this.password,
    this.guardianInfo,
    this.instructorId,
    this.gender,
    this.agreement,
  });

  // copyWith 메서드를 통해 기존 객체를 변경 없이 새 객체 생성
  UserModel copyWith({
    String? name,
    String? birthDate,
    String? phoneNumber,
    String? password,
    Map<String, dynamic>? guardianInfo,
    String? instructorId,
    String? gender,
    Map<String, dynamic>? agreement,
  }) {
    return UserModel(
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      password: password ?? this.password,
      guardianInfo: guardianInfo ?? this.guardianInfo,
      instructorId: instructorId ?? this.instructorId,
      gender: gender ?? this.gender,
      agreement: agreement ?? this.agreement,
    );
  }

  /* UserModel을 JSON으로 변환 */
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'birthDate': birthDate,
      'phoneNumber': phoneNumber,
      'password': password,
      'guardianInfo': guardianInfo,
      'instructorId': instructorId,
      'gender': gender,
      'agreement': agreement,
    };
  }

  /* JSON을 UserModel로 변환 */
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'],
      birthDate: json['birthDate'],
      phoneNumber: json['phoneNumber'],
      password: json['password'],
      guardianInfo: json['guardianInfo'],
      instructorId: json['instructorId'],
      gender: json['gender'],
      agreement: json['agreement'],
    );
  }
}
