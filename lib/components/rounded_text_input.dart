import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kacee_pos/components/text_field_container.dart';
import 'package:kacee_pos/constants.dart';

class RoundedInputField extends StatelessWidget {
  final String hintText;
  final IconData icon;
  final ValueChanged<String> onChanged;
  const RoundedInputField({
    Key? key,
    required this.hintText,
    required this.icon,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFieldContainer(
      child: TextField(
        controller: TextEditingController(text: "pos01"),
        readOnly :true,
        onChanged: onChanged,
        cursorColor: kcPrimaryColor,
        decoration: InputDecoration(
          icon: const Icon(
            Icons.account_circle,
            color: kcPrimaryColor,
          ),
          hintText: hintText,
          border: InputBorder.none,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]'))
        ],
      ),
    );
  }
}
