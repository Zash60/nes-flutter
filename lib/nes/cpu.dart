import 'dart:typed_data';

/// CPU 6502 - Ricoh 2A03 @ 1.79 MHz
class CPU6502 {
  int a = 0, x = 0, y = 0, sp = 0, pc = 0, status = 0;
  static const int FLAG_C = 0x01, FLAG_Z = 0x02, FLAG_I = 0x04;
  static const int FLAG_D = 0x08, FLAG_B = 0x10, FLAG_U = 0x20;
  static const int FLAG_V = 0x40, FLAG_N = 0x80;
  final Uint8List memory = Uint8List(0x10000);
  int cycles = 0;
  bool running = false;
  int Function(int addr)? readCallback;
  void Function(int addr, int value)? writeCallback;

  CPU6502() {
    _initInstructions();
  }

  int read(int addr) {
    addr &= 0xFFFF;
    return readCallback != null ? readCallback!(addr) : memory[addr];
  }

  void write(int addr, int value) {
    addr &= 0xFFFF;
    if (writeCallback != null) writeCallback!(addr, value & 0xFF);
    else memory[addr] = value & 0xFF;
  }

  int readWord(int addr) => read(addr) | (read((addr + 1) & 0xFFFF) << 8);
  void pushStack(int v) { write(0x0100 + sp, v & 0xFF); sp = (sp - 1) & 0xFF; }
  int popStack() { sp = (sp + 1) & 0xFF; return read(0x0100 + sp); }

  void setZ(int v) { status = (v & 0xFF) == 0 ? status | FLAG_Z : status & ~FLAG_Z; }
  void setN(int v) { status = (v & 0x80) != 0 ? status | FLAG_N : status & ~FLAG_N; }
  void setC(bool c) { status = c ? status | FLAG_C : status & ~FLAG_C; }
  void setV(bool v) { status = v ? status | FLAG_V : status & ~FLAG_V; }
  bool getFlagC() => (status & FLAG_C) != 0;
  bool getFlagZ() => (status & FLAG_Z) != 0;
  bool getFlagN() => (status & FLAG_N) != 0;
  bool getFlagV() => (status & FLAG_V) != 0;

  void nmi() {
    pushStack(pc >> 8); pushStack(pc & 0xFF); pushStack(status & ~FLAG_B);
    status |= FLAG_I; pc = readWord(0xFFFA); cycles += 7;
  }

  void reset() { sp = 0xFD; status |= FLAG_U | FLAG_I; pc = readWord(0xFFFC); cycles = 0; }

  int step() {
    final opcode = read(pc); pc = (pc + 1) & 0xFFFF;
    final instr = _instructions[opcode];
    if (instr == null) { cycles += 2; return 2; }
    final old = cycles; instr(this); return cycles - old;
  }

  static final List<void Function(CPU6502)> _instructions = List.filled(256, _invalid);
  static void _invalid(CPU6502 cpu) { cpu.cycles += 2; }
  static final bool _instructionsInitialized = _initInstructionsStatic();
  
  static bool _initInstructionsStatic() {
    // ADC
    _instructions[0x69] = (c) => c._adc(c._imm()); _instructions[0x65] = (c) => c._adc(c._zp());
    _instructions[0x75] = (c) => c._adc(c._zpx()); _instructions[0x6D] = (c) => c._adc(c._abs());
    _instructions[0x7D] = (c) => c._adc(c._absx()); _instructions[0x79] = (c) => c._adc(c._absy());
    _instructions[0x61] = (c) => c._adc(c._indx()); _instructions[0x71] = (c) => c._adc(c._indy());
    // AND
    _instructions[0x29] = (c) => c._and(c._imm()); _instructions[0x25] = (c) => c._and(c._zp());
    _instructions[0x35] = (c) => c._and(c._zpx()); _instructions[0x2D] = (c) => c._and(c._abs());
    _instructions[0x3D] = (c) => c._and(c._absx()); _instructions[0x39] = (c) => c._and(c._absy());
    _instructions[0x21] = (c) => c._and(c._indx()); _instructions[0x31] = (c) => c._and(c._indy());
    // ASL
    _instructions[0x0A] = (c) => c._aslAcc(); _instructions[0x06] = (c) => c._asl(c._zpAddr());
    _instructions[0x16] = (c) => c._asl(c._zpxAddr()); _instructions[0x0E] = (c) => c._asl(c._absAddr());
    _instructions[0x1E] = (c) => c._asl(c._absxAddr());
    // Branch
    _instructions[0x90] = (c) => c._branch(!c.getFlagC()); _instructions[0xB0] = (c) => c._branch(c.getFlagC());
    _instructions[0xF0] = (c) => c._branch(c.getFlagZ()); _instructions[0x30] = (c) => c._branch(c.getFlagN());
    _instructions[0xD0] = (c) => c._branch(!c.getFlagZ()); _instructions[0x10] = (c) => c._branch(!c.getFlagN());
    _instructions[0x50] = (c) => c._branch(!c.getFlagV()); _instructions[0x70] = (c) => c._branch(c.getFlagV());
    // BIT
    _instructions[0x24] = (c) => c._bit(c._zp()); _instructions[0x2C] = (c) => c._bit(c._abs());
    // BRK
    _instructions[0x00] = (c) => c._brk();
    // CLC, CLD, CLI, CLV
    _instructions[0x18] = (c) { c.status &= ~0x01; c.cycles += 2; };
    _instructions[0xD8] = (c) { c.status &= ~0x08; c.cycles += 2; };
    _instructions[0x58] = (c) { c.status &= ~0x04; c.cycles += 2; };
    _instructions[0xB8] = (c) { c.status &= ~0x40; c.cycles += 2; };
    // CMP
    _instructions[0xC9] = (c) => c._cmp(c._imm(), c.a); _instructions[0xC5] = (c) => c._cmp(c._zp(), c.a);
    _instructions[0xD5] = (c) => c._cmp(c._zpx(), c.a); _instructions[0xCD] = (c) => c._cmp(c._abs(), c.a);
    _instructions[0xDD] = (c) => c._cmp(c._absx(), c.a); _instructions[0xD9] = (c) => c._cmp(c._absy(), c.a);
    _instructions[0xC1] = (c) => c._cmp(c._indx(), c.a); _instructions[0xD1] = (c) => c._cmp(c._indy(), c.a);
    // CPX, CPY
    _instructions[0xE0] = (c) => c._cmp(c._imm(), c.x); _instructions[0xE4] = (c) => c._cmp(c._zp(), c.x);
    _instructions[0xEC] = (c) => c._cmp(c._abs(), c.x);
    _instructions[0xC0] = (c) => c._cmp(c._imm(), c.y); _instructions[0xC4] = (c) => c._cmp(c._zp(), c.y);
    _instructions[0xCC] = (c) => c._cmp(c._abs(), c.y);
    // DEC
    _instructions[0xC6] = (c) => c._dec(c._zpAddr()); _instructions[0xD6] = (c) => c._dec(c._zpxAddr());
    _instructions[0xCE] = (c) => c._dec(c._absAddr()); _instructions[0xDE] = (c) => c._dec(c._absxAddr());
    // DEX, DEY
    _instructions[0xCA] = (c) { c.x = (c.x - 1) & 0xFF; c.setN(c.x); c.setZ(c.x); c.cycles += 2; };
    _instructions[0x88] = (c) { c.y = (c.y - 1) & 0xFF; c.setN(c.y); c.setZ(c.y); c.cycles += 2; };
    // EOR
    _instructions[0x49] = (c) => c._eor(c._imm()); _instructions[0x45] = (c) => c._eor(c._zp());
    _instructions[0x55] = (c) => c._eor(c._zpx()); _instructions[0x4D] = (c) => c._eor(c._abs());
    _instructions[0x5D] = (c) => c._eor(c._absx()); _instructions[0x59] = (c) => c._eor(c._absy());
    _instructions[0x41] = (c) => c._eor(c._indx()); _instructions[0x51] = (c) => c._eor(c._indy());
    // INC
    _instructions[0xE6] = (c) => c._inc(c._zpAddr()); _instructions[0xF6] = (c) => c._inc(c._zpxAddr());
    _instructions[0xEE] = (c) => c._inc(c._absAddr()); _instructions[0xFE] = (c) => c._inc(c._absxAddr());
    // INX, INY
    _instructions[0xE8] = (c) { c.x = (c.x + 1) & 0xFF; c.setN(c.x); c.setZ(c.x); c.cycles += 2; };
    _instructions[0xC8] = (c) { c.y = (c.y + 1) & 0xFF; c.setN(c.y); c.setZ(c.y); c.cycles += 2; };
    // JMP, JSR
    _instructions[0x4C] = (c) => c._jmp(); _instructions[0x6C] = (c) => c._jmpInd();
    _instructions[0x20] = (c) => c._jsr();
    // LDA
    _instructions[0xA9] = (c) => c._lda(c._imm()); _instructions[0xA5] = (c) => c._lda(c._zp());
    _instructions[0xB5] = (c) => c._lda(c._zpx()); _instructions[0xAD] = (c) => c._lda(c._abs());
    _instructions[0xBD] = (c) => c._lda(c._absx()); _instructions[0xB9] = (c) => c._lda(c._absy());
    _instructions[0xA1] = (c) => c._lda(c._indx()); _instructions[0xB1] = (c) => c._lda(c._indy());
    // LDX
    _instructions[0xA2] = (c) => c._ldx(c._imm()); _instructions[0xA6] = (c) => c._ldx(c._zp());
    _instructions[0xB6] = (c) => c._ldx(c._zpy()); _instructions[0xAE] = (c) => c._ldx(c._abs());
    _instructions[0xBE] = (c) => c._ldx(c._absy());
    // LDY
    _instructions[0xA0] = (c) => c._ldy(c._imm()); _instructions[0xA4] = (c) => c._ldy(c._zp());
    _instructions[0xB4] = (c) => c._ldy(c._zpx()); _instructions[0xAC] = (c) => c._ldy(c._abs());
    _instructions[0xBC] = (c) => c._ldy(c._absx());
    // LSR
    _instructions[0x4A] = (c) => c._lsrAcc(); _instructions[0x46] = (c) => c._lsr(c._zpAddr());
    _instructions[0x56] = (c) => c._lsr(c._zpxAddr()); _instructions[0x4E] = (c) => c._lsr(c._absAddr());
    _instructions[0x5E] = (c) => c._lsr(c._absxAddr());
    // NOP
    _instructions[0xEA] = (c) { c.cycles += 2; };
    // ORA
    _instructions[0x09] = (c) => c._ora(c._imm()); _instructions[0x05] = (c) => c._ora(c._zp());
    _instructions[0x15] = (c) => c._ora(c._zpx()); _instructions[0x0D] = (c) => c._ora(c._abs());
    _instructions[0x1D] = (c) => c._ora(c._absx()); _instructions[0x19] = (c) => c._ora(c._absy());
    _instructions[0x01] = (c) => c._ora(c._indx()); _instructions[0x11] = (c) => c._ora(c._indy());
    // PHA, PHP, PLA, PLP
    _instructions[0x48] = (c) { c.pushStack(c.a); c.cycles += 3; };
    _instructions[0x08] = (c) { c.pushStack(c.status | 0x30); c.cycles += 3; };
    _instructions[0x68] = (c) { c.a = c.popStack(); c.setN(c.a); c.setZ(c.a); c.cycles += 4; };
    _instructions[0x28] = (c) { c.status = (c.popStack() | 0x20) & ~0x10; c.cycles += 4; };
    // ROL
    _instructions[0x2A] = (c) => c._rolAcc(); _instructions[0x26] = (c) => c._rol(c._zpAddr());
    _instructions[0x36] = (c) => c._rol(c._zpxAddr()); _instructions[0x2E] = (c) => c._rol(c._absAddr());
    _instructions[0x3E] = (c) => c._rol(c._absxAddr());
    // ROR
    _instructions[0x6A] = (c) => c._rorAcc(); _instructions[0x66] = (c) => c._ror(c._zpAddr());
    _instructions[0x76] = (c) => c._ror(c._zpxAddr()); _instructions[0x6E] = (c) => c._ror(c._absAddr());
    _instructions[0x7E] = (c) => c._ror(c._absxAddr());
    // RTI, RTS
    _instructions[0x40] = (c) => c._rti(); _instructions[0x60] = (c) => c._rts();
    // SBC
    _instructions[0xE9] = (c) => c._sbc(c._imm()); _instructions[0xE5] = (c) => c._sbc(c._zp());
    _instructions[0xF5] = (c) => c._sbc(c._zpx()); _instructions[0xED] = (c) => c._sbc(c._abs());
    _instructions[0xFD] = (c) => c._sbc(c._absx()); _instructions[0xF9] = (c) => c._sbc(c._absy());
    _instructions[0xE1] = (c) => c._sbc(c._indx()); _instructions[0xF1] = (c) => c._sbc(c._indy());
    // SEC, SED, SEI
    _instructions[0x38] = (c) { c.status |= 0x01; c.cycles += 2; };
    _instructions[0xF8] = (c) { c.status |= 0x08; c.cycles += 2; };
    _instructions[0x78] = (c) { c.status |= 0x04; c.cycles += 2; };
    // STA
    _instructions[0x85] = (c) => c._sta(c._zpAddr()); _instructions[0x95] = (c) => c._sta(c._zpxAddr());
    _instructions[0x8D] = (c) => c._sta(c._absAddr()); _instructions[0x9D] = (c) => c._sta(c._absxAddr());
    _instructions[0x99] = (c) => c._sta(c._absyAddr()); _instructions[0x81] = (c) => c._sta(c._indxAddr());
    _instructions[0x91] = (c) => c._sta(c._indyAddr());
    // STX
    _instructions[0x86] = (c) => c._stx(c._zpAddr()); _instructions[0x96] = (c) => c._stx(c._zpyAddr());
    _instructions[0x8E] = (c) => c._stx(c._absAddr());
    // STY
    _instructions[0x84] = (c) => c._sty(c._zpAddr()); _instructions[0x94] = (c) => c._sty(c._zpxAddr());
    _instructions[0x8C] = (c) => c._sty(c._absAddr());
    // TAX, TAY, TSX, TXA, TXS, TYA
    _instructions[0xAA] = (c) { c.x = c.a; c.setN(c.x); c.setZ(c.x); c.cycles += 2; };
    _instructions[0xA8] = (c) { c.y = c.a; c.setN(c.y); c.setZ(c.y); c.cycles += 2; };
    _instructions[0xBA] = (c) { c.x = c.sp; c.setN(c.x); c.setZ(c.x); c.cycles += 2; };
    _instructions[0x8A] = (c) { c.a = c.x; c.setN(c.a); c.setZ(c.a); c.cycles += 2; };
    _instructions[0x9A] = (c) { c.sp = c.x; c.cycles += 2; };
    _instructions[0x98] = (c) { c.a = c.y; c.setN(c.a); c.setZ(c.a); c.cycles += 2; };
    return true;
  }

  void _initInstructions() {}

  int _imm() { final v = read(pc); pc = (pc + 1) & 0xFFFF; cycles += 2; return v; }
  int _zp() { final a = read(pc); pc = (pc + 1) & 0xFFFF; cycles += 3; return read(a); }
  int _zpAddr() { final a = read(pc); pc = (pc + 1) & 0xFFFF; cycles += 3; return a; }
  int _zpx() { final a = (read(pc) + x) & 0xFF; pc = (pc + 1) & 0xFFFF; cycles += 4; return read(a); }
  int _zpxAddr() { final a = (read(pc) + x) & 0xFF; pc = (pc + 1) & 0xFFFF; cycles += 4; return a; }
  int _zpy() { final a = (read(pc) + y) & 0xFF; pc = (pc + 1) & 0xFFFF; cycles += 4; return read(a); }
  int _zpyAddr() { final a = (read(pc) + y) & 0xFF; pc = (pc + 1) & 0xFFFF; cycles += 4; return a; }
  int _abs() { final a = readWord(pc); pc = (pc + 2) & 0xFFFF; cycles += 4; return read(a); }
  int _absAddr() { final a = readWord(pc); pc = (pc + 2) & 0xFFFF; cycles += 4; return a; }
  int _absx() { final a = (readWord(pc) + x) & 0xFFFF; pc = (pc + 2) & 0xFFFF; cycles += 4; return read(a); }
  int _absxAddr() { final a = (readWord(pc) + x) & 0xFFFF; pc = (pc + 2) & 0xFFFF; cycles += 4; return a; }
  int _absy() { final a = (readWord(pc) + y) & 0xFFFF; pc = (pc + 2) & 0xFFFF; cycles += 4; return read(a); }
  int _absyAddr() { final a = (readWord(pc) + y) & 0xFFFF; pc = (pc + 2) & 0xFFFF; cycles += 4; return a; }
  int _indx() { final p = (read(pc) + x) & 0xFF; pc = (pc + 1) & 0xFFFF; final a = readWord(p); cycles += 6; return read(a); }
  int _indxAddr() { final p = (read(pc) + x) & 0xFF; pc = (pc + 1) & 0xFFFF; final a = readWord(p); cycles += 6; return a; }
  int _indy() { final p = read(pc); pc = (pc + 1) & 0xFFFF; final a = (readWord(p) + y) & 0xFFFF; cycles += 5; return read(a); }
  int _indyAddr() { final p = read(pc); pc = (pc + 1) & 0xFFFF; final a = (readWord(p) + y) & 0xFFFF; cycles += 5; return a; }

  void _adc(int v) { final r = a + v + (getFlagC() ? 1 : 0); setV(((a ^ r) & (v ^ r) & 0x80) != 0); setC(r > 0xFF); a = r & 0xFF; setN(a); setZ(a); cycles += 2; }
  void _and(int v) { a &= v; setN(a); setZ(a); cycles += 2; }
  void _asl(int a) { var v = read(a); setC((v & 0x80) != 0); v = (v << 1) & 0xFF; write(a, v); setN(v); setZ(v); cycles += 2; }
  void _aslAcc() { setC((a & 0x80) != 0); a = (a << 1) & 0xFF; setN(a); setZ(a); cycles += 2; }
  void _branch(bool c) { final o = read(pc); pc = (pc + 1) & 0xFFFF; if (c) { final old = pc; pc = (pc + (o >= 128 ? o - 256 : o)) & 0xFFFF; cycles += (old & 0xFF00) != (pc & 0xFF00) ? 4 : 3; } else { cycles += 2; } }
  void _bit(int v) { final r = a & v; setZ(r); setN((v & 0x80) != 0 ? 1 : 0); setV((v & 0x40) != 0 ? 1 : 0); cycles += 2; }
  void _brk() { pc = (pc + 1) & 0xFFFF; pushStack(pc >> 8); pushStack(pc & 0xFF); pushStack(status | 0x30); status |= 0x04; pc = readWord(0xFFFE); cycles += 7; }
  void _cmp(int v, int r) { final res = r - v; setC(res >= 0); setZ((res & 0xFF) == 0 ? 1 : 0); setN(res); cycles += 2; }
  void _dec(int a) { var v = (read(a) - 1) & 0xFF; write(a, v); setN(v); setZ(v); cycles += 2; }
  void _eor(int v) { a ^= v; setN(a); setZ(a); cycles += 2; }
  void _inc(int a) { var v = (read(a) + 1) & 0xFF; write(a, v); setN(v); setZ(v); cycles += 2; }
  void _jmp() { pc = readWord(pc); cycles += 3; }
  void _jmpInd() { final p = readWord(pc); pc = (pc + 2) & 0xFFFF; final lo = read(p); final hi = read((p & 0xFF00) | ((p + 1) & 0xFF)); pc = (hi << 8) | lo; cycles += 5; }
  void _jsr() { final a = readWord(pc); pc = (pc + 2) & 0xFFFF; pushStack((pc - 1) >> 8); pushStack((pc - 1) & 0xFF); pc = a; cycles += 6; }
  void _lda(int v) { a = v; setN(a); setZ(a); cycles += 2; }
  void _ldx(int v) { x = v; setN(x); setZ(x); cycles += 2; }
  void _ldy(int v) { y = v; setN(y); setZ(y); cycles += 2; }
  void _lsr(int a) { var v = read(a); setC((v & 1) != 0); v >>= 1; write(a, v); setN(0); setZ(v); cycles += 2; }
  void _lsrAcc() { setC((a & 1) != 0); a >>= 1; setN(0); setZ(a); cycles += 2; }
  void _ora(int v) { a |= v; setN(a); setZ(a); cycles += 2; }
  void _rol(int a) { var v = read(a); final c = getFlagC() ? 1 : 0; setC((v & 0x80) != 0); v = ((v << 1) | c) & 0xFF; write(a, v); setN(v); setZ(v); cycles += 2; }
  void _rolAcc() { final c = getFlagC() ? 1 : 0; setC((a & 0x80) != 0); a = ((a << 1) | c) & 0xFF; setN(a); setZ(a); cycles += 2; }
  void _ror(int a) { var v = read(a); final c = getFlagC() ? 0x80 : 0; setC((v & 1) != 0); v = (v >> 1) | c; write(a, v); setN(v); setZ(v); cycles += 2; }
  void _rorAcc() { final c = getFlagC() ? 0x80 : 0; setC((a & 1) != 0); a = (a >> 1) | c; setN(a); setZ(a); cycles += 2; }
  void _rti() { status = (popStack() | 0x20) & ~0x10; pc = popStack() | (popStack() << 8); cycles += 6; }
  void _rts() { pc = popStack() | (popStack() << 8); pc = (pc + 1) & 0xFFFF; cycles += 6; }
  void _sbc(int v) { final r = a - v - (getFlagC() ? 0 : 1); setV(((a ^ r) & (~v ^ r) & 0x80) != 0); setC(r >= 0); a = r & 0xFF; setN(a); setZ(a); cycles += 2; }
  void _sta(int a) { write(a, a); cycles += 2; }
  void _stx(int a) { write(a, x); cycles += 2; }
  void _sty(int a) { write(a, y); cycles += 2; }
}