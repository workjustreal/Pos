import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kacee_pos/components/text_field_container.dart';
import 'package:kacee_pos/constants.dart';

class RoundedNumberField extends StatelessWidget {
  final String hintText;
  final int maxLength;
  final IconData icon;
  final ValueChanged<String> onChanged;
  const RoundedNumberField({
    Key? key,
    required this.hintText,
    required this.maxLength,
    this.icon = Icons.person,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFieldContainer(
      child: TextField(
        onChanged: onChanged,
        cursorColor: kcPrimaryColor,
        maxLength: maxLength,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          counterText: "",
          icon: Icon(
            icon,
            color: kcPrimaryColor,
          ),
          hintText: hintText,
          border: InputBorder.none,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[0-9]'))
        ],
      ),
    );
  }
}
