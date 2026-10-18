# Reference Test Plan

场景来自作业里的 T01–T20。T09 不做：这次不准备、也不验收「没有网站的名片」。参考结果只来自 2026-10-18 的截图。

我们自己的 App 尚未运行，Actual Result 都是待测试，Status 都是 Not Run。

## T01 — First Launch

- Purpose: 名片夹最初是空的。
- Preconditions: 没有已保存名片。
- Steps:
  1. 启动 App。
  2. 打开 Card Holder。
- Expected Result: 标题「名片夹」。搜索占位「输入姓名/职位/公司进行搜索」。正文「没有名片」「您可以使用名片识别功能上传名片，高效管理人脉」。没有示例名片。
- Reference Result: `首次打开02.jpg`。首页的「暂无名片」是数字名片，不是这张列表。
- Actual Result: 待测试。
- Status: Not Run

## T02 — Enter Scanner

- Purpose: 从名片夹进入相机。
- Preconditions: 名片夹已打开。
- Steps:
  1. 点右上角「+」。
  2. 点「扫一扫」。
- Expected Result: 菜单中有「扫一扫」。进入后能看到取景和快门。
- Reference Result: 菜单见 `进入扫描01.jpg`。相机见 `拍摄01.jpg`。
- Actual Result: 待测试。
- Status: Not Run

## T03 — Permission

- Purpose: 相机权限不可用时不能拍摄。
- Preconditions: 相机权限未开启。
- Steps:
  1. 进入扫描。
  2. 看提示，并确认可以离开。
- Expected Result: 「开启相机权限」「请您开启相机权限，以正常使用此功能」「设置路径：设置->应用->名片全能王->权限」「去设置」。不能拍摄，也不崩溃。
- Reference Result: `相机权限01.jpg`、`相机权限02.jpg`。
- Actual Result: 待测试。
- Status: Not Run

## T04 — Capture

- Purpose: 拍摄后进入校正和核对，未保存不入库。
- Preconditions: 相机可用，可拍摄 C013。
- Steps:
  1. 打开相机并拍摄。
  2. 在校正页点「取消」，确认名片夹没有新记录。
  3. 再拍摄，在校正页点「完成」。
- Expected Result: 相机有「基础识别 / 高精准识别」「正在寻找名片边框」「连续拍摄」「单张拍摄」和快门。校正页有「取消」「完成」。完成后进入「核对名片信息」。取消不增加「全部」计数。
- Reference Result: 取景见 `拍摄01.jpg`，校正见 `手动矫正01.jpg`。识别不准确时的「重新拍摄 / 更换语言」见 `重拍01.jpg`。
- Actual Result: 待测试。
- Status: Not Run

## T05 — Import

- Purpose: 相册图片走同一条校正和核对流程。
- Preconditions: 相册中有测试名片。
- Steps:
  1. 打开相册后点取消。
  2. 再选一张并点完成。
  3. 在校正页点完成。
- Expected Result: 选择器有「取消」和「完成」。完成后进入校正，再进入核对。取消不产生已确认名片。
- Reference Result: `相册导入01.jpg` 有「照片」「相册」「取消」「完成」和「选择照片(1/100)」。
- Actual Result: 待测试。
- Status: Not Run

## T06 — Card Boundary Detection

- Purpose: 倾斜名片可以被四边形套住。
- Preconditions: 使用 `test_card_images/C014.png`，即 `倾斜名片01.png`。
- Steps:
  1. 导入 C014。
  2. 在校正页把 8 个点调整到名片边缘。
  3. 点「完成」。
- Expected Result: 校正页显示蓝色四边形和 8 个圆点，四个角和四条边中点各一个。左上「取消」，右上「完成」。完成后核对页顶部是名片，不是整张桌面。
- Reference Result: `手动矫正01.jpg`、`倾斜名片的识别01.jpg`。取景中的「正在寻找名片边框」见 `拍摄01.jpg`。
- Actual Result: 待测试。
- Status: Not Run

## T07 — OCR

- Purpose: 识别结果进入字段，修改前的结果另存。
- Preconditions: C013 已进入核对页。
- Steps:
  1. 查看核对页。
  2. 修改或新增一个电话后保存。
  3. 检查修改前的副本仍是旧值。
- Expected Result: 核对页是分栏字段，不是一整段文字。数据中保留 `ocrRawText` 和修改前副本。界面不增加原文框。
- Reference Result: `核对信息01.jpg` 没有原文框，只有缩略图和字段。
- Actual Result: 待测试。
- Status: Not Run

## T08 — Structured Extraction

- Purpose: 保存后的职位和公司与测试表一致。
- Preconditions: 导入 C013 和 C014。
- Steps:
  1. 完成核对并保存。
  2. 看列表和详情中的姓名、职位、公司、电话。
- Expected Result:
  - C013：何予安，分析师，津渡咨询。手机和工作电话的数字与 +86 138-0000-1013、+86 21-0000-2013 一致。邮箱 yuan.he@example.com。地址「澄湾市 渡口街15号」。
  - C014：马听澜，质量主管，石桥制造。工作传真单独成行，数字与 +86 21-0000-3014 一致。公司不是「质量部」。
- Reference Result: 核对页上的误差见观察记录第 3.6 节。列表最终显示见 `删除后的列表.jpg`。
- Actual Result: 待测试。
- Status: Not Run

## T10 — Multiple Phones

- Purpose: 三种号码分开。
- Preconditions: 使用 C014。
- Steps:
  1. 导入 C014，打开核对页的电话区。
  2. 保存后在详情再看一次。
- Expected Result: 手机、工作电话、工作传真是三行。传真不出现在手机行。
- Reference Result: `倾斜名片的识别01.jpg` 已把三个号码分成手机、工作电话、工作传真。
- Actual Result: 待测试。
- Status: Not Run

## T11 — Manual Correction

- Purpose: 人工新增的电话会留下。
- Preconditions: C013 的核对页已打开。
- Steps:
  1. 增加「住宅电话」`13601388888`。
  2. 保存并打开详情。
- Expected Result: 详情同时有原来的手机、工作电话，以及住宅电话 `13601388888`。
- Reference Result: 输入见 `修改电话01.jpg`，详情见 `分享导出03.jpg`。
- Actual Result: 待测试。
- Status: Not Run

## T12 — Save

- Purpose: 确认之后列表出现新名片。
- Preconditions: 从空列表导入 C013。
- Steps:
  1. 在核对页点「保存」。
  2. 点「全部确认」，再点「确定」。
  3. 回到名片夹。
- Expected Result: 先见「保存成功」和「完成」。未确认页为「您有1张名片待确认」，问题是「是否确认所有未确认的名片」。确定后列表出现何予安，职位分析师，公司津渡咨询。
- Reference Result: `保存01.jpg`、`确认01.jpg`、`再次打开01.jpg`。
- Actual Result: 待测试。
- Status: Not Run

## T13 — Detail

- Purpose: 详情与已保存内容一致。
- Preconditions: C013 已确认，并含住宅电话。
- Steps:
  1. 从列表打开详情。
  2. 核对姓名、职位、公司、电话和地址。
- Expected Result: 标题「名片详情」。何予安，分析师，津渡咨询。电话含手机、住宅电话、工作电话。地址含「澄湾市」和「渡口街15号」。页面有编辑、删除和「分享名片」。
- Reference Result: `分享导出03.jpg`。Theo 的详情结构见 `删除01.jpg`：Surveyor，Glasshouse Survey，+1-555-0136，16 Glass Road, Qinglan。
- Actual Result: 待测试。
- Status: Not Run

## T14 — Edit

- Purpose: 已保存名片还能改。
- Preconditions: 何予安已在详情中。
- Steps:
  1. 点「编辑」。
  2. 改职位并保存，看详情和列表。
  3. 再进入后取消，确认不再变化。
- Expected Result: 详情有「编辑」。保存后详情和列表一起更新。取消不改变已保存的值。编辑页复用核对页的字段行。
- Reference Result: `删除01.jpg` 和 `分享导出03.jpg` 都有「编辑」。已保存名片的编辑过程没有单独截图；已证实的修改是核对页上新增住宅电话。
- Actual Result: 待测试。
- Status: Not Run

## T15 — Search

- Purpose: 按姓名和公司找到名片。
- Preconditions: 列表中有何予安 / 津渡咨询。
- Steps:
  1. 搜索 `何予安`。
  2. 搜索 `津渡咨询`。
  3. 搜索 `not-in-set`。
- Expected Result: 前两步都只返回这一张。「名片(1张)」。第一步高亮「姓名: 何予安」，第二步高亮「公司: 津渡咨询」。无关词不返回这张名片。
- Reference Result: `姓名搜索01.jpg`、`公司名搜索01.jpg`。
- Actual Result: 待测试。
- Status: Not Run

## T16 — Tag

- Purpose: 分组可以新建、加入名片并筛选。作业里的标签，这一版叫做分组。
- Preconditions: 列表里有何予安和马听澜，都还没有名为「分析师」的分组。
- Steps:
  1. 打开分组，确认有「未分组」和「最近新增」。
  2. 新建分组，输入「分析师」并确认。
  3. 在空分组中选「从名片夹中添加」，只加何予安。
  4. 打开「分析师」分组。
  5. 在分组搜索中输入「分析师」。
- Expected Result: 新建对话框有「取消」「确认」。空分组是「分析师(0)」，提示「点击右上角按钮添加名片」。添加页标题可变成「已选择1项」，底部「取消」「添加」。完成后是「分析师(1)」，只有何予安。搜索分组名能看到「分析师(1)」。马听澜不在这个分组里。
- Reference Result: `分组之前.jpg`、`新建分组.jpg`、`为分组加名片.jpg`、`为分组加名片02.jpg`、`分组完成.jpg`、`筛选分组.jpg`。
- Actual Result: 待测试。
- Status: Not Run

## T17 — Delete

- Purpose: 确认删除后，只有这一张消失。
- Preconditions: 列表至少有 Theo Marlow、马听澜、何予安。准备删除 Theo Marlow。
- Steps:
  1. 打开 Theo Marlow 的详情，点「删除」。
  2. 先点「取消」，确认他还在。
  3. 再次删除并点确认框里的「删除」。
  4. 回到名片夹。
- Expected Result: 确认框原文为「名片删除之后30天内可以到官网回收站进行恢复，请确认是否要删除所选名片？」，按钮「取消」「删除」。取消后名片还在。确认后列表为「全部 2」，剩下马听澜和何予安。
- Reference Result: `删除02.jpg`、`删除后的列表.jpg`。取消那一步没有单独截图。
- Actual Result: 待测试。
- Status: Not Run

## T18 — Persistence

- Purpose: 强制结束后，已保存结果还在。
- Preconditions: 已删除 Theo Marlow，还剩马听澜和何予安。
- Steps:
  1. 强制结束 App。
  2. 重新启动。
  3. 打开名片夹，确认这两张还在。
- Expected Result: 重启后两张名片都还在，职位和公司不丢。
- Reference Result: `杀掉进程再打开01.jpg` 重新进入首页，显示「马听澜识别完成」，「我的数字名片」旁的数字是 2。
- Actual Result: 待测试。
- Status: Not Run

## T19 — Export

- Purpose: 分享文本的字段与截图一致。
- Preconditions: 何予安已保存，并含住宅电话。
- Steps:
  1. 在详情点「分享名片」。
  2. 经「更多」保存文件。
  3. 打开文本。
- Expected Result: 第一层标题是「分享到...」，含 CC联系人、二维码、短信、邮件、更多。文本依次包含：姓名何予安，职位分析师，公司津渡咨询，手机 +86138-0000-1013，住宅电话 13601388888，工作电话 +8621-0000-2013，工作邮箱 yuan.he@example.com，公司地址「澄湾市 渡口街15号」。不包含公司主页，也不包含 camcard.com 链接。
- Reference Result: 面板见 `分享导出01.jpg`、`分享导出02.jpg`。路径提示见 `分享导出03.jpg`。正文见 `导出文件的内容.jpg`。参考 App 的正文末尾另有一条 CamCard 链接，本项目不生成。
- Actual Result: 待测试。
- Status: Not Run

## T20 — Exception

- Purpose: 取消和权限拒绝不产生新名片。
- Preconditions: 名片夹里已有名片。相机权限可以关掉。
- Steps:
  1. 相机页点关闭。
  2. 校正页点「取消」。
  3. 相册点「取消」。
  4. 在权限不可用时确认出现「去设置」。
  5. 删除确认框点「取消」。
- Expected Result: 前三步都不增加已确认名片。权限表现与 T03 相同。删除确认点「取消」后，原名片仍在列表。
- Reference Result: 关闭按钮在 `拍摄01.jpg`，校正取消在 `手动矫正01.jpg`，相册取消在 `相册导入01.jpg`，权限对话框已看到，删除框的「取消」在 `删除02.jpg`。
- Actual Result: 待测试。
- Status: Not Run

## 截图对应

| 测试 | 截图 |
| ---- | ---- |
| T01–T03 | `首次打开02.jpg`，`进入扫描01.jpg`，`相机权限01.jpg` |
| T04–T06 | `拍摄01.jpg`，`手动矫正01.jpg`，`相册导入01.jpg`，`倾斜名片的识别01.jpg` |
| T07–T08、T10–T13 | `核对信息01.jpg`，`修改电话01.jpg`，`保存01.jpg`，`确认01.jpg`，`分享导出03.jpg` |
| T15–T19 | `姓名搜索01.jpg`，`公司名搜索01.jpg`，分组六张，`删除02.jpg`，`删除后的列表.jpg`，`杀掉进程再打开01.jpg`，`导出文件的内容.jpg` |
| T20 | 关闭、取消校正、取消相册、权限对话框、删除框的取消按钮 |
