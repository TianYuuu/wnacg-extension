# TianYuuu 自建扩展源（WNACG · CopyManga）

自建的 [Tachiyomi / Mihon / Komikku](https://github.com/mihonapp/mihon) 扩展仓库（客户端里显示为 **TianYuuu**）。目前两个扩展：

| 扩展 | 包名 | 源 | 说明 |
| --- | --- | --- | --- |
| **WNACG** | `…zh.wnacg` | 紳士漫畫 | 榜单 × 分类、搜索周期排序、多标签 AND；与官方同包名同 id，**替代**官方版 |
| **CopyManga** | `…zh.copymanga` | 拷贝漫画 | 新增排行榜（男频/女频 × 日/周/月/总榜）；同包名同源 id，**替换原版、收藏沿用** |

## 安装

在客户端添加仓库（新客户端用 `index.pb`，老客户端用 `index.min.json`，内容一致）：

```
https://raw.githubusercontent.com/TianYuuu/wnacg-extension/repo/index.pb
https://raw.githubusercontent.com/TianYuuu/wnacg-extension/repo/index.min.json
https://cdn.jsdelivr.net/gh/TianYuuu/wnacg-extension@repo/index.pb     ← GitHub 直连不畅时
```

- Mihon：设置 → 浏览 → 扩展 → 右上角「扩展仓库」→ 添加
- Komikku：浏览 → 扩展 → 右上角菜单 → 扩展仓库 → 添加
- Tachimanga（iOS）：浏览 → 扩展 → 该页设置 → Extension Repos → `+`

然后：

- **WNACG**：先卸载官方「紳士漫畫」（同包名、签名不同），再安装本仓库版本。收藏不需迁移。
- **CopyManga**：先卸载原来的「拷貝漫畫 / CopyManga」（同包名不同签名），再安装本仓库版本。
  源 id 与原版相同，旧收藏、阅读进度会直接指向新版本。

---

## 一、WNACG

### 相比官方扩展改了什么

| 改动 | 说明 |
| --- | --- |
| 榜单 × 分类自由组合 | 官方只能「热门=固定周榜、分类=最近更新」；这里今日/本周/本月/今年 × 任意分类都能拼 |
| 搜索带周期排序 | 搜索关键词时按「榜单」排序（`heat_year_DESC` 等），默认今年最热 |
| 搜索内筛分类 / 多标签 | 一次请求带上 `cate=` 与 `tag=a,b`（AND），不必「先搜再筛」 |
| 去掉了「跟随默认」中间态 | 榜单下拉永远是一个具体周期，显示什么就是什么 |
| 修掉小毛病 | 分类表补上「韩漫-合集」、去掉重复的「杂志&短篇-汉语」 |
| 关闭 R8 混淆 + lambda 编译为类 + minSdk 21 | 三者都是为 Tachimanga（iOS）的字节码校验器准备：否则会 `VerifyError: JVMVRFY021`；代价是 APK 从 68KB 变 194KB |

功能细节见 [`patch/改造说明.md`](patch/改造说明.md)。

### 与原版的关系（重要）

包名、扩展名、源名、源 id 都与官方**完全一致**：

```
pkg  eu.kanade.tachiyomi.extension.zh.wnacg
源名 紳士漫畫
id   6551136894818591762   ← 与官方相同
```

所以**原有收藏、阅读记录、章节进度都会自动指向这个版本**，不需要迁移。
代价是它和官方扩展不能共存（同包名），必须先卸载官方版本。

---

## 二、CopyManga

### 新增了什么

原版（bangxingni 仓库的 1.4.27）没有任何榜单接口，只能「推荐 / 最近更新」。这一版基于
[coffee522/extensions-copymanga](https://github.com/coffee522/extensions-copymanga) 的源码，把站点的排行榜接进筛选：

```
排行榜：不使用 / 日榜（上升最快）/ 周榜（最近 7 天）/ 月榜（最近 30 天）/ 总榜单
榜单频道：漫画排行榜（男频）/ 漫画排行榜（女频）
```

即 **2 × 4 = 8 种组合**，对应站点 `/rank?type={male|female}&table={day|week|month|total}`，
接口是 `GET /api/v3/ranks?date_type=…&audience_type=…&limit=&offset=`。

另外：

- 「最新模式」设置可以把「最近更新」标签直接绑到某个榜单（省得每次点筛选）；
- 保留原版的域名切换（mangacopy / copy3000 / copy4000）、繁简转换、题材筛选；
- 关闭 R8 + lambda 编译为类，避免 Tachimanga 的 `VerifyError`。

### 为什么没有「轻小说」

官方 App（ver 2.2.5 / 3.x）的排行榜确实有 男频 / 女频 / 轻小说 三个频道，
但**网站和公开 API 没有**，实测：

```
/rank            页面只有 漫畫排行榜(男頻) / (女頻) 两个标签，无輕小說
/rank?type=novel 返回空列表
GET /api/v3/ranks?audience_type=novel
   → {"code":210,"message":"Error: \"novel\" 不是有效的選擇。"}
   （试过 light / light_novel / novel_male / book / ln … 全部同样报错）
```

轻小说在 App 里走的是另一套接口，网页端没有暴露，所以扩展这边做不出来。

### 与原版的关系

包名、源名、源 id 与原版**完全一致**：

```
pkg  eu.kanade.tachiyomi.extension.zh.copymanga
源名 拷贝漫画
id   6696312508930833206   ← 由「拷贝漫画 / zh / 1」算出的原版 id
```

所以装好后**原有收藏、阅读进度、章节记录都会指向这个版本**，不需要迁移。
代价是同包名不同签名，必须先卸载原版扩展（卸载扩展不影响漫画库数据）。

---

## 自己重建 / 发版

```bash
KEYSTORE=./signingkey.jks \
ALIAS=wnacgkey \
KEY_STORE_PASSWORD=*** KEY_PASSWORD=*** \
./build/build.sh
```

脚本会分别：稀疏克隆上游 → 应用 `patch/*.diff` → 编译签名 → 把 APK 放进 `apk/`、图标放进 `icon/`，
最后调用 `build/make_index.py` 重写 `index.min.json`、`index.pb`、`repo.json`。

发版流程：

1. 改 `build.gradle.kts` 里的 `versionCode`（WNACG 当前 103；CopyManga 当前 110）；
2. 在上游工作区改完代码后 `git diff > patch/xxx.diff`；
3. 跑 `build.sh`，提交并推 `repo` 分支。

## 仓库结构

```
main 分支
  patch/wnacg.diff        相对 keiyoushi/extensions-source 的补丁（5 个文件）
  patch/copymanga.diff    相对 coffee522/extensions-copymanga 的补丁（2 个文件）
  patch/改造说明.md        WNACG 改动清单与技术细节
  build/build.sh          一键重建（两个扩展）
  build/make_index.py     生成 index.pb / index.min.json / repo.json（支持多扩展）

repo 分支（客户端读取的）
  index.min.json                                     旧格式索引
  index.pb                                           protobuf 索引（Tachimanga / 新版 Mihon）
  repo.json                                          仓库元信息 + 签名指纹
  apk/tachiyomi-zh.wnacg-v1.6.103.apk
  apk/tachiyomi-zh.copymanga-v1.6.110.apk
  icon/eu.kanade.tachiyomi.extension.zh.wnacg.png
  icon/eu.kanade.tachiyomi.extension.zh.copymanga.png
```

index 的目录约定（Mihon 的解析方式）：

- APK 固定 `<仓库根>/apk/<json 里 apk 字段>`
- 图标固定 `<仓库根>/icon/<包名>.png`
- 旧格式路径要求 URL 以 `/index.min.json` 结尾，并读取同目录的 `repo.json`

## 注意

- 签名指纹：`596be49ff9db3968db22dfa0c6a0390764353730770b83b1250f3270aea3e27c`
  （**整个仓库的所有扩展必须用同一把 key**，否则客户端会以签名不一致拒绝安装）。
- **签名密钥不进仓库**。`signingkey.jks` 自己离线保管；换 key 只能卸载重装。
- 上游改动导致补丁失效时，用 `git apply --3way` 或手动合并。

---

## 关于 Tachimanga（iOS）

Tachimanga 不是 Android 应用，它用自己的 JVM 跑扩展的 dex，因此对字节码形态比 Mihon/Komikku 挑剔得多。
按 [官方扩展指南](https://tachimanga.app/help/guides/extensions_guide.html) 和社区的实践，已经做了三件事：

| 改动 | 原因 |
| --- | --- |
| 关闭 R8（`isMinifyEnabled = false`） | 混淆后的单字母类 + 激进优化会被它的校验器拒绝（`class=k`） |
| lambda 编译为类（`-Xlambdas=class`） | 否则 D8 脱糖留下 `xxx$lambda$N`，同样报 `VerifyError` |
| **minSdk 降到 21** | minSdk ≥ 26 时 D8 不做完整脱糖（默认方法、部分 Java 8 构造保持原样），它的运行时校验不过 |

仓库地址请用 **`index.min.json`** 结尾的那条（Tachimanga 的文档只保证这个格式；`index.pb` 在部分版本上不认）：

```
https://raw.githubusercontent.com/TianYuuu/wnacg-extension/repo/index.min.json
```

若要更换/重装扩展：先在 Tachimanga 里卸载同名扩展，再装本仓库版本；装好后如果出现「未信任 / Trust」提示，
点一下确认——自建仓库的签名不在它的白名单里，这是正常流程。

> 仍未解决的部分：这套扩展是用 lib 1.6（suspend API）编译的。Tachimanga 的实现更接近老版
> Tachiyomi 的 1.4 API，若遇到「源能装但打开是空」这类症状，就需要把源码移植回 1.4 的
> Request/Parse 同步接口重新编译（社区里 `xixiwan/mihon-ehentai-extension` 就是这么做的）。
> 这一步工作量较大，且会丢掉 `fetchFilterData`（动态题材列表）和 `getMangaByUrl`（深链），
> 需要时再做。
