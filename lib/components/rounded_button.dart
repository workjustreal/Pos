import 'package:flutter/material.dart';
import 'package:kacee_pos/constants.dart';

class RoundedButton extends StatelessWidget {
  final String text;
  final Function press;
  final Color color, textColor;
  // Defaults to 28% of the screen width (the old fixed size).
  final double? width;
  const RoundedButton({
    Key? key,
    required this.text,
    required this.press,
    this.color = kcPrimaryColor,
    this.textColor = Colors.white,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: width ?? size.width * 0.28,
      height: 58,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(kcRadiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(kcRadiusMd),
          onTap: () => press(),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontFamily: 'Kanit',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
