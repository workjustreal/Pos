import 'package:flutter/material.dart';
import 'package:kacee_pos/constants.dart';
import 'package:kacee_pos/model/product.dart';

class TableContainer extends StatefulWidget {
  final List? data;
  const TableContainer({
    Key? key,
    required this.data,
  }) : super(key: key);
  @override
  State<TableContainer> createState() => _TableState();
}

class _TableState extends State<TableContainer> {
  List<Product>? productList;
  @override
  void initState() {
    productList = null;
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProduct());
  }

  void _loadProduct() {
    setState(() {
      productList = widget.data
          ?.map<Product>(
              (m) => Product.fromJson(Map<String, String>.from(m)))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: [
        DataColumn(
            label: Container(
          alignment: Alignment.center,
          width: 100,
          child: const Text('รหัสสินค้า',
              style: tableH, textAlign: TextAlign.center),
        )),
        DataColumn(
            label: Container(
          alignment: Alignment.center,
          width: 100,
          child: const Text('ชื่อสินค้า',
              style: tableH, textAlign: TextAlign.center),
        )),
        DataColumn(
            label: Container(
          alignment: Alignment.center,
          width: 100,
          child: const Text('ราคา', style: tableH, textAlign: TextAlign.center),
        )),
        DataColumn(
            label: Container(
          alignment: Alignment.center,
          width: 100,
          child:
              const Text('จำนวน', style: tableH, textAlign: TextAlign.center),
        )),
        DataColumn(
            label: Container(
          alignment: Alignment.center,
          width: 100,
          child: const Text('รวม', style: tableH, textAlign: TextAlign.center),
        )),
      ],
      rows: productList!
          .map(
            (pro) => DataRow(cells: [
              DataCell(
                Text(pro.sku.toString()),
              ),
              DataCell(
                Text(pro.name),
              ),
              DataCell(
                Text(pro.price),
              ),
              DataCell(
                Text(pro.name),
              ),
              DataCell(
                Text(pro.price),
              ),
            ]),
          )
          .toList(),
    );
  }
}
