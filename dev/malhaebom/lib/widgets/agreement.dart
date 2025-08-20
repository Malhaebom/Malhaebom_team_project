import 'package:flutter/material.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Agreement extends StatefulWidget {
  const Agreement({
    super.key,
    required this.agreementContent,
    required this.isAgree,
    required this.onChanged,
  });

  final Map<String, dynamic> agreementContent;
  final bool isAgree;
  final ValueChanged<bool?> onChanged;

  @override
  State<Agreement> createState() => _AgreementState();
}

class _AgreementState extends State<Agreement> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              widget.agreementContent["title"],
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),

            SizedBox(width: 10.w),

            Text(
              widget.agreementContent["required"] ? "*필수" : "선택",
              style: TextStyle(
                color:
                    widget.agreementContent["required"]
                        ? AppColors.red
                        : AppColors.blue,
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),

        Row(
          children: [
            Checkbox(
              value: widget.isAgree,
              onChanged: widget.onChanged,
              activeColor: AppColors.blue,
              checkColor: Colors.white,
            ),
            SizedBox(width: 5.w),
            Expanded(
              child: Text(
                "내용을 모두 확인했으며, 이에 동의합니다.",
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.sp),
              ),
            ),
          ],
        ),

        Container(
          width: double.infinity,
          height: 300.h,

          decoration: BoxDecoration(
            color: const Color.fromARGB(30, 158, 158, 158),
            borderRadius: BorderRadius.circular(5),
          ),

          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(widget.agreementContent["content"]),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 30.h),
      ],
    );
  }
}
