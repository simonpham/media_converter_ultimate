# AI Agent Rules

## General
- **Dart Version**: Use Dart 3.8+ features (patterns, records, class modifiers).
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
  - Use `Injector` to access dependencies.
  - Register new dependencies in the appropriate `Injector` (e.g., `ConverterInjector` for converter module).

## UI & Design System
- **Components**:
  - **MUST** use `package:design_system` components over raw Material widgets.
  - Use `Button` (with `ButtonVariant`) instead of `ElevatedButton`, `TextButton`, etc.
  - Use `Tappable` for custom interactive areas.
  - Use `ImageView` for icons and images.
- **Styling**:
  - **NEVER** hardcode colors. Use `ThemeConfigs().theme.colors` or `context.theme.colorScheme`.
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
- **Strings**: Use `context.l10n` for all user-facing strings. Do not hardcode English strings.
- **Constructors**: Use `const` constructors whenever possible.

## Configuration
- **FFmpeg**: When modifying `apps/mcu/assets/configs`, strictly follow `CONFIG_RULES.md`.
