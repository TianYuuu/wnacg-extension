#!/usr/bin/env python3
"""根据若干 keiyoushi-source-info.json 生成两种索引：

  index.min.json  旧格式（Tachiyomi / Komikku / Mihon 旧路径）
  index.pb        protobuf + gzip（Tachimanga、Mihon 新版）

用法：python3 build/make_index.py <仓库根目录> <info1.json> [info2.json ...]

约定（与 keiyoushi 构建产物一致）：
  apk  <root>/apk/tachiyomi-<包名后缀>-v<版本名>.apk
  icon <root>/icon/<完整包名>.png
"""
import gzip
import json
import sys
from pathlib import Path

SIGNING_KEY = "596be49ff9db3968db22dfa0c6a0390764353730770b83b1250f3270aea3e27c"
STORE_NAME = "TianYuuu"
STORE_SHORT = "TianYuuu"
STORE_SITE = "https://github.com/TianYuuu/wnacg-extension"
BASE = "https://raw.githubusercontent.com/TianYuuu/wnacg-extension/repo"
PKG_PREFIX = "eu.kanade.tachiyomi.extension."


def varint(n: int) -> bytes:
    out = b""
    while True:
        b = n & 0x7F
        n >>= 7
        out += bytes([b | 0x80]) if n else bytes([b])
        if not n:
            return out


def tag(field: int, wire: int) -> bytes:
    return varint((field << 3) | wire)


def pb_bytes(field: int, raw: bytes) -> bytes:
    return tag(field, 2) + varint(len(raw)) + raw


def pb_str(field: int, value: str) -> bytes:
    return pb_bytes(field, value.encode())


def pb_int(field: int, value: int) -> bytes:
    return tag(field, 0) + varint(value)


def load_entry(root: Path, info_path: Path) -> dict:
    meta = json.loads(info_path.read_text())
    pkg = meta["packageName"]
    suffix = pkg.removeprefix(PKG_PREFIX)
    apk = f"tachiyomi-{suffix}-v{meta['versionName']}.apk"
    if not (root / "apk" / apk).exists():
        raise SystemExit(f"缺少 APK：apk/{apk}（先把产物拷进 apk/ 目录）")
    return {
        "name": meta["name"],
        "pkg": pkg,
        "apk": apk,
        "lang": "zh",
        "code": meta["versionCode"],
        "version": meta["versionName"],
        # ContentWarning 枚举各版本不同：WNACG=3、CopyManga=2 都是含成人内容
        "nsfw": 1 if meta["contentWarning"] >= 2 else 0,
        "lib": meta["extensionLib"],
        "warning": meta["contentWarning"],
        "sources": [
            {
                "id": s["id"],
                "lang": s["lang"],
                "name": s["name"],
                "baseUrl": s["baseUrl"],
                "versionId": 1,
            }
            for s in meta["sources"]
        ],
    }


def main() -> None:
    root = Path(sys.argv[1])
    entries = [load_entry(root, Path(p)) for p in sys.argv[2:]]
    entries.sort(key=lambda e: e["name"].lower())

    (root / "index.min.json").write_text(
        json.dumps(
            [
                {k: e[k] for k in ("name", "pkg", "apk", "lang", "code", "version", "nsfw", "sources")}
                for e in entries
            ],
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
    )

    extensions = b""
    for e in entries:
        sources = b"".join(
            pb_bytes(
                8,
                pb_int(1, s["id"]) + pb_str(2, s["name"]) + pb_str(3, s["lang"]) + pb_str(4, s["baseUrl"]),
            )
            for s in e["sources"]
        )
        resources = pb_str(1, f"{BASE}/apk/{e['apk']}") + pb_str(2, f"{BASE}/icon/{e['pkg']}.png")
        ext = (
            pb_str(1, e["name"])
            + pb_str(2, e["pkg"])
            + pb_bytes(3, resources)
            + pb_str(4, e["lib"])
            + pb_int(5, e["code"])
            + pb_str(6, e["version"])
            + pb_int(7, e["warning"])
            + sources
        )
        extensions += pb_bytes(1, ext)

    store = (
        pb_str(1, STORE_NAME)
        + pb_str(2, STORE_SHORT)
        + pb_str(3, SIGNING_KEY)
        + pb_bytes(4, pb_str(1, STORE_SITE))
        + pb_bytes(101, extensions)
    )
    (root / "index.pb").write_bytes(gzip.compress(store, 9, mtime=0))

    repo_json = {
        "index_v2": None,
        "meta": {
            "name": STORE_NAME,
            "shortName": STORE_SHORT,
            "website": STORE_SITE,
            "signingKeyFingerprint": SIGNING_KEY,
        },
    }
    (root / "repo.json").write_text(json.dumps(repo_json, ensure_ascii=False, indent=2) + "\n")

    for e in entries:
        print(f"  {e['name']:<18} {e['version']:<10} code={e['code']:<8} {e['apk']}")
    print(f"index.min.json / index.pb / repo.json 已更新，共 {len(entries)} 个扩展")


if __name__ == "__main__":
    main()
