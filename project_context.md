# Project Context

## Overview
This project is a Flutter-based monorepo workspace managed with `melos` (implied by structure) or standard Dart workspace features. It contains a main application (`apps/mcu`), feature modules (`modules/converter`), and shared packages (`packages/core`, `design_system`, etc.).

## Project Structure
- **`apps/`**: Contains the application entry points.
  - `mcu`: The main "Media Converter Ultimate" application.
- **`modules/`**: Contains feature-specific business logic and UI.
  - `converter`: Core converter feature module.
- **`packages/`**: Shared libraries and utilities.
  - `core`: Core application logic and base classes.
  - `design_system`: Reusable UI components, themes, and assets.
  - `utils`: General utility functions.
  - `platform_utils`: Platform-specific implementations.
  - `l10n`: Localization resources.
  - `icons`: Custom icon font or SVG assets.

## Tech Stack
- **Language**: Dart (SDK ^3.8.1)
- **Framework**: Flutter
- **State Management**: `Provider` (`ChangeNotifierProvider`, `Consumer`), `ValueNotifier`, `StatefulWidget`.
- **Navigation**: `go_router` (implied by `GoRouterState` and `context.router`).
- **Dependency Injection**: Custom `Injector` or wrapper (likely `get_it` based).
- **Localization**: `flutter_localizations` with `l10n` package (`context.l10n`).
- **Storage**: `isar` (implied by `packages/core_storage_isar`), `hive` or similar box-based storage (`EasyBox`).

## Architecture & Patterns

### Modularization
The project follows a modular architecture where features are encapsulated in `modules/` and shared code resides in `packages/`.
- **Apps** depend on **Modules** and **Packages**.
- **Modules** depend on **Packages**.
- **Packages** should be independent or depend on lower-level packages.

### UI & Design System
- **Design System**: All UI components should come from `package:design_system`.
  - Use `ThemeConfigs().theme` for colors and typography.
  - Use `Spacing` class for dimensions (e.g., `Spacing.d16`).
  - Use `Assets` for images and icons.
- **Components**:
  - `Button` with `ButtonVariant` (primary, secondary, ghost).
  - `Tappable` for interactive elements.
  - `ImageView` for displaying images/icons.

### State Management
- ViewModels (`JobMakerViewModel`) extend `ChangeNotifier` or similar.
- UI consumes state using `Consumer`, `ValueListenableBuilder`, or `Selector`.
- `StatefulWidget` is used for local UI state (animations, controllers).

### Dependency Injection
- `Injector` class is used for initializing and accessing dependencies.
- Feature-specific injectors (e.g., `ConverterInjector`) register module dependencies.

### Configuration
- **FFmpeg Configs**: JSON-based configuration for FFmpeg formats in `apps/mcu/assets/configs`.
- **Rules**: `CONFIG_RULES.md` defines the schema for these configurations.

## Key Libraries
- `flutter_foreground_task`: For background processing.
- `isar`: Database.
- `lints`: Standard Dart/Flutter lints.

## Code Style Highlights
- **Imports**: Prefer package imports (`package:converter/...`) over relative imports, except for sibling files in the same package.
- **Exports**: Used liberally to expose public APIs from packages/modules.
- **Async**: `unawaited` used for fire-and-forget futures.
- **Logging**: `printLog` wrapper used instead of `print`.
