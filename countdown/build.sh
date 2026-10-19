#!/bin/zsh
# Builds Birthday-Countdown.apk (run from anywhere). Needs the Android SDK build-tools and Java 21 already on this Mac.
set -e
cd "$(dirname "$0")"
SDK=~/Library/Android/sdk; BT=$SDK/build-tools/36.0.0; JAR=$SDK/platforms/android-36/android.jar
export PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH
OUT=build; mkdir -p $OUT/gen $OUT/classes
$BT/aapt2 compile --dir res -o $OUT/res.zip
$BT/aapt2 link -o $OUT/base.apk -I $JAR --manifest AndroidManifest.xml --java $OUT/gen $OUT/res.zip --min-sdk-version 24 --target-sdk-version 36
javac -source 8 -target 8 -classpath $JAR -d $OUT/classes $(find src $OUT/gen -name '*.java') 2>&1 | grep -v "warning" || true
$BT/d8 --lib $JAR --min-api 24 --output $OUT $(find $OUT/classes -name '*.class')
cp $OUT/base.apk $OUT/unsigned.apk
(cd $OUT && zip -q -u unsigned.apk classes.dex)
$BT/zipalign -f 4 $OUT/unsigned.apk $OUT/aligned.apk
$BT/apksigner sign --ks ~/.android/debug.keystore --ks-pass pass:android --key-pass pass:android --out ../Birthday-Countdown.apk $OUT/aligned.apk
$BT/apksigner verify ../Birthday-Countdown.apk && echo "built: Birthday-Countdown.apk"
