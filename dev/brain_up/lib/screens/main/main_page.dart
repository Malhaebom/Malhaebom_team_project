import 'package:brain_up/screens/main/autobiography_page.dart';
import 'package:brain_up/screens/main/home_page.dart';
import 'package:brain_up/screens/main/info_page.dart';
import 'package:brain_up/screens/main/my_page.dart';
import 'package:flutter/material.dart';
import 'package:brain_up/theme/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _pages = [
    HomePage(),
    InfoPage(),
    AutobiographyPage(),
    MyPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            SizedBox(width: 10),
            Image.asset(
              "assets/logo/logo_brainup.png",
              height: kToolbarHeight * 0.5,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.blue,
        unselectedItemColor: AppColors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 23.w),
            label: "홈",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info, size: 23.w),
            label: "소개",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book, size: 23.w),
            label: "자서전",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, size: 23.w),
            label: "마이",
          ),
        ],
      ),

      body: _pages[_selectedIndex],
    );
  }
}
