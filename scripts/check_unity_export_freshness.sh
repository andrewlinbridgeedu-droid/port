#!/bin/sh

set -eu

workspace_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
unity_assets="$workspace_root/UnityBattleSource/Assets"
generated_cpp="$workspace_root/mistport-ios/UnityBuild/Il2CppOutputProject/Source/il2cppOutput/Assembly-CSharp.cpp"
export_metadata="$workspace_root/mistport-ios/UnityBuild/Data/Managed/Metadata/global-metadata.dat"
export_manifest="$workspace_root/mistport-ios/UnityBuild/.mistport-unity-export-manifest"
export_version_file="$workspace_root/mistport-ios/UnityBuild/.mistport-unity-export-version"
required_export_version="3"
unity_project_root="$workspace_root/UnityBattleSource"
unity_bin="${MISTPORT_UNITY_BIN:-/Users/andrewlin/.unity/bin/unity}"
auto_export="${MISTPORT_AUTO_EXPORT_UNITY:-1}"

fail() {
    echo "error: $1" >&2
    exit 1
}

actual_manifest="$(mktemp "${TMPDIR:-/tmp}/mistport-unity-manifest.XXXXXX")"
trap 'rm -f "$actual_manifest"' EXIT HUP INT TERM

write_actual_manifest() {
    {
        for source_root in \
            "$unity_assets/Scripts" \
            "$unity_assets/Mindstone" \
            "$unity_assets/Resources" \
            "$unity_assets/Scenes" \
            "$unity_project_root/BuildSupport"; do
            find "$source_root" -type f ! -name '*.meta' -print0 2>/dev/null \
                | LC_ALL=C sort -z \
                | xargs -0 shasum -a 256 \
                | sed "s|  $unity_project_root/|  |"
        done
    } > "$actual_manifest"
}

has_required_presentation_code() {
    # Chapter 1 Q2 requires two independently addressable Clock Guards. This
    # symbol is generated only when the matching Unity presentation code
    # reached the iOS export, preventing a new Swift HUD from being paired
    # with old actors.
    [ -f "$generated_cpp" ] && grep -q 'BattlePrototype_UseDualClockGuardModel' "$generated_cpp"
}

export_is_fresh() {
    [ -f "$generated_cpp" ] || return 1
    [ -f "$export_metadata" ] || return 1
    [ -f "$export_manifest" ] || return 1
    [ -f "$export_version_file" ] || return 1
    [ "$(tr -d '[:space:]' < "$export_version_file")" = "$required_export_version" ] || return 1

    write_actual_manifest
    cmp -s "$export_manifest" "$actual_manifest" || return 1
    has_required_presentation_code
}

if export_is_fresh; then
    echo "Unity export freshness check passed."
    exit 0
fi

if [ "$auto_export" = "0" ]; then
    fail "UnityBuild 缺失、过期或不完整。MISTPORT_AUTO_EXPORT_UNITY=0 已禁用自动导出；请执行 Unity iOS 导出后再构建。"
fi

if [ "${MISTPORT_BUILD_PHASE:-0}" = "1" ]; then
    fail "UnityBuild 缺失、过期或不完整。当前脚本运行在 Xcode target build phase，不能在 UnityFramework 已编译后重导出；请先运行 scheme pre-action 或 scripts/check_unity_export_freshness.sh。"
fi

[ -x "$unity_bin" ] || fail "Unity 自动导出不可用：找不到 $unity_bin。可用 MISTPORT_UNITY_BIN 指定 Unity 可执行文件，或手动执行 Mindstone > Export iOS Library。"

log_dir="$workspace_root/artifacts"
mkdir -p "$log_dir"

# Unity can rewrite/import an untracked source file while the export is
# finishing. Re-check after each export and allow one clean retry so the
# manifest always describes the source that the generated library contains.
attempt=1
while [ "$attempt" -le 2 ]; do
    log_file="$log_dir/unity-export-auto-$(date +%Y%m%d-%H%M%S)-$attempt.log"
    echo "UnityBuild 不新鲜，正在自动导出（第 $attempt/2 次）……"
    if "$unity_bin" --non-interactive run "$unity_project_root" --timeout 1800 -- \
        -executeMethod ExportIOSLibrary.Export -logFile "$log_file"; then
        :
    else
        echo "warning: Unity 导出命令失败；详情见 $log_file" >&2
    fi

    if export_is_fresh; then
        echo "Unity export freshness check passed after automatic export."
        exit 0
    fi

    attempt=$((attempt + 1))
done

fail "Unity 自动导出后仍未通过 freshness 校验（已尝试 2 次）。请查看 artifacts/unity-export-auto-*.log；若需手动接管，可设置 MISTPORT_AUTO_EXPORT_UNITY=0。"
