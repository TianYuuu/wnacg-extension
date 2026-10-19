# WNACG 修改版扩展源

自建的 [Tachiyomi / Mihon / Komikku](https://github.com/mihonapp/mihon) 扩展仓库，只有一个扩展：
**紳士漫畫（WNACG）** 的改进版。

## 相比官方扩展改了什么

| 改动 | 说明 |
| --- | --- |
| 榜单 × 分类自由组合 | 官方只能「热门=固定周榜、分类=最近更新」；这里今日/本周/本月/今年 × 任意分类都能拼 |
| 搜索带周期排序 | 搜索关键词时按「榜单」排序（`heat_year_DESC` 等），默认今年最热 |
| 搜索内筛分类 / 多标签 | 一次请求带上 `cate=` 与 `tag=a,b`（AND），不必「先搜再筛」 |
| 去掉了「跟随默认」中间态 | 榜单下拉永远是一个具体周期，显示什么就是什么 |
| 修掉小毛病 | 分类表补上「韩漫-合集」、去掉重复的「杂志&短篇-汉语」 |

功能细节见 [`patch/改造说明.md`](patch/改造说明.md)。

## 与原版的关系（重要）

包名、扩展名、源名、源 id 都与官方**完全一致**：

```
pkg  eu.kanade.tachiyomi.extension.zh.wnacg
源名 紳士漫畫
id   6551136894818591762   ← 与官方相同
```

所以**原有收藏、阅读记录、章节进度都会自动指向这个版本**，不需要迁移。
代价是它和官方扩展不能共存（同包名），必须先卸载官方版本。

## 安装

1. 在客户端里添加仓库（三端通用，地址任选其一）：
   ```
   https://raw.githubusercontent.com/TianYuuu/wnacg-extension/repo/index.min.json
   https://cdn.jsdelivr.net/gh/TianYuuu/wnacg-extension@repo/index.min.json
   ```
   - Mihon：设置 → 浏览 → 扩展 → 右上角「扩展仓库」→ 添加
   - Komikku：浏览 → 扩展 → 右上角菜单 → 扩展仓库 → 添加
2. 卸载官方「紳士漫畫」（签名不同，不卸载装不上）。
3. 在扩展列表里找到本仓库的 **WNACG**，安装。
4. 打开漫画库，原收藏应照常能打开、能继续读。

## 自己重建 / 发版

```bash
KEYSTORE=./signingkey.jks \
ALIAS=wnacgkey \
KEY_STORE_PASSWORD=*** KEY_PASSWORD=*** \
./build/build.sh
```

脚本会：稀疏克隆 `keiyoushi/extensions-source` → 应用 `patch/wnacg.diff` → 编译签名 →
把 APK 放到 `apk/`、图标放到 `icon/`、重写 `index.min.json`。

发版流程：

1. 改 `patch/wnacg.diff` 里的 `versionCode`（当前 100 → `1.6.100`，官方是 `1.6.2 / 106002`，
   保持高于官方就不会被上游覆盖）。
2. 重新生成补丁：在上游工作区改完代码后 `git diff > patch/wnacg.diff`。
3. 跑 `build.sh`，提交并推 `repo` 分支。

## 仓库结构

```
main 分支
  patch/wnacg.diff       相对 keiyoushi/extensions-source 的补丁（4 个文件）
  patch/改造说明.md       改动清单与技术细节
  build/build.sh         一键重建脚本

repo 分支（客户端读取的）
  index.min.json                           旧格式索引，兼容 Mihon / Komikku / TachiManga
  repo.json                                仓库元信息 + 签名指纹
  apk/tachiyomi-zh.wnacg-v1.6.100.apk      扩展本体
  icon/eu.kanade.tachiyomi.extension.zh.wnacg.png
```

## 注意

- 签名指纹：`596be49ff9db3968db22dfa0c6a0390764353730770b83b1250f3270aea3e27c`
  （与 `repo.json` 里必须一致，否则客户端会拒绝安装）。
- **签名密钥不进仓库**（公钥可公开、私钥不行）。`signingkey.jks` 自己离线保管：
  换了 key，客户端会因签名不一致拒绝覆盖安装，只能卸载重装。
- 上游 `extensions-source` 改动导致补丁失效时，用 `git apply --3way` 或手动合并。
