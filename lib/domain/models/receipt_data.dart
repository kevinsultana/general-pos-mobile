class ReceiptHeader {
  final String storeName;
  final String? storeAddress;
  final String? storePhone;
  final String? headerMessage;

  const ReceiptHeader({
    required this.storeName,
    this.storeAddress,
    this.storePhone,
    this.headerMessage,
  });
}

class ReceiptItem {
  final String productName;
  final String? variantName;
  final double quantity;
  final int unitPrice;
  final int subtotal;
  final int discountAmount;
  final int finalPrice;
  final String? note;

  const ReceiptItem({
    required this.productName,
    this.variantName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.discountAmount = 0,
    required this.finalPrice,
    this.note,
  });

  String get displayName =>
      variantName != null && variantName!.isNotEmpty
          ? '$productName ($variantName)'
          : productName;
}

class ReceiptPayment {
  final String method;
  final int amount;

  const ReceiptPayment({
    required this.method,
    required this.amount,
  });
}

class ReceiptData {
  final String transactionId;
  final String invoiceNumber;
  final DateTime transactionDate;
  final String? cashierName;
  final String? customerName;
  final ReceiptHeader storeHeader;
  final List<ReceiptItem> items;
  final int subtotal;
  final int orderDiscount;
  final int cashRounding;
  final int grandTotal;
  final List<ReceiptPayment> payments;
  final int amountPaid;
  final int changeAmount;
  final String? footerMessage;

  const ReceiptData({
    required this.transactionId,
    required this.invoiceNumber,
    required this.transactionDate,
    this.cashierName,
    this.customerName,
    required this.storeHeader,
    required this.items,
    required this.subtotal,
    this.orderDiscount = 0,
    this.cashRounding = 0,
    required this.grandTotal,
    required this.payments,
    required this.amountPaid,
    this.changeAmount = 0,
    this.footerMessage,
  });
}

class KitchenTicketData {
  final String orderId;
  final String invoiceNumber;
  final DateTime orderTime;
  final String? tableOrCustomer;
  final String? cashierName;
  final List<ReceiptItem> items;
  final String? orderNote;

  const KitchenTicketData({
    required this.orderId,
    required this.invoiceNumber,
    required this.orderTime,
    this.tableOrCustomer,
    this.cashierName,
    required this.items,
    this.orderNote,
  });
}
