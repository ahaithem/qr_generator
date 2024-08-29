import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Generator',
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _urlController = TextEditingController();
  String _qrData = "";
  bool _showQrCode = false;
  final GlobalKey _globalKey = GlobalKey();
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _controller;
  String _scannedResult = ""; // Variable to store the scanned result

  @override
  void initState() {
    super.initState();
    _urlController.addListener(() {
      setState(() {
        if (_urlController.text.isEmpty) {
          _showQrCode = false;
        }
      });
    });
  }

  void generateCode() {
    setState(() {
      _qrData = _urlController.text;
      _showQrCode = _qrData.isNotEmpty;
    });
  }

  Future<void> saveQrCode() async {
    try {
      var status = await Permission.storage.request();
      if (status.isGranted) {
        final qrValidationResult = QrValidator.validate(
          data: _qrData,
          version: QrVersions.auto,
          errorCorrectionLevel: QrErrorCorrectLevel.Q,
        );

        if (qrValidationResult.status == QrValidationStatus.valid) {
          final qrCode = qrValidationResult.qrCode!;
          final painter = QrPainter.withQr(
            qr: qrCode,
            color: const Color(0xFF000000),
            emptyColor: const Color(0xFFFFFFFF),
            gapless: true,
          );

          final picData = await painter.toImageData(200);
          final buffer = picData!.buffer.asUint8List();

          final directory = await getTemporaryDirectory();
          final path = '${directory.path}/qr_code.png';
          final file = File(path);
          await file.writeAsBytes(buffer);

          final result = await ImageGallerySaver.saveFile(file.path);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('QR Code saved to Gallery!')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Storage permission is required to save the image.')),
        );
      }
    } catch (e) {
      print('Error saving QR code: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save QR Code.')),
      );
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      _controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        _scannedResult = scanData.code ?? ""; // Store the scanned result
      });
      _controller
          ?.dispose(); // Dispose of the controller once scanning is complete
      Navigator.of(context).pop(); // Close the scanner after scanning
    });
  }

  void _scanQrCode() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Scan QR Code')),
          body: QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.blue,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 300,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Generator'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _showQrCode ? saveQrCode : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        // Added SingleChildScrollView
        child: Center(
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Enter URL',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: generateCode,
                  child: Text('Generate QR Code'),
                ),
                ElevatedButton(
                  onPressed: _scanQrCode,
                  child: Text('Scan QR Code'),
                ),
                ElevatedButton(
                  onPressed: () {},
                  child: Text('Scan an existing QR Code'),
                ),
                const SizedBox(height: 20),
                if (_scannedResult.isNotEmpty)
                  Text(
                    'Scanned Result: $_scannedResult',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 20),
                if (_showQrCode)
                  RepaintBoundary(
                    key: _globalKey,
                    child: QrImageView(
                      data: _qrData,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
