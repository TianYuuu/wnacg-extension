#!/usr/bin/env bash
# 重建 wnacg 修改版扩展，并把产物放进 repo 分支所需的目录结构。
#
# 依赖：JDK 21、Android SDK（build-tools / platforms）、git、unzip
# 用法：
#   KEYSTORE=./signingkey.jks ALIAS=wnacgkey KEY_STORE_PASSWORD=*** KEY_PASSWORD=*** ./build/build.sh
#
# 首次执行会稀疏克隆 keiyoushi/extensions-source 到 .work/extensions-source。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${SRC_DIR:-$ROOT/.work/extensions-source}"
UPSTREAM="${UPSTREAM:-https://github.com/keiyoushi/extensions-source.git}"
MODULE_PATH="src/zh/wnacg"
KEYSTORE="${KEYSTORE:-$ROOT/signingkey.jks}"
ALIAS="${ALIAS:-wnacgkey}"

if [[ ! -f "$KEYSTORE" ]]; then
    echo "缺少签名文件：$KEYSTORE" >&2
    echo "没有的话先生成一个（换 key 会导致只能卸载重装）：" >&2
    echo "  keytool -genkeypair -keystore signingkey.jks -alias wnacgkey \\" >&2
    echo "          -keyalg RSA -keysize 2048 -validity 10000 \\" >&2
    echo "          -storepass 你的密码 -keypass 你的密码 -dname 'CN=wnacg'" >&2
    exit 1
fi

echo "==> 准备上游源码"
if [[ ! -d "$SRC_DIR/.git" ]]; then
    mkdir -p "$(dirname "$SRC_DIR")"
    git clone --depth 1 --filter=blob:none --no-checkout "$UPSTREAM" "$SRC_DIR"
    git -C "$SRC_DIR" sparse-checkout init --cone
    git -C "$SRC_DIR" sparse-checkout set "$MODULE_PATH" core lib lib-multisrc gradle compiler common .github
    git -C "$SRC_DIR" checkout main
else
    git -C "$SRC_DIR" fetch --depth 1 origin main && git -C "$SRC_DIR" reset --hard origin/main
fi

echo "==> 应用补丁"
git -C "$SRC_DIR" apply --3way "$ROOT/patch/wnacg.diff"

echo "==> 编译"
cd "$SRC_DIR"
export ALIAS KEY_STORE_PASSWORD="${KEY_STORE_PASSWORD:-}" KEY_PASSWORD="${KEY_PASSWORD:-}"
./gradlew ":src:zh:wnacg:assembleRelease" --no-configuration-cache

APK="$(ls src/zh/wnacg/build/outputs/apk/release/*.apk | head -1)"
PKG="$(basename "$APK" .apk)"
echo "==> 产物：$APK"

echo "==> 同步到 repo 布局"
cp "$SRC_DIR/src/zh/wnacg/build/keiyoushi-source-info.json" "$ROOT/src-info.json"
mkdir -p "$ROOT/apk" "$ROOT/icon"
cp "$APK" "$ROOT/apk/"
unzip -o -j "$APK" "res/*.png" -d "$ROOT/.work/icon" >/dev/null
# 取分辨率最大的那张当仓库图标
BEST="$(python3 - "$ROOT/.work/icon" <<'PY'
import struct, sys, glob, os
best = max(glob.glob(os.path.join(sys.argv[1], "*.png")),
           key=lambda f: struct.unpack(">II", open(f, "rb").read(24)[16:24])[0])
print(best)
PY
)"
cp "$BEST" "$ROOT/icon/eu.kanade.tachiyomi.extension.zh.wnacg.png"

python3 - "$ROOT" "$PKG" <<'PY'
import json, sys, os
root, name = sys.argv[1], sys.argv[2]
meta = json.load(open(os.path.join(root, "src-info.json")))
entry = {
    "name": meta["name"],
    "pkg": meta["packageName"],
    "apk": name + ".apk",
    "lang": "zh",
    "code": meta["versionCode"],
    "version": meta["versionName"],
    "nsfw": 1 if meta["contentWarning"] >= 3 else 0,
    "sources": [
        {"id": s["id"], "lang": s["lang"], "name": s["name"], "baseUrl": s["baseUrl"]}
        for s in meta["sources"]
    ],
}
json.dump([entry], open(os.path.join(root, "index.min.json"), "w"), ensure_ascii=False, indent=2)
print("==> index.min.json 已更新：", entry["version"], entry["code"])
PY

echo "完成。提交 repo 分支："
echo "  git add -A && git commit -m 'update apk' && git push origin repo"
