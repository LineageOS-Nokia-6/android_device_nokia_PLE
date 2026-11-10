#!/vendor/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Exact619F cache only. Never erase a cache, invent readiness, select a carrier,
# invoke QMI/provisioning tools, or touch firmware/persist/NV block devices.
set -efu
umask 027
test "$(getprop ro.product.device)" = PLE
firmware=/vendor/firmware_mnt
manifest=/vendor/etc/radio/PLE-mcfg619F.sha256
data=/data/vendor
base=$data/modem_config
atl=$data/fih_atl/modem_config
model=$data/fih_mcfg
configs=$firmware/image/modem_pr/mcfg/configs
test -f "$manifest" && test ! -L "$manifest"
(cd "$firmware" && sha256sum -c "$manifest") >/dev/null

safe_path() {
    local path=$1
    case "$path" in "$data"/*) ;; *) return 1;; esac
    while test "$path" != "$data"; do
        test ! -L "$path"
        path=${path%/*}
        if test -e "$path"; then
            test -d "$path"
            test ! -L "$path"
        fi
    done
}
seen='|'
base_old='' base_new='' atl_old='' atl_new='' model_old='' model_new=''
missing_dirs='' all_files='' preimages='' final_images=''
files_base='' files_shared='' files_version='' files_lock=''
copy_base='' copy_atl='' copy_base_version=0 copy_model_version=0 copy_selector=0

# Collect only; ALL source and existing-target checks finish before any write.
collect_dir() {
    local path=$1
    test "$path" != "$data" || return 0
    case "$seen" in *"|$path|"*) return 0;; esac
    collect_dir "${path%/*}"
    test ! -L "$path"
    if test -e "$path"; then
        test -d "$path"
        case "$path" in
            "$base"|"$base"/*) base_old="$base_old $path";;
            "$model") model_old="$model_old $path";;
            "$data/fih_atl"|"$atl"|"$atl"/*) atl_old="$atl_old $path";;
            *) return 1;;
        esac
    else
        missing_dirs="$missing_dirs $path"
        case "$path" in
            "$base"|"$base"/*) base_new="$base_new $path";;
            "$model") model_new="$model_new $path";;
            "$data/fih_atl"|"$atl"|"$atl"/*) atl_new="$atl_new $path";;
            *) return 1;;
        esac
    fi
    seen=$seen$path'|'
}

record_file() {
    local target=$1 expected=$2 mode=$3 owner=$4
    safe_path "$target"
    if test -e "$target"; then
        test -f "$target"
        preimages="$preimages$expected  $target
"
    fi
    final_images="$final_images$expected  $target
"
    all_files="$all_files $target"
    collect_dir "${target%/*}"
    case "$mode:$owner" in
        0440:1001:0) files_base="$files_base $target";;
        0776:1000:2901) files_shared="$files_shared $target";;
        0440:1001:2901) files_version="$files_version $target";;
        0444:1000:2901) files_lock="$files_lock $target";;
        *) return 1;;
    esac
}

visit() {
    local source=$1 target=$2 expected=$3 mode=$4 owner=$5
    record_file "$target" "$expected" "$mode" "$owner"
    test ! -e "$target" || return 0
    # Only explicit manifest-selected files, never recursive/unlisted firmware.
    case "$target" in
        "$base/ver_info.txt") copy_base_version=1;;
        "$model/ver_info.txt") copy_model_version=1;;
        "$atl/mcfg_sw/oem_sw.txt") copy_selector=1;;
        "$base"/*)
            case "$source" in "$configs"/*) ;; *) return 1;; esac
            copy_base="$copy_base ${source#"$configs"/}";;
        "$atl"/*)
            case "$source" in "$configs"/*) ;; *) return 1;; esac
            copy_atl="$copy_atl ${source#"$configs"/}";;
        *) return 1;;
    esac
}
text_file() {
    local target=$1 value=$2 mode=$3 owner=$4 expected
    expected=$(printf '%s' "$value" | sha256sum)
    record_file "$target" "${expected%% *}" "$mode" "$owner"
}
walk_manifest() {
    local hash relative extra name
    local hardware=0 ple=0 version=0
    while read -r hash relative extra; do
        test -z "$extra" && test "${#hash}" = 64
        case "$hash" in *[!0-9a-f]*) return 1;; esac
        case "$relative" in /*|../*|*/../*|*/..|*[!a-zA-Z0-9_./+-]*) return 1;; esac
        case "$relative" in
            image/modem_pr/mcfg/configs/*)
                name=${relative#image/modem_pr/mcfg/configs/}
                if test "$name" = mcfg_hw/oem_hw.txt; then hardware=1; fi
                visit "$firmware/$relative" "$base/$name" "$hash" 0440 1001:0
                # Exact PLE stock uses oem_ple only for its FIH cache selector.
                if test "$name" != mcfg_sw/oem_sw.txt; then
                    visit "$firmware/$relative" "$atl/$name" "$hash" 0776 1000:2901
                fi
                if test "$name" = mcfg_sw/oem_ple.txt; then
                    ple=1
                    visit "$firmware/$relative" "$atl/mcfg_sw/oem_sw.txt" "$hash" 0776 1000:2901
                fi;;
            verinfo/ver_info.txt)
                version=1
                visit "$firmware/$relative" "$base/ver_info.txt" "$hash" 0440 1001:0
                visit "$firmware/$relative" "$model/ver_info.txt" "$hash" 0440 1001:2901;;
            *) return 1;;
        esac
    done < "$manifest"
    test "$hardware:$ple:$version" = 1:1:1
    text_file "$model/fih_model.txt" '00WW
' 0776 1000:2901
    text_file "$model/dev_model.txt" 'PLE
' 0776 1000:2901
    text_file "$model/fih_mcfg.lock" '' 0444 1000:2901
}
# Existing utilities receive bounded batches. Paths contain no whitespace or
# shell metacharacters (manifest validation above); glob expansion is disabled.
check_paths() {
    local target
    for target in $all_files; do
        safe_path "$target"
        if test -e "$target"; then test -f "$target"
        elif test "$1" = complete; then return 1
        fi
    done
}
verify_list() {
    if test -n "$1"; then printf '%s' "$1" | sha256sum -c >/dev/null; fi
}
fix_metadata() {
    local mode=$1 owner=$2
    shift 2
    test "$#" -gt 0 || return 0
    chmod "$mode" "$@"
    chown "$owner" "$@"
}
write_text() {
    if test ! -e "$1"; then (set -C; printf '%s' "$2" > "$1"); fi
}

walk_manifest
check_paths preflight
verify_list "$preimages"

# Existing base directories may be finalized0550; restore only their intended
# writable group before creating missing children. Never change /data/vendor.
fix_metadata 0570 1001:0 $base_old
fix_metadata 0776 1000:2901 $atl_old
fix_metadata 2775 1000:2901 $model_old
if test -n "$missing_dirs"; then mkdir -p -- $missing_dirs; fi
fix_metadata 0570 1001:0 $base_new
fix_metadata 0776 1000:2901 $atl_new
fix_metadata 2775 1000:2901 $model_new
check_paths preflight
if test -n "$copy_base"; then (cd "$configs" && cp -n --parents -- $copy_base "$base"); fi
if test -n "$copy_atl"; then (cd "$configs" && cp -n --parents -- $copy_atl "$atl"); fi
if test "$copy_base_version" = 1; then cp -n "$firmware/verinfo/ver_info.txt" "$base/ver_info.txt"; fi
if test "$copy_model_version" = 1; then cp -n "$firmware/verinfo/ver_info.txt" "$model/ver_info.txt"; fi
if test "$copy_selector" = 1; then cp -n "$configs/mcfg_sw/oem_ple.txt" "$atl/mcfg_sw/oem_sw.txt"; fi
write_text "$model/fih_model.txt" '00WW
'
write_text "$model/dev_model.txt" 'PLE
'
write_text "$model/fih_mcfg.lock" ''
check_paths complete
verify_list "$final_images"
fix_metadata 0440 1001:0 $files_base
fix_metadata 0776 1000:2901 $files_shared
fix_metadata 0440 1001:2901 $files_version
fix_metadata 0444 1000:2901 $files_lock
(cd "$firmware" && sha256sum -c "$manifest") >/dev/null
chmod 0550 $base_old $base_new
check_paths complete
verify_list "$final_images"
# The genuine stock property event lets init, not this domain, release RIL's
# radio-data flag. No completion is published on a failed copy/hash/metadata.
if test "$(getprop ro.vendor.ril.mbn_copy_completed)" != 1; then
    setprop ro.vendor.ril.mbn_copy_completed 1
fi
echo PLE_MCFG_CACHE_VERIFIED_READY
