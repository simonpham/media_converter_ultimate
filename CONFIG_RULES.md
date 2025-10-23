# Configuration Structure Rules for FFmpeg UI (Updated)

This document specifies the canonical JSON schema and extraction rules used by the FFmpeg UI. It reflects the current shape of:
- per-format config files in `apps/mcu/assets/configs/supported_configurations/`
- the global `format.json` in `apps/mcu/assets/configs/`

Follow these rules when adding or updating configuration JSON files so the UI and argument-extraction logic remain compatible.

---

## 1. Files & Top-level layout

- Per-format configuration files live under:
  `apps/mcu/assets/configs/supported_configurations/<format>.json`
  Each such file has a set of top-level keys. The most common top-level key is the format name itself (e.g. `"mp3"`, `"mp4"`, `"wav"`). Example:
  ```apps/mcu/assets/configs/supported_configurations/mp3.json#L1-200
  (see the file's top-level keys such as "mp3", "configs.mp3.bitrate_type.cbr.value", ...)
  ```

- `format.json` describes supported formats and UI cosmetic data (gradients). Example:
  ```apps/mcu/assets/configs/format.json#L1-200
  (see "format" array which includes objects with "name", "output_extension", "output_type", and "should_add_to_args", and the "ui_gradients" map)
  ```

- A per-format file's top-level keys may be:
  - The format key (array of config objects), e.g. `"mp3": [ ... ]`.
  - Trigger keys (strings used as nested config keys), e.g. `"configs.mp3.bitrate_type.cbr.value": [ ... ]` or `"-c:v libx264": [ ... ]`. These appear when selecting an option should reveal additional options.

---

## 2. Configuration object (entry) — fields

Each item in a top-level array is a configuration object. Recognized fields:

- `type` (string) — control UI widget type. Common values:
  - `"dropdown"` — chooses one value from many.
  - `"single_choice"` — a single selection, often stores a full ffmpeg arg as the `value`.
  - `"radio_group"` — like single_choice but visually radio buttons; may alter visibility of nested groups.
  - `"multi_choice"` — zero-or-more options; collects multiple args.
  - Other UI types may exist; keep semantics consistent (single vs multiple selection).

- `name` (string) — internal config key (unique identifier) used to reference this control; NOT user-facing. Examples: `configs.mp3.audio_encoder`, `configs.wav.sampling_rate`.

- `label` (string, optional) — translation key for the visible UI label (user-facing). Always use a translation key, not literal English.

- `description` (string, optional) — translation key for a help/tooltip text.

- `should_add_to_args` (boolean, optional) — indicates whether the selected value(s) from this control should be included in the final ffmpeg argument list. If omitted, treat as `false`.

- `is_visible` (boolean, optional) — UI-only; whether the control should be shown by default. If omitted, treat as `true`.

- `ffmpeg_flag` (string | null, optional) — the ffmpeg flag prefix to use for this control when combining with an option's `value`. Examples: `"-b:a"`, `"-c:v"`, `"-ar"`. If `null`, the control expects its options to provide full argument strings (via `ffmpeg_arg` or `value` containing a full arg).

- `default` (string or JSON-stringified-array, optional) — the default selected value(s). For:
  - single selection/dropdown: a string representing the default option `value`.
  - multi-choice: often a JSON-stringified array (string) representing a list of full argument strings (see examples in supported files). The consumer should accept either a string or an array, but note that many files use a string containing JSON array (e.g. "[\"-map 0:v\", \"-map '0:a?'\"]").

- `options` (array) — list of option objects (see next section).

---

## 3. Option object — fields

Each element in `options` is an object describing a pickable item:

- `label` (string) — translation key for the option text (user-facing). May be empty when the option is a hidden mapping with a `value` (for example codec string).

- `value` (string) — one of:
  - a value to combine with the parent's `ffmpeg_flag` (e.g. `"192k"` to become `-b:a 192k`).
  - a full ffmpeg argument string (e.g. `"-c:v libx264"`). Files use these when the option represents an entire argument or when selecting it should reveal nested config keyed by the same string.
  - a top-level trigger key (e.g. `"configs.m4a.audio_encoder.value.aac"`) — selecting this value means the extraction logic should process the top-level key with that name and include its array of configuration objects.
  - a JSON-stringified array of arguments (rare in `value`, more common in `default`).

- `ffmpeg_arg` (string, optional) — when present, this string is used directly as an ffmpeg argument (e.g. `"-map_metadata 0:g"`). This is generally used when `ffmpeg_flag` is `null` at the parent control or when the option should supply a full argument regardless of the parent's flag.

- `description` (string, optional) — translation key for option-specific description/help.

Notes:
- An option may include either `value` (plus parent `ffmpeg_flag`) or `ffmpeg_arg`. If both are present, prefer `ffmpeg_arg` as the canonical full-argument value.
- If `value` exactly matches another top-level key, the UI code must treat it as a trigger for nested options.

---

## 4. Nested / conditional configurations

- If a selected option's `value` equals the name of another top-level key in the same JSON file, then treat that key as a nested configuration group and process its array of config objects in order.

- This pattern enables "select codec X" → "then show codec-specific controls".

- Examples of nested keys:
  - `configs.mp3.bitrate_type.cbr.value` → reveals a bitrate dropdown for CBR.
  - `"-c:v libx264"` → reveals `preset`/`profile` controls for libx264.

---

## 5. How to build ffmpeg arguments (extraction algorithm)

Given a concrete selection state (default or user choices), produce ffmpeg CLI args using the following rules:

1. Walk the array for the chosen top-level key (format) in order.

2. For each configuration object:
   - If `should_add_to_args` is false, skip adding args for this control (but still evaluate nested configs if the selected option triggers them).
   - Determine the selected item(s):
     - `single_choice`, `dropdown`, `radio_group`: single selected option.
     - `multi_choice`: set of selected options.
   - For each selected option:
     - If option has `ffmpeg_arg`, append that string as-is.
     - Else if parent `ffmpeg_flag` is non-null:
       - If option `value` is a string that represents multiple args (i.e., a JSON array string), parse it into elements and append each element as separate args.
       - Otherwise append `ffmpeg_flag` and the option `value` as separate list entries (i.e. `["-b:a", "192k"]`).
     - Else (parent `ffmpeg_flag` is null):
       - If option `value` starts with `-` treat it as a full argument and append it directly (this covers `"-c:v libx264"` and similar).
       - If option `value` matches another top-level key, do not emit immediate args — instead descend into that key and process its array.
       - If option `value` is a JSON-stringified array, parse and append each element.
       - Otherwise — if no ffmpeg_arg and no ffmpeg_flag — treat `value` as full-arg string and append it.

3. After emitting args for the current control, if the selected `value` matches another top-level key, recursively process that key's array (respecting its `should_add_to_args` flags and rules).

4. Preserve order: options and nested groups are processed in file order and nested processing happens immediately where triggered.

5. Multi-choice:
   - Collect all chosen options; for each, apply the same emission logic (ffmpeg_arg or ffmpeg_flag + value). `default` for `multi_choice` will often be a JSON-stringified array; parse it accordingly.

6. Quoting:
   - Files sometimes include single quotes inside args (e.g., `"-map '0:a?'"`). The consumer should not alter quoting semantics — pass them through exactly as strings.

---

## 6. Special fields & behaviors

- `should_add_to_args`:
  - When `true`, this control contributes to the final ffmpeg arguments per the rules above.
  - When `false`, the control is for UI selection or grouping only (but its selected value may still trigger nested keys which themselves may add args).

- `is_visible`: UI hint for whether to show the control. Hidden controls can still be defaults or trigger nested groups.

- `ffmpeg_flag`:
  - If present (non-null): combine with option `value` into a two-element argument pair.
  - If `null`: expect `ffmpeg_arg` on the option or the option `value` to be a full-argument string/array.

- `default` format:
  - Single value controls: default is a string equal to one option's `value`.
  - Multi-choice: defaults are often a JSON-stringified array string. Implementations should accept both literal arrays and stringified arrays (and normalize into in-memory arrays).

---

## 7. `format.json` schema

`apps/mcu/assets/configs/format.json` has two top-level keys:

- `format` (array of objects). Each entry:
  - `name` (string) — canonical short format name (matches the supported_configurations filename without extension).
  - `output_extension` (string) — file extension for exports.
  - `output_type` (string) — `"audio"` or `"video"`.
  - `should_add_to_args` (boolean) — whether selecting this format should add anything to ffmpeg args (UI / wrapper decision).

- `ui_gradients` (object) — map from format name to an array of 2 hex color strings for gradient display in the UI.

Use this file to:
- Populate the format picker.
- Apply format-specific metadata (extensions, UI colors).
- Verify whether format should be treated as audio or video for default common option groups.

---

## 8. Common configuration groups

- Common audio/video settings live in:
  - `apps/mcu/assets/configs/supported_configurations/common_audio.json`
  - `apps/mcu/assets/configs/supported_configurations/common_video.json`
- These use `ffmpeg_flag: null` for groups that emit complex or multiple args via `ffmpeg_arg` values in options (e.g., mappings, metadata copying).
- The consumer should include these groups for formats marked as `audio` or `video` as appropriate.

---

## 9. Localization

- All strings shown to users must be translation keys (`label`, `description`, option `label`). Do not include raw human-language strings in config JSON.
- Add corresponding keys to the localization pipeline for each new UI label/description.

---

## 10. Extensibility & best practices

- Keep option `value`s stable and, when possible, consistent across formats (e.g., bitrate keys, codec names). If a `value` becomes a trigger key (points to nested configs), use a clearly namespaced string (e.g. `configs.<format>.<...>` or a full arg like `-c:v libx264`).
- Prefer `ffmpeg_flag` + `value` for simple flag/value pairs (keeps options small).
- Use `ffmpeg_arg` when an option must emit a complete or complex argument regardless of parent flags.
- Use nested top-level keys to reveal codec-specific or mode-specific sub-controls.
- When adding fields, preserve backward compatibility; the UI should gracefully ignore unknown fields.

---

## 11. Examples

- Dropdown with `ffmpeg_flag` (bitrate):
  ```apps/mcu/assets/configs/supported_configurations/mp3.json#L1-200
  (see `-b:a` usage in the mp3 bitrate dropdown and the `ffmpeg_flag` + `options[].value` pattern)
  ```

- Single-choice that stores a full ffmpeg argument and triggers nested configs:
  ```apps/mcu/assets/configs/supported_configurations/mp4.json#L1-200
  (see the `default` `-c:v libx264` which has a matching top-level key `"-c:v libx264"` with its own child controls)
  ```

- `format.json` (format metadata + gradients):
  ```apps/mcu/assets/configs/format.json#L1-200
  (see `format` array entries and `ui_gradients` mapping)
  ```

---

If you add or change configuration files, please:
- Update localization keys used in `label` and `description`.
- Ensure `default` values correspond to one of the declared `options` (or to a valid JSON-stringified array for multi-choice).
- Add comments to your change PR explaining whether new `value`s represent raw ffmpeg args or nested trigger keys.

This document covers the currently used fields and extraction semantics. When introducing new patterns, update this file and the argument-extraction implementation together.