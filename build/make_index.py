#!/usr/bin/env python3
"""根据 keiyoushi-source-info.json 生成两种索引：

  index.min.json  旧格式（Tachiyomi / Komikku / Mihon 旧路径）
  index.pb        protobuf + gzip（Tachimanga、Mihon 新版）

用法：python3 build/make_index.py <仓库根目录> <apk 文件名>
"""
import gzip
import json
import sys
from pathlib import Path

SIGNING_KEY = "596be49ff9db3968db22dfa0c6a0390764353730770b83b1250f3270aea3e27c"
STORE_NAME = "WNACG 自建源"
STORE_SHORT = "WNACG"
STORE_SITE = "https://github.com/TianYuuu/wnacg-extension"
BASE = "https://raw.githubusercontent.com/TianYuuu/wnacg-extension/repo"


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


def main() -> None:
    root = Path(sys.argv[1])
    apk = sys.argv[2]
    meta = json.loads((root / "src-info.json").read_text())

    entry = {
        "name": meta["name"],
        "pkg": meta["packageName"],
        "apk": apk,
        "lang": "zh",
        "code": meta["versionCode"],
        "version": meta["versionName"],
        "nsfw": 1 if meta["contentWarning"] >= 3 else 0,
        "sources": [
            {"id": s["id"], "lang": s["lang"], "name": s["name"], "baseUrl": s["baseUrl"]}
            for s in meta["sources"]
        ],
    }
    (root / "index.min.json").write_text(json.dumps([entry], ensure_ascii=False, indent=2) + "\n")

    sources = b"".join(
        pb_int(1, s["id"]) + pb_str(2, s["name"]) + pb_str(3, s["lang"]) + pb_str(4, s["baseUrl"])
        for s in meta["sources"]
    )
    resources = pb_str(1, f"{BASE}/apk/{apk}") + pb_str(2, f"{BASE}/icon/{meta['packageName']}.png")
    ext = (
        pb_str(1, meta["name"])
        + pb_str(2, meta["packageName"])
        + pb_bytes(3, resources)
        + pb_str(4, meta["extensionLib"])
        + pb_int(5, meta["versionCode"])
        + pb_str(6, meta["versionName"])
        + pb_int(7, meta["contentWarning"])
        + sources
    )
    store = (
        pb_str(1, STORE_NAME)
        + pb_str(2, STORE_SHORT)
        + pb_str(3, SIGNING_KEY)
        + pb_bytes(4, pb_str(1, STORE_SITE))
        + pb_bytes(101, pb_str(1, ext))
    )
    (root / "index.pb").write_bytes(gzip.compress(store, 9, mtime=0))

    # 旧格式路径需要 repo.json（meta + 签名指纹）
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
    print(f"index.min.json / index.pb / repo.json 已更新：{entry['version']} ({entry['code']})")


if __name__ == "__main__":
    main()
