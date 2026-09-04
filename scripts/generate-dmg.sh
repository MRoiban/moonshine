# This script requires create-dmg to be installed from https://github.com/sindresorhus/create-dmg
BUILD_CONFIG=$1

fail()
{
	echo "$1" 1>&2
	exit 1
}

if [ "$BUILD_CONFIG" != "Debug" ] && [ "$BUILD_CONFIG" != "Release" ]; then
  fail "Invalid build configuration - expected 'Debug' or 'Release'"
fi

BUILD_ROOT=$PWD/build
SOURCE_ROOT=$PWD
BUILD_FOLDER=$BUILD_ROOT/build-$BUILD_CONFIG
INSTALLER_FOLDER=$BUILD_ROOT/installer-$BUILD_CONFIG
APPLE_DEVICE_ARCHS=${QMAKE_APPLE_DEVICE_ARCHS:-$(uname -m)}

if [ -n "$CI_VERSION" ]; then
  VERSION=$CI_VERSION
else
  VERSION=`cat $SOURCE_ROOT/app/version.txt`
fi

if [ "$SIGNING_PROVIDER_SHORTNAME" == "" ]; then
  SIGNING_PROVIDER_SHORTNAME=$SIGNING_IDENTITY
fi
if [ "$SIGNING_IDENTITY" == "" ]; then
  SIGNING_IDENTITY=$SIGNING_PROVIDER_SHORTNAME
fi

[ "$SIGNING_IDENTITY" == "" ] || git diff-index --quiet HEAD -- || fail "Signed release builds must not have unstaged changes!"

echo Updating dependencies
python3 $SOURCE_ROOT/setup-deps.py

echo Cleaning output directories
rm -rf $BUILD_FOLDER
rm -rf $INSTALLER_FOLDER
mkdir $BUILD_ROOT
mkdir $BUILD_FOLDER
mkdir $INSTALLER_FOLDER

# Enable LTO for official builds
export CFLAGS=-flto=thin
export CXXFLAGS=-flto=thin
export LDFLAGS=-flto=thin

echo Configuring the project
echo "Building for macOS architecture(s): $APPLE_DEVICE_ARCHS"
pushd $BUILD_FOLDER
qmake $SOURCE_ROOT/moonlight-qt.pro QMAKE_APPLE_DEVICE_ARCHS="$APPLE_DEVICE_ARCHS" CONFIG+=no-release-dmg || fail "Qmake failed!"
popd

echo Compiling Moonlight in $BUILD_CONFIG configuration
mkdir -p $BUILD_FOLDER/app
pushd $BUILD_FOLDER/app
qmake $SOURCE_ROOT/app/app.pro QMAKE_APPLE_DEVICE_ARCHS="$APPLE_DEVICE_ARCHS" || fail "App qmake failed!"
make -f Makefile.Release mocables || fail "MOC generation failed!"
popd

pushd $BUILD_FOLDER
make -j$(sysctl -n hw.logicalcpu) $(echo "$BUILD_CONFIG" | tr '[:upper:]' '[:lower:]') || fail "Make failed!"
popd

echo Saving dSYM file
pushd $BUILD_FOLDER
dsymutil app/Moonlight.app/Contents/MacOS/Moonlight -o Moonlight-$VERSION.dsym || fail "dSYM creation failed!"
cp -R Moonlight-$VERSION.dsym $INSTALLER_FOLDER || fail "dSYM copy failed!"
popd

echo Creating app bundle
EXTRA_ARGS=
if [ "$BUILD_CONFIG" == "Debug" ]; then EXTRA_ARGS="$EXTRA_ARGS -use-debug-libs"; fi
echo Extra deployment arguments: $EXTRA_ARGS
macdeployqt $BUILD_FOLDER/app/Moonlight.app $EXTRA_ARGS -qmldir=$SOURCE_ROOT/app/gui -appstore-compliant || fail "macdeployqt failed!"

echo Removing dSYM files from app bundle
find $BUILD_FOLDER/app/Moonlight.app/ -name '*.dSYM' | xargs rm -rf

if [ "$SIGNING_IDENTITY" != "" ]; then
  echo Signing app bundle
  codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" $BUILD_FOLDER/app/Moonlight.app || fail "Signing failed!"
fi

echo Creating DMG
DMG_OUTPUT=$INSTALLER_FOLDER/Moonlight.dmg
rm -f "$DMG_OUTPUT"
if [ "$SIGNING_IDENTITY" != "" ]; then
  create-dmg --volname Moonlight --app-drop-link 425 120 --codesign "$SIGNING_IDENTITY" "$DMG_OUTPUT" $BUILD_FOLDER/app || fail "create-dmg failed!"
else
  create-dmg --volname Moonlight --app-drop-link 425 120 "$DMG_OUTPUT" $BUILD_FOLDER/app
  case $? in
    0) ;;
    2) ;;
    *) fail "create-dmg failed!";;
  esac
fi

if [ "$NOTARY_KEYCHAIN_PROFILE" != "" ]; then
  echo Uploading to App Notary service
  xcrun notarytool submit --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait $INSTALLER_FOLDER/Moonlight.dmg || fail "Notary submission failed"

  echo Stapling notary ticket to DMG
  xcrun stapler staple -v $INSTALLER_FOLDER/Moonlight.dmg || fail "Notary ticket stapling failed!"
fi

mv $INSTALLER_FOLDER/Moonlight.dmg $INSTALLER_FOLDER/Moonlight-$VERSION.dmg
echo Build successful
