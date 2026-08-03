// Conditional import for web download
import 'package:daily_mart/utils/csv_exporter_web.dart' if (dart.library.io) 'package:daily_mart/utils/csv_exporter_mobile.dart';

class CsvExporter {
  static void exportOrders(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) return;

    final StringBuffer csvBuf = StringBuffer();
    // 15 Column CSV Headers with UTF-8 BOM for Excel
    csvBuf.write('\uFEFF');
    csvBuf.writeln('S.N.,Date,Customer Name,Order No.,Order Send Date Time,Amount (INR),Seller Name,Seller Location,Pickup Date Time,Delivered Date Time,Order Status,Delivery Boy Name,Status Date Time,Payment Status,Payment Mode');

    for (int i = 0; i < orders.length; i++) {
      final ord = orders[i];
      final sn = (i + 1).toString();
      final date = _csvEscape(ord['date'] ?? '');
      final custName = _csvEscape(ord['customer_name'] ?? '');
      final orderNo = _csvEscape(ord['order_no'] ?? '');
      final orderSendTime = _csvEscape(ord['order_send_time'] ?? '');
      final amount = (double.tryParse(ord['amount']?.toString() ?? '') ?? 0.0).toStringAsFixed(2);
      final sellerName = _csvEscape(ord['seller_name'] ?? '');
      final sellerLoc = _csvEscape(ord['seller_location'] ?? '');
      final pickupTime = _csvEscape(ord['pickup_time'] ?? '');
      final deliveredTime = _csvEscape(ord['delivered_time'] ?? '');
      final orderStatus = _csvEscape(ord['order_status'] ?? '');
      final deliveryBoy = _csvEscape(ord['delivery_boy_name'] ?? '');
      final statusTime = _csvEscape(ord['status_time'] ?? '');
      final payStatus = _csvEscape(ord['payment_status_display'] ?? 'Unpaid');
      final payMode = _csvEscape(ord['payment_mode_display'] ?? '-');

      csvBuf.writeln('$sn,$date,$custName,$orderNo,$orderSendTime,$amount,$sellerName,$sellerLoc,$pickupTime,$deliveredTime,$orderStatus,$deliveryBoy,$statusTime,$payStatus,$payMode');
    }

    final now = DateTime.now();
    final fileName = 'DailyMart_Orders_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';

    downloadCsvFile(csvBuf.toString(), fileName);
  }

  static String _csvEscape(dynamic value) {
    String str = (value ?? '').toString().replaceAll('"', '""');
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"$str"';
    }
    return str;
  }
}
