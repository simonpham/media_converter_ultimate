#!/usr/bin/env bash
set -e

echo "=================================================="
echo "   Running Monorepo Flutter & Dart Test Suites    "
echo "=================================================="

echo "==> 1. Running JSON Schema & Localization Validator..."
./validate.sh

echo ""
echo "==> 2. Running Flutter Unit & Model Tests..."
flutter test apps/mcu/test packages/core/test packages/core_storage_isar/test packages/sofluffy_ui/test packages/platform_utils/test modules/converter/test

echo ""
echo "==> 3. Checking the isolated Android background QA launcher..."
python3 tools/test_android_background_helper.py

echo ""
echo "🎉 All Flutter & Dart test suites passed successfully!"
