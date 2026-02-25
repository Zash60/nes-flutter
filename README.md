# NES Emulator - Flutter

Nintendo Entertainment System emulator built with Flutter for Android.

## Features

- **CPU**: Full 6502 instruction set @ 1.79 MHz
- **PPU**: 256x240 @ 60 FPS with sprites and tiles
- **Mappers**: 0 (NROM), 1 (MMC1), 2 (UxROM), 3 (CNROM), 7 (AOROM)
- **Touch Controls**: D-Pad, A/B buttons, Start/Select

## Build

### GitHub Actions (Automatic)

The APK is built automatically on every push. Download from:
**Actions** > **Build Android APK** > **Artifacts**

### Local Build

```bash
flutter pub get
flutter build apk --release
```

## Controls

- **D-Pad**: Movement
- **A**: Jump/Action
- **B**: Run/Fire
- **Start**: Start/Pause
- **Select**: 1-2 Player

## Supported Games

- Super Mario Bros (Mapper 0)
- The Legend of Zelda (Mapper 1)
- Metroid (Mapper 1)
- Mega Man 2 (Mapper 1)
- Contra (Mapper 2)
- And more!

## License

MIT License - Educational purposes only.

Nintendo and NES are trademarks of Nintendo of America.
