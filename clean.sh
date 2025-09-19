packages=(
  "apps/mcu"
  "modules/converter"
  "packages/core"
  "packages/core_storage_base"
  "packages/core_storage_isar"
  "packages/icons"
  "packages/l10n"
  "packages/mobile_ads"
  "packages/mobile_ads_google"
  "packages/platform_utils"
  "packages/utils"
)

for package in "${packages[@]}"
do
    (
    echo "🧹 Running flutter clean for $package ..."
    flutter clean
    echo "✅ Completed cleaning for $package"
    ) &
done

wait

echo ""
echo "🧹 Removing CocoaPods..."
rm apps/mcu/ios/Podfile.lock
rm -rf apps/mcu/ios/Pods

echo ""
echo "🧹 Running flutter pub get..."
./get.sh
./gen.sh