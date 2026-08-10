# 易记 App Store Connect 上架资料草案

## 当前应用信息

- App 名称：易记
- 主屏显示名：易记
- Bundle ID：`com.blizzard1311.yiji`
- 当前版本：`1.0`
- 当前构建号：`1`
- 首发范围：美区本地优先 MVP
- 首发阶段不包含：注册、登录、group、付费

## 建议分类

- 主分类：Productivity
- 副分类：Utilities

## 建议副标题

- 一句话记住位置、提醒和想法

备选：

- 用语音快速记住生活小事
- 你的本地生活记忆助手

## 建议关键词

- 提醒
- 语音记录
- 备忘
- 物品位置
- 笔记
- 搜索
- family organizer
- reminder

可压缩成 App Store 关键词串时再做长度优化。

## 描述草案

### 中文版

易记是一款面向个人生活场景的轻量记录工具。你可以用一句自然语言，快速记下物品放在哪里、什么时候要提醒、以及临时想到的事项。

当前 MVP 版本支持：

- 语音或文字快速录入
- 自动识别位置记录、提醒事项和普通笔记
- 最近记录回看与搜索
- 本地提醒创建与系统通知送达
- iCloud 可用时的私有同步
- 本地备份导出与导入恢复

适合记录这类内容：

- 我把护照放在书房右边抽屉
- 明天下午三点提醒我交物业费
- 记一下，下周要给孩子准备报名材料

当前版本为本地优先设计：

- 不需要账号
- iCloud 可用时会同步到用户自己的私有数据库
- 数据以本地使用为主

### 英文版

Yiji is a lightweight personal memory app for everyday life. Capture where you put things, what you need to do later, and quick notes with a single natural sentence.

Current MVP features:

- Fast capture with voice or text
- Automatic parsing for storage notes, reminders, and general notes
- Search and recent history lookup
- Local reminders with iPhone system notifications
- Private iCloud sync when available
- Local backup export and import, with optional transfer through Files or iCloud Drive

Examples:

- I put my passport in the top drawer in the study.
- Remind me at 3 PM tomorrow to pay the property fee.
- Note this: prepare school registration materials next week.

This first release is designed as a local-first experience:

- No account required
- Syncs through the user's private iCloud database when available
- Built primarily for personal use

## Promotional Text 候选

- 用一句话，记住物品位置、提醒事项和临时想法。

## 隐私与数据说明

当前真实行为可对外描述为：

- 无账号系统
- 无开发者自建云端账号系统
- 无广告跟踪
- 无第三方营销 SDK
- 语音识别依赖 iOS 系统能力
- 提醒通过本地通知送达
- 数据以本地存储为主，并在 iCloud 可用时同步到用户自己的私有数据库

## Export Compliance

- `ITSAppUsesNonExemptEncryption = NO` 已写入 `Info.plist`

## 年龄分级建议

- 建议先按 `4+` 方向填写

前提：

- 无博彩
- 无成人内容
- 无暴力内容
- 无用户社交动态

## 截图清单

首发建议至少准备：

1. 首页最近记录
2. 语音录入页
3. 提醒管理页
4. 搜索页
5. 设置 / 本地备份页

## 仍待补充的素材

- 启动页最终 Logo
- App Store 截图
- 隐私政策链接
- 支持链接
- 营销文案最终定稿

## 链接占位

- 隐私政策草案：见 [隐私政策草案.md](/Users/Kenneth/Documents/Code/EJ/隐私政策草案.md:1)
- 支持页草案：见 [支持页面草案.md](/Users/Kenneth/Documents/Code/EJ/支持页面草案.md:1)
- 隐私政策 URL：待补
- 支持 URL：待补
- 营销站点 URL：可留空或后补

## 当前上线前最小收口顺序

1. 真机再做一轮带记录的完整回归
2. 在 CloudKit Console 确认 schema 已部署到 Production
3. 产出 5 组截图
4. 补隐私政策与支持页链接
5. 用当前 Archive 上传 TestFlight
