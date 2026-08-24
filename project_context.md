# Project Context

## Overview
This project is a Flutter-based monorepo workspace using native Dart workspace resolution (`workspace:` in root `pubspec.yaml`). It contains applications (`apps/mcu`, `apps/mcu_configs`), feature modules (`modules/converter`), and shared packages (`packages/core`, `design_system`, `platform_utils`, etc.).

## Project Structure
- **`apps/`**: Contains application entry points and CLI tools.
  - `mcu`: The main "Media Converter Ultimate" mobile/desktop application.
  - `mcu_configs`: Standalone CLI package for validating configuration JSON schemas, localization parity, and running live FFmpeg conversion test suites.
- **`modules/`**: Contains feature-specific business logic and UI.
  - `converter`: Core converter feature module (JobMaker, JobManager).
- **`packages/`**: Shared libraries and utilities.
  - `core`: Core application models, failures, base interfaces, and services.
  - `core_storage_base`: Storage interface abstractions.
  - `core_storage_isar`: Isar database storage implementation.
  - `design_system`: Reusable UI components, themes, typography, and assets.
  - `mobile_ads`: Abstractions for ad integrations.
  - `mobile_ads_google`: Google Mobile Ads SDK implementation.
  - `utils`: General utility helpers and extensions.
  - `platform_utils`: Platform-specific implementations (FFmpegKit bindings, notifications, file picker).
  - `l10n`: Localization resources supporting 11 languages (`de`, `en`, `es`, `id`, `it`, `ja`, `pt`, `tr`, `vi`, `zh`, `zh_TW`).
  - `icons`: Custom icon font and SVG assets.

## Tech Stack
- **Language**: Dart (SDK ^3.12.0) with native Dart workspace resolution
- **Framework**: Flutter
- **State Management**: `Provider` (`ChangeNotifierProvider`, `Consumer`, `Selector`), `ValueNotifier`, `StatefulWidget`.
- **Navigation**: `go_router` (`context.router`).
- **Dependency Injection**: `get_it` via `injector` singleton and module injectors (`ConverterInjector`).
- **Localization**: `flutter_localizations` with `l10n` package (`context.l10n`).
- **Storage**: `isar` (`packages/core_storage_isar`), `easy_hive` / `easy_hive_encryption` (`SettingsBox`, `LogDataBox`).
- **Media Engine**: `ffmpeg_kit_flutter_new` (`^3.2.0-full-gpl`, bundled FFmpeg 7.1.1).

## Architecture & Patterns

### Modularization
The project follows a clean modular architecture:
- **Apps** depend on **Modules** and **Packages**.
- **Modules** depend on **Packages**.
- **Packages** should be independent or depend on lower-level packages.

### UI & Design System
- **Design System**: All UI components come from `package:design_system`.
  - Use `context.theme` / `context.theme.colorScheme` for colors and typography (`ThemeConfigs` is deprecated).
  - Use `Spacing` class for dimensions (e.g., `Spacing.d16`, `Spacing.v8`).
  - Use `Assets` for images and icons.
- **Components**:
  - `Button` with `ButtonVariant` (primary, secondary, ghost).
  - `Tappable` for interactive elements.
  - `ImageView` for displaying images/icons.
  - Built-in `SliverReorderableList` for reorderable lists.

### File Operations
- Use `injector<FileService>()` for picking files, resolving paths, temporary directory management, and caching.

### Configuration & Validation
- **FFmpeg Configs**: JSON-based configuration for 25 FFmpeg formats in `apps/mcu/assets/configs/`.
- **Rules**: `CONFIG_RULES.md` defines schemas and conventions.
- **Validation**:
  - `./validate.sh` checks JSON schemas, cross-file references, and translation key parity.
  - `./test_ffmpeg.sh` executes live conversion tests across all formats and option matrices.

## Code Style Highlights
- **Imports**: Prefer package imports (`package:converter/...`) over relative imports, except for sibling files in the same directory.
- **Exports**: Used to expose public APIs from packages/modules.
- **Async**: `unawaited` used for fire-and-forget futures.
- **Logging**: `printLog` wrapper used instead of `print`.
