import 'dart:typed_data';

/// PPU - Picture Processing Unit @ 5.37 MHz
class PPU {
  final Uint8List vram = Uint8List(0x1000);
  final Uint8List palette = Uint8List(0x20);
  int ctrl = 0, mask = 0, status = 0, scrollX = 0, scrollY = 0, vramAddr = 0, dataBuffer = 0;
  final Uint8List oam = Uint8List(256);
  int oamAddr = 0, cycle = 0, scanline = 0;
  bool evenFrame = true, nmiOccurred = false, frameComplete = false;
  final Uint8List frameBuffer = Uint8List(256 * 240);
  
  bool get showBackground => (mask & 0x08) != 0;
  bool get showSprites => (mask & 0x10) != 0;
  bool get nmiEnabled => (ctrl & 0x80) != 0;
  int get nameTableBase => (ctrl & 0x03) * 0x400;
  int get patternTableBase => (ctrl & 0x10) != 0 ? 0x1000 : 0x0000;
  int get spritePatternTableBase => (ctrl & 0x08) != 0 ? 0x1000 : 0x0000;
  int get spriteSize => (ctrl & 0x20) != 0 ? 16 : 8;
  
  static final List<int> paletteRGB = [
    0xFF757575, 0xFF241D82, 0xFF00008A, 0xFF44009A, 0xFF820078, 0xFF940036, 0xFF8A1800, 0xFF683800,
    0xFF445000, 0xFF106000, 0xFF008200, 0xFF008A00, 0xFF008A46, 0xFF00756E, 0xFF005E8A, 0xFF00348A,
    0xFFBABA9E, 0xFF5848BA, 0xFF3828BA, 0xFF7820BA, 0xFFBA1A8A, 0xFFD41840, 0xFFD43C18, 0xFFBA5E00,
    0xFF8C8200, 0xFF50A400, 0xFF20BA28, 0xFF18BA46, 0xFF18BA82, 0xFF189EBA, 0xFF207ABA, 0xFF2850BA,
    0xFFFCFCFC, 0xFFA494FC, 0xFF7878FC, 0xFFBC68FC, 0xFFF868F8, 0xFFF858BC, 0xFFF87878, 0xFFECAC50,
    0xFFC4C438, 0xFF88E020, 0xFF58F058, 0xFF48F082, 0xFF38ECEC, 0xFF48D0EC, 0xFF58A8F8, 0xFF6888FC,
    0xFFFCFCFC, 0xFFE0D4FC, 0xFFC8C8FC, 0xFFE4C0FC, 0xFFF8C0F8, 0xFFF8B8E0, 0xFFF8C0C0, 0xFFF4D4AC,
    0xFFECEC9E, 0xFFD4F0AC, 0xFFB8F8C8, 0xFFACF8E4, 0xFFA8F4FC, 0xFFB0E4FC, 0xFFB8D4FC, 0xFFC4C8FC,
  ];
  
  int Function(int addr)? readCallback;
  void Function(int addr, int value)? writeCallback;
  void Function()? nmiCallback;
  
  int read(int addr) {
    addr &= 0x2007;
    switch (addr) {
      case 0: case 1: case 3: case 5: case 6: return 0;
      case 2: final v = status; status &= ~0x80; nmiOccurred = false; return v;
      case 4: return oam[oamAddr];
      case 7:
        final v = readCpu(vramAddr);
        final buf = dataBuffer; dataBuffer = v & 0xFF;
        vramAddr = (vramAddr + 1) & 0x3FFF;
        return vramAddr >= 0x3F00 ? readPalette(vramAddr & 0x1F) : buf;
    }
    return 0;
  }
  
  void write(int addr, int value) {
    addr &= 0x2007;
    switch (addr) {
      case 0: ctrl = value; break;
      case 1: mask = value; break;
      case 3: oamAddr = value; break;
      case 4: oam[oamAddr] = value; oamAddr = (oamAddr + 1) & 0xFF; break;
      case 5: if (scrollX == 0) scrollX = value; else scrollY = value; break;
      case 6: if (vramAddr == 0) vramAddr = (value & 0x3F) << 8; else vramAddr = (vramAddr | value) & 0x3FFF; break;
      case 7: writeCpu(vramAddr, value); vramAddr = (vramAddr + 1) & 0x3FFF; break;
    }
  }
  
  int readCpu(int addr) {
    if (readCallback != null) return readCallback!(addr & 0x3FFF);
    if (addr < 0x1000) return vram[addr];
    if (addr >= 0x3F00 && addr < 0x4000) return readPalette(addr & 0x1F);
    return 0;
  }
  
  void writeCpu(int addr, int value) {
    if (writeCallback != null) { writeCallback!(addr & 0x3FFF, value & 0xFF); return; }
    if (addr < 0x1000) vram[addr] = value & 0xFF;
  }
  
  int readPalette(int addr) {
    addr &= 0x1F;
    if (addr >= 0x10 && (addr % 4) == 0) addr -= 0x10;
    return palette[addr];
  }
  
  int step() {
    if (scanline >= 240) {
      if (scanline == 241 && cycle == 1) {
        status |= 0x80; nmiOccurred = true;
        if (nmiEnabled && nmiCallback != null) nmiCallback!();
      }
      cycle++; if (cycle >= 341) { cycle = 0; scanline++; if (scanline >= 262) { scanline = 0; evenFrame = !evenFrame; frameComplete = true; } }
      return 3;
    }
    if (showBackground || showSprites) { if (cycle == 1) _renderScanline(scanline); }
    cycle++; if (cycle >= 341) { cycle = 0; scanline++; }
    return 3;
  }
  
  void _renderScanline(int sl) {
    final offset = sl * 256;
    if (showBackground) {
      final fineY = scrollY & 0x07;
      final tileRow = (sl + fineY) ~/ 8;
      for (int x = 0; x < 256; x++) {
        final fineX = scrollX & 0x07, tileCol = (x + fineX) ~/ 8;
        if (tileCol >= 32 || tileRow >= 30) { frameBuffer[offset + x] = readPalette(0); continue; }
        final ntOff = nameTableBase + tileRow * 32 + tileCol;
        final tileIdx = readCpu(ntOff);
        final attrOff = 0x23C0 + (tileRow ~/ 4) * 8 + (tileCol ~/ 4);
        final attr = readCpu(attrOff);
        final shift = ((tileRow % 4) ~/ 2) * 2 + ((tileCol % 4) ~/ 2) * 2;
        final palIdx = (attr >> shift) & 0x03;
        final patOff = patternTableBase + tileIdx * 16 + fineY;
        final lo = readCpu(patOff), hi = readCpu(patOff + 8);
        final px = 7 - ((x + fineX) % 8);
        final colorIdx = ((hi >> px) & 1) << 1 | (lo >> px) & 1;
        frameBuffer[offset + x] = readPalette(palIdx * 4 + colorIdx);
      }
    } else {
      final bg = readPalette(0);
      for (int x = 0; x < 256; x++) frameBuffer[offset + x] = bg;
    }
  }
  
  void reset() {
    ctrl = 0; mask = 0; status = 0; scrollX = 0; scrollY = 0; vramAddr = 0;
    oamAddr = 0; cycle = 0; scanline = 0; evenFrame = true; nmiOccurred = false;
  }
  
  Uint32List getFrameBufferRGB() {
    final rgb = Uint32List(256 * 240);
    for (int i = 0; i < frameBuffer.length; i++) rgb[i] = paletteRGB[frameBuffer[i] & 0x3F];
    return rgb;
  }
}