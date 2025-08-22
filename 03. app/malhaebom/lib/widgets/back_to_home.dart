import 'package:flutter/material.dart';
import 'package:malhaebom/screens/main/home_page.dart';

class BackToHome extends StatelessWidget {
  final Widget child;
  const BackToHome({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
        return false;
      },
      child: child,
    );
  }
}
