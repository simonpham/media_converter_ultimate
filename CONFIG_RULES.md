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

## 8. Common configuration groups & Metadata / Album Art Preservation

- Common audio/video settings live in:
  - `apps/mcu/assets/configs/supported_configurations/common_audio.json`
  - `apps/mcu/assets/configs/supported_configurations/common_video.json`
- These use `ffmpeg_flag: null` for groups that emit complex or multiple args via `ffmpeg_arg` values in options (e.g., mappings, metadata copying).
- The consumer should include these groups for formats marked as `audio` or `video` as appropriate.
- **Global Metadata Preservation**:
  - Both `common_audio.json` and `common_video.json` enable `-map_metadata 0:g` by default under `configs.common.*.recommended_args`. This copies global tags (title, artist, album, genre, track, date, etc.) from input 0.
- **Cover / Album Art Preservation**:
  - Embedded cover artwork is stored as a video stream with disposition `attached_pic` (e.g., JPEG/PNG).
  - Pure audio containers that support attached picture streams (`mp3`, `flac`, `m4a`, `wma`, `mka`) MUST declare an attached picture preservation control using `"-map 0:v:disp:attached_pic?"` and `"-c:v copy"`.
  - The `0:v:disp:attached_pic?` stream specifier with trailing `?` ensures that:
    - Audio with embedded artwork preserves the image stream.
    - Video inputs (e.g., MP4 with H.264) converted to audio do NOT incorrectly map full video tracks into the audio container.
    - Audio without artwork converts cleanly without stream-missing errors.
  - Raw bitstreams or containers without video support (e.g., `aac`, `wav`, `ac3`, `eac3`, `amr`, `caf`, `opus`, `ogg`) must NOT map attached picture streams, as FFmpeg will reject video streams for those muxers.

---

### Runtime stream compatibility

The runner resolves the common optional maps using probed stream metadata before
encoding. `MediaStreamMapping` chooses the source's default audio track (or first
if no default is flagged) for formats supporting one audio track, and retains all
mapped audio tracks for formats supporting multiple tracks. Explicit audio maps
are unchanged. The stable configuration values remain the same.

Optional subtitles retain compatible tracks: text becomes MOV text for MP4/MOV/
3GP or WebVTT for WebM; Matroska copies supported text/bitmap tracks and converts
other supported text to SubRip. Regular TS uses DVB subtitle signalling; PGS
requires Blu-ray M2TS signalling and is omitted from the default TS output. Formats
without a compatible subtitle encoder/container omit those optional tracks. The
option's localized help explains this. Explicit subtitle maps/encoders retain
their specified behavior.

When adding a format or changing mappings, maintain the runtime compatibility
policy and run `apps/mcu/integration_test/native_multitrack_test.dart` on the
bundled Android engine. The host CLI matrix does not run the probe-based policy.
The native fixture covers multiple audio languages, UTF-8 text subtitles, owned
PGS/DVB bitmaps, track preservation, and decoding all 25 default outputs.

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

## 12. Guide & Checklist for Adding New Formats & Configs

Follow this checklist whenever adding a new format or editing configuration files to prevent runtime errors:

### Step 1: Register in `apps/mcu/assets/configs/format.json`
- Add entry to the `"format"` array:
  - `name`: format identifier (must match the filename `<name>.json` in `supported_configurations/`).
  - `output_extension`: file extension without dot (e.g. `"mp4"`).
  - `output_type`: `"audio"` or `"video"`.
  - `should_add_to_args`: **IMPORTANT RULE**:
    - Set to `true` **ONLY** if FFmpeg has a matching `-f <name>` muxer (e.g., `mp3`, `mp4`, `flac`, `wav`, `ogg`, `opus`, `mov`, `webm`, `avi`, `flv`, `aiff`, `ac3`, `eac3`, `gif`).
    - Set to `false` if the short name is **not** a direct FFmpeg `-f` muxer (e.g., `m4a` uses `ipod`/`mp4`, `mkv` uses `matroska`, `wma`/`wmv` uses `asf`, `mka` uses `matroska`, `ogv` uses `ogg`, `ts`, `3gp`, `caf`, `aac`). When `false`, FFmpeg automatically infers the container from the output filename extension.
- Add matching 2-color gradient to `"ui_gradients"` (e.g. `"ac3": ["#f857a6", "#ff5858"]`).

### Step 2: Create `apps/mcu/assets/configs/supported_configurations/<name>.json`
- Top-level key must match the format `name` (e.g. `"ac3": [ ... ]`).
- **Single Required Parameters (Hidden Encoders)**:
  - If a format has only 1 required encoder/parameter (e.g. Opus, FLAC, AAC, AC3, AMR, WMA, Theora), define it with `"is_visible": false`, `"type": "single_choice"`, `"should_add_to_args": true`, and an empty option label `""`.
  - **Do NOT** show redundant 1-item dropdowns to the user.
- **Multiple Fixed Arguments (Mappings)**:
  - Use `"type": "multi_choice"` with `"default": "[\"-map 0:v:0\", \"-map 0:a:0\"]"` where each item in `options` has an `ffmpeg_arg` matching one of the array elements.
- **Embedded Cover / Album Art Support (Audio Formats)**:
  - For audio containers supporting embedded image streams (`mp3`, `flac`, `m4a`, `wma`, `mka`), include an album art control:
    ```json
    {
      "type": "multi_choice",
      "name": "configs.<format>.album_art",
      "label": "configs.common.album_art.label",
      "description": "configs.common.album_art.desc",
      "should_add_to_args": true,
      "ffmpeg_flag": null,
      "default": "[\"-map 0:v:disp:attached_pic?\", \"-c:v copy\"]",
      "options": [
        {
          "label": "configs.common.album_art.preserve",
          "ffmpeg_arg": "-map 0:v:disp:attached_pic?"
        },
        {
          "label": "configs.common.album_art.copy_codec",
          "ffmpeg_arg": "-c:v copy"
        }
      ]
    }
    ```
  - Do **NOT** add this to raw bitstream or non-image-supporting audio containers (`aac`, `wav`, `ac3`, `eac3`, `amr`, `caf`, `opus`, `ogg`).
- **Nested Controls**:
  - When selecting an option needs to reveal sub-controls (e.g., `-c:v libx264` revealing CRF and preset dropdowns), add a top-level key matching the option's `value` (e.g. `"-c:v libx264": [ ... ]`).

### Step 3: Add Localization Keys in `apps/mcu/assets/configs/l10n/`
- Every user-facing string (`label`, `description`, option `label`) must be a translation key (e.g. `ui_codec_description.libx265`, `configs.common.crf.label`).
- Update **all 12 language files** in `apps/mcu/assets/configs/l10n/`:
  - `en.json`, `zh.json`, `zh_TW.json`, `de.json`, `es.json`, `id.json`, `it.json`, `ja.json`, `pt.json`, `ru.json`, `tr.json`, `vi.json`.

### Step 4: Validate
- Run `./validate.sh` from the repository root:
  - Checks `format.json` against `format.schema.json`.
  - Checks all files in `supported_configurations/` against `supported_configurations.schema.json`.
  - Validates `default` selections against declared `options`.
  - Validates cross-file parity between `format.json` and `supported_configurations/`.
  - Checks that every declared format has a UI gradient.

---

This document covers the currently used fields and extraction semantics. When introducing new patterns, update this file and the argument-extraction implementation together.