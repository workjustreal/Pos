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

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'],
        sku: json['sku'],
        barcode: json['barcode'],
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
