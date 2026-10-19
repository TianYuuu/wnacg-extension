#!/usr/bin/env bash
# 重建本仓库包含的扩展，并把产物放进 repo 分支所需的目录结构。
#
# 目前两个：
#   WNACG      改自 keiyoushi/extensions-source（patch/wnacg.diff）
#   CopyManga+ 改自 coffee522/extensions-copymanga（patch/copymanga.diff）
#
# 依赖：JDK 21、Android SDK（build-tools / platforms）、git、unzip
# 用法：
#   ALIAS=wnacgkey KEY_STORE_PASSWORD=*** KEY_PASSWORD=*** ./build/build.sh
#
# 首次执行会把两个上游仓库稀疏克隆到 .work/ 下。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYSTORE="${KEYSTORE:-$ROOT/signingkey.jks}"
ALIAS="${ALIAS:-wnacgkey}"
SPARSE="core lib lib-multisrc gradle compiler common .github"

if [[ ! -f "$KEYSTORE" ]]; then
    echo "缺少签名文件：$KEYSTORE" >&2
    echo "换 key 会导致客户端必须卸载重装，务必沿用同一把 key。" >&2
    exit 1
fi

mkdir -p "$ROOT/apk" "$ROOT/icon" "$ROOT/.work/meta"

# build_ext <扩展名> <上游仓库> <工作目录名> <模块路径> <补丁文件>
build_ext() {
    local name="$1" upstream="$2" dirname="$3" module="$4" patch="$5"
    local src="$ROOT/.work/$dirname"

    echo "==> [$name] 准备源码"
    if [[ ! -d "$src/.git" ]]; then
        git clone --depth 1 --filter=blob:none --no-checkout "$upstream" "$src"
        git -C "$src" sparse-checkout init --cone
        git -C "$src" sparse-checkout set "$module" $SPARSE
        git -C "$src" checkout main
    else
        git -C "$src" fetch --depth 1 origin main
        git -C "$src" reset --hard origin/main
    fi

    echo "==> [$name] 应用补丁"
    git -C "$src" apply --3way "$ROOT/patch/$patch"

    echo "==> [$name] 编译"
    (
        cd "$src"
        chmod +x gradlew
        printf 'sdk.dir=%s\n' "$ANDROID_HOME" > local.properties
        cp "$KEYSTORE" signingkey.jks
        export ALIAS KEY_STORE_PASSWORD="${KEY_STORE_PASSWORD:-}" KEY_PASSWORD="${KEY_PASSWORD:-}"
        ./gradlew ":$module:assembleRelease" --no-configuration-cache
    )

    local apk info pkg
    apk="$(ls "$src/$module"/build/outputs/apk/release/*.apk | head -1)"
    info="$src/$module/build/keiyoushi-source-info.json"
    echo "==> [$name] 产物：$(basename "$apk")"

    cp "$apk" "$ROOT/apk/"
    cp "$info" "$ROOT/.work/meta/$name.json"

    pkg="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['packageName'])" "$info")"
    rm -rf "$ROOT/.work/icon-$name" && mkdir -p "$ROOT/.work/icon-$name"
    unzip -o -j "$apk" "res/*.png" -d "$ROOT/.work/icon-$name" >/dev/null
    local best
    best="$(python3 - "$ROOT/.work/icon-$name" <<'PY'
import glob, os, struct, sys
best = max(glob.glob(os.path.join(sys.argv[1], "*.png")),
           key=lambda f: struct.unpack(">II", open(f, "rb").read(24)[16:24])[0])
print(best)
PY
)"
    cp "$best" "$ROOT/icon/$pkg.png"
}

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

build_ext wnacg \
    "https://github.com/keiyoushi/extensions-source.git" \
    extensions-source "src/zh/wnacg" "wnacg.diff"

build_ext copymanga \
    "https://github.com/coffee522/extensions-copymanga.git" \
    extensions-copymanga "src/zh/copymanga" "copymanga.diff"

echo "==> 重建索引"
python3 "$ROOT/build/make_index.py" "$ROOT" "$ROOT/.work/meta/wnacg.json" "$ROOT/.work/meta/copymanga.json"

echo "完成。提交 repo 分支："
echo "  git add -A && git commit -m 'update apk' && git push origin repo"
