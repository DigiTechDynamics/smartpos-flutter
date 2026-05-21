import 'package:flutter/material.dart';
import '../../../core/services/service_locator.dart';
import '../../../domain/repositories/settings_repository.dart';

class StoreSettingsPage extends StatefulWidget {
  const StoreSettingsPage({super.key});

  @override
  State<StoreSettingsPage> createState() => _StoreSettingsPageState();
}

class _StoreSettingsPageState extends State<StoreSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'SmartPOS Zimbabwe');
  final _addressController = TextEditingController(text: '123 Harare St, Harare');
  final _phoneController = TextEditingController(text: '+263770000000');
  final _taxRateController = TextEditingController(text: '15.0');
  final _footerController = TextEditingController(text: 'Thank you for shopping with us!');
  String _selectedCurrency = 'USD';
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final repo = sl<SettingsRepository>();
    final settings = await repo.getAllSettings();
    setState(() {
      if (settings.containsKey('store_name')) _nameController.text = settings['store_name']!;
      if (settings.containsKey('store_address')) _addressController.text = settings['store_address']!;
      if (settings.containsKey('store_phone')) _phoneController.text = settings['store_phone']!;
      if (settings.containsKey('tax_rate')) _taxRateController.text = settings['tax_rate']!;
      if (settings.containsKey('receipt_footer')) _footerController.text = settings['receipt_footer']!;
      if (settings.containsKey('currency')) _selectedCurrency = settings['currency']!;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final repo = sl<SettingsRepository>();
      await repo.saveSetting('store_name', _nameController.text);
      await repo.saveSetting('store_address', _addressController.text);
      await repo.saveSetting('store_phone', _phoneController.text);
      await repo.saveSetting('tax_rate', _taxRateController.text);
      await repo.saveSetting('receipt_footer', _footerController.text);
      await repo.saveSetting('currency', _selectedCurrency);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store configuration updated!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Store Name',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Store Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCurrency,
                decoration: const InputDecoration(
                  labelText: 'Default Currency',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'USD', child: Text('USD - US Dollar')),
                  DropdownMenuItem(value: 'ZiG', child: Text('ZiG - Zimbabwe Gold')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCurrency = val);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _taxRateController,
                decoration: const InputDecoration(
                  labelText: 'VAT / Tax Rate (%)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Must be a number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _footerController,
                decoration: const InputDecoration(
                  labelText: 'Receipt Footer Message',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('SAVE SETTINGS',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
