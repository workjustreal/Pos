import 'package:flutter/material.dart';
import 'package:kacee_pos/constants.dart';

class DecorationBox extends StatelessWidget {
  final String title;
  final Color color, textColor;

  const DecorationBox({
    Key? key,
    required this.title,
    this.color = kcPrimaryColor,
    this.textColor = Colors.black,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 15,top: 2),width: 400,height: 30,
      decoration: BoxDecoration(
      color: textColor,
        border: Border.all(
        color: color,
        width: 1.5,
      ),
      borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 14)),]
        ,
      ),
    );
  }
}
