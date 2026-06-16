import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  runApp(const JanboyarApp());
}

class JanboyarApp extends StatelessWidget {
  const JanboyarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'جانبویار',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, String>> items = [];
  List<Map<String, String>> filtered = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('items') ?? [];
    items = data.map((e) {
      final parts = e.split('|');
      return {'barcode': parts[0], 'date': parts[1]};
    }).toList();
    filtered = List.from(items);
    if (mounted) setState(() {});
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = items.map((e) => '${e['barcode']}|${e['date']}').toList();
    await prefs.setStringList('items', data);
  }

  void addItemWithDate(String barcode, String date) {
    setState(() {
      items.add({'barcode': barcode, 'date': date});
      filtered = List.from(items);
    });
    saveData();
  }

  void search(String value) {
    setState(() {
      filtered = items.where((e) => e['barcode']!.toLowerCase().contains(value.toLowerCase())).toList();
    });
  }

  void deleteItem(int index) {
    setState(() {
      items.remove(filtered[index]);
      filtered = List.from(items);
    });
    saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جانبویار'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'جستجوی بارکد',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: search,
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'هیچ کالایی وجود ندارد',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'برای افزودن کالا، دکمه اسکن را بزنید',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.qr_code, color: Colors.blue.shade700),
                          ),
                          title: Text(
                            filtered[index]['barcode']!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('تاریخ: ${filtered[index]['date']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => deleteItem(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScannerPage()),
          );
          if (result != null && mounted) {
            addItemWithDate(result['barcode'] as String, result['date'] as String);
          }
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('اسکن بارکد'),
      ),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController controller = MobileScannerController(
    formats: [BarcodeFormat.ean13], // فقط بارکد ۱۳ رقمی کالاها
  );
  bool _isScanning = true;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اسکن بارکد'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, state, child) {
                final isOn = state.torchState == TorchState.on;
                return Icon(isOn ? Icons.flash_on : Icons.flash_off);
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) async {
              if (!_isScanning) return;
              try {
                final barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;
                final rawValue = barcodes.first.rawValue;
                if (rawValue == null || rawValue.isEmpty) return;

                // بررسی اینکه دقیقاً ۱۳ رقمی باشه (اختیاری)
                if (rawValue.length != 13) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('بارکد نامعتبر! فقط بارکد ۱۳ رقمی کالاها قابل قبول است.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                  return;
                }

                _isScanning = false;
                final hasVibrator = await Vibration.hasVibrator();
                if (hasVibrator == true) {
                  await Vibration.vibrate(duration: 200);
                }

                if (!mounted) return;
                final selectedDate = await showDialog<Jalali>(
                  context: context,
                  builder: (context) => const DatePickerDialog(),
                );

                if (!mounted) return;
                if (selectedDate != null) {
                  final dateString =
                      '${selectedDate.year}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.day.toString().padLeft(2, '0')}';
                  if (mounted) {
                    Navigator.pop(context, {'barcode': rawValue, 'date': dateString});
                  }
                } else {
                  if (mounted) Navigator.pop(context);
                }
              } catch (e) {
                print('Scanner error: $e');
                if (mounted) {
                  setState(() => _isScanning = true);
                }
              }
            },
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(60),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'بارکد ۱۳ رقمی کالا را اسکن کنید',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DatePickerDialog extends StatefulWidget {
  const DatePickerDialog({super.key});

  @override
  State<DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<DatePickerDialog> {
  late Jalali selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = Jalali.now();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('انتخاب تاریخ'),
      content: SizedBox(
        width: 300,
        height: 350,
        child: Column(
          children: [
            const Text('تاریخ انقضا یا تولید را انتخاب کنید:'),
            const SizedBox(height: 16),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: CalendarDatePicker(
                  initialDate: selectedDate.toDateTime(),
                  firstDate: DateTime(1350, 1, 1),
                  lastDate: DateTime(1450, 12, 31),
                  onDateChanged: (date) {
                    setState(() {
                      selectedDate = Jalali.fromDateTime(date);
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, selectedDate),
          child: const Text('تایید'),
        ),
      ],
    );
  }
}