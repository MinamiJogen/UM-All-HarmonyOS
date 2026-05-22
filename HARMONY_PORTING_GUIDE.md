# ARK ALL / UMARKALL 鸿蒙原生移植工作指南

生成时间：2026-05-21  
目标平台：HarmonyOS 6.1，API 23  
目标工程：当前目录的原生鸿蒙工程  
业务来源：`ReactNative版本/`

本文档用于指导后续 GPT 或开发者把 `ReactNative版本` 中的 ARK ALL App 完整移植为 ArkTS/ArkUI 原生鸿蒙应用。本文只基于当前工作目录代码梳理；鸿蒙 API 具体导入路径、组件签名和权限名以 DevEco Studio 当前 API 23 SDK 补全和编译结果为准。

核心要求：迁移结果必须是鸿蒙原生 App。React Native 版本用于对照业务方法、数据流、缓存策略和交互目标，不作为组件实现方式或运行时依赖。

## 1. 当前工程状态

### 1.1 原生鸿蒙工程

当前鸿蒙工程是 DevEco/Hvigor 的 Stage Model 骨架：

- `build-profile.json5`
  - `targetSdkVersion`: `6.1.0(23)`
  - `compatibleSdkVersion`: `6.1.0(23)`
  - `runtimeOS`: `HarmonyOS`
  - 模块：`entry`
- `AppScope/app.json5`
  - `bundleName`: `com.shuyuan.umarkall`
  - `versionName`: `1.0.0`
  - `versionCode`: `1000000`
- `entry/src/main/module.json5`
  - `deviceTypes`: `phone`, `tablet`, `2in1`
  - `EntryAbility`
  - `EntryBackupAbility`
- `entry/src/main/ets/pages/Index.ets`
  - 当前仅为 `Hello World` 示例页。

结论：原生侧尚未实现业务逻辑，后续应从基础设施开始搭建，而不是直接逐页堆 ArkUI 页面。

### 1.2 React Native 业务来源

`ReactNative版本/package.json` 显示 RN 版本为：

- App version：`26.5.0`
- Expo：`^55.0.19`
- React Native：`0.83.6`
- React：`19.2.0`

RN 源码规模：

- `ReactNative版本/src`：约 14 MB
- `ReactNative版本/src/static`：约 13 MB
- `ReactNative版本/src/static/UMCourses`：约 2.5 MB
- `ReactNative版本/src/static/img`：约 8.8 MB
- 非大 JSON 源码约 20k 行；含课程 JSON 后约 86k 行。

最大业务文件：

- `src/pages/TabbarPages/courseSim/index.js`：课表模拟，约 1576 行
- `src/pages/TabbarPages/info/news/UMEventDetail.js`：澳大活动详情，约 988 行
- `src/static/UMCalendar/UMCalendar.js`：校历静态数据，约 974 行
- `src/pages/TabbarPages/features/FeatureList.js`：服务入口配置，约 907 行
- `src/pages/TabbarPages/info/home/index.js`：首页，约 758 行

## 2. App 功能总览

### 2.1 启动与全局初始化

来源：`ReactNative版本/App.js`

启动时做这些事：

1. 读取主题偏好 `themePreference`。
2. 根据系统深浅色或用户选择生成主题。
3. 初始化课程数据版本：
   - 首次启动写入 `course_version`
   - 若内置课程版本比本地缓存新，覆盖课程缓存。
4. 每 6 小时执行一次云端课程版本检查：
   - `last_version_check_timestamp`
   - `https://course-api.umall.one/version`
5. 初始化 Firebase Analytics 设备信息。
6. 注入全局 Toast、SafeArea、KeyboardProvider、ThemeProvider。

鸿蒙移植要求：

- 启动流程应沉到 `AppBootstrap` / `StartupService`，页面只消费结果。
- 课程数据初始化必须先于 `What2Reg` 和 `CourseSim` 页面使用。
- Firebase Analytics 在鸿蒙侧需要替换为可用分析方案，或提供 no-op 埋点层，避免业务页面到处判断平台。

### 2.2 导航结构

来源：

- `ReactNative版本/src/Nav.js`
- `ReactNative版本/src/Tabbar.js`
- `ReactNative版本/src/pages/TabbarPages/info/index.js`

一级底部 Tab：

1. `NewsTabbar`：资讯
2. `What2RegTab`：揾课/课程目录
3. `HarborNewTopic`：发帖快捷入口，不是真页面，点击后打开 Harbor 新帖页
4. `CourseSimTab`：课表模拟
5. `FeaturesTabbar`：服务

资讯页顶部 Tab：

1. `HomePage`：首页
2. `ClubPage`：组织
3. `UMEventPage`：澳大活动
4. `NewsPage`：澳大新闻

Stack 页面：

- `Bus`
- `CarPark`
- `UMOrg`
- `ClubDetail`
- `EventDetail`
- `NewsDetail`
- `UMEventDetail`
- `AllEvents`
- `LocalCourse`
- `Webviewer`
- `SettingPage`

鸿蒙移植建议：

- 使用一个全局 `NavPathStack` 管理二级页面。
- 根页面使用 ArkUI `Tabs` 实现底部 Tab。
- 资讯页内部再用一个顶部 `Tabs`。
- `HarborNewTopic` 不要作为真实 Tab 页面实现，应作为 Tab 点击事件打开外部链接，再保持当前 Tab。
- Modal/Sheet 用统一的 `AppSheet` 组件封装，避免每个页面单独实现。

## 3. 建议的原生目录结构

在 `entry/src/main/ets` 下建议按以下结构重建：

这是组织代码的建议，不是强制逐步创建文件的清单。后续步骤应先查看 8.2 迁移状态记录和现有实现，再决定是否复用、扩展或调整目录。

```text
entry/src/main/ets/
  app/
    AppBootstrap.ets
    AppRouter.ets
    AppState.ets
  common/
    constants/
      ApiEndpoints.ets
      RouteNames.ets
      StorageKeys.ets
    i18n/
      I18nService.ets
      lang/en_US.ets
      lang/zh_HK.ets
    net/
      HttpClient.ets
      ApiClient.ets
    storage/
      PreferencesStore.ets
      JsonStore.ets
    theme/
      AppTheme.ets
      ThemeStore.ets
    utils/
      DateTime.ets
      OpenLink.ets
      SearchText.ets
      VersionCompare.ets
      Haptics.ets
      Logger.ets
  components/
    AppToast.ets
    AppDialog.ets
    AppSheet.ets
    AppSegmentControl.ets
    AppWebView.ets
    AsyncImage.ets
    LoadingView.ets
    PressableScale.ets
    SectionCard.ets
    ScrollToTopButton.ets
  models/
    AppInfo.ets
    Course.ets
    Club.ets
    Event.ets
    News.ets
    Parking.ets
    Bus.ets
  services/
    AppInfoService.ets
    CourseDataService.ets
    BusService.ets
    UmOpenDataService.ets
    ClubService.ets
    UmehHostService.ets
    AnalyticsService.ets
  pages/
    root/
      RootTabs.ets
      InfoTopTabs.ets
    home/
      HomePage.ets
      CalendarBar.ets
      HomeCard.ets
      HomeSearchBar.ets
    info/
      NewsPage.ets
      NewsDetailPage.ets
      UMEventPage.ets
      UMEventDetailPage.ets
      ClubPage.ets
      ClubDetailPage.ets
      ClubAllEventsPage.ets
    courses/
      What2RegPage.ets
      CourseCard.ets
      CourseFilterPanel.ets
      CourseSearchBar.ets
      FirstLetterNav.ets
      LocalCoursePage.ets
    timetable/
      CourseSimPage.ets
      TimetableDayColumn.ets
      TimetableImportPanel.ets
      TimetableSearchSheet.ets
    features/
      FeaturesPage.ets
      FeatureList.ets
      BusPage.ets
      CarParkPage.ets
      UMOrgPage.ets
      SettingPage.ets
```

原则：

- `pages` 只写页面 UI 和页面级状态。
- 网络、缓存、课程处理、搜索过滤放到 `services` 或 `common/utils`。
- RN 的工具函数不要逐字翻译成页面内函数，应先抽服务。
- 先建模型类型，再写 UI，否则课程/新闻/活动字段很容易写错。

## 4. 原生基础设施移植清单

### 4.1 资源与静态数据

来源：

- `ReactNative版本/src/static/UMCourses/*.json`
- `ReactNative版本/src/static/img/**`
- `ReactNative版本/src/static/UMARK_Assets/**`
- `ReactNative版本/src/static/UMCalendar/**`
- `ReactNative版本/src/static/icon/iconSvg.js`

迁移要求：

- 大 JSON 放入 `entry/src/main/resources/rawfile/UMCourses/`。
- 图片可按两类处理：
  - App 图标、Logo、固定 UI 图：放 `resources/base/media`。
  - 巴士站点图、捐赠图、课程/校历大资源：放 `resources/rawfile` 或分目录管理。
- 不建议把大 JSON 直接转为 `.ets` 常量，容易拖慢编译和类型检查。
- 课程数据读取统一由 `CourseDataService` 负责：
  - 先读 Preferences 缓存。
  - 缓存不存在时读 rawfile 内置 JSON。
  - 云端更新成功后写缓存。

课程数据结构：

- `courseVersion.json`
  - `pre.updateTime`
  - `pre.academicYear`
  - `pre.sem`
  - `adddrop.updateTime`
  - `adddrop.academicYear`
  - `adddrop.sem`
- `coursePlan.json`
  - `Courses`: 612 条
  - 字段含 `Offering Unit`, `Offering Department`, `Course Code`, `Course Title`, `Section`, `Teacher Information`, `Day`, `Time From`, `Time To`, `Classroom`, `Course Title Chi`
- `coursePlanTime.json`
  - `Courses`: 2464 条
  - 用于按节次生成一周课表。
- `offerCourses.json`
  - `Courses`: 593 条
  - 字段含 `Credit Units`, `Course For Info`, `Enrolled Year Level (on or above)`, `Course Title Chi`

### 4.2 本地缓存键

RN 使用 AsyncStorage。鸿蒙侧统一使用 Preferences/持久化 KV 封装，所有 key 集中到 `StorageKeys.ets`。

必须迁移的 key：

| Key | 用途 |
| --- | --- |
| `themePreference` | 主题偏好：0 跟随系统，1 浅色，2 深色 |
| `language` | 语言：`tc` / `en` |
| `course_version` | 当前课程数据版本 |
| `offer_courses` | 预选课程缓存 |
| `course_plan` | Add/Drop 课程缓存 |
| `course_plan_time` | 课程时间表缓存 |
| `ARK_Courses_filterOptions` | 揾课筛选条件 |
| `ARK_Timetable_Storage` | 用户已加入课表的课程和 Section |
| `ARK_WeekTimetable_Storage` | 按星期分组的课表，用于首页“下节课” |
| `last_version_check_timestamp` | 课程版本 6 小时检查节流 |
| `userInfo` | 用户信息，当前多处为预留 |
| `appInfo` | 服务端 App 信息 |
| `umPass` | WebView 自动填充账号密码，涉及敏感信息，移植时需重新评估 |
| `ARK_Harbor_Setting` | Harbor 打开偏好 |
| `umeh_host_pref` | 选咩课主/备站偏好 |

注意：

- `umPass` 不建议原样移植自动注入逻辑，除非明确需要并完成安全评审。
- 清除缓存功能必须清理以上业务 key，并重新执行启动初始化。

### 4.3 网络层

来源：`ReactNative版本/src/utils/pathMap.js`

统一封装：

- `HttpClient.get/post`
- 超时、错误码、JSON parse、loading 状态
- UM Open Data token 注入
- 网络错误统一转用户可读 Toast/Dialog

主要服务端：

| 服务 | URL |
| --- | --- |
| ARK 后端 | `https://umall.one/api/` |
| ARK 站点 | `https://umall.one` |
| 课程 Worker | `https://course-api.umall.one` |
| Harbor | `https://harbor.umall.one` |
| Wiki | `https://wiki.umall.one` |
| What2Reg 主站 | `https://www.umeh.top` |
| What2Reg 备站 | `https://cf.umeh.top` |
| UM Open Data | `https://api.data.um.edu.mo/...` |

UM Open Data API：

- `UM_API_NEWS`: `/service/media/news/all`
- `UM_API_EVENT`: `/service/media/events/all`
- `UM_API_CAR_PARK`: `/service/facilities/car_park_availability/all`
- `UM_ORG`: `/service/aboutum/organizational_units/all`

注意：

- RN 中 `UM_API_TOKEN` 来自 `process.env.EXPO_PUBLIC_UM_API_TOKEN`。鸿蒙侧不能继续依赖 Expo 环境变量。
- 不要把真实 token 直接提交到仓库。建议用本地未提交配置、构建注入或远端代理方案。
- `module.json5` 需要补充网络权限，例如互联网访问权限；具体权限名以 API 23 SDK 编译为准。

### 4.4 WebView / 外部链接

来源：

- `src/utils/browser.js`
- `src/components/Webviewer.js`
- `src/components/IntegratedWebView.js`
- `src/pages/TabbarPages/arkwiki/index.js`
- `src/pages/TabbarPages/arkHarbor/index.js`

鸿蒙侧需要两个能力：

1. `openLink(url, mode?)`
   - 默认打开系统浏览器/系统能力。
   - 支持 `fullScreen` 语义。
   - URL 非 http 时走系统 URI 能力。
2. `AppWebView`
   - 进度条。
   - 返回/前进能力。
   - 下拉刷新可选。
   - 当前 URL 回传。
   - 外部浏览器打开。
   - 失败时降级打开系统浏览器。

优先级：

- 服务入口中的多数链接可以先走系统浏览器，降低首版复杂度。
- 必须 App 内嵌的页面再使用原生 Web 组件。
- Harbor 当前 RN 已偏向系统浏览器模式，鸿蒙首版也建议优先外部浏览器。

### 4.5 主题系统

来源：`src/components/ThemeContext.js`

保留三种模式：

- `SYSTEM = 0`
- `LIGHT = 1`
- `DARK = 2`

核心颜色：

- `themeColor`: light `#4796d6`，dark `#4a9cde`
- `secondThemeColor`: `#FF8627`
- `success`: `#27ae60`
- `unread`: `#f75353`
- `bg_color`: light `#F5F5F7`，dark `#121212`
- `white`: light `#fff`，dark `#272729`
- `TIME_TABLE_COLOR`: 课程色板

鸿蒙实现建议：

- `AppTheme` 定义 light/dark 两套对象。
- `ThemeStore` 负责读取系统深浅色和用户偏好。
- 页面从统一状态读取，不要在每页散落硬编码颜色。
- RN 中大量 `${themeColor}15` 这类透明度色值，鸿蒙侧应封装 `withAlpha(color, alpha)` 或预置 tonal 色阶。

### 4.6 国际化

来源：

- `src/i18n/i18n.js`
- `src/i18n/en-us.json`
- `src/i18n/zh-hk.js`

语言：

- `tc`: 繁体中文
- `en`: English

命名空间：

- `common`
- `home`
- `about`
- `wiki`
- `harbor`
- `catalog`
- `timetable`
- `features`
- `club`
- `setting`

鸿蒙实现建议：

- 先保留 RN 当前 key，不要一边移植一边改文案 key。
- 做一个 `t(key, ns?)` 函数，页面调用保持接近 RN 逻辑。
- 后续可再迁入系统 resource string，但首轮迁移更应关注功能一致。

### 4.7 埋点、触感、Toast、Clipboard

RN 依赖：

- Firebase Analytics
- `react-native-haptic-feedback`
- `react-native-toast-message` / `react-native-simple-toast` / `react-native-easy-toast`
- `@react-native-clipboard/clipboard`

鸿蒙侧统一封装：

- `AnalyticsService.log(eventName, params)`：没有可用分析 SDK 时先 no-op，但保留调用。
- `Haptics.trigger(method?)`：不可用时 no-op。
- `AppToast.show(text, type?)`
- `ClipboardService.copy(text)`

不要在页面中直接依赖具体 SDK，后续替换成本低。

## 5. 功能模块迁移详解

### 5.1 Root Tabs 与页面容器

来源：

- `src/Tabbar.js`
- `src/Nav.js`

迁移目标：

- 底部 Tab：
  - 资讯
  - 揾课
  - 新想法
  - 课表
  - 服务
- 顶栏/标题栏：
  - 子页面有返回按钮。
  - 页面背景跟主题。
  - 状态栏深浅色跟主题。

验收：

- App 启动后直接进入资讯页首页。
- 五个底部入口可点击。
- `新想法` 点击打开 `https://harbor.umall.one/new-topic`，不切换到空页面。
- 返回按钮、系统返回键、深色模式视觉一致。

### 5.2 首页 Home

来源：`src/pages/TabbarPages/info/home/index.js`

功能：

- 快捷入口：校巴、Moodle、新想法、支持我们、论坛登录。
- 搜索澳大网页。
- 获取 AppInfo：`BASE_URI + GET.APP_INFO`
- 检查服务端 App 版本并弹更新提示。
- 首页活动列表：`EventPage.js`
- 日历/校历条：`CalendarBar.js`
- 读取 `ARK_WeekTimetable_Storage` 显示下节课。
- 支持刷新、BottomSheet、Modal。

迁移重点：

- 首页是多个服务的聚合页，不要把网络请求写在 UI 组件里。
- 先实现静态布局和快捷入口，再接 AppInfo、活动和下节课。
- `UMCalendar.js` 静态数据需要单独确认是否继续使用，或改从资源读取。

验收：

- 首页 5 个快捷入口可用。
- AppInfo 网络失败时不会白屏。
- 有课表缓存时能显示下节课。
- 下拉刷新不重复触发大量请求。

### 5.3 资讯：新闻、澳大活动、详情页

来源：

- `src/pages/TabbarPages/info/NewsPage.js`
- `src/pages/TabbarPages/info/UMEventPage.js`
- `src/pages/TabbarPages/info/news/NewsDetail.js`
- `src/pages/TabbarPages/info/news/UMEventDetail.js`
- `src/pages/TabbarPages/info/components/NewsCard.js`

新闻列表：

- API：`UM_API_NEWS`
- 需要 Header：`Authorization: UM_API_TOKEN`
- 头条选取：第一条有 `common.imageUrls` 的新闻。
- 详情语言：`zh_TW`, `en_US`, `pt_PT`
- 内容为 HTML，需要解析/渲染。

澳大活动列表：

- API：`UM_API_EVENT`
- 需要 Header：`Authorization: UM_API_TOKEN`
- 活动排序：今天/未来活动优先，再过往活动。
- 详情页有 Hero 图片、时间、地点、介绍、链接。

迁移重点：

- 先定义 `NewsItem`, `UMEventItem` 类型。
- HTML 内容可先做简化渲染：去标签/保留链接；后续再做富文本。
- 图片 URL 需把 `http:` 替换为 `https:`。
- 葡文/英文/中文语言切换要保留。

验收：

- 新闻列表、头条、详情三语切换可用。
- 活动列表按当前日期排序。
- 详情页图片可打开大图或至少可预览。
- API token 缺失时显示明确错误，不崩溃。

### 5.4 组织 Club

来源：

- `src/pages/TabbarPages/info/ClubPage.js`
- `src/pages/TabbarPages/info/club/ClubDetail.js`
- `src/pages/TabbarPages/info/club/EventDetail.js`
- `src/pages/TabbarPages/info/club/AllEvents.js`
- `src/pages/TabbarPages/info/components/ClubCard.js`
- `src/utils/clubMap.js`
- `src/pages/TabbarPages/info/utils/clubSearchFilter.js`

功能：

- 拉取所有组织：`BASE_URI + GET.CLUB_INFO_ALL`
- 按 tag 分组，3 列网格。
- 搜索组织名称。
- 分类快速定位。
- 组织详情：
  - logo
  - tag
  - 简介
  - 联系方式
  - 照片
  - 近期活动
- 组织活动详情：
  - 封面
  - 时间地点
  - 介绍
  - 相关图片
  - Follow/取消 Follow 逻辑目前依赖登录状态，RN 侧多为预留。

迁移重点：

- 首版可以先不实现组织登录、Follow、编辑资料。
- `BASE_HOST + logo_url/cover_image_url` 的拼接必须统一封装。
- `HyperlinkText` 需要迁移为可点击链接文本组件。

验收：

- 组织列表按分类显示。
- 搜索能匹配中文/英文/简称。
- 组织详情展示 logo、简介、联系方式和活动。
- 活动详情能展示封面、时间、地点、介绍和链接。

### 5.5 揾课 What2Reg / 课程目录

来源：

- `src/pages/TabbarPages/what2Reg/index.js`
- `hooks/useCourseData.js`
- `hooks/useCourseFiltering.js`
- `hooks/useCourseSearch.js`
- `utils/search.js`
- `components/CourseCard.js`
- `components/FilterPanel.js`
- `components/SearchBarSection.js`
- `components/FirstLetterNav.js`
- `components/EatingScheduleSheetContent.js`
- `pages/LocalCourse.js`

功能：

- 模式：
  - `ad`: Add/Drop
  - `preEnroll`: Pre Enroll
- 过滤：
  - `CMRE`: 必修/选修
  - `GE`: 通识
  - 学院
  - 学系
  - GE 类别
- 搜索：
  - 课程代码
  - 英文课程名
  - 中文课程名
  - 简体输入转繁体后匹配
  - 合并 `coursePlanTime.Courses` 后去重
- 课程卡操作：
  - 写 Wiki：`ARK_WIKI_SEARCH + courseCode`
  - What2Reg：`${umehHost}/course/${courseCode}`
  - 官方课程：`OFFICIAL_COURSE_SEARCH + courseCode`
  - 加入课表/查看本地课节
- 课程数据更新：
  - `checkCloudCourseVersion`
  - 官方 SharePoint 链接
- `umeh_host_pref` 支持 auto/primary/backup。

迁移重点：

- 这是第一批复杂模块，必须先迁移数据服务和搜索/过滤纯函数。
- OpenCC 简繁转换需要替代方案：
  - 先引入可用 ArkTS 包；
  - 或提供最小字符映射；
  - 或首版只支持原文匹配，并在 TODO 标出。
- 大列表需要懒加载/虚拟列表能力，避免一次性渲染 500+ 卡片卡顿。
- `CourseCard` 的菜单用统一 `AppMenu` 或 `ActionSheet` 替代。

验收：

- 首次启动可从 rawfile 读取课程数据。
- Add/Drop 与 PreEnroll 可切换。
- 学院/学系/GE 筛选可用。
- 搜索 ECE、Electrical、中文课程名均可用。
- 手动检查课程版本不会破坏本地缓存。

### 5.6 课表模拟 CourseSim

来源：`src/pages/TabbarPages/courseSim/index.js`

核心数据：

- 用户选择：`ARK_Timetable_Storage`
  - 数组元素：`{ "Course Code": string, "Section": string }`
- 首页下节课缓存：`ARK_WeekTimetable_Storage`
  - 按 `MON` 到 `SUN` 分组。
- 源数据：`coursePlanTime.Courses`

核心功能：

- 从 ISW 复制的文本中解析课程：
  - 正则：`[A-Z]{4}[0-9]{4}((/[0-9]{4})+)?(\s)?(\([0-9]{3}\))`
  - 输出 Course Code + Section
- 生成一周课表：
  - 根据 Course Code + Section 从 `coursePlanTime` 匹配所有节次。
  - 按星期和时间排序。
- 冲突检测：
  - 当下一节开始时间早于上一节结束时间时标红。
- 搜索/加课：
  - 课程代码、英文名、中文名、教师、星期、学院、学系。
  - 可添加单节或所有 Section。
- 操作：
  - 删除单节
  - 删除同课程全部 Section
  - 清空课表
  - 跳 Wiki / What2Reg / 官方课程
  - 跳 `LocalCourse`
- 时间过滤：
  - 星期过滤
  - 起止时间过滤

迁移重点：

- 先把解析、匹配、排序、冲突检测写成纯 ArkTS 工具并单元测试。
- 页面 UI 再基于纯函数输出渲染。
- `BottomSheet` 内搜索是复杂交互，建议第二阶段再做完整；首版可用全屏选择页替代。
- `DateTimePicker` 需要用鸿蒙原生时间选择器替代。

验收：

- 粘贴 ISW 课程字符串可导入。
- 添加/删除/清空课表会持久化。
- 周一到周日列展示正确。
- 冲突课程有明显警示。
- 首页能读取下节课缓存。

### 5.7 服务 Features

来源：

- `src/pages/TabbarPages/features/index.js`
- `src/pages/TabbarPages/features/FeatureList.js`
- `src/pages/Features/Bus.js`
- `src/pages/Features/CarPark.js`
- `src/pages/Features/UMOrg.js`
- `src/pages/Features/SettingPage.js`

服务入口分组：

- 校园资讯：
  - 校园巴士
  - 校历
  - 校园地图
  - 课室占用
  - 车位
  - E6 电脑
  - 图书馆
  - UM Pass
  - 电子公告
  - 打印余额
  - 失物认领
  - 职位空缺
  - 书院餐单
  - 饭堂排队
  - 学生会
  - 更多服务
- 预约服务：
  - 维修预约
  - 体育预订
  - 场地预约
  - Lib 房间
  - 打印
  - UM 提意见
  - 储物箱
  - 泊车月票
  - 证明文件
  - `Lib佔用` 在 RN 配置中是注释项，首版不迁移。
- 课业发展：
  - Moodle
  - Wiki
  - 课表模拟
  - 选咩课
  - ISW
  - New ISW
  - 预选课
  - 预选表格
  - Add Drop
  - 重要日期
  - 全人发展
  - 交流
  - 奖学金
  - 资源搜索
  - 论文计划
- 新生推荐：
  - 职涯港
  - 生存指南
  - 内地生
  - 新生注册
  - 图文包
  - 防诈骗
  - 书院
  - 校友会
  - 澳大部门

迁移重点：

- `FeatureList` 应改成 ArkTS 配置数组。
- 多数入口首版直接 `openLink`，不需要 WebView 页。
- 长按复制链接的 BottomSheet 可第二阶段做。
- 图标建议统一为本地 icon 字体、SVG 转资源，或先用 ArkUI Symbol/文本占位。

验收：

- 所有非注释入口都能点击。
- 内部页面：Bus、CarPark、UMOrg、Setting 能跳转。
- 外部链接入口能打开。
- 长标题不溢出。

### 5.8 校园巴士 Bus

来源：`src/pages/Features/Bus.js`

功能：

- 根据语言选择：
  - 中文：`UM_BUS_LOOP_ZH`
  - 英文：`UM_BUS_LOOP_EN`
- 每 7 秒自动刷新。
- 拉取 HTML 后解析 `span` 和 `.left` class，得到：
  - `busInfoArr`
  - `busPositionArr`
- 展示路线图、巴士当前位置、站点图片。
- 点击站点可查看站点图。
- 打开校园地图。

迁移重点：

- 需要 HTML 解析能力。可先用正则/字符串解析实现当前页面需要的最小逻辑。
- 定时器必须在页面退出时取消。
- 站点图片迁移到 rawfile/media。
- `useKeepAwake` 可先不实现，或用鸿蒙对应保持亮屏能力。

验收：

- 可刷新当前巴士信息。
- 无车/网络错误有提示。
- 自动刷新离开页面后停止。
- 路线图和站点图片正常显示。

### 5.9 车位 CarPark

来源：`src/pages/Features/CarPark.js`

功能：

- API：`UM_API_CAR_PARK`
- Header：`Authorization: UM_API_TOKEN`
- 参数：`date_from = 澳门时间当前时间 - 30 分钟`
- 只展示最新 5 条。
- 过滤：
  - 提供对象：All / Staff / Monthly Pass / Visitor
  - 车辆类型：All / Light Vehicle / Motorcycle
- P1/P2/P3/P5/P6 地点说明硬编码。

迁移重点：

- `moment-timezone` 替换为原生时间处理；时区固定 `Asia/Macau`。
- SegmentControl 迁移为统一组件。

验收：

- 有 token 时能展示 P1-P6 剩余车位。
- 两组筛选可用。
- 下拉刷新可用。

### 5.10 澳大部门 UMOrg

来源：`src/pages/Features/UMOrg.js`

功能：

- API：`UM_ORG`
- Header：`Authorization: UM_API_TOKEN`
- 展示主部门和子部门。
- 搜索匹配：
  - 中文名
  - 英文名
  - code
  - 子部门
  - 简体输入转繁体
- 点击部门执行 Google site 搜索。
- 子部门可折叠。

迁移重点：

- 先实现页面内搜索框，不依赖导航栏搜索能力。
- OpenCC 替代同 What2Reg。
- `lodash.startCase/lower` 可用简单工具替代。

验收：

- 部门列表可展示。
- 搜索可过滤主部门/子部门。
- 点击部门打开搜索链接。

### 5.11 设置 Setting

来源：`src/pages/Features/SettingPage.js`

功能：

- 主题切换：System / Light / Dark
- 语言切换：繁中 / EN
- 清除缓存
- 检查更新
- What2Reg Host 偏好：auto / primary / backup
- 关于：
  - 版本
  - GitHub
  - 常见问题
  - 隐私政策
  - Donate
  - Feedback
  - Activity
  - About ARK ALL
- 联系：
  - 官网
  - Email

迁移重点：

- 设置页依赖主题、i18n、缓存、更新检查、外链，是基础设施验收页。
- `packageInfo.version` 替换为鸿蒙 `versionName` 或统一 `AppVersionService`。
- 清缓存后应重新执行启动初始化，而不是只清数据。

验收：

- 主题切换立即生效并持久化。
- 语言切换立即生效并持久化。
- 清缓存后课程数据可重新初始化。
- 检查更新可请求 `get_appInfo/`。

### 5.12 Wiki / Harbor

来源：

- `src/pages/TabbarPages/arkwiki/index.js`
- `src/pages/TabbarPages/arkHarbor/index.js`
- `src/pages/TabbarPages/HarborNewTopicTab.js`

当前 RN 状态：

- Wiki 顶部 Tab 在 `info/index.js` 中被注释，实际不是主入口。
- Harbor 真实 Tab 也被注释，当前只有 `HarborNewTopic` 快捷发帖。
- Harbor 支持 browser/webview 偏好，但更推荐系统浏览器。

鸿蒙首版建议：

- Wiki 先作为服务入口打开系统浏览器。
- Harbor 新帖保留快捷入口。
- Harbor WebView 偏好可延后。

验收：

- 新想法可打开 `https://harbor.umall.one/new-topic`。
- Wiki 服务入口可打开 `https://wiki.umall.one`。

## 6. RN 依赖替换表

| RN/Expo 依赖 | 用途 | 鸿蒙迁移策略 |
| --- | --- | --- |
| `@react-navigation/*` | Stack、Bottom Tabs、Top Tabs | ArkUI `Navigation` + `Tabs` + 自定义路由状态 |
| `@react-native-async-storage/async-storage` | 本地 KV | Preferences/本地 KV 封装 |
| `axios` / `fetch` | HTTP | 统一 `HttpClient` |
| `react-native-webview` | 内嵌网页 | ArkWeb/Web 组件或系统浏览器 |
| `expo-web-browser` / `Linking` | 外部浏览器 | `OpenLink` 服务 |
| `i18next` | i18n | 自建 `I18nService` 或资源化 |
| `moment` / `moment-timezone` | 日期、澳门时间 | 原生 Date + 工具函数 |
| `lodash` | groupBy/uniq/sortBy/deburr | 写小型工具函数，避免全量引入 |
| `opencc-js` | 简转繁 | 找 ArkTS 可用库或先做最小映射 |
| `expo-image` / RN `Image` | 图片 | ArkUI Image + rawfile/media |
| `@gorhom/bottom-sheet` | BottomSheet | `AppSheet` |
| `zeego/dropdown-menu` | 菜单 | `AppMenu` / ActionSheet |
| `react-native-toast-message` 等 | Toast | `AppToast` |
| `react-native-haptic-feedback` | 触感 | `Haptics` no-op/原生实现 |
| `@react-native-clipboard/clipboard` | 剪贴板 | `ClipboardService` |
| `react-native-htmlview` | HTML 渲染 | 简化 HTML parser / 富文本组件 |
| `react-native-html-parser` | 巴士 HTML 解析 | 最小 HTML 解析工具 |
| `@react-native-firebase/*` | Analytics | `AnalyticsService` no-op 或鸿蒙分析 SDK |
| `react-native-modal-datetime-picker` | 时间选择 | 鸿蒙原生时间选择器 |
| `@shopify/flash-list` | 高性能列表 | ArkUI LazyForEach/List |

## 7. API 与数据字段清单

### 7.1 ARK 后端

Base：`https://umall.one/api/`

GET：

- `get_appInfo/`
- `get_club_info/all`
- `get_club_info/club_num/?club_num=`
- `get_activity/all`
- `get_activity/club_num/?club_num=`
- `get_activity/club_num/`
- `get_activity/id/?id=`
- `get_follow_activity/`
- `get_follow_club/`
- `get_notice/`

POST：

- `student_signin/`
- `club_signin/`
- `edit_club_info/`
- `create_activity/`
- `edit_activity/`
- `delete_activity/`
- `student_add_follow_activity/`
- `student_del_follow_activity/`
- `student_add_follow_club/`
- `student_del_follow_club/`
- `create_notice/`

首版可暂缓：

- 登录
- 组织编辑
- Follow
- Notice 创建

### 7.2 课程 Worker

Base：`https://course-api.umall.one`

- `/version`
- `/pre`
- `/adddrop`
- `/timetable`

更新逻辑：

1. 拉 `/version`。
2. 对比本地 `course_version`。
3. `pre` 更新时拉 `/pre` 写 `offer_courses`。
4. `adddrop` 更新时拉 `/adddrop` 和 `/timetable`，分别写 `course_plan` 和 `course_plan_time`。
5. 写入新的 `course_version`。

### 7.3 UM Open Data

所有请求都需要 `Authorization: UM_API_TOKEN`。

- 新闻：`https://api.data.um.edu.mo/service/media/news/all`
- 活动：`https://api.data.um.edu.mo/service/media/events/all`
- 车位：`https://api.data.um.edu.mo/service/facilities/car_park_availability/all`
- 部门：`https://api.data.um.edu.mo/service/aboutum/organizational_units/all`

### 7.4 重要外链

- 校巴中文：`https://campusloop.cmdo.um.edu.mo/zh_TW/busstopinfo`
- 校巴英文：`https://campusloop.cmdo.um.edu.mo/en_US/busstopinfo`
- 校园地图：`https://maps.um.edu.mo`
- Moodle：`https://ummoodle.um.edu.mo/login/`
- ISW：`https://isw.um.edu.mo/siweb/faces/login.jspx`
- New ISW：`https://isw.um.edu.mo/siapp`
- 官方课程查询：`https://isw.um.edu.mo/siwci/faces/courseDetailUG?courseCode=`
- ARK Wiki 搜索：`https://wiki.umall.one/wiki/Special:Search?search=`
- Harbor 新帖：`https://harbor.umall.one/new-topic`

完整外链以 `ReactNative版本/src/utils/pathMap.js` 为准。

### 7.5 敏感配置与环境变量清单

当前扫描范围：`ReactNative版本/`、`entry/` 和本文档。明确发现的构建期环境变量只有 RN 侧的 `EXPO_PUBLIC_UM_API_TOKEN`；鸿蒙侧还没有等价配置入口。后续实现服务层前必须先确定注入方式，不能把真实值写入 `ApiEndpoints.ets`、`module.json5` 或任何会提交的源码。

| 配置项 | 来源/现状 | 用途 | 鸿蒙迁移要求 | 缺失时行为 |
| --- | --- | --- | --- | --- |
| `EXPO_PUBLIC_UM_API_TOKEN` / `UM_API_TOKEN` | RN 在 `ReactNative版本/src/utils/pathMap.js` 中通过 `process.env.EXPO_PUBLIC_UM_API_TOKEN` 导出；鸿蒙当前只保留 endpoint 和 `Authorization` header 名称，没有 token 值。 | UM Open Data：新闻、澳大活动、车位、澳大部门。请求头为 `Authorization: <token>`。 | Step 3 应定义鸿蒙侧配置入口，例如本地未提交配置、构建注入、DevEco Build Profile 注入或远端代理。建议鸿蒙服务层内部命名为 `UM_OPEN_DATA_TOKEN` 或 `UmOpenDataConfig.token`，但真实名称以实现为准。 | 页面必须显示“缺少 UM Open Data Token/配置”之类明确错误态，不发起无限重试，不崩溃。 |
| ARK 后端登录 token | RN 登录后写入 `userInfo` 缓存，注释中说明服务器返回 token；不是构建环境变量。 | 学生/组织登录、Follow、编辑组织、创建活动等首版暂缓能力。 | 不作为构建密钥。后续登录服务实现后由运行期接口返回并写入安全存储/业务缓存；退出登录需清除 `userInfo`、`appInfo` 等相关缓存。 | 登录相关动作提示未登录或功能暂未开放；浏览类页面不能依赖此 token。 |
| `umPass` | RN WebView 自动填充账号密码相关缓存 key；当前 Step 2 仅记录历史 key。 | ISW/UM Pass 等网页自动填充，涉及用户账号密码。 | 默认不迁移自动注入。除非完成安全评审，否则不得把它设计成环境变量、不得写入构建配置、不得在 WebView 中自动注入。 | 相关网页只外开或普通 WebView 打开，不自动填充账号密码。 |
| Firebase / Analytics 配置 | RN 依赖 Firebase Analytics，iOS 工程中存在 Firebase 构建脚本；当前鸿蒙侧没有可用分析 SDK 配置。 | 埋点、设备信息统计。 | Step 3 先实现 `AnalyticsService` no-op。若未来接入鸿蒙可用分析方案，再单独记录厂商 app id/key、注入方式和隐私说明。 | 埋点静默 no-op，不影响业务页面。 |
| 签名材料 / 私有构建配置 | 当前本机可用调试签名；发布签名不应提交仓库。 | HAP/App 打包签名。 | 作为本机/CI 私有配置管理，不进入源码；发布前在发布 checklist 中复核。 | 本机 debug 可继续使用当前配置；release 构建需补齐私有签名。 |

当前无需 token 的服务：

- ARK 后端公开浏览接口：`get_appInfo/`、组织列表/详情、活动列表/详情等，按现有 RN 行为无需构建期 token。
- 课程 Worker：`/version`、`/pre`、`/adddrop`、`/timetable` 当前无需 token。
- Wiki、Harbor、What2Reg、UMEH、UM 常用网页外链当前无需构建期 token。

## 8. 分步迁移路线与接力规则

本章用于指导后续 GPT 分阶段迁移。这里刻意不规定“必须改哪个文件、创建哪个文件”，因为原生鸿蒙实现应根据当时已经完成的工程结构继续演进。每一步只说明目标、应复用 React Native 版本的哪些业务方法、应优先使用哪些鸿蒙原生能力，以及完成后必须如何更新本文档。

### 8.1 总原则

1. **必须使用鸿蒙原生组件和能力。** UI 使用 ArkUI 原生组件与状态管理；导航使用鸿蒙原生 Navigation/Tabs 能力；存储、网络、Web、剪贴板、弹窗、权限等都使用 HarmonyOS API 23 可用的原生 kit 或项目内 ArkTS 封装。
2. **React Native 版本只作为业务行为参考。** 不要把 RN 页面结构逐行翻译成 ArkTS，也不要用 WebView 或 RN 运行时包一层来“移植”。RN 里的数据处理方法、接口调用顺序、筛选规则、缓存 key、页面流程可以复用思想和算法。
3. **先抽公共能力，再做页面。** 缓存、HTTP、外链、主题、i18n、课程数据、Toast、Dialog、Sheet、图片加载、埋点等能力一旦完成，后续步骤必须复用，不能重复造第二套。
4. **每一步完成后必须维护本文档。** 完成者要更新“8.2 迁移状态记录”，写清已经做了什么、复用了哪些公共能力、还没做什么、下一步应该接哪里。后续 GPT 开始前必须先读该记录，避免重复实现同一个服务、组件或页面。
5. **每一步以能编译、能运行、边界清楚为准。** 如果某项能力暂缓，必须在记录中写明原因和后续补点，而不是悄悄留半成品。

### 8.2 迁移状态记录

后续每完成一个 Step，都在这里追加或更新一行。不要删除历史记录，除非它明显错误并在备注中说明。

| Step | 状态 | 已完成内容 | 主要复用/沉淀 | 未完成/风险 | 完成者备注 |
| --- | --- | --- | --- | --- | --- |
| Step 0 | 已完成 | 已核对鸿蒙工程为 DevEco/Hvigor Stage Model 骨架：`targetSdkVersion`/`compatibleSdkVersion` 为 `6.1.0(23)`，`runtimeOS` 为 `HarmonyOS`，入口模块为 `entry`，`EntryAbility` 加载 `pages/Index`，当前页面仍是 `Hello World` 示例；已核对 RN 侧 `package.json`、`App.js`、`Nav.js`、`Tabbar.js`、资讯顶部 Tab 入口，确认 RN 仅作为业务行为来源。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过。 | 沉淀基线认知：后续 UI 必须使用 ArkUI 原生组件；主导航应按 RN 业务关系迁为鸿蒙原生 Navigation/Tabs，包含底部 5 个入口、资讯顶部 4 个入口和统一二级 Stack/路由；启动初始化应下沉为原生 bootstrap/service，不在页面中散落实现。 | 当前鸿蒙侧没有业务基础设施、主题/i18n/存储/网络/外链/埋点/课程数据均未实现；本机可编译但具体 API 23 import、权限名和组件签名仍需在后续步骤按 DevEco SDK 编译结果校准；UM Open Data token 和 Expo env 不能直接写入鸿蒙工程；当前签名材料是本机调试配置。 | Step 1 应从原生 App 壳和导航骨架开始，先实现可运行、可切换的底部 Tabs 与资讯顶部 Tabs；`新想法` 保持动作入口，不做空页面。 |
| Step 1 | 已完成 | 已将 `entry/src/main/ets/pages/Index.ets` 从 Hello World 改为原生 `Navigation(this.pathStack)` 根容器；新增底部 5 入口 `RootTabs`，启动默认进入资讯首页；新增资讯页内部 4 个顶部入口 `InfoTopTabs`；新增统一占位页和二级页容器，二级页通过 `NavPathStack.pushPathByName(routeName, null)` 进入并用统一返回按钮 `pathStack.pop()` 返回；`新想法` 底部入口不保留空页面，点击后调用 `UIAbilityContext.openLink('https://harbor.umall.one/new-topic')` 并回到上一个真实 Tab。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过。 | 沉淀 `common/constants/RouteNames.ets` 作为当前路由名入口，`common/constants/ApiEndpoints.ets` 先保存 Harbor 发帖链接；后续页面应接入现有 `Index.routeMap` / `NavPathStack`，不要另建一套导航；底部 Tab 结构在 `pages/root/RootTabs.ets`，资讯顶部 Tab 结构在 `pages/root/InfoTopTabs.ets`。 | 当前各业务页仍是原生占位内容，未实现真实数据、主题/i18n、网络、缓存或图标资源；`openLink` 行为已按 API 23 编译通过，但仍需真机/模拟器验证外部浏览器选择和返回体验；后续 Step 2 应先补公共常量、模型和接口边界，再替换占位页内容。 | Step 1 保持纯 ArkUI 原生实现，没有引入 RN/WebView 运行时；路由命名沿用 RN Stack 名称，方便后续逐页替换。 |
| Step 2 | 已完成 | 已扩展 `entry/src/main/ets/common/constants/ApiEndpoints.ets`，集中迁入 RN `pathMap.js` 中的 ARK 后端、课程 Worker、UM Open Data、Wiki/Harbor、What2Reg/UMEH、UM 服务入口、书院/新生推荐等 URL，保留常用 RN 命名兼容别名，并提供 `buildArkApiUrl`、`buildCourseApiUrl`、`buildWikiSearchUrl`、`buildOfficialCourseUrl`、`addArkHost`/`addHost` 等基础拼接函数；新增 `entry/src/main/ets/common/constants/StorageKeys.ets`，集中定义 RN AsyncStorage 语义对应的主题、语言、课程、课表、AppInfo、Harbor、What2Reg host 等缓存 key 及清缓存 key 集合；新增 `entry/src/main/ets/models/` 下的 `ApiResponse`、`AppInfo`、`Bus`、`Club`、`Course`、`Event`、`News`、`Organization`、`Parking`、`WebLink` 类型边界，覆盖后续服务和页面需要的核心原始字段；已补充 7.5 敏感配置与环境变量清单。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过。 | 沉淀公共常量入口：所有 URL/外链从 `common/constants/ApiEndpoints.ets` 读取，所有业务缓存 key 从 `common/constants/StorageKeys.ets` 读取；沉淀模型入口：后续服务层应直接复用 `models/*.ets` 中的后端原始数据类型，不要在页面内临时声明重复字段；UM Open Data 只保留 endpoint 和 `Authorization` header 名称，没有写入真实 token。 | 当前只完成边界定义，尚未实现 HTTP、Preferences、OpenLink、Toast、日志、JsonStore 等实际服务；模型保留 RN/后端原始字段命名，包括课程字段中的空格命名，后续如需页面友好字段应在 service/mapper 层转换；`umPass` 仅作为历史缓存 key 记录，不表示会继续移植自动填充账号密码；大量服务入口 URL 已迁入但尚未逐一真机打开验证。 | Step 3 应基于本次常量和模型实现原生基础服务：网络统一走 `HttpClient`/`ApiClient`，缓存统一走 `PreferencesStore`/`JsonStore`，外链统一走 `OpenLink`，埋点先提供 `AnalyticsService` no-op；不要再从页面直接拼 URL、写缓存 key 或散落后端字段类型。 |
| Step 3 | 已完成 | 已新增原生基础服务封装并接入现有 Harbor 外链调用：`common/storage/PreferencesStore.ets` 统一封装 HarmonyOS Preferences 的读写、删除、批量清理和 flush；`common/storage/JsonStore.ets` 统一做 JSON 字符串缓存读写和解析失败降级；`common/net/HttpClient.ets` 统一封装 HTTP request、超时、状态码检查、JSON parse 和 `ServiceResult<T>` 错误返回；`common/net/ApiClient.ets` 提供 ARK API、课程 Worker、UM Open Data 的稳定入口；`common/config/UmOpenDataConfig.ets` 定义 UM Open Data token 运行期注入入口和缺失配置错误；`common/utils/OpenLink.ets`、`ClipboardService.ets`、`VersionCompare.ets`、`Haptics.ets`、`Logger.ets` 分别沉淀外链、剪贴板、版本比较、触感 no-op 和 hilog；`components/AppToast.ets`、`components/AppDialog.ets` 封装 UIContext prompt；`services/AnalyticsService.ets` 提供 Firebase 替代 no-op 埋点入口；`module.json5` 已补充 `ohos.permission.INTERNET`。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过。 | 后续页面必须复用这些入口：网络请求走 `HttpClient`/`ApiClient`，不要在页面直接 `http.createHttp()`；本地业务缓存走 `PreferencesStore`/`JsonStore`，不要散落 Preferences key 和 flush；外链走 `OpenLink.open`；提示走 `AppToast`/`AppDialog`；版本判断走 `compareVersion`/`isVersionNewer`；埋点调用 `AnalyticsService`，当前静默 no-op；触感调用 `Haptics.trigger`，当前无系统实现。现有 `RootTabs` 的 Harbor 发帖动作已从直接 `context.openLink` 改为 `OpenLink` + `AppToast`。 | UM Open Data token 仍未写入仓库，当前 `UmOpenDataConfig` 默认空 token，调用 `getUmOpenData` 会返回 `UM_OPEN_DATA_TOKEN_MISSING`，页面必须展示明确错误态；`OpenLink.open` 目前基于 API 23 `UIAbilityContext.openLink` 编译通过，但外部浏览器选择、非 http URI 和 fullScreen 语义仍需真机/模拟器验证；`AnalyticsService` 和 `Haptics` 首版 no-op，后续接入真实 SDK/能力时只替换服务内部；`AppToast`/`AppDialog` 只是 prompt 封装，完整自定义 UI 组件仍留到 Step 6。 | Step 4 迁移资源和课程数据读取时，应直接使用 `JsonStore`/`PreferencesStore` 管理课程缓存，云端版本检查走 `ApiClient.getCourse`；读取 UM Open Data 的页面不要绕过 `UmOpenDataConfig`，缺 token 时不要发请求、不要无限重试。 |
| Step 4 | 已完成 | 已迁移 RN 静态资源到鸿蒙资源体系：四个课程 JSON 原样放入 `entry/src/main/resources/rawfile/UMCourses/`，Logo、圆形 Logo、透明图、巴士图、巴士路线图、8 张巴士站点图、捐赠图、App Store/Play Store 图放入 rawfile 分目录；常用 Logo、圆形 Logo、巴士图同时复制到 `resources/base/media` 作为 `$r('app.media.*')` 固定 UI 资源；`UMCalendar` 和 `iconSvg` 源文件已放入 rawfile 供后续页面/数据迁移对照。新增 `common/constants/ResourcePaths.ets` 统一记录 rawfile 和 media 资源路径；新增 `common/resources/RawFileReader.ets`，基于 `context.resourceManager.getRawFileContent` 与 `util.TextDecoder` 读取 rawfile 文本/JSON；新增 `services/CourseDataService.ets`，提供课程版本、PreEnroll、Add/Drop、课程时间表的内置 rawfile 读取、缓存优先读取、缓存写入和首次缓存初始化入口；`JsonStore` 补充 `getOptionalObject` 以支持缓存缺失/损坏时降级 rawfile。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过；已用 Node 解析迁移后的四个课程 JSON，确认 `offerCourses` 593 条、`coursePlan` 612 条、`coursePlanTime` 2464 条；已对四个课程 JSON 与 RN 源文件做 `cmp`，内容一致；已检查生成 HAP 中包含 rawfile 与 media 资源。 | 后续课程相关页面和启动初始化应复用 `CourseDataService`：本地数据读取优先 `getCourseVersion` / `getOfferCourses` / `getCoursePlan` / `getCoursePlanTime`，首次启动或清缓存后调用 `ensureBuiltInCourseCache`；读取任意 rawfile 文本/JSON 复用 `RawFileReader`；资源路径从 `ResourcePaths.ets` 获取，不要在页面散落字符串。课程大 JSON 保持 rawfile，不转 ArkTS 常量。 | 当前只完成本地资源读取与缓存初始化入口，尚未实现 Step 5 的启动调度、6 小时云端课程版本检查和远端课程更新落盘；rawfile 图片路径已进入 HAP，但尚未在真实页面组件中视觉验证；`UMCalendar.js` 和 `iconSvg.js` 仅作为 rawfile 对照资源迁入，还没有转换为原生可消费的数据/图标模型。 | Step 5 应在 App bootstrap 中调用 `CourseDataService.ensureBuiltInCourseCache`，再实现主题、i18n 和启动初始化；课程云端更新继续走 Step 3 的 `ApiClient.getCourse`，成功后调用本 Step 沉淀的 `saveCourseVersion` / `saveOfferCourses` / `saveCoursePlan` / `saveCoursePlanTime`。 |
| Step 5 | 已完成 | 已实现主题、国际化和全局启动初始化：新增 `common/theme/AppTheme.ets`，保留 RN 的 System/Light/Dark 三种主题偏好，使用 `PreferencesStore` 持久化 `themePreference`，并通过 `ApplicationContext.setColorMode` 接入鸿蒙应用级深浅色；新增 `common/i18n/I18nService.ets` 与 `lang/zh_HK.ets`、`lang/en_US.ets`，保留 `tc`/`en` 两种语言偏好，持久化 `language`，并提供项目内 `t(language, key, fallback)` 文案入口；新增 `app/AppState.ets`、`app/AppBootstrap.ets`，启动时按顺序加载主题/语言、初始化课程缓存、校准内置课程版本、按 6 小时间隔检查云端课程版本、同步 AppInfo/版本信息并调用 no-op Analytics；新增 `services/AppInfoService.ets`；扩展 `CourseDataService`，实现内置课程版本覆盖旧缓存、`/version` 云端检查、`/pre`、`/adddrop`、`/timetable` 更新落盘和 `last_version_check_timestamp` 冷却时间；`Index.ets` 现在提供全局 `appThemeMode`、`appLanguage`、`appStartupState`，`RootTabs`/`InfoTopTabs`/占位页已改为消费主题和 i18n；`ROUTE_SETTING` 已接入一个基础设施验收版 `pages/features/SettingPage.ets`，可即时切换主题、语言并重新执行启动初始化。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过。 | 后续页面必须复用 `ThemeStore.resolveTheme` / `ThemeStore.setThemeMode`、`I18nService.t` / `I18nService.setLanguage`、`AppBootstrap.initialize`、`AppStartupState` 和扩展后的 `CourseDataService.checkCloudCourseVersionIfNeeded`；页面不要自行读取 `themePreference`/`language`，不要绕过 `CourseDataService` 直接写课程缓存；AppInfo/版本检查统一走 `AppInfoService.checkUpdateState`；ArkTS 严格模式不支持索引签名，本步已把 HTTP header、Analytics 参数和 i18n map 改为显式结构，后续新增公共结构也应遵守。 | 已编译验证但尚未真机/模拟器点击验证主题、语言、外链和云端课程下载的运行时体验；`SettingPage.ets` 目前只是 Step 5 的基础设施验收页，完整设置页信息架构、清缓存确认、外链、What2Reg Host 偏好应在 Step 7 扩展；i18n 当前是项目内 switch map，只迁入了导航、启动和设置基础文案，后续页面迁移时需按模块补齐；`HttpClient` 为符合 ArkTS 严格语法目前只显式支持 `Authorization` header，未来如需更多自定义 header 应扩展显式字段/转换类；构建仍有既有 Preferences throw 警告和 RawFileReader deprecated 警告，不影响通过。 | Step 6 应在现有主题/i18n/启动状态基础上做通用 UI 组件：卡片、点击项、Segment、Loading/Empty、Sheet/Dialog、图片和链接文本；Step 7 扩展设置页时直接复用本步的 `SettingPage.ets`、`ThemeStore`、`I18nService`、`AppBootstrap`、`AppInfoService` 与 `CourseDataService`，不要重建第二套基础设施。 |
| Step 6 | 已完成 | 已实现原生通用 UI 组件并接入现有页面：新增 `components/AppCard.ets` 作为 8px 圆角基础卡片/可点击容器；`components/AppListItem.ets` 作为设置项、信息行和普通点击项；`components/AppSegmentedControl.ets` 作为主题/语言/筛选等单选分段控件；`components/AppLoading.ets` 与 `components/AppEmptyState.ets` 分别承载加载态和空/占位/错误态；`components/AppBottomSheet.ets` 提供可复用底部面板；`components/AppNetworkImage.ets` 提供远程图片加载、加载中和失败占位；`components/AppLinkText.ets` 统一链接文本打开逻辑；`components/AppPageHeader.ets` 统一二级页返回头。`SettingPage.ets` 已改用 `AppCard`、`AppListItem`、`AppSegmentedControl`、`AppLoading`、`AppBottomSheet`、`AppLinkText` 和 `AppPageHeader`；`PlaceholderPage.ets`/`StackPlaceholderPage.ets` 已改用 `AppEmptyState`/`AppPageHeader`。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过。 | 后续业务页优先复用本步组件：页面分组用 `AppCard`；设置行/可点击行用 `AppListItem`；单选切换、筛选模式、课程模式用 `AppSegmentedControl`；网络/资源请求等待用 `AppLoading`；无数据、缺 token、请求失败可重试入口用 `AppEmptyState`；更多操作、筛选面板、链接集合用 `AppBottomSheet`；远程新闻/活动/组织图片用 `AppNetworkImage`；正文里的外链入口用 `AppLinkText`，内部继续走 `OpenLink` + `AppToast`；二级页标题栏用 `AppPageHeader`。组件内部复用 `ThemeStore`、全局 `colorMode`、`Haptics`、`OpenLink`、`AppToast`，没有引入 RN 组件库。 | 已编译验证但尚未真机/模拟器视觉和交互验证；`AppNetworkImage` 当前是远程 URL 加载包装，rawfile/media 图片仍可由页面直接用 ArkUI `Image($r(...))` 或后续扩展；`AppBottomSheet` 是轻量底部面板，复杂表单、键盘避让和多层弹窗需在具体页面继续验证；`AppDialog` 仍是 promptAction 服务封装，后续如需完全自定义确认弹窗可在本组件体系上扩展；构建仍有既有 Preferences throw 警告和 RawFileReader deprecated 警告，不影响通过。 | Step 7 扩展设置页时应直接复用 `SettingPage.ets` 当前结构和本步组件，不要恢复页面内私有卡片/分段按钮；新增组件属性不要命名为 ArkUI 通用属性（如 `padding`、`onClick`、`background`），本步已改用 `cardPadding`、`onTap`、`resolvedBackground` 规避严格模式冲突。 |
| Step 7 | 已完成 | 已按 RN `SettingPage.js` 的信息架构扩展鸿蒙设置页：外观分区继续验证主题/语言持久化；应用分区新增清缓存确认、手动检查更新、What2Reg Host 偏好入口和启动状态查看；关于分区迁入版本、GitHub、常见问题、隐私政策、Donate、Feedback、Activity、About ARK ALL 外链；联系分区迁入官网和邮件入口。新增 `services/UmehHostService.ets`，保留 RN `umehHost.js` 的 auto/primary/backup 偏好、主站探测、5 分钟探测缓存和当前 host 统一读取入口；补齐设置页中英文文案。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过。 | 设置页继续复用 Step 6 的 `AppCard`、`AppListItem`、`AppSegmentedControl`、`AppBottomSheet`、`AppDialog`、`AppToast`、`AppLoading`、`AppPageHeader`；清缓存走 `PreferencesStore.removeKeys(CACHE_RESET_STORAGE_KEYS)`，清完立即调用 `AppBootstrap.initialize` 重新初始化课程缓存和 AppInfo；更新检查走 `AppInfoService.checkUpdateState`；所有外链走 `OpenLink.open`；What2Reg host 后续页面应通过 `UmehHostService.getCurrentHost`、`buildCourseUrl`、`buildSearchUrl` 或 `refreshHost` 获取，不要自己读写 `umeh_host_pref`。 | 已完成编译验证但尚未真机/模拟器逐项点击确认系统浏览器、邮件 URI、prompt 弹窗和网络探测体验；What2Reg auto 探测当前用统一 `HttpClient` 对主站发起短超时 GET，若后续需要更接近 RN 的 HEAD 探测，可在服务内部替换；清缓存保留主题和语言偏好，仅清业务缓存与 What2Reg/Harbor/AppInfo/课程等缓存键，符合当前 `CACHE_RESET_STORAGE_KEYS` 定义。 | Step 8 做服务页入口聚合时可直接链接设置页；What2Reg/课程页面必须复用 `UmehHostService` 的 host 状态；不要在页面内直接散落 What2Reg 主备站 URL 或 `umeh_host_pref`。 |
| Step 8 | 已完成 | 已把 RN `FeatureList.js` 的服务入口迁成鸿蒙原生 `ServicePage`：底部“服务”Tab 不再显示占位页，改为 4 个分组、49 个入口的原生列表；入口名称、描述、外链 URL 和内部路由均按 RN 当前启用项迁入；页面顶部保留反馈和设置入口；校巴、车位、课表模拟、澳大部门进入统一 Stack 占位路由，设置进入 Step 7 设置页，What2Reg 打开前复用 `UmehHostService.refreshHost` 获取当前主/备站。新增 `common/constants/ServiceFeatureCatalog.ets` 集中维护服务入口数据，新增 `UM_STUDENT_UNION_BULLETIN` 常量和 `ROUTE_COURSE_SIM` 路由。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过。 | 服务页复用 `OpenLink`、`AppToast`、`AppBottomSheet`、`AppCard`、`AppListItem`、`ThemeStore`、`I18nService`、`AnalyticsService` 和 `UmehHostService`；所有外链 URL 继续从 `ApiEndpoints.ets` 或 `ServiceFeatureCatalog.ets` 的常量化数据读取；内部导航继续走全局 `NavPathStack.pushPathByName`，没有新建第二套路由。 | 已编译验证但尚未真机/模拟器逐项点击 45 个外链、邮件 URI 和系统浏览器返回体验；服务图标首版采用项目内文字徽标方案，未引入 RN icon 生态，后续若沉淀统一 Symbol/Icon 组件可只替换 `ServicePage.FeatureIcon`；校巴、车位、课表模拟、澳大部门仍是明确占位，真实页面留给 Step 9 及后续步骤。 | Step 9 做车位、部门、巴士时直接复用本次已接好的 `ROUTE_CAR_PARK`、`ROUTE_UM_ORG`、`ROUTE_BUS` 入口；后续新增/调整服务入口只改 `ServiceFeatureCatalog.ets`，不要在页面内散落 URL 或分组数据。 |
| Step 9 | 已完成 | 已实现服务内部页 `BusPage`、`CarParkPage`、`UMOrgPage` 并接入 Step 8 已配置的 `ROUTE_BUS`、`ROUTE_CAR_PARK`、`ROUTE_UM_ORG`：车位页按澳门时间当前时间减 30 分钟请求 UM Open Data，保留最新 5 条，支持提供对象和车辆类型两组筛选、手动刷新、更新时间和 P1/P2/P3/P5/P6 地点说明；部门页支持 UM Open Data 部门/子部门列表、页面内搜索、简体关键字小型字符映射、主部门折叠/展开、子部门点击和 Google `site:umall.one OR site:um.edu.mo` 搜索；巴士页按语言选择中/英文报站页，使用最小 HTML 解析器抽取 `span` 运行信息和 `.left` 车牌位置，支持手动刷新、7 秒自动刷新、离开页面清理定时器、路线图、车牌位置列表、校园地图和 8 个站点图片底部面板。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过；已用当前中文巴士 HTML 抽样验证解析器可读到运行信息和车牌位置。 | 新增 `services/CarParkService.ets`、`OrganizationService.ets`、`BusService.ets`，继续复用 `ApiClient.getUmOpenData`、`HttpClient.requestText`、`UmOpenDataConfig`、`ServiceResult`、`ApiEndpoints.ets`、`models/Parking.ets`、`models/Organization.ets`、`models/Bus.ets`、`ThemeStore`、`I18nService`、`AnalyticsService`、`OpenLink`、`AppToast`、`AppPageHeader`、`AppCard`、`AppSegmentedControl`、`AppLoading`、`AppEmptyState`、`AppBottomSheet` 和 Step 4 rawfile/media 巴士资源；没有在页面内直接创建 HTTP request，也没有写入真实 UM Open Data token。 | UM Open Data token 仍沿用 Step 3 的运行期注入策略，仓库内默认空 token；车位/部门在缺 token 时显示明确错误并允许重试，不会无限请求。部门搜索未引入 OpenCC，只做常见简体到繁体字符映射，极端简体关键字可能不完全等价 RN；巴士 UI 首版用原生卡片展示路线图、当前位置和站点图，没有复刻 RN 的绝对定位路线叠加、倒计时圆环和保持亮屏；巴士解析器针对当前官方 HTML 的 `span`/`.left` 结构，若官方页面结构大改需只替换 `BusService.parse`。尚未真机/模拟器逐项验证外链、站点图片弹层、定时器后台生命周期和有 token 时的 UM Open Data 实际响应。 | Step 10 开始课程数据服务和 What2Reg 业务逻辑时继续复用现有 `CourseDataService`、`UmehHostService`、`ApiClient`、`JsonStore` 和 `PreferencesStore`；后续新闻/活动等 UM Open Data 页面也必须走 `ApiClient.getUmOpenData`，缺 token 错误态可参考本步车位/部门页面。 |
| Step 10 | 已完成 | 已实现课程数据服务之上的 What2Reg 业务逻辑层：新增 `services/CourseCatalogService.ets`，支持 Add/Drop 与 PreEnroll 模式切换、读取并归一化 `ARK_Courses_filterOptions`、生成可用学院/学系/GE 列表、按 CMRE/GE 筛选课程、按课程代码/英文名/中文名/教师/星期/学院/学系搜索，并把 `coursePlanTime.Courses` 合并进搜索结果后按 `Course Code` 去重排序；新增课程模式、学院、学系、GE 标签映射和课程卡所需 Wiki/What2Reg/官方课程链接构建；新增 `common/utils/ChineseText.ets`，封装中文检测和简体关键字到繁体的轻量归一化；扩展 `models/Course.ets`，沉淀 `CourseCatalogItem`、`CourseFilterResult`、`CourseSearchResult`、`CourseCatalogState`、`CourseLinkBundle` 等页面复用类型。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过；已用迁移后的课程 JSON 抽样验证 Add/Drop 612 条、PreEnroll 593 条、默认 FST/ECE 筛选 24 条、GEST 筛选 14 条，`ECE`、`Electrical`、`电机`、`會計` 搜索均可命中。 | 继续复用 Step 4/5 的 `CourseDataService`、`JsonStore`、`PreferencesStore`、`StorageKeys`、`UmehHostService`、`ApiEndpoints` 和 `ServiceResult`；后续 What2Reg 页面应直接调用 `CourseCatalogService.loadCatalog`、`buildFilterResult`、`buildSearchResults`、`saveFilterOptions`、`buildCourseLinks`，不要在页面里重复实现课程数据读取、筛选分组、搜索去重或 What2Reg host 拼接。 | 简繁转换首版没有引入 OpenCC，只在 `ChineseText.normalizeSimplifiedChinese` 中放了课程/部门搜索常见字映射并标明 TODO，极端简体关键字可能不能完整匹配；本步只完成业务逻辑和数据层，没有实现 Step 11 的 ArkUI 大列表、筛选面板、课程卡菜单或手动更新按钮 UI；云端版本检查继续沿用 Step 5 的 `CourseDataService.checkCloudCourseVersion`，网络失败会返回错误结果且不破坏本地 rawfile/缓存数据。尚未在真机/模拟器上验证后续页面接入后的滚动性能和外链体验。 | Step 11 实现揾课页面时应以 `CourseCatalogState` 作为页面状态来源：先 `CourseCatalogService.loadCatalog(context)`，模式或筛选变化后调用 `buildFilterResult` 并 `saveFilterOptions`，搜索框使用 `shouldSearch`/`buildSearchResults`，课程卡菜单链接使用 `buildCourseLinks`；What2Reg host 仍需先通过 `UmehHostService.refreshHost` 刷新。 |
| Step 11 | 已完成 | 已实现鸿蒙原生揾课页面并接入底部“揾课”Tab：新增 `pages/courses/What2RegPage.ets`，启动时加载 `CourseCatalogService.loadCatalog(context)` 和 `UmehHostService.refreshHost`；用原生 `TextInput` 实现课程代码、英文名、中文名搜索，搜索结果复用 `buildSearchResults` 并合并课程时间表数据；用 `AppSegmentedControl` 实现 Add/Drop 与 PreEnroll 模式、CMRE/GE、学院、学系、GE 分类筛选，筛选变化后调用 `buildFilterResult` 并写回 `ARK_Courses_filterOptions`；课程列表使用 ArkUI `List` 承载原生课程卡，点击课程通过 `AppBottomSheet` 打开 Wiki、What2Reg、官方课程、Section/课表入口；页面更新入口可查看 Add/Drop/PreEnroll 版本、手动调用 `CourseDataService.checkCloudCourseVersion` 并重新加载页面数据，也可打开官方 SharePoint 版本页。为满足 ArkTS 严格模式，已把课程模型字段从带空格的 JSON 原始字段规范化为 camelCase，并在 `CourseDataService` 里对 rawfile、缓存和云端课程 JSON 做统一键名转换，`CourseCatalogService` 已改为只消费规范化字段。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过。 | 继续复用 Step 4/5/10 的 `CourseDataService`、`CourseCatalogService`、`UmehHostService`、`JsonStore`、`PreferencesStore`、`StorageKeys` 和课程 rawfile；UI 复用 Step 6 的 `AppCard`、`AppSegmentedControl`、`AppBottomSheet`、`AppListItem`、`AppLoading`、`AppEmptyState`、`AppToast`，外链统一走 `OpenLink`，埋点继续走 no-op `AnalyticsService`。后续课程、课表和首页读取课程模型时应使用 camelCase 字段，例如 `courseCode`、`courseTitle`、`offeringUnit`、`section`、`day`、`timeFrom`，不要再在 ArkTS 中访问带空格的 JSON 字段名。 | RN 的侧边首字母快速跳转和“幹飯”课程时间筛选 Sheet 未在本步复刻，后续如确有性能或定位需求可在当前 List 上追加；`LocalCourse` 和 `CourseSim` 入口目前仍进入既有占位路由，真正加入课表、查看本地课节留给 Step 12/13；课程卡菜单采用鸿蒙底部 Sheet 替代 RN dropdown menu；尚未在真机/模拟器视觉验证滚动、键盘和外链返回体验；构建仍有既有 Preferences throw 警告和 RawFileReader deprecated 警告，不影响通过。 | Step 12 做课表模拟业务逻辑时必须复用本步已规范化的课程模型字段和 `CourseDataService.getCoursePlanTime`，不要再假设课程对象含 `Course Code`、`Section` 等 RN 原始字段；Step 13 页面若要从揾课课程卡接收课程代码，需要把当前占位路由扩展为可读参数或统一课程选择状态。 |
| Step 12 | 已完成 | 已实现课表模拟业务逻辑层：新增 `services/CourseTimetableService.ets`，提供 ISW 复制文本导入解析、Course Code + Section 归一化去重、从 `coursePlanTime.Courses` 展开一周全部课节、MON-SUN + `timeFrom` 排序、相邻课节休息时间计算、冲突标记、首页下节课缓存生成、课表搜索候选与 Section 汇总，以及添加单个 Section、添加同课程全部 Section、删除单节、删除同课程全部 Section、清空课表等持久化入口；新增 `common/utils/DateTime.ets` 统一星期码、`HH:mm` 解析和排序；扩展 `models/Course.ets`，沉淀 `TimetableCourseMeeting`、`TimetableBuildResult`、`WeekTimetableHomeCache`、`TimetableSearchResult` 等页面和首页复用类型。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过；已用迁移后的 `coursePlanTime.json` 抽样验证导入正则覆盖 `ABCD1234(001)`、`ACCT1000 (001)`、`GESB1001/1002(001)`，可匹配 ACCT/GESB 课节，并用 `CPED1000(001)` + `CPED1000(003)` 验证同日同时间冲突可被标记。 | 继续复用 Step 4/5/11 的 `CourseDataService.getCoursePlanTime`、`JsonStore`、`PreferencesStore`、`StorageKeys`、规范化后的 camelCase 课程字段和 Step 10 的 `ChineseText` 简繁关键字归一化；`ARK_Timetable_Storage` 保存用户选择数组，`ARK_WeekTimetable_Storage` 保存按 `MON` 到 `SUN` 分组的首页缓存，读旧缓存时兼容 RN 的 `"Course Code"` / `"Section"` 字段并在写回时统一为 camelCase。后续首页和课表页面必须调用 `CourseTimetableService.loadTimetable`、`replaceSelections`、`importFromText`、`addCourseSection`、`addAllSectionsForCourse`、`dropCourseSection`、`dropCourse`、`clearTimetable` 和 `buildSearchResults`，不要在页面内再写第二套解析、匹配、排序或冲突逻辑。 | 本步只完成业务逻辑和缓存生成，没有实现 Step 13 的课表 UI、导入输入框、搜索加课面板、课程卡菜单或从 What2Reg 课程卡直接传参加课；首页读取下节课缓存要到 Step 14 接入。首页缓存字段在鸿蒙侧使用 camelCase，与 RN 历史结构语义一致但字段名已随 Step 11 规范化；如后续需要兼容外部旧数据展示，应继续通过 service 做转换。尚未在真机/模拟器验证 Preferences 实际读写生命周期和页面返回刷新体验；构建仍有既有 Preferences throw 警告和 RawFileReader deprecated 警告，不影响通过。 | Step 13 实现课表模拟页面时以 `TimetableBuildResult` 作为页面状态来源：启动先 `CourseTimetableService.loadTimetable(context)`，导入文本调用 `importFromText`，搜索加课调用 `buildSearchResults` 后用 `addCourseSection`/`addAllSectionsForCourse`，删除和清空只走本 service；页面只负责渲染 `weekTimetable`、`breakBeforeMinutes`、`conflict`、`periodHint`，不要直接遍历原始 `coursePlanTime.Courses` 生成课表。 |
| Step 13 | 已完成 | 已实现鸿蒙原生课表模拟页面并接入底部“课表”Tab 与 `ROUTE_COURSE_SIM` Stack 入口：新增 `pages/timetable/CourseSimPage.ets`，启动时读取 `CourseDataService.getCoursePlan`、`getCoursePlanTime` 和 `CourseTimetableService.loadTimetable`；空状态提供 RN 同款两条路径：手动“搵课/加课”和旧 ISW Timetable 文本导入；加课面板使用原生 `TextInput` 搜索课程，搜索结果复用 `CourseTimetableService.buildSearchResults`，支持星期筛选和全天/上午/下午/晚上时间段筛选，单课程结果可加入单个 Section、加入该课全部 Section、删除该课全部 Section；课表主体按 MON-SUN 横向展示课程卡，渲染 `breakBeforeMinutes`、`conflict`、`periodHint`，冲突课节有明确红色标识；课程卡底部 Sheet 支持 Wiki、What2Reg、官方课程外链、删除单个 Section、删除同课程全部 Section；清空课表、导入、加课、删课全部调用 `CourseTimetableService`，同步写入 `ARK_Timetable_Storage` 与 `ARK_WeekTimetable_Storage`；新增 `common/navigation/CourseSimNavigationState.ets`，揾课页点击“查模拟课表”会带课程代码打开加课面板。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过。 | 继续复用 Step 4/5/6/10/12 的 `CourseDataService`、`CourseTimetableService`、`CourseCatalogService.buildCourseLinks`、`UmehHostService`、`OpenLink`、`AnalyticsService`、`AppCard`、`AppBottomSheet`、`AppListItem`、`AppSegmentedControl`、`AppDialog`、`AppToast`、`AppLoading`、`AppEmptyState`、`ThemeStore` 和 `I18nService`；页面不直接遍历原始课程 JSON 生成课表，只消费 service 输出的 `TimetableBuildResult.weekTimetable` / `allMeetings` / `missingSelections`。 | 已支持导入课表、手动搜索加课、加入单节/全 Section、删除单节/整课、清空、持久化、首页缓存同步和冲突可见；RN 的 BottomSheet 展开档位动画、iOS dropdown menu、滚动到顶部动画和原生滚轮式任意时间选择暂缓，当前以鸿蒙底部 Sheet、课程卡点击菜单、星期 + 预设时间段筛选替代；尚未在真机/模拟器视觉验证横向课表滚动、键盘避让、外链返回和 Preferences 实际生命周期；构建仍有既有 Preferences throw 警告和 RawFileReader deprecated 警告，不影响通过。 | Step 14 首页接入下节课时直接读取 `ARK_WeekTimetable_Storage` 或复用 `WeekTimetableHomeCache` 结构，不要重新解析用户课表；如后续补 `LocalCourse` 页，可复用本步的 `CourseSimNavigationState` 或直接调用 `CourseTimetableService.addCourseSection`。 |
| Step 14 | 已完成 | 已实现资讯首页、澳大新闻、澳大活动和两类详情页，并接入资讯顶部 Tabs 与 `ROUTE_NEWS_DETAIL` / `ROUTE_UM_EVENT_DETAIL` Stack 路由：新增 `services/InfoFeedService.ets`，统一读取 UM Open Data 新闻/活动、选择新闻头条、活动按今天/未来优先再过往排序、图片 URL https 规范化、下节课首页缓存读取、三语详情选择、HTML 正文简化为纯文本和可点击链接列表；新增 `common/navigation/InfoNavigationState.ets`，列表点击后把当前新闻/活动交给详情页；新增 `pages/info/home/HomePage.ets`，实现首页搜索澳大网页/本地服务入口、下节课卡片、校巴/Moodle/新想法/支持/论坛登入 5 个快捷入口、AppInfo 版本提示和近期澳大活动预览；新增 `pages/info/NewsPage.ets`、`pages/info/UMEventPage.ets`、`pages/info/news/NewsDetailPage.ets`、`pages/info/news/UMEventDetailPage.ets`，支持新闻头条、新闻列表、活动列表、三语切换、远程图片预览、正文复制和链接外开。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过。 | 继续复用 Step 3/5/6/12 的 `ApiClient.getUmOpenData`、`UmOpenDataConfig`、`OpenLink`、`AppToast`、`AppInfoService`、`JsonStore`、`StorageKeys.STORAGE_WEEK_TIMETABLE`、`ThemeStore`、`I18nService`、`AnalyticsService`、`AppCard`、`AppListItem`、`AppNetworkImage`、`AppLoading`、`AppEmptyState`、`AppPageHeader`、`AppSegmentedControl` 和 `CourseTimetableService` 生成的 `WeekTimetableHomeCache`；首页只读取 `ARK_WeekTimetable_Storage` 的缓存结构，不重新解析用户课表；新闻/活动请求仍走统一 HTTP/UM Open Data token 入口。 | UM Open Data token 仍未写入仓库，默认缺 token 时新闻、活动和首页活动预览会展示明确错误态，不会无限重试或白屏；HTML 首版不做富文本排版，策略是去标签保留可读纯文本，并把 `<a href>` 和裸 URL 提取成独立可点击链接列表；新闻图片和活动海报可预览但尚未实现 RN 的大图查看器/手势缩放；活动详情 Hero 视差、玻璃态、复杂动画未复刻，使用原生图片 + 卡片信息结构替代；首页校历首版提供官方校历入口和活动预览，未迁入 `UMCalendar.js` 的横向校历条；尚未真机/模拟器验证远程图片、外链返回、键盘、横竖屏和有 token 时的实际 Open Data 响应。构建仍有既有 Preferences throw 警告和 RawFileReader deprecated 警告，不影响通过。 | Step 15 做组织模块时继续复用 `InfoNavigationState` 的“列表选中项进入详情”模式或抽成组织专用状态；组织/活动详情图片路径继续用 `addArkHost` / `InfoFeedService.normalizeImageUrl` 类似的集中规范化，不要在页面散落 host 拼接。若后续补 WebView 或富文本，可优先替换详情页内部 HTML 渲染组件，保留 `InfoFeedService.simplifyHtml` 作为无 WebView/解析失败降级。 |
| Step 15 | 已完成 | 已实现组织模块、组织活动详情、WebViewer 和最终路由补齐：新增 `services/ClubService.ets`，统一读取 ARK 组织列表、组织详情、组织活动分页和活动详情，集中做 `addArkHost` 图片 URL 规范化、组织分类映射、搜索、分页和活动时间状态；新增 `common/navigation/ClubNavigationState.ets` 与 `WebNavigationState.ets`，复用 Step 14 的“列表选中项进入详情”模式；新增 `pages/info/ClubPage.ets`、`pages/info/club/ClubDetailPage.ets`、`ClubEventDetailPage.ets`、`AllClubEventsPage.ets`，支持组织分组网格、搜索、刷新、详情封面/Logo/照片/联系方式/简介、活动预览、全部活动分页、活动详情、活动链接跳 WebViewer、举报邮件入口；新增 `pages/web/WebViewerPage.ets`，使用鸿蒙原生 `Web` + `WebviewController` 支持加载进度、网页内后退/前进、刷新、外部浏览器打开；`InfoTopTabs` 的组织 Tab 已替换占位页，`Index.routeMap` 已接入 `ROUTE_CLUB_DETAIL` / `ROUTE_EVENT_DETAIL` / `ROUTE_ALL_EVENTS` / `ROUTE_WEBVIEWER`。已执行 `hvigor assembleApp --no-daemon --stacktrace`，构建通过。 | 继续复用 `ApiClient.getArk` / `HttpClient` / `ServiceResult`、`ApiEndpoints` 的 ARK API 常量与 `addArkHost`、`OpenLink`、`AppToast`、`AppDialog`、`ThemeStore`、`I18nService`、`AnalyticsService`、`AppCard`、`AppListItem`、`AppNetworkImage`、`AppLoading`、`AppEmptyState`、`AppPageHeader`、`AppBottomSheet`、`InfoFeedService.simplifyHtml` 和 `ChineseText.normalizeSimplifiedChinese`；Web 入口统一通过 `WebNavigationState` 传递 `WebLinkParams`，Harbor 新想法仍优先系统浏览器。 | 组织/活动的登录、Follow、组织后台编辑、新增活动等 RN 预留能力未迁入，首版只做浏览和外链；组织照片和活动相关图片可展示、可在底部 Sheet 查看，但未实现 RN 的手势缩放大图查看器；WebViewer 不迁移 RN 的 `umPass` 自动填充，避免账号密码注入风险；WebView 内核、返回栈、外链返回、横屏/平板、深浅色、无网络和真实图片加载尚未在真机/模拟器逐项验证；组织搜索仍沿用轻量简繁映射，不是完整 OpenCC；构建仍有既有 Preferences throw 警告、RawFileReader deprecated 警告和 WebViewer `loadUrl` throw 警告，不影响通过。 | Step 15 已完成当前指南定义的迁移终点；后续若继续增强，应优先做真机/模拟器验收、WebView 运行时错误态、统一图片预览器、完整 OpenCC 替代、登录/Follow/组织后台能力和发布前版本/混淆策略检查。 |

状态建议使用：`未开始`、`进行中`、`已完成`、`部分完成`、`阻塞`。

每次完成后的记录至少包含：

- 完成了哪些页面或能力。
- 这些能力现在应该从哪里复用，例如“所有网络请求统一走 HttpClient”。
- 哪些 RN 行为已对齐，哪些暂未对齐。
- 验证方式，例如“真机运行、切换深色、断网、无 token”。
- 下一步继续时要注意什么。

### Step 0：确认基线与迁移约束

目标：让后续工作在同一个认知上开始。

参考 RN 方法：读取 `package.json`、`App.js`、`Nav.js`、`Tabbar.js`，确认 RN 版本的入口、初始化流程、导航层级和主业务模块。

鸿蒙原生方向：确认当前 DevEco/Hvigor 工程、API 23 配置、Stage Model 入口和设备类型。不要引入 RN 运行时，不要把 RN 当 Web 项目托管。

完成标准：能明确说明当前鸿蒙侧只是骨架工程，RN 侧是业务来源；能说明底部 Tab、资讯顶部 Tab、Stack 页面和启动初始化的大致结构。

文档维护：把当前工程状态、发现的阻塞、SDK/权限注意点写入 8.2。

### Step 1：搭建原生 App 壳和导航骨架

目标：先做一个能运行、能切换主入口的原生鸿蒙 App 壳。

参考 RN 方法：保持 RN 的导航关系：底部 5 个入口，资讯页内部 4 个顶部入口，二级页面通过统一路由进入。

鸿蒙原生方向：使用 ArkUI 原生 Navigation/Tabs/TabContent 等能力实现导航，不复刻 React Navigation API。`新想法` 是动作入口，不应变成空页面。

完成标准：App 启动进入资讯首页；底部入口可切换；资讯内部入口可切换；页面返回逻辑有统一方案。

文档维护：记录导航方案、路由命名约定、后续页面应该如何接入，避免下一步再重做一套导航。

### Step 2：建立公共常量、模型和接口边界

目标：把 URL、缓存 key、数据模型从页面中隔离出来。

参考 RN 方法：沿用 `pathMap.js` 的接口和外链定义，沿用 `storageKits.js` 的缓存 key 语义，沿用课程/新闻/活动/组织/车位接口字段。

鸿蒙原生方向：用 ArkTS 类型和项目内常量管理 API、路由和缓存 key。字段可以兼容后端原始字段，但页面不应散落硬编码 URL 或 key。

完成标准：后续页面能从统一位置拿 API、外链、缓存 key 和核心数据类型。

文档维护：记录已确定的常量入口、模型边界和任何字段命名取舍。

### Step 3：沉淀原生基础服务

目标：让页面不直接碰具体系统 API，而是通过项目内封装访问存储、网络、外链、Toast、Dialog、剪贴板、埋点和日志。

参考 RN 方法：保留 RN 的调用语义，例如 `getLocalStorage/setLocalStorage`、`openLink`、`logToFirebase`、`trigger`、版本比较等方法的业务角色。

鸿蒙原生方向：底层使用 HarmonyOS 原生 Preferences、HTTP、Want/URI 打开、prompt/dialog、pasteboard、hilog 等能力；Firebase 暂不可用时，埋点服务可先 no-op，但调用入口要稳定。

完成标准：任意页面可以复用同一套缓存、网络、外链和提示能力；网络错误、解析错误、无权限等有统一返回方式。

文档维护：在 8.2 写清“公共服务已存在，后续必须复用”，并说明每类能力的入口名称。

### Step 4：迁移资源和课程数据读取能力

目标：让 App 能用鸿蒙资源体系读取 RN 版本里的静态图片和大 JSON 数据。

参考 RN 方法：沿用 `src/static/UMCourses` 的四个课程文件，沿用巴士路线图、站点图、Logo、捐赠图等资源含义。

鸿蒙原生方向：大 JSON 使用 rawfile 或鸿蒙推荐资源方式读取，不转成巨大 ArkTS 常量；图片使用资源引用或 rawfile 路径，由统一图片组件加载。

完成标准：课程版本、Add/Drop、PreEnroll、课程时间表可从本地资源读取；巴士图、Logo 等关键图片可被页面引用。

文档维护：记录资源目录约定、大 JSON 读取方式和已经迁移的资源范围。

### Step 5：实现主题、国际化和全局启动初始化

目标：把 RN 里的 ThemeContext、i18n 和 App 启动初始化迁成鸿蒙原生状态体系。

参考 RN 方法：保留三种主题模式、两种语言、课程版本首次初始化、6 小时课程更新检查、AppInfo/版本检查的时机。

鸿蒙原生方向：使用 ArkTS 状态管理和系统深浅色能力；i18n 可以先用项目内 map 服务，不要求立即资源化；启动任务由原生 Ability/应用 bootstrap 调度。

完成标准：主题和语言可切换并持久化；启动时课程版本能初始化；启动流程失败不会白屏。

文档维护：记录主题状态入口、i18n 入口、启动任务顺序。后续页面必须使用这些入口，不要自己读取系统主题或语言。

### Step 6：实现原生通用 UI 组件

目标：沉淀项目内基础组件，后续页面统一使用，避免每个页面写一套卡片、按钮、Sheet、Segment、Loading。

参考 RN 方法：保留 RN 组件的交互意图，如 PressableScale 的触感反馈、SegmentControl 的选中态、ModalBottom/BottomSheet 的承载场景、HyperlinkText 的链接打开逻辑。

鸿蒙原生方向：用 ArkUI 原生 Button、Text、Image、List、Dialog、Sheet/Popup、Progress、Menu 等能力实现。不要引入 RN 风格组件库来模拟。

完成标准：至少具备可复用的卡片、点击项、分段控件、加载态、空状态、弹窗/底部面板、图片加载、链接文本。

文档维护：记录每个通用组件的适用场景。后续业务页如果需要新组件，应先检查是否能扩展已有组件。

### Step 7：实现设置页作为基础设施验收页

目标：用设置页验证主题、语言、缓存、更新检查、外链和 What2Reg Host 偏好是否真的可用。

参考 RN 方法：沿用 `SettingPage.js` 的信息架构：外观、应用、关于、联系；沿用 `appUpdateKits.js` 和 `umehHost.js` 的业务逻辑。

鸿蒙原生方向：用原生列表、分段控件、菜单/弹窗和系统外链打开能力实现；版本号从鸿蒙应用信息或统一 AppInfo 服务获取。

完成标准：主题切换、语言切换、清缓存、检查更新、外链打开、What2Reg Host 偏好都能工作。清缓存后必须能重新完成启动初始化。

文档维护：记录设置页已验证的公共能力；若某项只是占位，必须写清楚。

### Step 8：实现服务页入口聚合

目标：把 RN 的服务入口完整迁到鸿蒙原生页面，先让所有入口可用。

参考 RN 方法：沿用 `FeatureList.js` 的分组、入口名称、URL、内部路由和描述。多数入口点击后打开外部链接，少数入口进入内部原生页面。

鸿蒙原生方向：用原生网格/List/Grid 容器和原生点击反馈；图标优先用鸿蒙可用 Symbol、本地资源或统一图标方案。不要为了图标引入整套 RN icon 生态。

完成标准：四个服务分组完整显示；外链入口可打开；内部入口能进入对应页面或明确占位；设置入口可进入设置页。

文档维护：记录已迁移的入口数量、哪些入口是内部页、哪些入口暂时只是外链。

### Step 9：实现服务内部页：车位、部门、巴士

目标：优先迁移服务页中用户可直接感知的三个原生内部页。

参考 RN 方法：沿用 `CarPark.js` 的过滤和澳门时间逻辑；沿用 `UMOrg.js` 的部门/子部门搜索和折叠逻辑；沿用 `Bus.js` 的 HTML 解析、7 秒刷新和站点展示逻辑。

鸿蒙原生方向：网络请求走统一 HTTP 服务；筛选、搜索、折叠、定时器都用 ArkTS 和 ArkUI 原生机制；巴士 HTML 解析可以先做最小解析器，不依赖 RN HTML parser。

完成标准：车位可筛选刷新；部门可搜索折叠并打开站内搜索；巴士可手动/自动刷新，离开页面后停止定时器。

文档维护：记录 UM Open Data token 处理方式、巴士解析策略和已知不完全一致的 UI 细节。

### Step 10：实现课程数据服务和揾课业务逻辑

目标：先把课程数据、版本更新、搜索、筛选做成可测试的 ArkTS 业务逻辑，再做页面。

参考 RN 方法：沿用 `checkCoursesKits.js` 的版本比较和缓存更新流程；沿用 What2Reg hooks 的课程模式、筛选归一化、搜索长度规则、课程时间表合并去重逻辑。

鸿蒙原生方向：课程 JSON 由资源读取，缓存由统一 JsonStore/PreferencesStore 管理，搜索/筛选写成纯 ArkTS 方法。简繁转换如果暂时缺库，应封装统一方法并明确 TODO。

完成标准：无网络可读内置课程；能检查云端版本并安全失败；Add/Drop 与 PreEnroll 数据可切换；搜索和筛选函数可被页面复用。

文档维护：记录课程服务入口、缓存结构、简繁转换处理现状。后续课表和首页都必须复用同一课程服务。

### Step 11：实现揾课页面

目标：把课程目录/搜索/筛选以鸿蒙原生页面呈现出来。

参考 RN 方法：沿用 `what2Reg/index.js` 的页面流程、`CourseCard.js` 的展示信息和菜单动作、`FilterPanel.js` 的筛选交互。

鸿蒙原生方向：用原生搜索框、List/LazyForEach、Menu/Sheet、Segment 等组件；大列表必须考虑懒加载和滚动性能。

完成标准：课程列表能显示；搜索课程代码、英文名、中文名可用；筛选可用；课程卡能打开 Wiki、What2Reg、官方课程；手动课程更新后页面刷新数据。

文档维护：记录页面复用了哪些课程服务和通用组件，哪些 RN 交互用鸿蒙原生方式替代了。

### Step 12：实现课表模拟业务逻辑

目标：把课表导入、匹配、排序、冲突检测和首页缓存生成做成独立逻辑。

参考 RN 方法：沿用 `courseSim/index.js` 的 `parseImportData` 正则意图、Course Code + Section 匹配规则、MON-SUN 排序、休息时间/冲突判断、`ARK_Timetable_Storage` 和 `ARK_WeekTimetable_Storage` 结构。

鸿蒙原生方向：纯 ArkTS 函数处理导入文本和课程数据，不依赖页面状态。日期和时间处理使用项目内 DateTime 工具。

完成标准：能解析 ISW 复制文本；能从课程时间表生成一周课表；能标记冲突；能生成首页下节课需要的缓存结构。

文档维护：记录课表缓存结构和逻辑入口。后续首页和课表页面不得再实现第二套解析逻辑。

### Step 13：实现课表模拟页面

目标：用原生 UI 完成课表导入、展示、加课、删课和持久化。

参考 RN 方法：沿用 `CourseSim` 的空状态引导、导入课表、搜索加课、删除单节/全部 Section、清空课表、课程卡菜单等流程。

鸿蒙原生方向：用原生输入框、时间选择、列表/网格、菜单/弹窗/Sheet 实现。复杂 BottomSheet 可以用鸿蒙更自然的页面或弹层替代，但行为要等价。

完成标准：用户能导入课表、手动加课、删课、清空；重启后课表仍在；冲突可见；首页缓存被同步写入。

文档维护：记录已经支持的课表操作和暂缓的筛选/动画/高级交互。

### Step 14：实现首页与资讯模块

目标：完成资讯页的主入口体验，包括首页、新闻、澳大活动。

参考 RN 方法：沿用 Home 的快捷入口、AppInfo/版本检查、下节课展示；沿用 NewsPage 的头条选择和详情多语言；沿用 UMEventPage 的活动排序和详情展示。

鸿蒙原生方向：用原生 Tabs、List、Image、RichText/简化 HTML 文本、Dialog、外链打开能力实现。HTML 渲染可以先简化，但链接必须可点击。

完成标准：首页快捷入口可用，能显示下节课；新闻列表/详情可用；澳大活动列表/详情可用；无 token 或网络失败有明确错误态。

文档维护：记录 HTML 处理策略、Open Data token 状态和哪些详情样式尚未完全对齐 RN。

### Step 15：实现组织模块、Web 相关能力与最终补齐

目标：完成组织浏览、组织活动详情、Wiki/Harbor/WebViewer，以及发布前体验检查。

参考 RN 方法：沿用 ClubPage 的分组和搜索、ClubDetail/EventDetail 的详情数据展示；沿用 Webviewer/IntegratedWebView 的进度、返回、刷新、外部打开；沿用 HarborNewTopicTab 的快捷发帖行为。

鸿蒙原生方向：组织页面用原生 List/Grid/Image；Web 页面使用鸿蒙原生 Web 组件或系统浏览器，不用 WebView 承载整个 App；Harbor 默认优先系统浏览器。

完成标准：组织列表、搜索、详情和活动详情可用；WebViewer 能打开、刷新、返回和外部打开；Harbor 新想法入口可用；手机/平板/横屏、深浅色、无网络、清缓存路径完成最终检查。

文档维护：把 8.2 所有 Step 状态更新到最新；在“已知风险”中补充实际遗留问题；在“测试与验收清单”中标注已验证项。

## 9. 后续 GPT 工作规则

后续 GPT 接任务时，请按以下规则执行：

1. 先读本文档，尤其是 8.2 的迁移状态记录，再读对应 RN 源文件和当前已完成的鸿蒙实现。
2. 开工前先确认已有公共能力，避免重复实现第二套缓存、网络、主题、i18n、课程服务、Toast、Sheet 或 WebView。
3. 不要一次迁移多个复杂模块。一个任务最好只覆盖一个页面、一个服务或一个清晰能力。
4. 页面迁移前先确认依赖的 service/model/component 是否已经存在；存在则复用，不存在再补。
5. 尽量保留 RN 的业务行为和数据处理方法，但 UI 和系统能力必须使用鸿蒙原生实现。
6. 所有网络请求必须走统一 HTTP 服务。
7. 所有缓存必须走统一存储服务。
8. 所有外链必须走统一 OpenLink 服务。
9. 所有埋点必须走统一 AnalyticsService；不可用时保持 no-op。
10. 对大 JSON 和图片资源不要手写成 ArkTS 常量。
11. 每完成一步，都必须更新 8.2 迁移状态记录和相关风险/验收说明。
12. 每个模块完成后必须至少验证：
    - 空数据
    - 网络错误
    - 深色模式
    - 英文/繁中
    - 页面返回

建议每次交付格式：

```text
本次迁移模块：
参考的 RN 行为：
使用/沉淀的鸿蒙原生能力：
复用的公共服务或组件：
已实现行为：
未实现/延期行为：
本地验证：
文档已更新位置：
已知风险：
```

## 10. 测试与验收清单

### 10.1 基础

- App 可启动。
- 无网络时不崩溃。
- 深色/浅色/跟随系统可切换。
- 英文/繁中可切换。
- 清缓存后可恢复初始数据。
- 所有底部 Tab 可切换。
- Step 15 已编译验证：组织 Tab、组织详情/活动详情/WebViewer 路由均已接入原生 Navigation；仍需真机/模拟器点击验收。

### 10.2 网络

- UM Open Data token 缺失时有明确提示。
- UM Open Data token 正常时，新闻/活动/车位/部门可拉取。
- ARK 组织接口正常时，组织列表、组织详情、组织活动分页和活动详情可拉取；无网络或接口失败时需展示错误态。
- 课程 Worker 不可用时使用本地课程数据。
- 请求超时不导致无限 loading。

### 10.3 课程

- 首次启动写入课程版本。
- 手动更新课程数据成功后缓存变更。
- 搜索课程代码、英文名、中文名。
- Add/Drop 与 PreEnroll 切换。
- 课表导入正则覆盖 `ABCD1234(001)` 和 `GESB1001/1002(001)`。
- 课表冲突检测正确。
- 课表页面可导入、搜索加课、删除单节/整课、清空，并同步首页课表缓存。

### 10.4 UI

- 手机、平板、2in1 基本布局可用。
- 横屏底部 Tab/顶部 Tab 不挤压。
- 长文本不溢出按钮或卡片。
- 列表滚动不卡顿。
- 图片加载失败有占位。
- Step 15 已编译覆盖组织网格、组织/活动卡片、详情长文本和 WebViewer 控制栏；仍需多设备截图验收。

### 10.5 发布

- `AppScope/app.json5` 的 `versionName/versionCode` 与业务版本策略同步。
- Release 混淆策略明确。
- 不提交本地 token、签名密码、私有配置。
- 权限列表最小化。

## 11. 已知风险与建议

1. **API 23 SDK 差异**
   - 当前工程配置是 API 23，但本机可见的 OpenHarmony SDK 目录包含较旧版本。后续写具体 import 时必须以 DevEco API 23 编译为准。

2. **UM Open Data Token**
   - RN 通过 Expo env 注入，鸿蒙需重新设计配置方式。不要把真实 token 写进 Git。

3. **大 JSON 性能**
   - 课程数据较大，直接作为 ArkTS 常量可能影响编译和启动。优先 rawfile + 缓存。

4. **简繁转换**
   - `opencc-js` 是 RN 侧搜索体验的重要依赖。鸿蒙侧没有替代前，中文搜索体验会下降。

5. **WebView 登录自动填充**
   - RN 的 `umPass` 注入账号密码有安全风险。移植时不应默认启用。

6. **HTML 渲染**
   - 新闻详情和巴士页面依赖 HTML 解析。首版可做简化，但要标注缺口。

7. **登录/Follow/组织后台**
   - RN 中相关逻辑不完整或偏预留。首版应先迁移浏览能力，登录和编辑后台后置。

8. **多端布局**
   - 当前鸿蒙工程声明支持 phone/tablet/2in1。每个页面都要避免只按手机宽度硬编码。

9. **课表页面运行时体验**
   - Step 13 已完成编译验证，但仍需在真机/模拟器检查横向课表滚动、键盘避让、底部 Sheet 高度、外链返回和 Preferences 实际读写生命周期。

10. **组织模块运行时体验**
   - Step 15 已完成编译验证，但组织图片、活动分页、举报邮件、WebViewer 返回栈、网页刷新、外部浏览器打开、横屏/平板布局和无网络错误态仍需在真机/模拟器验收。

11. **WebViewer 安全与兼容**
   - 鸿蒙原生 WebViewer 不迁移 RN 的 `umPass` 注入；如后续需要登录辅助，应重新设计显式授权和本地安全存储方案。Harbor 新想法默认继续使用系统浏览器，避免把论坛完整承载在 App WebView 内。

## 12. 关键源文件索引

入口与导航：

- `ReactNative版本/App.js`
- `ReactNative版本/src/Nav.js`
- `ReactNative版本/src/Tabbar.js`

全局：

- `ReactNative版本/src/components/ThemeContext.js`
- `ReactNative版本/src/i18n/i18n.js`
- `ReactNative版本/src/i18n/en-us.json`
- `ReactNative版本/src/i18n/zh-hk.js`
- `ReactNative版本/src/utils/pathMap.js`
- `ReactNative版本/src/utils/storageKits.js`
- `ReactNative版本/src/utils/browser.js`
- `ReactNative版本/src/utils/checkCoursesKits.js`
- `ReactNative版本/src/utils/umehHost.js`
- `ReactNative版本/src/utils/appUpdateKits.js`

资讯：

- `ReactNative版本/src/pages/TabbarPages/info/index.js`
- `ReactNative版本/src/pages/TabbarPages/info/home/index.js`
- `ReactNative版本/src/pages/TabbarPages/info/NewsPage.js`
- `ReactNative版本/src/pages/TabbarPages/info/UMEventPage.js`
- `ReactNative版本/src/pages/TabbarPages/info/ClubPage.js`
- `ReactNative版本/src/pages/TabbarPages/info/news/NewsDetail.js`
- `ReactNative版本/src/pages/TabbarPages/info/news/UMEventDetail.js`
- `ReactNative版本/src/pages/TabbarPages/info/club/ClubDetail.js`
- `ReactNative版本/src/pages/TabbarPages/info/club/EventDetail.js`
- `ReactNative版本/src/pages/TabbarPages/info/club/AllEvents.js`

课程：

- `ReactNative版本/src/pages/TabbarPages/what2Reg/index.js`
- `ReactNative版本/src/pages/TabbarPages/what2Reg/hooks/useCourseData.js`
- `ReactNative版本/src/pages/TabbarPages/what2Reg/hooks/useCourseFiltering.js`
- `ReactNative版本/src/pages/TabbarPages/what2Reg/hooks/useCourseSearch.js`
- `ReactNative版本/src/pages/TabbarPages/what2Reg/utils/search.js`
- `ReactNative版本/src/pages/TabbarPages/courseSim/index.js`
- `ReactNative版本/src/pages/TabbarPages/what2Reg/pages/LocalCourse.js`
- `ReactNative版本/src/static/UMCourses/*.json`

服务：

- `ReactNative版本/src/pages/TabbarPages/features/index.js`
- `ReactNative版本/src/pages/TabbarPages/features/FeatureList.js`
- `ReactNative版本/src/pages/Features/Bus.js`
- `ReactNative版本/src/pages/Features/CarPark.js`
- `ReactNative版本/src/pages/Features/UMOrg.js`
- `ReactNative版本/src/pages/Features/SettingPage.js`

Web：

- `ReactNative版本/src/components/Webviewer.js`
- `ReactNative版本/src/components/IntegratedWebView.js`
- `ReactNative版本/src/pages/TabbarPages/arkwiki/index.js`
- `ReactNative版本/src/pages/TabbarPages/arkHarbor/index.js`
- `ReactNative版本/src/pages/TabbarPages/HarborNewTopicTab.js`
