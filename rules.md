# AI Agent Rules

## General
- **Dart Version**: Use Dart 3.13+ features (dot shorthands, primary constructors, patterns, records, class modifiers, workspace resolution).
- **Dot Shorthands**: Use dot shorthands (`.foo`, `.all()`, `.circular()`, `.center`, `.bold`, `.new()`) wherever context type is clearly defined to reduce boilerplate.
- **Primary Constructors**: Use primary constructors for classes, data models, widgets, and enhanced enums to streamline field declarations and eliminate redundant constructor bodies.
- **Lints**: Strictly follow `analysis_options.yaml`. Ensure no new lint errors are introduced.
- **Imports**:
  - ALWAYS use `package:` imports for files in other packages/modules.
  - Relative imports are allowed ONLY for files within the same directory or subdirectories of the current package.
  - Sort imports: Dart -> Package -> Relative.

## Architecture
- **Layering**:
  - `apps` depends on `modules` and `packages`.
  - `modules` depends on `packages`.
  - `packages` should not depend on `apps` or `modules`.
- **Dependency Injection**:
  - Use `injector<T>()` to access dependencies.
  - Register new dependencies in the appropriate `Injector` (e.g., `ConverterInjector` for converter module).
- **File Management**:
  - Use `injector<FileService>()` for file picker, temporary cache, and directory resolution (do not use raw static utilities).

## UI & Design System
- **Components**:
  - **MUST** use `package:design_system` components over raw Material widgets.
  - Use `Button` (with `ButtonVariant`) instead of `ElevatedButton`, `TextButton`, etc.
  - Use `Tappable` for custom interactive areas.
  - Use `ImageView` for icons and images.
  - Use `Scrollbar` with `thumbVisibility: true` for scrollable steps and lists.
- **Styling**:
  - **NEVER** hardcode colors. Use `context.theme.colorScheme` or `context.theme`. Do not use deprecated `ThemeConfigs`.
  - **NEVER** hardcode dimensions. Use `Spacing` class (e.g., `Spacing.d16`, `Spacing.v8`).
  - Use `Assets` class for all image/icon assets.

## State Management
- **Provider**: Use `ChangeNotifierProvider` for ViewModels.
- **ViewModels**:
  - Should extend `ChangeNotifier`.
  - Business logic should reside in ViewModels, not UI widgets.
- **Consumption**: Use `Consumer` or `Selector` to listen to changes.

## Coding Style
- **Async**: Use `unawaited(...)` for Futures that are intentionally not awaited.
- **Logging**: Use `printLog(...)` instead of `print(...)`.
- **Strings**: Use `context.l10n` for all user-facing strings across all 11 supported languages. Do not hardcode English strings.
- **Constructors**: Use `const` constructors whenever possible.

## Configuration & Testing
- **FFmpeg**: When modifying `apps/mcu/assets/configs`, strictly follow `CONFIG_RULES.md`.
- **Validation**:
  - Run `./validate.sh` to ensure JSON schemas, cross-file mappings, and 11-language l10n parity are 100% valid.
  - Run `./test_ffmpeg.sh` to verify that FFmpeg commands build and execute properly.
