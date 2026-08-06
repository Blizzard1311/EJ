# 易记 Yiji

易记是一个本地优先的 iOS MVP，用一句自然语言帮用户记录生活信息，并在之后通过搜索或提醒把信息找回来。

当前工程已经不是纯方案文档，而是一个可直接在 Xcode 中运行、可做真机试用的 SwiftUI 项目。

## 当前能力

- 简体中文、繁体中文、English、Español 与日本語界面
- 设置页可在跟随系统、简体中文、繁体中文、English、Español 和日本語之间即时切换
- 设置首页采用摘要入口，语言、权限与备份分别进入详情页，避免长语言文案互相挤压
- App 界面语言与语音识别语言可独立选择
- 语音识别选择“跟随 App”时，五种界面语言分别映射为 `zh-CN`、`zh-TW`、`en-US`、`es-US` 与 `ja-JP`
- 语音转写支持选择 `zh-CN`、`zh-TW`、`en-US`、`es-US`、`es-MX`、`es-ES` 与 `ja-JP`，并在设备不支持对应 locale 时明确降级为文字输入
- 中文、英文、西班牙语与日语文字录入及普通笔记保存
- 中文位置、提醒和时间规则解析
- 西班牙语与日语支持常用提醒时间、重复规则、物品位置及自然语言位置搜索解析
- 本地记录保存
- 本地搜索找回
- 提醒建模与本地通知
- 设置页、备份导出、备份导入
- 最近搜索历史持久化
- 日历中的未来 10 天天气提示（用户主动授权定位后）
- JSON 备份导出、导入，以及通过“文件”或 iCloud Drive 手动传递

## 当前限制

- 当前阶段不开发付费、订阅、恢复购买
- 当前阶段不做账号体系或自动云同步
- CloudKit 实验代码仅保留在 Debug 构建；App Store Release 使用本机存储和手动备份

## 公开支持页面

- 隐私政策：<https://blizzard1311.github.io/EJ/privacy.html>
- 在线支持：<https://blizzard1311.github.io/EJ/support.html>
- 支持邮箱：`zl.kenneth@gmail.com`
- 页面使用 GitHub Pages 默认 HTTPS 域名，不依赖自有服务器运行或续费

## 首发策略

- 首发目标是 `美区本地优先 MVP`，优先满足个人记录与提醒需求
- 首发版本不引入注册、登录、群组、共享、任务传递
- 首发版本不依赖自建后端、数据库、登录能力或自动云同步
- 先通过真机试用和 TestFlight 验证“是否有人持续使用”
- 邮箱账号、家庭共享和 group 协作放到首发之后再做

## 目录结构

- `project.yml`: XcodeGen 配置
- `YijiApp/`: SwiftUI App、页面、服务与本地持久化
- `YijiCore/`: 共享模型、解析器、搜索与测试
- `项目进度跟踪.md`: 当前阶段、待办与里程碑跟进
- `真机试用说明.md`: 真机试用与回归执行说明
- `易记_APP_MVP_开发文档_iOS_腾讯云_到期提醒版.md`: 产品与技术开发文档

## 本地运行

1. 生成 Xcode 工程

```bash
xcodegen generate
```

2. 用 Xcode 打开 `Yiji.xcodeproj`

3. 选择 `YijiApp` scheme

4. 运行到模拟器或真机

## 命令行验证

业务逻辑测试：

```bash
swift test --package-path YijiCore
```

App 工程构建：

```bash
xcodebuild -project Yiji.xcodeproj -scheme YijiApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4' build
```

## 试用建议

- 首次真机试用时，优先验证语音权限、麦克风权限和通知权限链路
- 日历天气为可选能力；拒绝定位不应阻止记录、搜索、提醒和备份
- 录入一条新记录后，应用会自动回到首页，并高亮刚保存的记录
- 导入备份后，应用会自动回到首页，并高亮最新导入的一条记录
- 如果导入了错误文件，应用会提示“不是易记导出的 JSON 备份文件”一类可理解文案
- 如需换机或跨设备转移，请导出 JSON 到“文件”或 iCloud Drive，再在另一台设备中执行覆盖导入

更完整的试用步骤见 [真机试用说明.md](/Users/Kenneth/Documents/Code/EJ/真机试用说明.md:1)。
