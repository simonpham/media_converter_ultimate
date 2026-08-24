#!/usr/bin/env bash
set -e

# Run MCU FFmpeg Configuration End-to-End Live Validator
dart run apps/mcu_configs/bin/test_ffmpeg.dart
