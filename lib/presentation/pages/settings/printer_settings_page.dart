import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as bts;
import '../../../core/services/service_locator.dart';
import '../../../core/services/bluetooth_service.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final BluetoothService _bluetoothService = sl<BluetoothService>();
  List<bts.BluetoothDevice> _devices = [];
  bool _isScanning = false;
  String? _connectedDeviceAddress;

  @override
  void initState() {
    super.initState();
    _scanDevices();
  }

  Future<void> _scanDevices() async {
    setState(() => _isScanning = true);
    try {
      final devices = await _bluetoothService.discoverDevices();
      setState(() {
        _devices = devices;
        _isScanning = false;
      });
    } catch (e) {
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to scan devices: $e')),
      );
    }
  }

  Future<void> _connect(bts.BluetoothDevice device) async {
    setState(() => _connectedDeviceAddress = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting to ${device.name ?? "Device"}...')),
    );

    try {
      await _bluetoothService.connectDevice(device.address);
      if (await _bluetoothService.isConnected()) {
        setState(() => _connectedDeviceAddress = device.address);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected successfully to ${device.name}!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _testPrint() async {
    if (_connectedDeviceAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect a printer first'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      await _bluetoothService.printTest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test receipt printed!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test print failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanDevices,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bluetooth Printer Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _testPrint,
                  icon: const Icon(Icons.print),
                  label: const Text('TEST PRINT'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isScanning
                ? const Center(child: CircularProgressIndicator())
                : _devices.isEmpty
                    ? const Center(
                        child: Text('No bonded Bluetooth devices found'),
                      )
                    : ListView.separated(
                        itemCount: _devices.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final isConnected = _connectedDeviceAddress == device.address;
                          return ListTile(
                            leading: const Icon(Icons.print_outlined, color: Colors.blue),
                            title: Text(device.name ?? 'Unknown Device'),
                            subtitle: Text(device.address),
                            trailing: isConnected
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : ElevatedButton(
                                    onPressed: () => _connect(device),
                                    child: const Text('CONNECT'),
                                  ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
