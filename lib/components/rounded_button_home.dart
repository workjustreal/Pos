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
      height: 70,
      width: 80,
      padding: const EdgeInsets.only(left:10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: newElevatedButton(),
      ),
    );
  }

  Widget newElevatedButton() {
    return  Material(
      color: kcPrimaryColor,
      child: Center(
        child: Ink(
          width: 70,
          height: 70,
          child: IconButton(
            icon: const Icon(Icons.shopping_cart_outlined,size: 35,),
            color: Colors.white,
            onPressed: () => press(),
          ),
        ),
      ),
    );
  }
}