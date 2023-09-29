import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:kacee_pos/model/product.dart';

class MyHomePageProvider extends ChangeNotifier {
  late Product data;

  Future getData(context) async {
    var response = await DefaultAssetBundle.of(context)
        .loadString('assets/raw/mJson.json');
    var mJson = json.decode(response);
    data = Product.fromJson(mJson);
    notifyListeners();
  }
}