import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../nes/emulator.dart';
import 'emulator_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NesEmulator emulator = NesEmulator();
  bool isLoading = false;
  String? errorMessage;

  Future<void> pickRom() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['nes']);
      if (result != null && result.files.single.path != null) {
        final bytes = await File(result.files.single.path!).readAsBytes();
        final success = await emulator.loadRom(Uint8List.fromList(bytes));
        if (success && mounted) {
          setState(() => isLoading = false);
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => EmulatorScreen(emulator: emulator, romName: result.files.single.name)));
        } else {
          setState(() { errorMessage = 'Failed to load ROM'; isLoading = false; });
        }
      } else { setState(() => isLoading = false); }
    } catch (e) {
      setState(() { errorMessage = 'Error: $e'; isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Colors.red.shade900, Colors.red.shade700, Colors.orange.shade800])),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 120, height: 120,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]),
                    child: const Icon(Icons.sports_esports, size: 60, color: Colors.red)),
                  const SizedBox(height: 32),
                  const Text('NES Emulator', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Text('Flutter Edition', style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.8), letterSpacing: 4)),
                  const SizedBox(height: 64),
                  if (isLoading)
                    const CircularProgressIndicator(color: Colors.white)
                  else
                    ElevatedButton.icon(
                      onPressed: pickRom,
                      icon: const Icon(Icons.folder_open, size: 28),
                      label: const Text('Load ROM', style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, foregroundColor: Colors.red.shade900,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8)),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 24),
                    Container(padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: Text(errorMessage!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center)),
                  ],
                  const SizedBox(height: 48),
                  Container(padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2))),
                    child: Column(children: [
                      _buildInfoRow(Icons.memory, 'CPU: 6502 @ 1.79 MHz'),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.graphic_eq, 'PPU: 256x240 @ 60 FPS'),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.volume_up, 'APU: 5 Audio Channels'),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.storage, 'Mappers: 0, 1, 2, 3, 7'),
                    ])),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16)),
      ]);
}