# Business Card Schema

一条名片要保存的内容，按 Android 名片全能王 7.90.5.20261016 的核对页、详情、分组和导出文本来定。没有网站的名片不单独设计。

`String?` 表示可以没有值。原图上没有的栏就空着。

## 1. Identity

- `id: String` — 创建后不改。
- `createdAt: Date` — 首次保存时间。列表按日期分组，截图里的日期是 2026-10-18。
- `updatedAt: Date` — 字段、分组或备注变化时更新。
- `confirmed: Bool` — 保存后先进入「未确认」。点「全部确认」并确定之后，才算进入名片夹的「全部」计数。

## 2. Images

- `originalImage: String?` — 拍摄或导入的原图。
- `processedImage: String?` — 手动校正页点「完成」之后的图。校正页用四边形和 8 个点圈住名片，四个角、四条边中点各一个。
- `backImage: String?` — 核对页有「添加名片背面」。这次没有保存过背面，为空。

删除名片时，记录和这些本地图片一起从名片夹消失。确认框写明 30 天内可以到官网回收站恢复；本项目不做官网回收站，只做本地删除。

## 3. 核对页字段

### 姓名

- `name: String?`

### 电话

`phones: [{ label: String, value: String }]`

截图里出现过的 label：手机、工作电话、工作传真、住宅电话。住宅电话可以是用户后来加上的，原图没有也允许存在。传真单独一行，不写入手机。

### 邮箱

`emails: [{ label: String, value: String }]`

这次的 label 是「工作邮箱」。

### 公司

`organizations: [{ company: String?, department: String?, jobTitle: String? }]`

核对页可以有多行公司。最终详情和列表只展示一个职位和一个公司：何予安是「分析师 / 津渡咨询」，马听澜是「质量主管 / 石桥制造」。

### 网址

`websites: [{ label: String, value: String }]`

核对页的 label 是「公司主页」。本次导出的文本没有这一行，所以网址留在名片记录里，不写进导出文本。

### 地址

- `addressStreet: String?` — 公司地址
- `addressExtended: String?` — 扩展地址
- `addressCity: String?` — 城市
- `addressRegion: String?` — 省/直辖市/自治区
- `postalCode: String?` — 邮编
- `addressCountry: String?` — 国家/地区

详情和导出把何予安的地址写成「澄湾市 渡口街15号」。英文详情写成「16 Glass Road, Qinglan」，不保留核对页里误带上的单词 Address。

### 分组和备注

- `groupNames: [String]` — 用户创建的分组，例如「分析师」。没有加入这种分组时，名片出现在「未分组」。系统还显示「最近新增」，按创建时间算，不需要用户输入。
- `notes: String?` — 备注。详情上出现过「2026-10-18其他方式保存」，截图没有显示手写过程，不规定每张名片都自动写这句话。

## 4. 列表和详情使用的扁平字段

- `company: String?`
- `department: String?`
- `jobTitle: String?`
- `mobile: String?` — 手机
- `phone: String?` — 工作电话
- `fax: String?` — 工作传真
- `homePhone: String?` — 住宅电话
- `website: String?` — 公司主页，只在名片记录里
- `address: String?` — 详情和导出用的一整行地址

号码可以有两种显示：核对页 `+8613800001013`，详情和导出 `+86138-0000-1013`。英文号码核对页 `+15550136`，详情 `+1-555-0136`。对答案时比数字和类型。

`05_test_cards.xlsx` 的空白格表示原图没有该栏。多个邮箱在表里用 `; ` 连接。

## 5. Recognition Snapshot

用户修改最终字段时，不覆盖这里。

- `ocrRawText: String?` — 核对页没有原文框。记录仍保存原文，界面不单独做一页。
- `extractedFields` — 修改前的核对结果。
- `recognitionMode: String?` — 「基础识别」或「高精准识别」。
- `recognitionLanguages: [String]` — 截图为英语、简体中文、繁体中文。
- `correctedFields: [String]` — 何予安可以确定新增了住宅电话。

不保存置信度分数。

## 6. 导出文本

分享保存打开后是纯文本，不是一份需要照抄的 CamCard 网页。字段顺序按 `导出文件的内容.jpg`：

1. 姓名
2. 职位
3. 公司
4. 手机
5. 住宅电话
6. 工作电话
7. 工作邮箱
8. 公司地址

有值才输出该行。这次的文本没有公司主页，也没有工作传真，因为导出的那张何予安名片没有传真。住宅电话是后来加上的，所以出现在文本里。

文本末尾那条 `camcard.com` 链接属于对方的分享页，本项目不生成。

## 7. Data Rules

1. 原图上没有的电话、邮箱、职位和公司不生成。
2. 手机、工作电话、工作传真、住宅电话分行保存。
3. 多个邮箱全部保留。
4. 核对页未保存就返回，不进入「全部」计数。
5. 用户加上的住宅电话，详情和导出文本里都要在。
6. 搜索姓名、公司时标出命中字段。
7. 分组「分析师」里只有被添加的名片。删除分组这步没有截图；删除名片不会把它的分组名称变成另一张名片的分组。
8. 从详情删除并确认后，该名片离开列表，其他名片还在。
