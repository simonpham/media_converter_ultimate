# Contributing

Thanks for your interest in Media Converter Pro! Contributions are welcome —
bug fixes, new formats, translations, tests, or documentation improvements.

## Getting started

You need Flutter 3.47+ (Dart 3.13+).

```sh
git clone --recurse-submodules https://github.com/simonpham/media_converter_ultimate.git
cd media_converter_ultimate
flutter pub get

cd apps/mcu
flutter run
```

If you cloned without `--recurse-submodules`, run
`git submodule update --init` first.

## Before you submit

1. **Analyze** — make sure `flutter analyze` reports no issues.
2. **Tests** — run `./run_tests.sh` and make sure everything passes.
3. **Validate configs** — if you touched anything in `apps/mcu/assets/configs`
   or translations, run `./validate.sh`.
4. **FFmpeg commands** — if you changed a format config, run `./test_ffmpeg.sh`.

## Code conventions

See [CONVENTIONS.md](CONVENTIONS.md) for the full coding style, architecture
rules, UI guidelines, and commit format.

## Translations

Translations live in three places:

- **`packages/l10n/lib/l10n/*.arb`** — UI strings (ARB format, used by `gen-l10n`)
- **`apps/mcu/assets/configs/l10n/*.json`** — format names and config labels
- **`apps/mcu/assets/content/`** — changelogs, support page and other HTML content

After editing any of these, run `./validate.sh` to verify every language has
every key.

## Architecture at a glance

```
apps/mcu              — the app
modules/converter     — converter feature (jobs, settings)
packages/             — shared packages (UI, platform, storage, ads, l10n)
```

`apps` depends on `modules` and `packages`. `modules` depends on `packages`.
`packages` should not depend on `apps` or `modules`.

## License

By contributing, you agree that your contributions will be licensed under the
[GPL-3.0 License](LICENSE).
