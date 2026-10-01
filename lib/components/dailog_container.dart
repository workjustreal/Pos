import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kacee_pos/constants.dart';

class AlertDailogBox extends StatelessWidget {
  final String title;
  final String content;
  final Color color, textColor;

  const AlertDailogBox({
    Key? key,
    required this.title,
    required this.content,
    this.color = kcPrimaryColor,
    this.textColor = kcTextPrimary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kcRadiusLg)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kcSurfaceColorHi, kcSurfaceColor],
            ),
            borderRadius: BorderRadius.circular(kcRadiusLg),
            border: Border.all(color: kcStrokeColor, width: 1),
            boxShadow: kcShadowSoft,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: const BoxDecoration(
                  gradient: kcBrandGradient,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(kcRadiusLg),
                    topRight: Radius.circular(kcRadiusLg),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Kanit',
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Text(
                  content,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontFamily: 'Kanit',
                    height: 1.5,
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(kcRadiusLg),
                  bottomRight: Radius.circular(kcRadiusLg),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: kcStrokeColor, width: 1),
                    ),
                  ),
                  child: const Text(
                    "ตกลง",
                    style: TextStyle(
                        color: kcAccentOrange,
                        fontSize: 16,
                        fontFamily: 'Kanit',
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
