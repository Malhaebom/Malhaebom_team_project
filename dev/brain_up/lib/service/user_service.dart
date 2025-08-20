import 'package:brain_up/models/user_model.dart';

class UserService {
  static bool signUp(UserModel usermodel) {
    print("name : ${usermodel.name}");
    print("birthDate : ${usermodel.birthDate}");
    print("phoneNumber : ${usermodel.phoneNumber}");
    print("password : ${usermodel.password}");
    print("guardianInfo : ${usermodel.guardianInfo}");
    print("instructorId : ${usermodel.instructorId}");
    print("gender : ${usermodel.gender}");
    print("agreement : ${usermodel.agreement}");

    return true;
  }
}
