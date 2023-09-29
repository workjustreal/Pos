import 'package:flutter/material.dart';

class RoundedButtonLogout extends StatelessWidget {
  final Function press;
  const RoundedButtonLogout({
    Key? key,
    required this.press,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      width: 80,
      padding: const EdgeInsets.only(left:10),
      child: ClipRRect(
        child: newElevatedButton(),
      ),
    );
  }

  Widget newElevatedButton() {
    return IconButton(
        icon: const Icon(Icons.logout_outlined,size: 40,),
        color: Colors.white,
        onPressed: () => press(),
      );
  }
}