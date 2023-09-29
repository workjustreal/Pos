import 'package:flutter/material.dart';

class CalculatorBox extends StatefulWidget {
  const CalculatorBox({Key? key}) : super(key: key);
  @override
  State<CalculatorBox> createState() => _CalculatorBaseState();
}

class _CalculatorBaseState extends State<CalculatorBox> {
  String input = "";
  String output = "";
  var style = const TextStyle(fontSize: 15,color: Color(0xffffffff),fontWeight: FontWeight.normal);

  final List<String> calButtonsList = [
    '7',
    '8',
    '9',
    '4',
    '5',
    '6',
    '1',
    '2',
    '3',
    'C',
    '0',
    '.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            // Input display
            Align(
              alignment: Alignment.topRight,
              child: Text(
                input,
                style: style.copyWith(
                    color: const Color(0xff000000), fontSize: 20),
              ),
            ),
            // Output Display
            Align(
              alignment: Alignment.topRight,
              child: Text(
                output,
                style: style.copyWith(
                    color: const Color(0xff000000),
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Expanded(
          flex: 10,
          child: GridView.builder(
              itemCount: calButtonsList.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemBuilder: (BuildContext context, int index) {
                if (index == 9) {
                  return CalButton(
                      onTapped: () {
                        setState(() {
                          input = '';
                          output = '0';
                        });
                      },
                      value: calButtonsList[index],
                      color: const Color(0xff0099CC),
                      btnTextStyle: style);
                }
                else {
                  return CalButton(
                    onTapped: () {
                      setState(() {
                        input += calButtonsList[index];
                      });
                    },
                    value: calButtonsList[index],
                    color: Colors.grey[200],
                    btnTextStyle: style.copyWith(
                      color: const Color(0xff000000),
                    ),
                  );
                }
              }),
        ),
      ],
    );
  }

  displayBtn(String value, int index, Color color) {
    TextStyle style = const TextStyle(fontSize: 16);

    return CalButton(
      onTapped: () {
        setState(() {
          input += calButtonsList[index];
        });
      },
      value: value,
      color: color,
      btnTextStyle: style,
    );
  }
}

// Buttons
class CalButton extends StatelessWidget {
  final Color? color;
  final String? value;
  final TextStyle? btnTextStyle;
  final VoidCallback? onTapped;

  const CalButton(
      {Key? key,
        required this.color,
        required this.value,
        required this.btnTextStyle,
        this.onTapped})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTapped!,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(50)),
            color: color,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                offset: const Offset(0, 1), // changes position of shadow
              ),
            ],
          ),
          child: Center(
            child: Text(
              value!,
              textAlign: TextAlign.center,
              style: btnTextStyle,
            ),
          ),
        ),
      ),
    );
  }
}