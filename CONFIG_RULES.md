# Configuration Structure Rules for FFmpeg UI

This document describes the standard structure for configuration files used to drive the FFmpeg UI. Follow these rules for all format-specific and common configuration files to ensure consistency and extensibility.

---

## 1. Top-Level Structure

- Each config file should have a single top-level key (e.g., `"mp3"`, `"common"`), whose value is an array of configuration objects.

---

## 2. Configuration Object Fields

- **type**: The UI element type (`"single_choice"`, `"multi_choice"`, `"radio_group"`, `"dropdown"`, etc.).
- **name**: Translation key for the UI label.
- **description**: Translation key for the UI description (optional).
- **ffmpeg_flag**: The FFmpeg flag to use for this option group (e.g., `"-b:a"`). If the option is a full argument, set to `null` and use `"ffmpeg_arg"` in options.
- **default**: The default value(s) for the option (string for single choice, array for multi choice).

---

## 3. Options Array

- Each option should be an object with:
  - **label**: Translation key for the option label.
  - **value**: The value to pass to the flag (if using `"ffmpeg_flag"`).
  - **ffmpeg_arg**: The full FFmpeg argument (if not using `"ffmpeg_flag"`).

---

## 4. Extraction Logic

- If `"ffmpeg_flag"` is set, combine it with the selected `"value"`:  
  `ffmpeg_flag value` (e.g., `-b:a 192k`)
- If `"ffmpeg_flag"` is `null`, use the selected `"ffmpeg_arg"` directly.
- For multi-choice, collect all selected values/args.

---

## 5. Localization

- All user-facing strings (labels, descriptions) must use translation keys.
- Add corresponding keys to your l10n files for each supported language.

---

## 6. Example

```json
{
  "mp3": [
    {
      "type": "dropdown",
      "name": "configs.mp3.bitrate_type.cbr.bitrate.label",
      "ffmpeg_flag": "-b:a",
      "default": "192k",
      "options": [
        { "label": "configs.mp3.bitrate_type.cbr.bitrate.320k", "value": "320k" }
      ]
    }
  ]
}
```

---

## 7. Extensibility

- Add new formats/configs by following this structure.
- Keep option extraction logic simple and uniform.
