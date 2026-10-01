import 'package:flutter/material.dart';
import 'package:kacee_pos/constants.dart';

class RoundedButtonHome extends StatelessWidget {
  final Function press;
  const RoundedButtonHome({
    Key? key,
    required this.press,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      margin: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: kcBrandGradient,
        boxShadow: kcShadowGlow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => press(),
          splashColor: Colors.white24,
          child: const Center(
            child: Icon(
              Icons.shopping_bag_rounded,
              size: 30,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
