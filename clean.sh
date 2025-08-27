echo "🧹 Running flutter clean..."
flutter clean

echo ""
echo "🧹 Removing CocoaPods..."
rm apps/mcu/ios/Podfile.lock
rm -rf apps/mcu/ios/Pods

echo ""
echo "🧹 Running flutter pub get..."
./get.sh
./gen.sh