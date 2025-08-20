import 'package:flutter/material.dart';
import 'package:brain_up/theme/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomTextfield extends StatefulWidget {
  const CustomTextfield({
    super.key,
    required this.type,
    required this.hintText,
    required this.controller,
  });

  final String type;
  final String hintText;
  final TextEditingController controller;

  @override
  State<CustomTextfield> createState() => _CustomTextfieldState();
}

class _CustomTextfieldState extends State<CustomTextfield> {
  final Map<String, dynamic> iconMap = {
    "id": Icons.phone,
    "password": Icons.password,
  };

  final Map<String, dynamic> keyboardTypeMap = {
    "id": TextInputType.number,
    "password": TextInputType.text,
    "birth": TextInputType.number,
    "phone": TextInputType.number,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60.h,
      child: TextField(
        enabled: widget.type != "brith",
        controller: widget.controller,
        keyboardType: keyboardTypeMap[widget.type],
        obscureText: widget.type.contains("password"),
        style: TextStyle(fontSize: 15.sp),
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon:
              widget.type == "id" || widget.type == "password"
                  ? Icon(iconMap[widget.type], size: 18.w)
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: AppColors.grey, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: AppColors.blue, width: 2),
          ),
        ),
      ),
    );
  }
}
