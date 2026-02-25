import 'dart:typed_data';

/// NES Cartridge with Mapper Support
class Cartridge {
  Uint8List? prgRom, chrRom;
  int prgRomSize = 0, chrRomSize = 0, mapperNumber = 0, mirrorType = 0;
  bool hasBattery = false, hasTrainer = false;
  Mapper? mapper;
  final Uint8List sram = Uint8List(0x2000);
  
  bool load(Uint8List data) {
    if (data.length < 16) return false;
    if (data[0] != 0x4E || data[1] != 0x45 || data[2] != 0x53 || data[3] != 0x1A) return false;
    prgRomSize = data[4] * 16384;
    chrRomSize = data[5] * 8192;
    mirrorType = data[6] & 0x01;
    hasBattery = (data[6] & 0x02) != 0;
    hasTrainer = (data[6] & 0x04) != 0;
    mapperNumber = ((data[6] >> 4) & 0x0F) | (data[7] & 0xF0);
    int romOffset = 16;
    if (hasTrainer) romOffset += 512;
    prgRom = Uint8List(prgRomSize);
    prgRom!.setRange(0, prgRomSize, data, romOffset);
    if (chrRomSize > 0) {
      chrRom = Uint8List(chrRomSize);
      chrRom!.setRange(0, chrRomSize, data, romOffset + prgRomSize);
    }
    mapper = createMapper(mapperNumber, this);
    return true;
  }
  
  int cpuRead(int addr) => mapper?.cpuRead(addr) ?? 0;
  void cpuWrite(int addr, int value) => mapper?.cpuWrite(addr, value);
  int ppuRead(int addr) => mapper?.ppuRead(addr) ?? 0;
  void ppuWrite(int addr, int value) => mapper?.ppuWrite(addr, value);
  void reset() => mapper?.reset();
}

abstract class Mapper {
  final Cartridge cartridge;
  Mapper(this.cartridge);
  int cpuRead(int addr);
  void cpuWrite(int addr, int value);
  int ppuRead(int addr);
  void ppuWrite(int addr, int value);
  void reset();
}

/// Mapper 0 - NROM (Super Mario Bros, Tetris)
class Mapper0 extends Mapper {
  Mapper0(super.cartridge);
  @override
  int cpuRead(int addr) {
    if (addr >= 0x6000 && addr < 0x8000) return cartridge.sram[addr - 0x6000];
    if (addr >= 0x8000) {
      if (cartridge.prgRomSize == 32768) return cartridge.prgRom![addr - 0x8000];
      return cartridge.prgRom![addr & 0x3FFF];
    }
    return 0;
  }
  @override
  void cpuWrite(int addr, int value) {
    if (addr >= 0x6000 && addr < 0x8000) cartridge.sram[addr - 0x6000] = value;
  }
  @override
  int ppuRead(int addr) {
    if (addr < 0x2000 && cartridge.chrRom != null) return cartridge.chrRom![addr];
    return 0;
  }
  @override
  void ppuWrite(int addr, int value) {}
  @override
  void reset() {}
}

/// Mapper 1 - MMC1 (Zelda, Metroid, Mega Man 2)
class Mapper1 extends Mapper {
  int shiftRegister = 0x10, regs0 = 0x0C, prgBank = 0, chrBank0 = 0, chrBank1 = 0, prgMode = 3, chrMode = 0;
  Mapper1(super.cartridge);
  @override
  int cpuRead(int addr) {
    if (addr >= 0x6000 && addr < 0x8000) return cartridge.sram[addr - 0x6000];
    if (addr >= 0x8000) {
      final offset = addr - 0x8000;
      int bank = prgMode == 3 ? (offset < 16384 ? prgBank * 16384 : cartridge.prgRomSize - 16384) : (prgBank & ~1) * 16384;
      return cartridge.prgRom![(offset + bank) % cartridge.prgRomSize];
    }
    return 0;
  }
  @override
  void cpuWrite(int addr, int value) {
    if (addr >= 0x6000 && addr < 0x8000) { cartridge.sram[addr - 0x6000] = value; return; }
    if (addr >= 0x8000) {
      if ((value & 0x80) != 0) { shiftRegister = 0x10; regs0 = 0x0C; prgMode = 3; }
      else {
        if ((shiftRegister & 1) != 0) {
          final reg = (addr >> 13) & 0x03;
          if (reg == 0) { regs0 = shiftRegister; prgMode = (shiftRegister >> 2) & 0x03; chrMode = (shiftRegister >> 4) & 0x01; }
          else if (reg == 1) chrBank0 = shiftRegister & 0x1F;
          else if (reg == 2) chrBank1 = shiftRegister & 0x1F;
          else if (reg == 3) prgBank = shiftRegister & 0x0F;
          shiftRegister = 0x10;
        }
        shiftRegister = ((shiftRegister >> 1) | ((value & 1) << 4)) & 0x1F;
      }
    }
  }
  @override
  int ppuRead(int addr) {
    if (addr < 0x2000 && cartridge.chrRom != null) {
      int bank = chrMode == 0 ? (chrBank0 & ~1) * 4096 : (addr < 0x1000 ? chrBank0 * 4096 : chrBank1 * 4096);
      return cartridge.chrRom![(addr + bank) % cartridge.chrRomSize];
    }
    return 0;
  }
  @override
  void ppuWrite(int addr, int value) {}
  @override
  void reset() { shiftRegister = 0x10; regs0 = 0x0C; prgBank = 0; chrBank0 = 0; chrBank1 = 0; prgMode = 3; chrMode = 0; }
}

/// Mapper 2 - UxROM (Contra, Battletoads)
class Mapper2 extends Mapper {
  int prgBank = 0;
  Mapper2(super.cartridge);
  @override
  int cpuRead(int addr) {
    if (addr >= 0x6000 && addr < 0x8000) return cartridge.sram[addr - 0x6000];
    if (addr >= 0x8000) {
      final offset = addr - 0x8000;
      int bank = offset < 16384 ? prgBank * 16384 : cartridge.prgRomSize - 16384;
      return cartridge.prgRom![(offset + bank) % cartridge.prgRomSize];
    }
    return 0;
  }
  @override
  void cpuWrite(int addr, int value) {
    if (addr >= 0x6000 && addr < 0x8000) cartridge.sram[addr - 0x6000] = value;
    else if (addr >= 0x8000) prgBank = value & 0x0F;
  }
  @override
  int ppuRead(int addr) => addr < 0x2000 && cartridge.chrRom != null ? cartridge.chrRom![addr] : 0;
  @override
  void ppuWrite(int addr, int value) {}
  @override
  void reset() { prgBank = 0; }
}

/// Mapper 3 - CNROM (Blaster Master)
class Mapper3 extends Mapper {
  int chrBank = 0;
  Mapper3(super.cartridge);
  @override
  int cpuRead(int addr) {
    if (addr >= 0x6000 && addr < 0x8000) return cartridge.sram[addr - 0x6000];
    if (addr >= 0x8000) return cartridge.prgRom![(addr - 0x8000) % cartridge.prgRomSize];
    return 0;
  }
  @override
  void cpuWrite(int addr, int value) {
    if (addr >= 0x6000 && addr < 0x8000) cartridge.sram[addr - 0x6000] = value;
    else if (addr >= 0x8000) chrBank = value & 0x03;
  }
  @override
  int ppuRead(int addr) {
    if (addr < 0x2000 && cartridge.chrRom != null) return cartridge.chrRom![(addr + chrBank * 8192) % cartridge.chrRomSize];
    return 0;
  }
  @override
  void ppuWrite(int addr, int value) {}
  @override
  void reset() { chrBank = 0; }
}

/// Mapper 7 - AOROM (Battletoads)
class Mapper7 extends Mapper {
  int prgBank = 0;
  Mapper7(super.cartridge);
  @override
  int cpuRead(int addr) {
    if (addr >= 0x8000) return cartridge.prgRom![(addr - 0x8000 + prgBank * 32768) % cartridge.prgRomSize];
    return 0;
  }
  @override
  void cpuWrite(int addr, int value) { if (addr >= 0x8000) prgBank = value & 0x0F; }
  @override
  int ppuRead(int addr) => addr < 0x2000 && cartridge.chrRom != null ? cartridge.chrRom![addr] : 0;
  @override
  void ppuWrite(int addr, int value) {}
  @override
  void reset() { prgBank = 0; }
}

Mapper createMapper(int number, Cartridge cartridge) {
  switch (number) {
    case 0: return Mapper0(cartridge);
    case 1: return Mapper1(cartridge);
    case 2: return Mapper2(cartridge);
    case 3: return Mapper3(cartridge);
    case 7: return Mapper7(cartridge);
    default: return Mapper0(cartridge);
  }
}