import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kacee_pos/components/textpass_field_container.dart';
import 'package:kacee_pos/constants.dart';

class RoundedPasswordField extends StatefulWidget  {
  final int maxLength;
  final ValueChanged<String> onChanged;
  const RoundedPasswordField({
    Key? key,
    required this.maxLength,
    required this.onChanged,
    }) : super(key: key);
  @override
  State<RoundedPasswordField> createState() => _PassState();
}

class _PassState extends State<RoundedPasswordField> {
  bool _isHidden = true;
  TextEditingController passController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return TextFieldContainer(
      child: TextFormField(
        validator: (val) {
          if (val == null || val.isEmpty) {
            return 'Please enter some text';
          }
          if (val.trim().length < 8) {
            return 'Password must be at least 8 characters in length';
          }
          return null;
        },
        onChanged: widget.onChanged,
        controller: passController,
        obscureText: _isHidden,
        enableSuggestions: false,
        autocorrect: false,
        cursorColor: kcPrimaryColor,
        maxLength: widget.maxLength,
        decoration: InputDecoration(
          counterText: "",
          hintText: "Password",
          icon: const Icon(
            Icons.lock,
            color: kcPrimaryColor,
          ),
          suffix: InkWell(
            onTap: _togglePassword,
            child: Icon(
              _isHidden ? Icons.visibility : Icons.visibility_off,
              color: kcPrimaryColor,
            ),
          ),
          border: InputBorder.none,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]'))
        ],
      ),
    );
  }

  void _togglePassword() {
    setState(() {
      _isHidden = !_isHidden;
    });
  }
}