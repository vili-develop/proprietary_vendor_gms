#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=common
VENDOR=gms

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" true

# Warning headers and guards
write_headers "arm64" "TARGET_ARCH"
sed -i 's/vendor\/gms\//vendor\/gms\/common/' "${PRODUCTMK}"

write_makefiles "${MY_DIR}/proprietary-files.txt" true

echo -e "\nPRODUCT_SOONG_NAMESPACES += vendor/$VENDOR/overlay" >> "$PRODUCTMK"
echo "PRODUCT_PACKAGES += GmsOverlay" >> "$PRODUCTMK"

# Remove PrebuiltGmsCore definition from Android.bp
awk '/name: "PrebuiltGmsCore"/ {
        start=NR-1;
        count=1
     }
     {
        count += gsub(/{/, "");
        count -= gsub(/}/, "");
        if (count == 0 && start) {
            print start "," NR+1 "d";
            start=0
        }
}' "$ANDROIDBP" | sed -f - -i "$ANDROIDBP"

# Compress to gzip to fulfil to github's 100M limit
cat <<EOF >>"${ANDROIDMK}"
\$(PRODUCT_OUT)/obj/GMS/PrebuiltGmsCore.apk: \$(MINIGZIP)
$(printf '\t')@rm -rf \$(dir \$@)
$(printf '\t')@mkdir -p \$(dir \$@)
$(printf '\t')@\$(MINIGZIP) -c -d vendor/gms/common/proprietary/product/priv-app/PrebuiltGmsCore/PrebuiltGmsCore.apk.gz > \$@

include \$(CLEAR_VARS)
LOCAL_MODULE := PrebuiltGmsCore
LOCAL_MODULE_CLASS := APPS
LOCAL_PRODUCT_MODULE := true
LOCAL_PRIVILEGED_MODULE := true
LOCAL_DEX_PREOPT := false
LOCAL_ENFORCE_USES_LIBRARIES := false
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_SRC_FILES := \$(PRODUCT_OUT)/obj/GMS/PrebuiltGmsCore.apk
LOCAL_REPLACE_PREBUILT_APK_INSTALLED := \$(LOCAL_SRC_FILES)
include \$(BUILD_PREBUILT)

EOF
gzip -f "${ANDROID_ROOT}/${OUTDIR}/proprietary/product/priv-app/PrebuiltGmsCore/PrebuiltGmsCore.apk"

# Finish
write_footers
