# 易记 UI 改版交付说明

## 交付目标

本次只调整 SwiftUI 界面与页面内部交互，不修改业务功能、数据模型、解析规则或服务层。

设计方向：暖灰背景、白色表面、低饱和鼠尾草绿主色，减少蓝色渐变、发光、玻璃效果和嵌套卡片。

## 需要覆盖的文件

将 `SwiftUI-Files/` 中的文件覆盖到易记最新版工程的相同路径：

1. `YijiApp/App/AppTheme.swift`
2. `YijiApp/App/RootTabView.swift`
3. `YijiApp/Features/Capture/CaptureView.swift`
4. `YijiApp/Features/Home/HomeView.swift`
5. `YijiApp/Features/Home/CalendarMonthView.swift`
6. `YijiApp/Features/Settings/SettingsView.swift`

`HomeView.swift` 与 `CalendarMonthView.swift` 必须一起覆盖。新版 `HomeView` 会向日历传入当天记录摘要。

这些文件沿用原文件名和工程引用，因此不需要向 Xcode 工程新增 Swift 文件，也不需要重新配置 target membership。

## 页面变化

### 记录

- 保留按住录音、松开识别、文字编辑、保存和语音搜索。
- 去掉蓝色渐变背景与发光圆环。
- 使用暖灰背景、鼠尾草绿录音按钮和更克制的状态面板。
- 增加“记录优先保存在本机”的隐私提示。

### 收纳

- 保留全部容器、数量、管理入口、详情页和删除操作。
- 分类卡片改成白色表面、细描边和低饱和分类色。
- 减少大卡片嵌套，突出分类名称、物品和位置。

### 日历

- `CalendarMonthView` 从 `UICalendarView` 包装组件改为纯 SwiftUI 按周月历。
- 点击日期后，在日期所在周下方展开天气和当天记录摘要。
- 再点同一天收起；点击其他日期时展开区移动到对应周。
- 保留月份切换、今天状态、记录、待提醒、已提醒和天气标记。
- 页面下方仍保留原完整记录列表及详情跳转，避免功能损失。

### 设置

- 保留本机数据、语音/通知/定位权限、iCloud、备份导入导出和系统设置入口。
- 改为暖灰背景、白色分组、细边框和统一的绿色图标语义。

## 明确没有修改

- `AppModel.swift`
- `YijiCore/` 下的模型、解析器、分类器与搜索逻辑
- `SpeechTranscriber.swift`
- `LocalNotificationScheduler.swift`
- `CalendarWeatherModel.swift`
- `FileBackedVaultStore.swift`
- `CloudKitVaultSyncCoordinator.swift`
- entitlements、Info.plist、签名、Bundle ID 和 Xcode 工程配置

## 合入建议

1. 在朋友的最新 Git 工程中新建分支，例如 `ui/warm-minimal-redesign`。
2. 确认工程已经包含四个标签页和 CloudKit 版本，不要覆盖到早期三个标签页版本。
3. 覆盖上述六个同路径文件。
4. 在 Xcode 中执行 Clean Build Folder，然后重新构建。
5. 用至少一台常规尺寸 iPhone 和一台小屏 iPhone 检查四个页面。

## 必测交互

- 记录页按住、松开、识别、编辑、清空、保存和搜索。
- 收纳容器管理、进入容器详情、记录详情和删除。
- 日历前后月份、日期展开/收起、天气权限、记录状态点和记录详情。
- 设置页通知授权、跳系统设置、导出、导入和 ShareLink。
- iCloud 同步状态刷新与应用重新进入前台。

## 当前验证状态

- 六个 Swift 文件已通过 `swiftc -frontend -parse` 语法解析。
- 当前交付机器没有安装完整 Xcode，未执行 iOS target 的最终编译和模拟器视觉检查。
- 合入后必须由朋友在完整 Xcode 环境中完成 build 和真机/模拟器回归。

## 视觉参考

`Design-Reference/` 中保留了功能保留版 HTML、CSS 和三张预览图，只用于视觉对照，不需要放入 iOS App target。

`Preview/` 中是记录、收纳、日历展开和设置四张独立界面图，便于逐页核对。
