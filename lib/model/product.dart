class Product {
  int id;
  String sku, barcode, name, price, qty, totalprice;

  Product({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.name,
    required this.price,
    required this.qty,
    required this.totalprice,
  });

  // Tolerant of null / numeric-as-string fields so one malformed item
  // can't throw a TypeError and blank the whole cart.
  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: int.tryParse(json['id'].toString()) ?? 0,
        sku: (json['sku'] ?? '').toString(),
        barcode: (json['barcode'] ?? '').toString(),
        name: json['name'].toString(),
        qty: json['qty'].toString(),
        price: json['price'].toString(),
        totalprice: json['total_price'].toString(),
      );

  get last => null;

  get length => null;

  Map<String, dynamic> toJson() => {
        "id": id,
        "sku": sku,
        "barcode": barcode,
        "name": name,
        "price": price,
        "qty": qty,
        "total_price": totalprice,
      };
}
