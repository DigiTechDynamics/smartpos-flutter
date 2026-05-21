import 'dart:async';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:usb_serial/usb_serial.dart';
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
enum PrinterType { bluetooth, usb }

class PrinterService {
  final Logger _logger = Logger();
  
  BluetoothConnection? _btConnection;
  UsbPort? _usbPort;
  PrinterType? _activePrinterType;
  
  final StreamController<PrintStatus> _statusController = StreamController<PrintStatus>.broadcast();
  Stream<PrintStatus> get printStatusStream => _statusController.stream;

  // ==== BLUETOOTH ====

  Future<List<BluetoothDevice>> discoverBluetoothDevices() async {
    try {
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      _logger.e('Failed to get bonded devices: $e');
      return [];
    }
  }

  Future<void> connectBluetoothDevice(String deviceAddress) async {
    _statusController.add(PrintStatus.connecting);
    try {
      _btConnection = await BluetoothConnection.toAddress(deviceAddress);
      _activePrinterType = PrinterType.bluetooth;
      _statusController.add(PrintStatus.none);
    } catch (e) {
      _logger.e('Connection failed: $e');
      _statusController.add(PrintStatus.error);
    }
  }

  // ==== USB ====

  Future<List<UsbDevice>> discoverUsbDevices() async {
    try {
      return await UsbSerial.listDevices();
    } catch (e) {
      _logger.e('Failed to get USB devices: $e');
      return [];
    }
  }

  Future<void> connectUsbDevice(UsbDevice device) async {
    _statusController.add(PrintStatus.connecting);
    try {
      _usbPort = await device.create();
      if (!await _usbPort!.open()) {
        throw Exception("Failed to open USB port");
      }
      _activePrinterType = PrinterType.usb;
      _statusController.add(PrintStatus.none);
    } catch (e) {
      _logger.e('USB Connection failed: $e');
      _statusController.add(PrintStatus.error);
    }
  }

  // ==== COMMON ====

  Future<void> disconnect() async {
    if (_activePrinterType == PrinterType.bluetooth) {
      await _btConnection?.close();
      _btConnection = null;
    } else if (_activePrinterType == PrinterType.usb) {
      await _usbPort?.close();
      _usbPort = null;
    }
    _activePrinterType = null;
  }

  bool get isConnected {
    if (_activePrinterType == PrinterType.bluetooth) {
      return _btConnection != null && _btConnection!.isConnected;
    } else if (_activePrinterType == PrinterType.usb) {
      return _usbPort != null;
    }
    return false;
  }

  Future<void> _sendBytes(List<int> bytes) async {
    if (_activePrinterType == PrinterType.bluetooth) {
      _btConnection!.output.add(Uint8List.fromList(bytes));
      await _btConnection!.output.allSent;
    } else if (_activePrinterType == PrinterType.usb) {
      await _usbPort!.write(Uint8List.fromList(bytes));
    }
  }

  Future<void> printReceipt(ReceiptData receipt) async {
    if (!isConnected) {
      _statusController.add(PrintStatus.error);
      return;
    }
    
    _statusController.add(PrintStatus.printing);
    try {
      // ESC/POS Initialization
      await _sendBytes([0x1B, 0x40]); 
      
      // Print Header
      await _sendBytes([0x1B, 0x61, 0x01]); // Align Center
      await _sendBytes(receipt.storeName.codeUnits + [0x0A]);
      await _sendBytes(receipt.storeAddress.codeUnits + [0x0A]);
      await _sendBytes(receipt.phone.codeUnits + [0x0A, 0x0A]);
      
      // Reset alignment
      await _sendBytes([0x1B, 0x61, 0x00]); // Align Left
      
      // Print Items
      for (var item in receipt.items) {
        String line = '${item.name} x${item.quantity}  \$${item.price.toStringAsFixed(2)}\n';
        await _sendBytes(line.codeUnits);
      }
      
      await _sendBytes('\n'.codeUnits);
      await _sendBytes('Subtotal: \$${receipt.subtotal.toStringAsFixed(2)}\n'.codeUnits);
      await _sendBytes('Tax: \$${receipt.tax.toStringAsFixed(2)}\n'.codeUnits);
      await _sendBytes('Total: \$${receipt.total.toStringAsFixed(2)}\n'.codeUnits);
      
      await _sendBytes('\n\n\n\n\n'.codeUnits); // Feed paper
      
      _statusController.add(PrintStatus.success);
    } catch (e) {
      _logger.e('Print failed: $e');
      _statusController.add(PrintStatus.error);
    }
  }
}
