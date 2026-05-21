import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as bts;
import 'package:usb_serial/usb_serial.dart' as usb;
import '../../../core/services/service_locator.dart';
import '../../../core/services/printer_service.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> with SingleTickerProviderStateMixin {
  final PrinterService _printerService = sl<PrinterService>();
  late TabController _tabController;
  
  List<bts.BluetoothDevice> _btDevices = [];
  List<usb.UsbDevice> _usbDevices = [];
  bool _isScanning = false;
  
  String? _connectedBtAddress;
  String? _connectedUsbDeviceName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scanDevices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _scanDevices() async {
    setState(() => _isScanning = true);
    try {
      final btDevices = await _printerService.discoverBluetoothDevices();
      final usbDevices = await _printerService.discoverUsbDevices();
      setState(() {
        _btDevices = btDevices;
        _usbDevices = usbDevices;
        _isScanning = false;
      });
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to scan devices: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _connectBt(bts.BluetoothDevice device) async {
    setState(() {
      _connectedBtAddress = null;
      _connectedUsbDeviceName = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting to ${device.name ?? "Bluetooth Printer"}...')),
    );

    try {
      await _printerService.connectBluetoothDevice(device.address);
      if (_printerService.isConnected) {
        setState(() {
          _connectedBtAddress = device.address;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected successfully to ${device.name}!'),
              backgroundColor: Colors.green.shade600,
            ),
          );
        }
      } else {
        throw Exception("Could not establish connection.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _connectUsb(usb.UsbDevice device) async {
    setState(() {
      _connectedBtAddress = null;
      _connectedUsbDeviceName = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting to ${device.deviceName ?? "USB Printer"}...')),
    );

    try {
      await _printerService.connectUsbDevice(device);
      if (_printerService.isConnected) {
        setState(() {
          _connectedUsbDeviceName = device.deviceName;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected successfully to USB Printer!'),
              backgroundColor: Colors.green.shade600,
            ),
          );
        }
      } else {
        throw Exception("Could not establish USB connection.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('USB Connection failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _testPrint() async {
    if (!_printerService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect a printer first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final receipt = ReceiptData(
        storeName: 'SmartPOS Zimbabwe',
        storeAddress: '123 Harare St, Harare',
        phone: '+263 770 000 000',
        items: [
          ReceiptItem(name: 'Premium Coffee Beans', quantity: 2.0, price: 18.50),
          ReceiptItem(name: 'Organic Green Tea', quantity: 1.0, price: 6.20),
        ],
        subtotal: 43.20,
        tax: 3.46,
        discount: 2.00,
        total: 44.66,
        paymentMethod: 'ecocash',
        amountTendered: 45.00,
        change: 0.34,
      );

      await _printerService.printReceipt(receipt);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Test receipt printed!'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test print failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware Settings'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanDevices,
            tooltip: 'Rescan Printers',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(
              icon: Icon(Icons.bluetooth),
              text: 'Bluetooth',
            ),
            Tab(
              icon: Icon(Icons.usb),
              text: 'USB Cable',
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.background,
              theme.colorScheme.background.withOpacity(0.95),
            ],
          ),
        ),
        child: Column(
          children: [
            // Status Banner
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: _printerService.isConnected 
                    ? Colors.green.shade50 
                    : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _printerService.isConnected 
                      ? Colors.green.shade200 
                      : theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _printerService.isConnected ? Icons.check_circle : Icons.print_disabled,
                    color: _printerService.isConnected ? Colors.green.shade700 : Colors.grey.shade600,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _printerService.isConnected ? 'Printer Active' : 'No Printer Connected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _printerService.isConnected ? Colors.green.shade900 : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _printerService.isConnected 
                              ? 'Configured for high-speed receipts.'
                              : 'Select a printer interface below to get started.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _printerService.isConnected ? Colors.green.shade800 : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_printerService.isConnected)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: _testPrint,
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('TEST PRINT'),
                    ),
                ],
              ),
            ),
            
            // Devices Lists Tabs
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Bluetooth Tab
                  _isScanning
                      ? const Center(child: CircularProgressIndicator())
                      : _btDevices.isEmpty
                          ? _buildEmptyState(Icons.bluetooth_searching, 'No Bonded Bluetooth Printers Found', 'Make sure your POS printer is paired with this device in system settings.')
                          : _buildBtDevicesList(),
                          
                  // USB Tab
                  _isScanning
                      ? const Center(child: CircularProgressIndicator())
                      : _usbDevices.isEmpty
                          ? _buildEmptyState(Icons.usb, 'No USB Printing Devices Found', 'Ensure the USB OTG printer cable is plugged in firmly.')
                          : _buildUsbDevicesList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _scanDevices,
              icon: const Icon(Icons.search),
              label: const Text('Scan Again'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBtDevicesList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _btDevices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final device = _btDevices[index];
        final isConnected = _connectedBtAddress == device.address;
        
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isConnected ? Colors.green.shade300 : Colors.grey.shade200,
              width: isConnected ? 2 : 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isConnected ? Colors.green.shade100 : Colors.blue.shade50,
              child: Icon(
                Icons.bluetooth,
                color: isConnected ? Colors.green.shade800 : Colors.blue.shade800,
              ),
            ),
            title: Text(
              device.name ?? 'Thermal Printer',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              device.address,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            trailing: isConnected
                ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
                : OutlinedButton(
                    onPressed: () => _connectBt(device),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('CONNECT'),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildUsbDevicesList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _usbDevices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final device = _usbDevices[index];
        final isConnected = _connectedUsbDeviceName == device.deviceName;
        
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isConnected ? Colors.green.shade300 : Colors.grey.shade200,
              width: isConnected ? 2 : 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isConnected ? Colors.green.shade100 : Colors.orange.shade50,
              child: Icon(
                Icons.usb,
                color: isConnected ? Colors.green.shade800 : Colors.orange.shade800,
              ),
            ),
            title: Text(
              device.deviceName ?? 'USB Printing Device',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Vendor ID: ${device.vid} | Product ID: ${device.pid}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            trailing: isConnected
                ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
                : OutlinedButton(
                    onPressed: () => _connectUsb(device),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('CONNECT'),
                  ),
          ),
        );
      },
    );
  }
}
