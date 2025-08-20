import 'package:flutter/material.dart';
import 'package:brain_up/theme/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StoryDetailPage extends StatefulWidget {
  const StoryDetailPage({super.key, required this.title});

  final String title;

  @override
  State<StoryDetailPage> createState() => _StoryDetailPageState();
}

class _StoryDetailPageState extends State<StoryDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          widget.title,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20.sp),
        ),
      ),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
      ),
    );
  }
}
