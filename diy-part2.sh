#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate

#!/bin/bash
# diy-part2.sh
# 执行时机：feeds update + install 之后，make defconfig/download 之前

set -e

# ============================================================
# 1. 修复 simple-obfs 的 isdigit 补丁（解决 fuzz / 截断问题）
# ============================================================
OBFS_PATCH="feeds/helloworld/simple-obfs/patches/001-convert-arguments-of-isdigit-to-int.patch"

if [ -f "$OBFS_PATCH" ]; then
    echo ">>> Rewriting $OBFS_PATCH"
    cat > "$OBFS_PATCH" << 'EOF'
From bc8014cd6637798ee96b9394c716eff46115c002 Mon Sep 17 00:00:00 2001
From: DDoSolitary <DDoSolitary@gmail.com>
Date: Thu, 12 Mar 2020 12:15:37 +0800
Subject: [PATCH] Convert arguments of isdigit to int.

---
 src/utils.c | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/src/utils.c b/src/utils.c
index 67cc250..514a001 100644
--- a/src/utils.c
+++ b/src/utils.c
@@ -92,7 +92,7 @@ int
 ss_isnumeric(const char *s) {
     if (!s || !*s)
         return 0;
-    while (isdigit(*s))
+    while (isdigit((int)*s))
         ++s;
     return *s == '\0';
 }
EOF
else
    echo ">>> WARNING: $OBFS_PATCH not found, skip"
fi

# ============================================================
# 2. 修复 mac80211 的 netns_local 补丁（适配 6.12.114 内核）
# ============================================================
MAC80211_PATCH="package/kernel/mac80211/patches/build/210-wireless_netns_local_backport.patch"

if [ -d "package/kernel/mac80211/patches/build" ]; then
    echo ">>> Rewriting $MAC80211_PATCH"
    cat > "$MAC80211_PATCH" << 'EOF'
--- a/net/wireless/core.c
+++ b/net/wireless/core.c
@@ -162,11 +162,19 @@ int cfg80211_switch_netns(struct cfg8021
 	list_for_each_entry(wdev, &rdev->wiphy.wdev_list, list) {
 		if (!wdev->netdev)
 			continue;
+#if LINUX_VERSION_IS_GEQ(6,15,0)
 		wdev->netdev->netns_immutable = false;
+#elif LINUX_VERSION_IS_GEQ(6,12,0)
+		wdev->netdev->netns_local = false;
+#endif
 		err = dev_change_net_namespace(wdev->netdev, net, "wlan%d");
 		if (err)
 			break;
+#if LINUX_VERSION_IS_GEQ(6,15,0)
 		wdev->netdev->netns_immutable = true;
+#elif LINUX_VERSION_IS_GEQ(6,12,0)
+		wdev->netdev->netns_local = true;
+#endif
 	}
 
 	if (err) {
@@ -178,11 +186,19 @@ int cfg80211_switch_netns(struct cfg8021
 						     list) {
 			if (!wdev->netdev)
 				continue;
+#if LINUX_VERSION_IS_GEQ(6,15,0)
 			wdev->netdev->netns_immutable = false;
+#elif LINUX_VERSION_IS_GEQ(6,12,0)
+			wdev->netdev->netns_local = false;
+#endif
 			err = dev_change_net_namespace(wdev->netdev, net,
 							"wlan%d");
 			WARN_ON(err);
+#if LINUX_VERSION_IS_GEQ(6,15,0)
 			wdev->netdev->netns_immutable = true;
+#elif LINUX_VERSION_IS_GEQ(6,12,0)
+			wdev->netdev->netns_local = true;
+#endif
 		}
 
 		return err;
@@ -1549,7 +1565,11 @@ static int cfg80211_netdev_notifier_call
 		SET_NETDEV_DEVTYPE(dev, &wiphy_type);
 		wdev->netdev = dev;
 		/* can only change netns with wiphy */
+#if LINUX_VERSION_IS_GEQ(6,15,0)
 		dev->netns_immutable = true;
+#elif LINUX_VERSION_IS_GEQ(6,12,0)
+		dev->netns_local = true;
+#endif
 
 		cfg80211_init_wdev(wdev);
 		break;
EOF
else
    echo ">>> WARNING: mac80211 patches dir not found, skip"
fi

echo ">>> diy-part2.sh done"
