import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;
  runApp(JanboyarApp(camera: firstCamera));
}

class JanboyarApp extends StatelessWidget {
  final CameraDescription camera;
  const JanboyarApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'جانبویار',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: HomePage(camera: camera),
    );
  }
}

class HomePage extends StatefulWidget {
  final CameraDescription camera;
  const HomePage({super.key, required this.camera});

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
            MaterialPageRoute(
              builder: (_) => ScannerPage(camera: widget.camera),
            ),
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
  final CameraDescription camera;
  const ScannerPage({super.key, required this.camera});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  late CameraController _controller;
  bool _isScanning = true;
  bool _isInitialized = false;
  final BarcodeScanner _barcodeScanner = GoogleMlKit.vision.barcodeScanner();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _controller = CameraController(widget.camera, ResolutionPreset.medium);
      await _controller.initialize();
      if (!mounted) return;
      setState(() => _isInitialized = true);
      _startScanning();
    } catch (e) {
      print('Camera init error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطا در دسترسی به دوربین')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _startScanning() {
    if (!_isInitialized) return;
    
    _controller.startImageStream((CameraImage image) async {
      if (!_isScanning) return;
      
      try {
        int totalBytes = 0;
        for (final Plane plane in image.planes) {
          totalBytes += plane.bytes.length;
        }
        
        final Uint8List allBytes = Uint8List(totalBytes);
        int offset = 0;
        for (final Plane plane in image.planes) {
          allBytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
          offset += plane.bytes.length;
        }
        
        final InputImage inputImage = InputImage.fromBytes(
          bytes: allBytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );
        
        final barcodes = await _barcodeScanner.processImage(inputImage);
        
        if (barcodes.isNotEmpty) {
          final rawValue = barcodes.first.rawValue;
          if (rawValue != null && rawValue.isNotEmpty) {
            _isScanning = false;
            _controller.stopImageStream();

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
              _isScanning = true;
              _controller.startImageStream((CameraImage image) {});
            }
          }
        }
      } catch (e) {
        print('Scan error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطا در اسکن، دوباره تلاش کنید')),
          );
          _isScanning = true;
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اسکن بارکد'),
        centerTitle: true,
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                CameraPreview(_controller),
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
                        'بارکد کالا را اسکن کنید',
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