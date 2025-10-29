#!/bin/bash
ROOTDIR=$(pwd)
echo $ROOTDIR
if [ ! -e "$ROOTDIR/build" ]; then
    echo "Please run from root / no build dir"
    exit 1
fi

OPENWRT_BRANCH=24.10

cd "$ROOTDIR/build"

# clone stangri repo
rm -rf stangri_repo
mkdir stangri_repo
cd stangri_repo
# stick to version 1.1.8 of pbr for now
git clone -b 1.1.8 https://github.com/stangri/pbr.git
git clone -b 1.1.8 https://github.com/stangri/luci-app-pbr.git
#git clone https://github.com/stangri/source.openwrt.melmac.net stangri_repo
cd ..

# clone kenzok8 repos for specific packages
rm -rf kenzok8_packages kenzok8_small
git clone --depth=1 https://github.com/kenzok8/openwrt-packages.git kenzok8_packages
git clone --depth=1 https://github.com/kenzok8/small.git kenzok8_small

# install feeds
cd openwrt
./scripts/feeds update -a

# replace pbr packages
rm -rf feeds/packages/net/pbr/
cp -R ../stangri_repo/pbr feeds/packages/net/
rm -rf feeds/luci/applications/luci-app-pbr
cp -R ../stangri_repo/luci-app-pbr feeds/luci/applications/

# replace adguardhome with prebuilt latest version
rm -rf feeds/packages/net/adguardhome
cp -R $ROOTDIR/openwrt-$OPENWRT_BRANCH/patches/package/adguardhome feeds/packages/net/

./scripts/feeds update -i && ./scripts/feeds install -a

# add kenzok8 packages (argon theme, argon config, smartdns)
mkdir -p package/custom

# argon theme and config from kenzok8_packages
if [ -d "../kenzok8_packages/luci-theme-argon" ]; then
    cp -R ../kenzok8_packages/luci-theme-argon package/custom/
fi
if [ -d "../kenzok8_packages/luci-app-argon-config" ]; then
    cp -R ../kenzok8_packages/luci-app-argon-config package/custom/
fi

# smartdns from kenzok8_small
if [ -d "../kenzok8_small/smartdns" ]; then
    cp -R ../kenzok8_small/smartdns package/custom/
fi
if [ -d "../kenzok8_small/luci-app-smartdns" ]; then
    cp -R ../kenzok8_small/luci-app-smartdns package/custom/
fi

# Time stamp with $Build_Date=$(date +%Y.%m.%d)
MANUAL_DATE="$(date +%Y.%m.%d) (manual build)"
BUILD_STRING=${BUILD_STRING:-$MANUAL_DATE}
echo "Write build date in openwrt : $BUILD_STRING"
echo -e '\nTJT-JTJ Build@'${BUILD_STRING}'\n'  >> package/base-files/files/etc/banner
#sed -i '/DISTRIB_REVISION/d' package/base-files/files/etc/openwrt_release
#echo "DISTRIB_REVISION='${BUILD_STRING}'" >> package/base-files/files/etc/openwrt_release
sed -i '/DISTRIB_DESCRIPTION/d' package/base-files/files/etc/openwrt_release
echo "DISTRIB_DESCRIPTION='TJT-JTJ Build@${BUILD_STRING}'" >> package/base-files/files/etc/openwrt_release
#sed -i '/luciversion/d' feeds/luci/modules/luci-base/luasrc/version.lua

rm -rf .config
