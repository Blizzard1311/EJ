# Mind U App Store Connect 上架资料

更新日期：2026 年 8 月 6 日

## 1. 当前应用信息

- Bundle ID：`com.blizzard1311.yiji`
- 版本：`1.0`
- 构建号：`11`（本地构建 `10` 生成于西班牙语、日语输入链路加入前，已废止；App Store Connect 已存在构建 `8`）
- 平台：iPhone，竖屏
- 最低系统：iOS 16.0
- 首发区域：美国区
- 首发边界：无注册、无登录、无 group、无付费、无开发者自建后端
- 界面语言：简体中文、繁体中文、English、Español、日本語（西班牙语与日语界面资源已进入 Build 11，提交前仍需真机截断检查和母语审校）
- 语音转写：可独立选择跟随 App、`zh-CN`、`zh-TW`、`en-US`、`es-US`、`es-MX`、`es-ES` 与 `ja-JP`
- 跟随 App 映射：简体中文 → `zh-CN`、繁体中文 → `zh-TW`、English → `en-US`、Español → `es-US`、日本語 → `ja-JP`；用户仍可独立覆盖语音 locale
- 语义解析边界：简体中文自然语言支持物品位置、提醒和时间计划解析；西班牙语与日语支持已由自动化测试覆盖的常用相对时间、明确日期、每日/每周/每月/每年重复、物品位置和自然语言位置搜索；繁体中文与英文提醒语义仍需按 locale 单独验证

App 名称最终能否使用，必须以 App Store Connect 创建 App 记录时的名称校验为准。网页搜索不能替代名称预留。

当前 App Store Connect 已存在此 Bundle ID 的 1.0 版本记录，内部返回名称为 `YijiApp`，且“在 Apple 芯片 Mac 上分发 iOS App”当前为开启状态。正式提交前应确认最终本地化名称，并决定关闭 Mac 分发或补做 Mac 兼容性测试。

## 2. 建议本地化

### 简体中文

- 名称：`Mind U`
- 副标题：`一句话记住位置、提醒和想法`
- Promotional Text：`用一句话记住物品位置、提醒事项和临时想法。数据保存在本机，并可随时导出或恢复 JSON 备份。`
- 关键词：`语音记录,物品收纳,备忘,生活记录,日历,搜索,本地笔记,到期,清单`

描述：

Mind U是一款面向个人生活场景的轻量记录工具。用一句中文自然语言，就能快速记下物品放在哪里、什么时候要提醒，以及临时想到的事项。

主要功能：

- 语音或文字快速录入
- 自动识别物品位置、提醒事项和普通笔记
- 按类别与位置查看同一条物品记录
- 最近记录、日历回看与搜索
- 本地提醒与 iPhone 系统通知
- 授权定位后显示未来天气提示
- JSON 备份导出、导入，以及通过“文件”或 iCloud Drive 手动传递

适合记录：

- 我把护照放在书房右边抽屉
- 明天下午三点提醒我交物业费
- 记一下，下周要给孩子准备报名材料

Mind U不需要账号，不含广告或第三方营销跟踪。核心记录先保存在本机；拒绝定位只会关闭天气提示，不影响记录、搜索、提醒或备份。

### 繁體中文

- 名稱：`Mind U`
- 副標題：`一句話記住位置、提醒與想法`
- Promotional Text：`用一句話記住物品位置、提醒事項和臨時想法。資料儲存在本機，並可隨時匯出或還原 JSON 備份。`
- 關鍵字：`語音記錄,物品收納,備忘,生活記錄,日曆,搜尋,本機筆記,到期,清單`

描述：

Mind U 是一款面向個人生活情境的輕量記錄工具。你可以用語音或文字快速記下物品放在哪裡、什麼時候需要提醒，以及臨時想到的事項。

主要功能：

- 語音或文字快速輸入
- 儲存物品位置、提醒事項和一般筆記
- 按類別與位置查看同一筆物品記錄
- 最近記錄、日曆回顧與搜尋
- 本機提醒與 iPhone 系統通知
- 授權定位後顯示未來天氣提示
- JSON 備份匯出、匯入，以及透過「檔案」或 iCloud Drive 手動傳遞

適合記錄：

- 我把護照放在書房右邊抽屜
- 明天下午三點提醒我繳管理費
- 記一下，下週要幫孩子準備報名資料

Mind U 不需要帳號，不含廣告或第三方行銷追蹤。核心記錄先儲存在本機；拒絕定位只會關閉天氣提示，不影響記錄、搜尋、提醒或備份。

### English (U.S.)

- Name: `Mind U`（仍需在 App Store Connect 校验可用性）
- Subtitle: `Voice Notes & Reminders`
- Promotional Text: `Capture everyday details by voice or text in English or Chinese. Keep records on your iPhone and export or restore a JSON backup anytime.`
- Keywords: `voice memo,item location,memory,organizer,calendar,search,storage,task`

Description:

Mind U is a local-first personal memory app with English, Simplified Chinese, Traditional Chinese, Spanish, and Japanese interfaces. Capture everyday details by voice or text, keep them organized on your iPhone, and find them again when you need them.

Key features:

- English, Chinese, Spanish, and Japanese speech-to-text capture
- English, Simplified Chinese, Traditional Chinese, Spanish, and Japanese app interfaces
- Quick notes and keyword search across the supported languages
- Chinese natural-language parsing for item locations, reminders, and schedules
- Spanish and Japanese parsing for common reminder schedules, item locations, and natural-language location searches
- Browse the same item by category and physical location
- Recent history, calendar review, and search
- Local reminders delivered through iPhone notifications
- Optional calendar weather after you grant location permission
- Export and import JSON backups, including manual transfer through Files or iCloud Drive

Examples:

- “我把护照放在书房右边抽屉” — I put my passport in the right drawer in the study.
- “明天下午三点提醒我交物业费” — Remind me at 3 PM tomorrow to pay the property fee.

No account is required. Mind U contains no ads or third-party marketing trackers. Core data is stored locally first. If you deny location access, only calendar weather is unavailable; capture, search, reminders, and backups continue to work.

## 3. 分类与年龄分级

- 主分类：Productivity
- 副分类：Utilities
- 年龄分级：按 App Store Connect 2026 年更新后的问卷如实作答；基于当前无社交、无博彩、无成人、无暴力和无 UGC 发布能力，预期为低年龄分级，但不要直接照抄旧的 `4+` 结论

## 4. App Review Notes 模板

```text
Mind U is a local-first personal memory app with English, Simplified Chinese, Traditional Chinese, Spanish, and Japanese interfaces. No account or login is required.

Core review path:
1. The app includes separate settings for app language and speech recognition language. App language options are Follow System, Simplified Chinese, Traditional Chinese, English, Spanish, and Japanese.
2. In English, use the first tab to enter or dictate a quick note such as “The spare key is in the desk drawer”, then save and search for it.
3. To review Chinese reminder parsing, enter “明天下午三点提醒我交物业费”, save it, and review the created record/reminder.
4. Switch the app language to Traditional Chinese, Spanish, or Japanese to review the localized interfaces. Traditional Chinese supports text/voice capture, ordinary notes, and keyword search. Spanish and Japanese additionally support the common reminder, item-location, and location-search patterns covered by the release tests.
5. Open Calendar to review records by date. Location permission is optional and is used only for Apple WeatherKit forecasts.
6. Open Settings to review permission status, independent app/speech language selection, and JSON backup export/import.

Apple Speech can follow the app language or be selected independently as `zh-CN`, `zh-TW`, `en-US`, `es-US`, `es-MX`, `es-ES`, or `ja-JP`. Following the app maps Simplified Chinese to `zh-CN`, Traditional Chinese to `zh-TW`, English to `en-US`, Spanish to `es-US`, and Japanese to `ja-JP`. The release build uses on-device storage, local notifications, Apple WeatherKit, and manual JSON backup export/import. It does not require an account, a developer-operated backend, or automatic cloud sync. Denying microphone, speech, notification, or location permissions does not prevent text capture and local record management.
```

这段 Review Notes 已按首发 Release 的“本机存储 + 手动 JSON 备份”边界撰写；若重新启用 CloudKit，必须先完成 Production schema、多设备和冲突测试后再改写。

## 5. 隐私与数据说明

- 无账号系统、无开发者自建后端
- 无广告、分析或第三方营销 SDK
- 语音识别由 Apple Speech 能力提供
- 定位仅用于 Apple WeatherKit 天气请求，不写入记录、备份或 Release 日志
- 提醒通过本地通知送达
- 记录、提醒和搜索历史保存在本机；用户可主动导出或导入 JSON 备份
- App Store Privacy 建议以 [隐私营养标签填写建议.md](/Users/Kenneth/Documents/Code/EJ/隐私营养标签填写建议.md:1) 为核对基线

## 6. Export Compliance

- `ITSAppUsesNonExemptEncryption = NO` 已写入 `Info.plist`
- 上传后仍按 App Store Connect 实际出现的出口合规问题逐项回答

## 7. 截图清单与规格

首发建议制作 5～7 张真实 App 使用截图：

1. 一句话快速录入
2. 最近记录与同一物品的分类/位置浏览
3. 日历回看与天气提示
4. 搜索找回
5. 提醒管理
6. 设置、iCloud 状态和备份恢复

当前 App 仅支持 iPhone。优先提交 6.9 英寸竖屏截图，同一组统一使用 Apple 接受的一个尺寸，例如 `1320 × 2868`、`1290 × 2796` 或 `1260 × 2736`。每个本地化最少 1 张、最多 10 张；截图不能带 alpha 通道，且应展示真实 App 使用界面，不能只放启动页。

## 8. 必填链接与联系人

- Privacy Policy URL：`https://blizzard1311.github.io/EJ/privacy.html`
- Support URL：`https://blizzard1311.github.io/EJ/support.html`
- 支持邮箱：`zl.kenneth@gmail.com`
- Marketing URL：可选

隐私政策 URL 与支持页使用 GitHub Pages 默认 HTTPS 域名；App 内设置页提供同一组网页入口和支持邮箱。

## 9. 当前上线前最小收口顺序

1. 用蜂窝网络复核已部署的隐私政策与支持页
2. 完成真实 Release 真机回归并记录结果
3. 产出 6.9 英寸真实截图
4. 每次上传前从当前最高构建号继续递增，重新 Archive，核对签名、Release entitlement、`PrivacyInfo.xcprivacy` 和 App 图标
5. 上传 TestFlight，完成内部测试后再提交审核
