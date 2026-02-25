import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:typed_data';
import '../nes/emulator.dart';

class EmulatorScreen extends StatefulWidget {
  final NesEmulator emulator;
  final String romName;
  const EmulatorScreen({super.key, required this.emulator, required this.romName});
  @override
  State<EmulatorScreen> createState() => _EmulatorScreenState();
}

class _EmulatorScreenState extends State<EmulatorScreen> {
  Timer? gameLoop;
  Uint32List? frameBuffer;
  bool showControls = true;
  final Map<int, bool> pressedButtons = {};

  @override
  void initState() {
    super.initState();
    widget.emulator.onFrameComplete = _onFrameComplete;
    widget.emulator.start();
    _startGameLoop();
    _hideSystemUI();
  }

  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  void _startGameLoop() {
    gameLoop = Timer.periodic(const Duration(milliseconds: 16), (_) => widget.emulator.step());
  }

  void _onFrameComplete() {
    if (mounted) setState(() => frameBuffer = widget.emulator.getFrameBufferRGB());
  }

  @override
  void dispose() {
    gameLoop?.cancel();
    widget.emulator.stop();
    super.dispose();
  }

  void _setButton(int button, bool pressed) {
    setState(() => pressedButtons[button] = pressed);
    widget.emulator.setButton(button, pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => showControls = !showControls),
        onDoubleTap: () => setState(() {}),
        child: Stack(children: [
          Center(
            child: AspectRatio(aspectRatio: 256 / 240,
              child: frameBuffer != null
                ? CustomPaint(painter: FrameBufferPainter(frameBuffer!), size: Size.infinite)
                : const Center(child: CircularProgressIndicator(color: Colors.red)))),
          Positioned(top: 0, left: 0, right: 0,
            child: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.8), Colors.transparent])),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Text(widget.romName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.pause, color: Colors.white),
                  onPressed: () => setState(() {
                    if (widget.emulator.paused) widget.emulator.resume(); else widget.emulator.pause();
                  })),
              ]))),
          if (showControls) ...[
            Positioned(left: 20, bottom: 40, child: _buildDPad()),
            Positioned(right: 20, bottom: 40, child: _buildActionButtons()),
            Positioned(left: 0, right: 0, bottom: 20,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _buildSmallButton(label: 'SELECT', onPressed: (p) => _setButton(NesController.BUTTON_SELECT, p)),
                const SizedBox(width: 40),
                _buildSmallButton(label: 'START', onPressed: (p) => _setButton(NesController.BUTTON_START, p)),
              ])),
          ],
          if (widget.emulator.paused)
            Container(color: Colors.black.withOpacity(0.7),
              child: const Center(child: Text('PAUSED', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 8)))),
        ]),
      ),
    );
  }

  Widget _buildDPad() {
    const size = 50.0, color = Colors.white38, pressed = Colors.red;
    return SizedBox(width: size * 3, height: size * 3, child: Stack(children: [
      Positioned(left: size, top: 0, child: _dpadBtn(Icons.arrow_drop_up, size, color, pressed, (p) => _setButton(NesController.BUTTON_UP, p))),
      Positioned(left: size, bottom: 0, child: _dpadBtn(Icons.arrow_drop_down, size, color, pressed, (p) => _setButton(NesController.BUTTON_DOWN, p))),
      Positioned(top: size, left: 0, child: _dpadBtn(Icons.arrow_left, size, color, pressed, (p) => _setButton(NesController.BUTTON_LEFT, p))),
      Positioned(top: size, right: 0, child: _dpadBtn(Icons.arrow_right, size, color, pressed, (p) => _setButton(NesController.BUTTON_RIGHT, p))),
      Positioned(left: size, top: size, child: Container(width: size, height: size, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)))),
    ]));
  }

  Widget _dpadBtn(IconData icon, double size, Color color, Color pressed, Function(bool) fn) =>
      GestureDetector(onPanDown: (_) => fn(true), onPanEnd: (_) => fn(false), onPanCancel: () => fn(false),
        child: Container(width: size, height: size, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.white, size: 36)));

  Widget _buildActionButtons() {
    const size = 70.0;
    return SizedBox(width: size * 2.5, height: size * 1.5, child: Stack(children: [
      Positioned(left: 0, top: size * 0.3, child: _actionBtn('B', size, Colors.white38, (p) => _setButton(NesController.BUTTON_B, p))),
      Positioned(right: 0, top: 0, child: _actionBtn('A', size, Colors.red, (p) => _setButton(NesController.BUTTON_A, p))),
    ]));
  }

  Widget _actionBtn(String label, double size, Color color, Function(bool) fn) =>
      GestureDetector(onPanDown: (_) => fn(true), onPanEnd: (_) => fn(false), onPanCancel: () => fn(false),
        child: Container(width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: Colors.white54, width: 2)),
          child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)))));

  Widget _buildSmallButton({required String label, required Function(bool) onPressed}) =>
      GestureDetector(onPanDown: (_) => onPressed(true), onPanEnd: (_) => onPressed(false), onPanCancel: () => onPressed(false),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white54)),
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2))));
}

class FrameBufferPainter extends CustomPainter {
  final Uint32List frameBuffer;
  FrameBufferPainter(this.frameBuffer);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final image = Image.fromBytes(ImageByteFormat.rawRgba, frameBuffer.buffer.asUint8List(), width: 256, height: 240);
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, 256, 240), Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }
  @override
  bool shouldRepaint(FrameBufferPainter old) => old.frameBuffer != frameBuffer;
}