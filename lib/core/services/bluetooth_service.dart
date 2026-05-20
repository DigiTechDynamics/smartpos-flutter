import 'dart:async';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:logger/logger.dart';
import 'dart:typed_data';

class ReceiptData {
  final String storeName;
  final String storeAddress;
  final String phone;
  final List<ReceiptItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final String paymentMethod;
  final double amountTendered;
  final double change;

  ReceiptData({
    required this.storeName,
    required this.storeAddress,
    required this.phone,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    required this.amountTendered,
    required this.change,
  });
}

class ReceiptItem {
  final String name;
  final double quantity;
  final double price;
  ReceiptItem({required this.name, required this.quantity, required this.price});
}

enum PrintStatus { none, connecting, printing, success, error }

class BluetoothService {
  final Logger _logger = Logger();
  BluetoothConnection? _connection;
  final StreamController<PrintStatus> _statusController = StreamController<PrintStatus>.broadcast();

  Stream<PrintStatus> get printStatusStream => _statusController.stream;

  Future<List<BluetoothDevice>> discoverDevices() async {
    try {
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      _logger.e('Failed to get bonded devices: \$e');
      return [];
    }
  }

  Future<void> pairDevice(BluetoothDevice device) async {
    // Usually handled by system, but we can request bonding
    // await FlutterBluetoothSerial.instance.bondDeviceAtAddress(device.address);
  }

  Future<void> connectDevice(String deviceAddress) async {
    _statusController.add(PrintStatus.connecting);
    try {
      _connection = await BluetoothConnection.toAddress(deviceAddress);
      _statusController.add(PrintStatus.none);
    } catch (e) {
      _logger.e('Connection failed: \$e');
      _statusController.add(PrintStatus.error);
    }
  }

  Future<void> disconnectDevice() async {
    await _connection?.close();
    _connection = null;
  }

  Future<bool> isConnected() async {
    return _connection != null && _connection!.isConnected;
  }

  Future<void> printReceipt(ReceiptData receipt) async {
    if (!await isConnected()) {
      _statusController.add(PrintStatus.error);
      return;
    }
    
    _statusController.add(PrintStatus.printing);
    try {
      // ESC/POS Initialization
      _connection!.output.add(Uint8List.fromList([0x1B, 0x40])); 
      
      // Print Header
      _connection!.output.add(Uint8List.fromList([0x1B, 0x61, 0x01])); // Align Center
      _connection!.output.add(Uint8List.fromList(receipt.storeName.codeUnits + [0x0A]));
      _connection!.output.add(Uint8List.fromList(receipt.storeAddress.codeUnits + [0x0A]));
      _connection!.output.add(Uint8List.fromList(receipt.phone.codeUnits + [0x0A, 0x0A]));
      
      // Reset alignment
      _connection!.output.add(Uint8List.fromList([0x1B, 0x61, 0x00])); // Align Left
      
      // Print Items
      for (var item in receipt.items) {
        String line = '\${item.name} x\${item.quantity}  \$\${item.price.toStringAsFixed(2)}\\n';
        _connection!.output.add(Uint8List.fromList(line.codeUnits));
      }
      
      _connection!.output.add(Uint8List.fromList('\\n'.codeUnits));
      _connection!.output.add(Uint8List.fromList('Subtotal: \$\${receipt.subtotal.toStringAsFixed(2)}\\n'.codeUnits));
      _connection!.output.add(Uint8List.fromList('Tax: \$\${receipt.tax.toStringAsFixed(2)}\\n'.codeUnits));
      _connection!.output.add(Uint8List.fromList('Total: \$\${receipt.total.toStringAsFixed(2)}\\n'.codeUnits));
      
      _connection!.output.add(Uint8List.fromList('\\n\\n\\n\\n\\n'.codeUnits)); // Feed paper
      
      await _connection!.output.allSent;
      _statusController.add(PrintStatus.success);
    } catch (e) {
      _logger.e('Print failed: \$e');
      _statusController.add(PrintStatus.error);
    }
  }

  Future<void> printTest() async {
    // Implement test print
  }
}
