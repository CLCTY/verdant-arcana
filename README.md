# 翠启 · Verdant Arcana

<img src="assets/branding/app-icon.png" width="96" alt="翠启：新月与星芒图标">

中文 | [English](README.en.md)

「翠」是翡翠绿，「启」是灵感与启示。新月环绕四芒星，以玫瑰金勾勒直觉与指引。

Flutter 深色手机应用，采用每日一牌 / 大牌面布局，翡翠绿与玫瑰金。版本 0.2。

## 功能

- 今日 / 占卜 / 牌库 / 日记四个底栏入口；设置为独立页面。
- 完整 78 张牌：22 张大阿卡纳和四组各 14 张小阿卡纳。每张有独立原创卡面、关键词、正位和逆位含义。死神使用兜帽骷髅与镰刀等大众熟悉的符号。
- 9 种图形牌阵：单张、二选一、是非澄清、三张现状、三张时间、关系之镜、四元素、五张十字、凯尔特十字。选择项使用带编号位置图的原生 MD3 卡片，当前选项高亮并动画滚动。
- 不重复随机抽牌与正逆位；逐张翻牌，全部展开后查看解读；十牌阵支持滚动。
- 牌库搜索和分类筛选，正逆位切换；本地日记保存、长按多选、全选删除和 8 秒撤销。
- AI 配置入口：选择服务、模型、独立 API Key、保存、测试连接、移除密钥。解读页可主动请求深入解读，返回内容可随日记保存。
- 官方 Flutter MD3 组件：NavigationBar、AppBar、Card、ListTile、FilledButton、OutlinedButton、TextButton、IconButton、FilterChip、SegmentedButton、SearchBar、TextField、DropdownMenu、Checkbox、SnackBar 和进度指示器。固定 `useMaterial3: true`、深色模式。
- 水波纹、底栏动画、页面淡入位移、Hero、700ms 3D 翻牌、正逆位旋转、图形选项切换和保存反馈。

## AI 接入

设置 → AI 接入，填写自己对应服务的 API Key 后点击「测试连接并保存」。测试会发出一条简短请求；正常解读只在用户点击「AI 深入解读」时调用。

| 服务 | 模型 | 接口 |
| --- | --- | --- |
| DeepSeek 官方 | `deepseek-flash`、`deepseek-v4-pro` | `https://api.deepseek.com/chat/completions` |
| OpenCode Go | `deepseek-v4.1-flash` | `https://opencode.ai/zen/go/v1/chat/completions` |

接口依据 [DeepSeek 官方文档](https://api-docs.deepseek.com/) 与 [OpenCode Go 官方文档](https://docs.opencode.ai/docs/go/) 实现。Go 请求带稳定的 `x-opencode-session`，使用应用自身身份，不伪装编程代理。Go 主要面向编程代理，塔罗用途的许可与实际可用性取决于服务方规则及账户权限。

手机端通过系统安全存储保存 Key；普通偏好设置仅保存服务和模型。Web 预览的 Key 仅保存在内存，刷新后清除。两个服务的密钥独立保存。AI 只接收当前问题、牌阵位置、牌名和正逆位，不上传日记感受。错误信息不回显服务原始响应或密钥。

没有使用真实账户密钥进行在线认证或计费验证。请求协议、返回内容解析、错误分支和凭据隔离经过模拟 HTTP 测试。浏览器可能受服务端 CORS 限制；手机端直接发 HTTPS 请求，未添加绕过限制的代理。

## 运行

验证环境：Flutter 3.41.9 / Dart 3.11.5。

```powershell
flutter pub get
flutter run -d edge
```

已构建 Web：

```powershell
node tool/preview.cjs
```

浏览器打开 http://127.0.0.1:4180 。建议用 390 × 844 手机视口，宽屏下应用居中显示。

```powershell
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run
flutter build apk --release
```

Android 工程已包含联网权限，但本机缺少 Android SDK，未生成 APK，也未进行 Android 真机验证。

日记保存在设备或当前浏览器站点本地，清除应用 / 站点数据会清除记录。尚无云同步和导出。

## 资源与源码

卡面与牌背由 ImageGen 原创生成，未复制商用卡面。中文字体随应用打包，来自 Google Fonts 官方仓库，SIL OFL 许可证保存在 `assets/fonts/`。

- `lib/main.dart`：主题、首页、底栏和占卜表单。
- `lib/spreads.dart`：牌阵位置、图形选择。
- `lib/models.dart`、`lib/deck.dart`：全牌库、抽牌、日记持久化。
- `lib/pages.dart`：抽牌、解读、牌库与详情。
- `lib/journal.dart`：多选删除与撤销。
- `lib/settings.dart`、`lib/ai.dart`、`lib/ai_panel.dart`：AI 配置和解读。
- `test/`：抽牌 / 78 张资源完整性、牌阵、保存迁移、删除撤销、AI 协议和页面交互测试。
- `design/`：实际渲染截图与 78 张卡面总览。
- [品牌与图标](BRANDING.md)：名称、配色、图标来源与使用说明。

使用官方 MD3，符合用户要求的「M3E 或 MD3」；未引入第三方 M3E 包。

正式资源以 `assets/cards` 为准，生成过程原稿未包含在仓库中。

## 预览

![应用界面](design/revision-preview.png)

![完整 78 张卡面](design/deck-all-78.png)

## 许可说明

字体采用随附的 SIL OFL 许可证。项目代码与图像尚未指定开源许可证；公开仓库不等同于授予再分发许可。
