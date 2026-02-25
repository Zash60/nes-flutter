import 'dart:typed_data';
import 'cpu.dart';
import 'ppu.dart';
import 'cartridge.dart';

/// NES Controller Input
class NesController {
  static const int BUTTON_B = 0, BUTTON_A = 1, BUTTON_SELECT = 2, BUTTON_START = 3;
  static const int BUTTON_UP = 4, BUTTON_DOWN = 5, BUTTON_LEFT = 6, BUTTON_RIGHT = 7;
  int buttons = 0, strobe = 0, shiftRegister = 0;
  
  void setButton(int button, bool pressed) {
    buttons = pressed ? buttons | (1 << button) : buttons & ~(1 << button);
  }
  
  int read() {
    if (strobe == 1) shiftRegister = buttons;
    final result = shiftRegister & 1;
    shiftRegister >>= 1; shiftRegister |= 0x80;
    return result;
  }
  
  void write(int value) { strobe = value & 1; }
}

/// Main NES Emulator
class NesEmulator {
  final CPU6502 cpu = CPU6502();
  final PPU ppu = PPU();
  final Cartridge cartridge = Cartridge();
  final NesController controller1 = NesController();
  
  int dmaPage = 0, dmaData = 0, dmaCycle = 0;
  bool dmaTransfer = false;
  bool running = false, paused = false;
  
  static const int CPU_CLOCK = 1789773;
  static const int CYCLES_PER_FRAME = CPU_CLOCK ~/ 60;
  
  Function()? onFrameComplete;
  
  NesEmulator() {
    cpu.readCallback = _cpuRead;
    cpu.writeCallback = _cpuWrite;
    ppu.readCallback = _ppuRead;
    ppu.writeCallback = _ppuWrite;
    ppu.nmiCallback = _nmi;
  }
  
  Future<bool> loadRom(Uint8List data) async {
    if (!cartridge.load(data)) return false;
    reset();
    return true;
  }
  
  void reset() {
    cpu.reset(); ppu.reset(); cartridge.reset(); dmaTransfer = false; dmaCycle = 0;
  }
  
  void step() {
    if (!running || paused) return;
    int cycles = 0;
    while (cycles < CYCLES_PER_FRAME && running && !paused) {
      if (dmaTransfer) {
        if (dmaCycle == 0) dmaData = cpu.read(0x2004);
        else if (dmaCycle <= 512) ppu.oam[((dmaCycle - 1) * 4) & 0xFF] = dmaData;
        else { dmaTransfer = false; cpu.cycles += 513; if (cpu.cycles & 1 != 0) cpu.cycles++; }
        dmaCycle++; cycles++; continue;
      }
      cpu.step();
      for (int i = 0; i < 3; i++) ppu.step();
      cycles++;
    }
    if (ppu.frameComplete) { ppu.frameComplete = false; onFrameComplete?.call(); }
  }
  
  int _cpuRead(int addr) {
    addr &= 0xFFFF;
    if (addr < 0x0800) return cpu.memory[addr];
    if (addr < 0x2000) return cpu.memory[addr & 0x07FF];
    if (addr >= 0x2000 && addr < 0x2008) return ppu.read(addr);
    if (addr >= 0x2008 && addr < 0x4000) return ppu.read(addr & 0x2007);
    if (addr == 0x4016) return controller1.read();
    if (addr >= 0x4020) return cartridge.cpuRead(addr);
    return 0;
  }
  
  void _cpuWrite(int addr, int value) {
    addr &= 0xFFFF; value &= 0xFF;
    if (addr < 0x0800) { cpu.memory[addr] = value; return; }
    if (addr < 0x2000) { cpu.memory[addr & 0x07FF] = value; return; }
    if (addr >= 0x2000 && addr < 0x2008) { ppu.write(addr, value); return; }
    if (addr >= 0x2008 && addr < 0x4000) { ppu.write(addr & 0x2007, value); return; }
    if (addr == 0x4014) { dmaPage = value; dmaTransfer = true; dmaCycle = 0; return; }
    if (addr == 0x4016) { controller1.write(value); return; }
    cartridge.cpuWrite(addr, value);
  }
  
  int _ppuRead(int addr) => cartridge.ppuRead(addr);
  void _ppuWrite(int addr, int value) => cartridge.ppuWrite(addr, value);
  void _nmi() => cpu.nmi();
  
  void setButton(int button, bool pressed) => controller1.setButton(button, pressed);
  Uint32List getFrameBufferRGB() => ppu.getFrameBufferRGB();
  void start() { running = true; paused = false; }
  void stop() { running = false; }
  void pause() { paused = true; }
  void resume() { paused = false; }
}