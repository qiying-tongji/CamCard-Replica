# CardVault 回归报告

- 日期：2026-10-20
- 工程：`CardVault/CardVault.xcodeproj`，scheme `CardVault`
- 设备：iPhone 17 Pro 模拟器（iOS 26.0，id `0B4DFBA3-EA12-424B-B173-AE36373C404B`）
- 结果文件：`Test-CardVault-2026.10.20_19-39-41-+0800.xcresult`
- 本轮没有改代码。唯一失败来自 OCR 把 C013 的公司读成「津波咨询」，解析器按原文写入，没有改字。

界面场景没有 XCUITest。第 1–8 条按当前实现的数据流核对；第 9、10 条有 XCTest 结果。

## XCTest

共 3 项，通过 2，失败 1。

| 测试 | 结果 | 实际 |
| --- | --- | --- |
| `VisionOCRServiceTests.testRecognizeTextContainsGroundTruthName` | 通过 | 0.903 秒。C001 的 `fullText` 非空，并包含 Elena 或 Marsh。 |
| `VCFExporterTests.testVCardContainsMappedFieldsAndSkipsNil` | 通过 | 0.002 秒。输出含 `FN:何予安`、`ORG:津渡咨询`、`TEL;TYPE=CELL:+86 138-0000-1008` 和 `VERSION:3.0`，行尾为 CRLF。`TITLE`、`TEL;TYPE=WORK`、`EMAIL`、`URL`、`ADR` 未出现。 |
| `BusinessCardFieldParserTests.testParsedFieldsMatchGroundTruthOrStayNil` | 失败 | 9.089 秒。10 张名片、80 个字段，79 个与 Ground Truth 一致（98.8%）。分字段：name、jobTitle、mobile、phone、email、website、address 均为 10/10；company 为 9/10。漏识别：无。唯一错字段：C013 company，OCR 置信度 0.50 的行是「津波咨询」，解析结果同为「津波咨询」，Ground Truth 为「津渡咨询」。 |

C013 这一项不修。核对页应显示识别到的字，用户可以在保存前改。把「波」改成「渡」会写入 OCR 没有给出的字。

## 硬性场景

| 场景 | 预期 | 实际 | 结果 |
| --- | --- | --- | --- |
| 首次启动空状态 | 本地没有名片时，名片夹显示空状态，不放入示例名片。 | `CardVaultApp` 使用默认的磁盘 `ModelContainer`，启动时不插入数据。`CardListView` 在 `cards.isEmpty` 时显示图标、「还没有名片」和「扫描第一张名片」。示例名片只在预览用的内存容器里。 | 通过 |
| 导入→识别→确认→保存→列表更新 | 相册图片经检测、校正、OCR、字段解析和核对后，保存写入名片夹，列表出现这张名片。 | `ImportView`：相册 `Data` 转 `UIImage`，`RectangleDetector` 给出可拖动四边形，确认后 `ImageCorrector` 校正，点「进入识别」调用 `VisionOCRService` 和 `BusinessCardFieldParser`，进入 `ConfirmView`。保存时插入 `BusinessCard` 和 `OCRResult`，`modelContext.save()` 后切到名片夹。列表 `@Query` 按 `createdAt` 倒序，会看到新记录。C013 的公司字段会先显示 OCR 原文「津波咨询」，核对页可以改后再保存。 | 通过 |
| 详情页字段完整 | 详情展示原图和 8 个联系人字段。空字段有明确空态。 | `CardDetailView` 展示原图，以及姓名、公司、职位、手机、电话、邮箱、网址、地址。空值显示「未填写」。另有标签和备注。 | 通过 |
| 编辑后列表和详情同步更新 | 保存编辑后，详情和列表都是新值。取消不写入。 | `EditView` 与核对页共用 `CardFieldForm`。保存调用 `draft.apply(to:)` 写回同一条 `BusinessCard` 并 `save()`。列表和详情读的是这条记录。取消只 `dismiss()`，不调用 `apply`。 | 通过 |
| 删除后列表消失 | 确认删除后，这张名片从列表消失。 | 详情「删除」先弹出确认框，确认后 `modelContext.delete(card)`、`save()`、`dismiss()`。`@Query` 不再包含该记录。删光后回到空状态。 | 通过 |
| Kill App 后重启数据仍在 | 进程结束后再打开，原图、改过的字段、标签、备注都还在。 | 容器是默认磁盘库，原图和处理图使用 `externalStorage`。保存、编辑、增删标签都会 `modelContext.save()`。备注在输入时写入 `card.notes`，离开详情时再 `save()`。默认 `autosaveEnabled` 为 true，退到后台时上下文会自动保存。 | 通过 |
| 搜索姓名/公司/电话命中 | 输入姓名、公司或电话的一部分，能筛出对应名片；大小写不敏感。 | `matchesSearch` 对 name、company、jobTitle、mobile、phone、email 做 `localizedCaseInsensitiveContains`。电话同时查手机和工作电话。空关键字不过滤。无命中时显示「没有匹配的名片」。 | 通过 |
| 标签筛选命中 | 点标签只保留带该标签的名片，再点一次取消。 | 列表上方按标签名排列。点中的标签写入 `selectedTagID`，`matchesSelectedTag` 要求名片的 `tags` 含该 id。再点同一个标签把 `selectedTagID` 置空。筛选与搜索同时生效。 | 通过 |
| VCF 导出字段正确 | vCard 3.0 含姓名、公司、手机；空字段不出现。 | `VCFExporterTests` 通过。样例输出含 `FN:何予安`、`N:何予安;;;;`、`ORG:津渡咨询`、`TEL;TYPE=CELL:+86 138-0000-1008`。职位、工作电话、邮箱、网址、地址为 nil，对应行不存在。详情「导出」把 UTF-8 `.vcf` 写到临时目录，并用 `ShareLink` 分享。 | 通过 |
| 无 website 的名片保存后 website 为 nil | 名片上没有网址时，解析和保存都不得补一个网址。 | 解析测试里 website 为 10/10。Ground Truth 中 website 为 null 的 C007、C015、C025、C029、C030、C032、C034 都是 8/8，解析出的 website 为 nil。核对页空字符串经 `CardFieldDraft.stored` 写成 nil。 | 通过 |
