import 'package:brain_up/screens/main/main_page.dart';
import 'package:flutter/material.dart';
import 'package:brain_up/screens/users/login_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ScreenUtilInit(
      designSize: Size(375, 812),
      builder: (context, child) => MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brain Up',
      theme: ThemeData(fontFamily: 'Pretendard'),
      debugShowCheckedModeBanner: false,
      home: const MainPage(),
    );
  }
}
