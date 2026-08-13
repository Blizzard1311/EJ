# Mind Talk 上传到 App Store Connect 前的最终检查清单

更新日期：2026-08-10

本文档只保留上传前真正需要逐项确认的内容，按执行顺序排列。

## 一、版本与构建号

- [ ] 确认本次上传目标版本为 `1.0`
- [ ] 确认 `MARKETING_VERSION` 与 App Store Connect 版本页一致
- [ ] 确认 `CURRENT_PROJECT_VERSION` 使用一个未被 App Store Connect 占用的新构建号
- [ ] 如果你准备上传的是包含新 logo 的构建，必须重新 Archive 并重新上传；GitHub 推送不会自动更新 App Store Connect 图标

说明：

- 你当前工程里的 iOS target 构建号仍是 `11`
- 如果 App Store Connect 已经存在同号 build，上传前先递增

## 二、App 名称与品牌展示

- [ ] App Store Connect 中的名称最终确认使用 `Mind Talk`
- [ ] 本地 App Icon 已是最新 logo
- [ ] 启动画面已是最新 logo
- [ ] 如果 App Store Connect 顶部仍显示空白 icon，不要直接判断资源失败，先确认新 build 已处理完成

图标说明：

- App Store Connect 的图标来自已上传并处理完成的构建包
- 仅修改本地资源或推送 GitHub，不会更新 App Store Connect 中显示的 icon

## 三、二进制与本地验证

- [ ] `YijiCore` 测试通过
- [ ] iOS Simulator Debug 构建通过
- [ ] iOS Simulator Release 构建通过
- [ ] 使用当前代码重新生成 Release Archive
- [ ] 如需导出 IPA，确认导出成功
- [ ] 归档包内 App Icon、Launch Screen、五语言资源都为最新版本

建议本地命令：

```bash
cd /Users/Kenneth/Documents/Code/EJ/YijiCore
swift test
```

```bash
cd /Users/Kenneth/Documents/Code/EJ
xcodebuild -project Yiji.xcodeproj -scheme YijiApp -configuration Release -destination 'generic/platform=iOS' -archivePath /private/tmp/YijiApp.xcarchive archive
```

## 四、功能回归最低要求

- [ ] 记录页语音按住开始、松开结束正常
- [ ] 文字录入与保存正常
- [ ] 搜索正常
- [ ] 收纳详情正常
- [ ] 日历日期展开与收起正常
- [ ] 天气权限允许/拒绝路径正常
- [ ] 通知权限允许/拒绝路径正常
- [ ] 备份导出/导入正常
- [ ] iCloud 状态文案正常

说明：

- iCloud 空间不足不作为当前发版阻塞项
- 但界面文案不能出现误导或明显异常状态

## 五、商店元数据

- [ ] 简体中文商店文案已填写
- [ ] 繁体中文商店文案已填写
- [ ] English (U.S.) 商店文案已填写
- [ ] 如本次要带西班牙语/日语商店页，再补对应本地化
- [ ] 主分类：`Productivity`
- [ ] 副分类：`Utilities`
- [ ] 年龄分级问卷已完成
- [ ] App Privacy 问卷已完成
- [ ] 价格与地区已确认

## 六、链接类字段

- [ ] Privacy Policy URL：`https://blizzard1311.github.io/EJ/privacy.html`
- [ ] Technical Support URL：`https://blizzard1311.github.io/EJ/support.html`
- [ ] Marketing URL：可留空；如需要填写可用 `https://blizzard1311.github.io/EJ/`
- [ ] Copyright：
  - 建议填写：`© 2026 你的真实姓名`

## 七、审核信息

- [ ] Sign-in required：`No`
- [ ] 不填写 demo account 用户名和密码
- [ ] Review 联系人姓名、邮箱、电话已填写
- [ ] Review Notes 已填写最终英文版

结论：

- 这个 App 当前不需要审核账号
- 不要提供你的 Apple ID、iCloud 账号或任何私人登录信息

推荐使用文档：

- [App Review Notes 最终版.md](/Users/Kenneth/Documents/Code/EJ/App%20Review%20Notes%20最终版.md:1)

## 八、截图与展示素材

- [ ] 使用当前最新 build 截图
- [ ] 截图尺寸统一
- [ ] 不带 alpha 通道
- [ ] 不出现调试信息、占位文案或个人隐私数据
- [ ] 首页、收纳、日历、设置等关键页面均已覆盖

## 九、上传后必须复核

- [ ] build 在 App Store Connect 中处理完成
- [ ] 版本页能选中这次新 build
- [ ] App Store Connect 顶部 icon 已更新为新 logo
- [ ] Included Assets / Build 信息正常
- [ ] 没有新的 Export Compliance 或 Missing Compliance 阻塞

如果图标仍为空白，按这个顺序排查：

1. 确认上传的是包含新 `AppIcon-1024.png` 的新构建
2. 确认该 build 已处理完成
3. 确认版本页绑定的是这次新 build，而不是旧 build
4. 再回头检查本地资源集与 Archive 内容

## 十、提交审核前最后确认

- [ ] 版本页没有红色必填报错
- [ ] 审核信息已完整填写
- [ ] 隐私、年龄分级、地区、价格、链接都已保存
- [ ] 已选定正确 build
- [ ] 商店图标、名称、截图和文案一致
- [ ] 确认后再点 Submit for Review
