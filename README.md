# Media Converter Pro: Ultimate

Convert video and audio right on your device with FFmpeg. No uploads, no servers.

[Get it on Google Play](https://play.google.com/store/apps/details?id=com.github.khangnt.mcp)

- 25 output formats (14 audio, 11 video), with format-specific options
- Quick presets, trimming with waveform preview, batch queues
- Conversions keep running in the background
- Adaptive layouts for phones, tablets, foldables and large screens
- 12 languages

This is a Flutter rewrite of the original native Android app,
[Android-Media-Converter](https://github.com/simonpham/Android-Media-Converter),
built in 2018 with Khang Nguyen.

## Project structure

A Dart workspace monorepo:

- `apps/mcu`: the app
- `apps/mcu_configs`: CLI that validates the FFmpeg configs and translations
- `modules/converter`: the converter feature (job maker, job manager, settings)
- `packages/`: shared packages, including the design system (`sofluffy_ui`, a
  git submodule), the platform layer (FFmpegKit, notifications, files),
  storage, ads and translations (`l10n`)

## Getting started

You need Flutter 3.47+ (Dart 3.13+). The project pins its Flutter version with
[puro](https://puro.dev) in `.puro.json`.

```sh
git clone --recurse-submodules <this repo>
cd converter
flutter pub get

cd apps/mcu
flutter run
```

If you cloned without `--recurse-submodules`, run
`git submodule update --init` first.

### Configuration (optional)

Everything builds out of the box. Without `.assets/env.props`:

- the app ID is `io.sofluffy.mcu`
- release builds are signed with the debug key
- ads use Google's sample ad units

To sign release builds or use real AdMob IDs, copy
`.assets/env.props.example` to `.assets/env.props` and fill it in. It's
gitignored.

## Checks

```sh
./run_tests.sh      # unit and widget tests across the workspace
./validate.sh       # FFmpeg config schemas and translation parity
./test_ffmpeg.sh    # runs the FFmpeg commands for real
```

Code conventions are in [CONVENTIONS.md](CONVENTIONS.md), and FFmpeg config
rules are in [CONFIG_RULES.md](CONFIG_RULES.md).

## License

[GPL-3.0](LICENSE). The app bundles the GPL build of FFmpeg through
[FFmpegKit](https://pub.dev/packages/ffmpeg_kit_flutter_new).
