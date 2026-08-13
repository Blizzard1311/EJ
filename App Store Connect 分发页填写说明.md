# Mind Talk App Store Connect 分发页填写说明

更新日期：2026-08-09

本文档用于填写 App Store Connect 分发页面中与公开链接和特殊物料相关的字段，基于当前 `Mind Talk` 项目仓库与已上线公开页面的实际状态整理。

## 1. 技术支持 URL

- 可直接填写：`https://blizzard1311.github.io/EJ/support.html`
- 当前状态：已存在，且公网可访问
- 本地对应文件：[site/support.html](/Users/Kenneth/Documents/Code/EJ/site/support.html:1)
- App 内对应常量：[YijiApp/App/AppLocalization.swift](/Users/Kenneth/Documents/Code/EJ/YijiApp/App/AppLocalization.swift:22)

说明：

- 设置页中的“支持”入口已经使用同一 URL。
- 该页面内容包含功能说明、常见问题、权限说明和联系方式，满足 Support URL 的基本要求。

## 2. 营销网址 URL

当前项目没有单独制作营销落地页，但已有一个公开入口页可用。

- 可选填写地址：`https://blizzard1311.github.io/EJ/`
- 当前状态：已存在，且公网可访问
- 本地对应文件：[site/index.html](/Users/Kenneth/Documents/Code/EJ/site/index.html:1)

建议：

- 如果本次发版以最快提交为优先，`Marketing URL` 可以留空。
- 如果希望 App Store Connect 中三个 URL 字段都有值，可先填写：
  - `https://blizzard1311.github.io/EJ/`

注意：

- 这个页面目前是“公开信息/合规入口页”，不是典型营销页。
- 如果后续需要更完整的品牌展示、产品卖点、截图说明或下载引导，建议再单独补一版正式营销页。

## 3. 路由 App 覆盖地区文件

结论：当前不需要提供。

原因：

- `Mind Talk` 不是 Routing App，不提供面向其他 App 的点到点路线导航能力。
- 当前仓库中也不存在 routing coverage / geographic coverage 相关文件。
- Apple 的该项要求仅适用于 Routing App。

填写建议：

- 如果 App Store Connect 页面出现 `Routing App Coverage File` 字段，对当前 App 视为不适用。
- 不需要为了通过审核额外生成这类文件。

## 4. 本次可直接使用的填写值

### 建议填写版本

- Technical Support URL
  - `https://blizzard1311.github.io/EJ/support.html`
- Marketing URL
  - 留空
- Routing App Coverage File
  - 不适用
- Copyright
  - `© 2026 你的真实姓名`

### 备选填写版本

- Technical Support URL
  - `https://blizzard1311.github.io/EJ/support.html`
- Marketing URL
  - `https://blizzard1311.github.io/EJ/`
- Routing App Coverage File
  - 不适用
- Copyright
  - `© 2026 你的真实姓名`

## 5. Copyright 填写建议

结论：可以直接填写，不需要先办理中国软件著作权登记。

适用于你当前情况的建议写法：

- 如果 App 由你个人开发，权利归你本人：
  - `© 2026 你的真实姓名`

不建议当前写法：

- 仅写品牌名，例如 `Mind Talk`

原因：

- `Copyright` 更稳妥的写法是实际权利主体名称。
- 对个人开发者来说，通常应写自然人真实姓名。
- `Mind Talk` 是品牌名，不一定等于法律意义上的权利主体名称。

补充说明：

- 年份通常填写首次上架年份；当前首发年份为 `2026`。
- 如果以后改为公司主体持有，再改成：
  - `© 2026 公司全称`
- Apple 上架并不要求你先取得中国软件著作权证书；只要你对 App 享有相应权利即可填写。

## 6. 对应仓库文件

- 支持页：[site/support.html](/Users/Kenneth/Documents/Code/EJ/site/support.html:1)
- 隐私页：[site/privacy.html](/Users/Kenneth/Documents/Code/EJ/site/privacy.html:1)
- 公开入口页：[site/index.html](/Users/Kenneth/Documents/Code/EJ/site/index.html:1)
- App 内支持与隐私链接常量：[YijiApp/App/AppLocalization.swift](/Users/Kenneth/Documents/Code/EJ/YijiApp/App/AppLocalization.swift:22)
- 上架资料草案：[App Store Connect 上架资料草案.md](/Users/Kenneth/Documents/Code/EJ/App%20Store%20Connect%20上架资料草案.md:168)

## 7. 备注

- 2026-08-09 已核对 `support.html`、`privacy.html` 和站点根路径公网访问状态，均返回可访问响应。
- 如果后续更换域名或迁移站点，需要同步更新：
  - App Store Connect 中填写的 URL
  - App 内设置页使用的支持/隐私常量
