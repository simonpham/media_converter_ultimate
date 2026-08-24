#!/usr/bin/env bash
set -e

echo "=================================================="
echo "   Running Monorepo Flutter & Dart Test Suites    "
echo "=================================================="

echo "==> 1. Running JSON Schema & Localization Validator..."
./validate.sh

echo ""
echo "==> 2. Running Flutter Unit & Model Tests..."
flutter test apps/mcu packages/core modules/converter

echo ""
echo "🎉 All Flutter & Dart test suites passed successfully!"
