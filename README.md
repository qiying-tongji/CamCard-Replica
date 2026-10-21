# CamCard-Replica

同济大学移动应用开发课程作业：用规格驱动开发，黑盒复刻「名片全能王」里的「名片数字化与联系人管理」闭环。

参考对象是 Android 名片全能王 **7.90.5.20261016**（简体中文，未登录）。观察记录只写 2026-10-18 截图里看到的行为。iOS 实现是 `CardVault`，用 SwiftUI 和 SwiftData，不复制 CamCard 的界面原文，也不复刻会员、云同步、CRM 和二维码交换。

## 仓库里有什么

| 路径 | 内容 |
| --- | --- |
| `01_reference_observation.md` | 参考 App 的版本、页面和操作记录 |
| `02_spec.md` | 要复刻的功能和页面流程 |
| `03_business_card_schema.md` | 名片字段、空值规则和导出文本格式 |
| `04_test_plan.md` | T01–T08、T10–T20。T09（没有网站的名片）不验收 |
| `05_test_cards.xlsx` | 40 张虚构名片的正确答案 |
| `reference_screenshots/` | 参考 App 截图 |
| `test_card_images/` | C001–C040 图片 |
| `generate_test_cards.py` | 生成测试名片和 Excel 的脚本 |
| `CardVault/` | iOS 工程 |
| `TEST_REPORT.md` | 2026-10-20 在 Mac 模拟器上的测试记录 |

测试名片的姓名、电话和邮箱都是虚构的。如果老师发放官方测试集，用官方数据，不用这 40 张替换。

## 运行

需要 Mac 和 Xcode。工程按 Xcode 26、iOS 17 配置，只支持 iPhone。

1. 打开 `CardVault/CardVault.xcodeproj`。
2. Scheme 选择 `CardVault`。
3. 选一台 iPhone 模拟器，运行。
4. 单元测试目标是 `CardVaultTests`。

Bundle ID 是 `edu.tongji.CardVault`。相机和通讯录的用途说明已经写在工程设置里。相册导入使用系统照片选择器。

Windows 上不能编译这个工程。

## 当前 App 做什么

底部有两个标签：名片夹、扫描。

扫描页可以拍照或从相册导入。导入后用可拖动的四边形圈住名片，校正后再做 OCR。核对页展示姓名、公司、职位、手机、电话、邮箱、网址和地址；空着的字段保持空，不补全。确认后写入本地数据库，名片夹列表会更新。

名片夹支持搜索（姓名、公司、职位、电话、邮箱）、标签筛选、备注、编辑、删除和 vCard 导出。原图、改过的字段、标签和备注保存在本机。详情里的空字段显示「未填写」。

没有实现参考 App 里的这些部分：五个底部标签、未确认队列、分组（本工程用标签）、传真和多行电话、分享成纯文本，以及会员和云同步。`04_test_plan.md` 里的 Status 仍是 Not Run，那份文件记录的是参考行为，不是这次模拟器测试的勾选结果。

## 测试结果

`TEST_REPORT.md` 记录的是 2026-10-20、iPhone 17 Pro 模拟器（iOS 26.0）上的一次检查。

单元测试 3 项，通过 2 项，失败 1 项：

- `VisionOCRServiceTests` 通过：C001 能识别出姓名。
- `VCFExporterTests` 通过：有值的字段写入 vCard，空字段不出现。
- `BusinessCardFieldParserTests` 失败：10 张样例、80 个字段里 79 个与正确答案一致。C013 的公司被 OCR 读成「津波咨询」，正确答案是「津渡咨询」。解析器按识别原文保存，核对页可以手改。

同一份报告里，空列表、导入后保存、详情、编辑、删除、重启后数据仍在、搜索、标签和缺网址不补全，是按代码路径核对的，没有单独的界面自动化测试。
