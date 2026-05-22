import { common } from '@kit.AbilityKit';
import {
  AFD_UMACARK,
  ARK_HARBOR_LOGIN,
  ARK_HARBOR_NEW_TOPIC,
  ARK_SUPPORT_MAIL,
  UM_CALENDAR,
  UM_MOODLE
} from '../../../common/constants/ApiEndpoints';
import { RAWFILE_UM_CALENDAR } from '../../../common/constants/ResourcePaths';
import {
  SERVICE_DYNAMIC_LINK_UMEH,
  SERVICE_FEATURE_SECTIONS,
  ServiceFeatureItem,
  ServiceFeatureSection
} from '../../../common/constants/ServiceFeatureCatalog';
import {
  ROUTE_BUS,
  ROUTE_UM_EVENT_DETAIL
} from '../../../common/constants/RouteNames';
import { ROOT_CONTENT_BOTTOM_PADDING } from '../../../common/constants/LayoutMetrics';
import { ROOT_TAB_TIMETABLE } from '../../../common/constants/TabIndexes';
import { InfoNavigationState } from '../../../common/navigation/InfoNavigationState';
import {
  INFO_TOP_TAB_HOME,
  InfoRefreshHandler,
  InfoRefreshRegistry
} from '../../../common/navigation/InfoRefreshRegistry';
import { ServiceResult } from '../../../common/net/HttpClient';
import { I18nService, LANGUAGE_EN } from '../../../common/i18n/I18nService';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../../../common/theme/AppTheme';
import { OpenLink } from '../../../common/utils/OpenLink';
import { AppCard } from '../../../components/AppCard';
import { AppListItem } from '../../../components/AppListItem';
import { AppLoading } from '../../../components/AppLoading';
import { AppNetworkImage } from '../../../components/AppNetworkImage';
import { AppSearchField } from '../../../components/AppSearchField';
import { AppToast, AppToastType } from '../../../components/AppToast';
import { AppInfoUpdateState } from '../../../services/AppInfoService';
import { AppInfoService } from '../../../services/AppInfoService';
import { AnalyticsParams, AnalyticsService } from '../../../services/AnalyticsService';
import { InfoFeedService } from '../../../services/InfoFeedService';
import { UmehHostService, UmehHostState } from '../../../services/UmehHostService';
import { TimetableHomeCacheItem } from '../../../models/Course';
import {
  UmEventDetail,
  UmEventItem
} from '../../../models/Event';
import {
  OPEN_DATA_LOCALE_EN_US,
  OPEN_DATA_LOCALE_ZH_TW
} from '../../../models/News';
import { RawFileReader } from '../../../common/resources/RawFileReader';

interface HomeCalendarItem {
  startDate: string;
  endDate: string;
  summary: string;
  summaryCn: string;
}

function emptyHomeCourse(): TimetableHomeCacheItem {
  return {
    courseCode: '',
    section: '',
    timeFrom: '',
    color: 0
  };
}

function calendarValue(block: string, key: string): string {
  const singleQuotePattern: RegExp = new RegExp("'" + key + "'\\s*:\\s*'([^']*)'");
  const singleQuoteMatch: RegExpExecArray | null = singleQuotePattern.exec(block);
  if (singleQuoteMatch !== null) {
    return singleQuoteMatch[1];
  }
  const doubleQuotePattern: RegExp = new RegExp("'" + key + "'\\s*:\\s*\"([^\"]*)\"");
  const doubleQuoteMatch: RegExpExecArray | null = doubleQuotePattern.exec(block);
  return doubleQuoteMatch === null ? '' : doubleQuoteMatch[1];
}

function parseHomeCalendar(text: string): HomeCalendarItem[] {
  const result: HomeCalendarItem[] = [];
  const blockPattern: RegExp = /\{[\s\S]*?\}/g;
  let match: RegExpExecArray | null = blockPattern.exec(text);
  while (match !== null) {
    const block: string = match[0];
    const startDate: string = calendarValue(block, 'startDate');
    const endDate: string = calendarValue(block, 'endDate');
    const summary: string = calendarValue(block, 'summary');
    if (startDate.length > 0 && endDate.length > 0 && summary.length > 0) {
      result.push({
        startDate: startDate,
        endDate: endDate,
        summary: summary,
        summaryCn: calendarValue(block, 'summary_cn')
      });
    }
    match = blockPattern.exec(text);
  }
  return result;
}

function timestampOf(dateText: string): number {
  const timestamp: number = new Date(dateText).getTime();
  return Number.isNaN(timestamp) ? 0 : timestamp;
}

function startOfTodayTimestamp(): number {
  const today: Date = new Date();
  today.setHours(0, 0, 0, 0);
  return today.getTime();
}

function pad2(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

@Component
export struct HomePage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @Consume('appCurrentTabIndex') currentTabIndex: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State loading: boolean = true;
  @State appInfoError: string = '';
  @State eventError: string = '';
  @State updateAvailable: boolean = false;
  @State latestVersion: string = '';
  @State localVersion: string = '';
  @State versionInfo: string = '';
  @State hasUpcomingCourse: boolean = false;
  @State upcomingCourse: TimetableHomeCacheItem = emptyHomeCourse();
  @State eventPreview: UmEventItem[] = [];
  @State calendarItems: HomeCalendarItem[] = [];
  @State selectedCalendarIndex: number = 0;
  @State calendarError: string = '';
  @State searchText: string = '';
  @State showSearchSheet: boolean = false;
  @State featureResults: ServiceFeatureItem[] = [];
  @BuilderParam topContent: () => void = this.EmptySlot;
  private loaded: boolean = false;
  private refreshHandler: InfoRefreshHandler = (): void => {
    this.refresh(true);
  };

  @Builder
  private EmptySlot(): void {
  }
  private calendarScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    InfoRefreshRegistry.register(INFO_TOP_TAB_HOME, this.refreshHandler);
    const params: AnalyticsParams = new AnalyticsParams();
    params.routeName = 'Home';
    AnalyticsService.log('openPage', params);
    if (!this.loaded) {
      this.loaded = true;
      this.refresh(false);
    } else {
      this.reloadUpcomingCourse();
      this.loadCalendar();
    }
  }

  aboutToDisappear(): void {
    InfoRefreshRegistry.unregister(INFO_TOP_TAB_HOME, this.refreshHandler);
  }

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private isEnglish(): boolean {
    return I18nService.normalizeLanguage(this.language) === LANGUAGE_EN;
  }

  private localized(tcText: string, enText: string): string {
    return this.isEnglish() ? enText : tcText;
  }

  private preferredLocale(): string {
    return this.isEnglish() ? OPEN_DATA_LOCALE_EN_US : OPEN_DATA_LOCALE_ZH_TW;
  }

  private getContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async reloadUpcomingCourse(): Promise<void> {
    const course: TimetableHomeCacheItem | null = await InfoFeedService.readUpcomingCourse(this.getContext());
    this.hasUpcomingCourse = course !== null;
    this.upcomingCourse = course ?? emptyHomeCourse();
  }

  private async loadCalendar(): Promise<void> {
    if (this.calendarItems.length > 0) {
      this.selectCalendarIndex(this.resolveCalendarIndex(this.calendarItems));
      return;
    }
    this.calendarError = '';
    const textResult: ServiceResult<string> = await RawFileReader.readText(this.getContext(), RAWFILE_UM_CALENDAR);
    if (!textResult.ok || !textResult.data) {
      this.calendarError = textResult.error?.message ?? this.localized('校曆讀取失敗', 'Failed to load calendar');
      return;
    }
    const items: HomeCalendarItem[] = parseHomeCalendar(textResult.data);
    this.calendarItems = items;
    this.selectCalendarIndex(this.resolveCalendarIndex(items));
  }

  private resolveCalendarIndex(items: HomeCalendarItem[]): number {
    if (items.length === 0) {
      return 0;
    }
    const todayStart: number = startOfTodayTimestamp();
    const nextEssentialIndex: number = this.resolveNextCalendarIndex(items, todayStart, true);
    if (nextEssentialIndex >= 0) {
      return nextEssentialIndex;
    }
    const nextCalendarIndex: number = this.resolveNextCalendarIndex(items, todayStart, false);
    if (nextCalendarIndex >= 0) {
      return nextCalendarIndex;
    }
    return items.length - 1;
  }

  private resolveNextCalendarIndex(items: HomeCalendarItem[], minTimestamp: number, essentialOnly: boolean): number {
    for (let i = 0; i < items.length; i++) {
      if (essentialOnly && !this.calendarIsEssential(items[i])) {
        continue;
      }
      if (timestampOf(items[i].startDate) >= minTimestamp) {
        return i;
      }
    }
    return -1;
  }

  private selectCalendarIndex(index: number): void {
    if (this.calendarItems.length === 0) {
      return;
    }
    const lastIndex: number = this.calendarItems.length - 1;
    const safeIndex: number = Math.min(Math.max(index, 0), lastIndex);
    this.selectedCalendarIndex = safeIndex;
    this.scrollCalendarToSelection();
  }

  private selectCalendarOffset(offset: number): void {
    this.selectCalendarIndex(this.selectedCalendarIndex + offset);
  }

  private canSelectCalendarOffset(offset: number): boolean {
    const targetIndex: number = this.selectedCalendarIndex + offset;
    return targetIndex >= 0 && targetIndex < this.calendarItems.length;
  }

  private scrollCalendarToSelection(): void {
    const targetOffset: number = Math.max(this.selectedCalendarIndex - 2, 0) * 56;
    this.scrollCalendarToOffset(targetOffset, 80);
    this.scrollCalendarToOffset(targetOffset, 240);
  }

  private scrollCalendarToOffset(targetOffset: number, delay: number): void {
    setTimeout(() => {
      this.calendarScroller.scrollTo({
        xOffset: targetOffset,
        yOffset: 0,
        animation: true
      });
    }, delay);
  }

  private async refresh(showToast: boolean): Promise<void> {
    this.loading = true;
    this.appInfoError = '';
    this.eventError = '';
    await this.reloadUpcomingCourse();
    await this.loadCalendar();

    const appInfoResult: ServiceResult<AppInfoUpdateState> = await AppInfoService.checkUpdateState(this.getContext());
    if (appInfoResult.data) {
      this.localVersion = appInfoResult.data.localVersion;
      this.latestVersion = appInfoResult.data.latestVersion;
      this.updateAvailable = appInfoResult.data.updateAvailable;
      this.versionInfo = appInfoResult.data.appInfo?.version_info ?? '';
    }
    if (!appInfoResult.ok) {
      this.appInfoError = appInfoResult.error?.message ?? this.localized('App 信息同步失敗', 'App info sync failed');
    }

    const eventResult: ServiceResult<UmEventItem[]> = await InfoFeedService.fetchUmEvents(4);
    if (eventResult.ok && eventResult.data) {
      this.eventPreview = eventResult.data;
    } else {
      this.eventPreview = [];
      this.eventError = eventResult.error?.message ?? this.localized('活動資料讀取失敗', 'Failed to load events');
    }

    this.loading = false;
    if (showToast) {
      AppToast.show(this.getUIContext(), this.localized('首頁已刷新', 'Home refreshed'), AppToastType.Success);
    }
  }

  private async openExternal(url: string): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), url);
    if (!success) {
      AppToast.showError(this.getUIContext(), this.localized('無法打開鏈接', 'Unable to open link'));
    }
  }

  private searchFeatures(keyword: string): ServiceFeatureItem[] {
    const trimmed: string = keyword.trim().toLowerCase();
    const result: ServiceFeatureItem[] = [];
    if (trimmed.length === 0) {
      return result;
    }
    for (let sectionIndex = 0; sectionIndex < SERVICE_FEATURE_SECTIONS.length; sectionIndex++) {
      const section: ServiceFeatureSection = SERVICE_FEATURE_SECTIONS[sectionIndex];
      for (let itemIndex = 0; itemIndex < section.items.length; itemIndex++) {
        const item: ServiceFeatureItem = section.items[itemIndex];
        const target: string = (item.titleTc + ' ' + item.titleEn + ' ' + item.descriptionTc + ' ' +
        item.descriptionEn + ' ' + item.key).toLowerCase();
        if (target.includes(trimmed)) {
          result.push(item);
          if (result.length >= 3) {
            return result;
          }
        }
      }
    }
    return result;
  }

  private updateSearch(value: string): void {
    this.searchText = value;
    this.featureResults = this.searchFeatures(value);
  }

  private async openFeature(item: ServiceFeatureItem): Promise<void> {
    const routeName: string = item.routeName ?? '';
    if (routeName.length > 0) {
      this.showSearchSheet = false;
      this.pathStack.pushPathByName(routeName, null);
      return;
    }
    if ((item.dynamicLink ?? '') === SERVICE_DYNAMIC_LINK_UMEH) {
      const state: UmehHostState = await UmehHostService.refreshHost(this.getContext());
      this.showSearchSheet = false;
      await this.openExternal(state.currentHost);
      return;
    }
    if ((item.url ?? '').length > 0) {
      this.showSearchSheet = false;
      await this.openExternal(item.url ?? '');
    }
  }

  private async openGoogleSearch(keywordText: string = this.searchText): Promise<void> {
    const keyword: string = keywordText.trim();
    if (keyword.length === 0) {
      return;
    }
    this.showSearchSheet = false;
    await this.openExternal('https://www.google.com/search?q=' +
    encodeURIComponent('site:umall.one OR site:um.edu.mo ' + keyword));
  }

  private titleForEvent(item: UmEventItem): string {
    const detail: UmEventDetail | undefined =
      InfoFeedService.findDetail<UmEventDetail>(item.details, this.preferredLocale());
    return detail?.title ?? this.localized('無標題活動', 'Untitled event');
  }

  private openEvent(item: UmEventItem): void {
    InfoNavigationState.setSelectedUmEvent(item);
    this.pathStack.pushPathByName(ROUTE_UM_EVENT_DETAIL, null);
  }

  private quickIconBackground(index: number): string {
    const colors: string[] = [
      this.theme().themeColorUltraLight,
      '#FFE1C7',
      '#D6F2DF',
      '#E4DCF8',
      '#D4EEF3'
    ];
    return colors[index % colors.length];
  }

  private formatCalendarDate(dateText: string): string {
    const parsed: Date = new Date(dateText);
    if (Number.isNaN(parsed.getTime())) {
      return dateText;
    }
    return parsed.getFullYear().toString() + '-' + pad2(parsed.getMonth() + 1) + '-' + pad2(parsed.getDate());
  }

  private formatCalendarShortDate(dateText: string): string {
    const parsed: Date = new Date(dateText);
    if (Number.isNaN(parsed.getTime())) {
      return '--.--';
    }
    return pad2(parsed.getMonth() + 1) + '.' + pad2(parsed.getDate());
  }

  private calendarYear(dateText: string): string {
    const parsed: Date = new Date(dateText);
    if (Number.isNaN(parsed.getTime())) {
      return '';
    }
    return parsed.getFullYear().toString();
  }

  private calendarWeekLabel(dateText: string): string {
    const parsed: Date = new Date(dateText);
    if (Number.isNaN(parsed.getTime())) {
      return '';
    }
    const dayIndex: number = parsed.getDay();
    const tc: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    const en: string[] = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return this.isEnglish() ? en[dayIndex] : tc[dayIndex];
  }

  private calendarRangeText(item: HomeCalendarItem): string {
    const startTimestamp: number = timestampOf(item.startDate);
    const endTimestamp: number = timestampOf(item.endDate);
    const oneDayMs: number = 24 * 60 * 60 * 1000;
    if (startTimestamp > 0 && endTimestamp - startTimestamp > oneDayMs) {
      return this.formatCalendarDate(item.startDate) + ' ~ ' +
      this.formatCalendarDate(new Date(endTimestamp - oneDayMs).toISOString()) + '\n';
    }
    return '';
  }

  private calendarSummaryText(item: HomeCalendarItem): string {
    if (this.isEnglish() || item.summaryCn.length === 0) {
      return item.summary;
    }
    return item.summary + '\n' + item.summaryCn;
  }

  private calendarIsEssential(item: HomeCalendarItem): boolean {
    const summary: string = item.summary.toUpperCase();
    return summary.includes('EXAM') || (summary.includes('SEMESTER') && !summary.includes('BREAK'));
  }

  @Builder
  HomeSearchBar(): void {
    Column() {
      Row() {
        Text(this.localized('搜索: 關於澳大的一切...', 'Search: everything about UM...'))
          .fontSize(14)
          .fontColor(this.theme().textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .height(40)
      .borderRadius(8)
      .backgroundColor(this.theme().surfaceColor)
      .border({ width: 1, color: this.theme().themeColor })
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.showSearchSheet = true;
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 2 })
  }

  @Builder
  SearchSheetContent(): void {
    Column() {
      Row() {
        AppSearchField({
          placeholder: this.localized('搜索澳大網頁或本地服務', 'Search UM pages or services'),
          value: this.searchText,
          onChange: (value: string): void => {
            this.updateSearch(value);
          },
          onSubmit: (value: string): void => {
            this.updateSearch(value);
            this.openGoogleSearch(value);
          }
        })
          .layoutWeight(1)

        Button(this.localized('搜索', 'Search'))
          .width(64)
          .height(38)
          .borderRadius(8)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(this.searchText.trim().length > 0 ? this.theme().themeColor : this.theme().disabledColor)
          .enabled(this.searchText.trim().length > 0)
          .margin({ left: 8 })
          .onClick(() => {
            this.openGoogleSearch();
          })
      }
      .width('100%')

      if (this.searchText.trim().length > 0) {
        AppCard({
          cardPadding: 0,
          content: (): void => {
            this.SearchResultContent();
          }
        })
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 18 })
  }

  @Builder
  SearchResultContent(): void {
    Column() {
      ForEach(this.featureResults, (item: ServiceFeatureItem, index: number) => {
        AppListItem({
          title: this.localized(item.titleTc, item.titleEn),
          subtitle: this.localized(item.descriptionTc, item.descriptionEn),
          clickable: true,
          showChevron: true,
          onTap: (): void => {
            this.openFeature(item);
          }
        })
      }, (item: ServiceFeatureItem) => item.key)
      AppListItem({
        title: this.localized('在澳大網頁搜索', 'Search UM websites'),
        subtitle: this.searchText,
        clickable: true,
        showChevron: true,
        showDivider: false,
        onTap: (): void => {
          this.openGoogleSearch();
        }
      })
    }
    .width('100%')
  }

  @Builder
  CalendarDateItem(item: HomeCalendarItem, index: number): void {
    Column() {
      Text(this.calendarYear(item.startDate))
        .fontSize(8)
        .fontColor(index === this.selectedCalendarIndex ? this.theme().themeColor : this.theme().textTertiary)
        .fontWeight(index === this.selectedCalendarIndex ? FontWeight.Bold : FontWeight.Regular)
        .maxLines(1)
      Text(this.formatCalendarShortDate(item.startDate))
        .fontSize(12)
        .fontColor(index === this.selectedCalendarIndex ? this.theme().themeColor : this.theme().textTertiary)
        .fontWeight(index === this.selectedCalendarIndex ? FontWeight.Bold : FontWeight.Regular)
        .maxLines(1)
      Text(this.calendarWeekLabel(item.startDate))
        .fontSize(8)
        .fontColor(index === this.selectedCalendarIndex ? this.theme().themeColor : this.theme().textTertiary)
        .fontWeight(index === this.selectedCalendarIndex ? FontWeight.Bold : FontWeight.Regular)
        .maxLines(1)
    }
    .width(50)
    .height(54)
    .padding({ left: 5, right: 5, top: 4, bottom: 4 })
    .margin(3)
    .borderRadius(5)
    .backgroundColor(index === this.selectedCalendarIndex ? this.theme().themeColorUltraLight : Color.Transparent)
    .border({ width: index === this.selectedCalendarIndex ? 1 : 0, color: this.theme().themeColorUltraLight })
    .opacity(index !== this.selectedCalendarIndex && !this.theme().isLight ? 0.5 : 1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.selectCalendarIndex(index);
    })
  }

  @Builder
  CalendarSummary(): void {
    if (this.calendarItems.length > this.selectedCalendarIndex) {
      Row() {
        Text('<')
          .fontSize(16)
          .fontColor(this.canSelectCalendarOffset(-1) ? this.theme().themeColor : this.theme().textTertiary)
          .width(20)
          .textAlign(TextAlign.Center)
          .opacity(this.canSelectCalendarOffset(-1) ? 1 : 0.35)
          .onClick(() => {
            this.selectCalendarOffset(-1);
          })
        Column() {
          Text(this.localized('校曆 Upcoming:', 'Calendar Upcoming:') + '\n' +
          this.calendarRangeText(this.calendarItems[this.selectedCalendarIndex]) +
          this.calendarSummaryText(this.calendarItems[this.selectedCalendarIndex]))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme().themeColor)
            .textAlign(TextAlign.Center)
            .lineHeight(18)
            .width('100%')
        }
        .width('80%')
        .constraintSize({ maxWidth: 430, minWidth: 280 })
        .padding({ left: 6, right: 6, top: 5, bottom: 5 })
        .borderRadius(10)
        .backgroundColor(this.theme().themeColorUltraLight)
        .border({ width: 1, color: this.theme().themeColorUltraLight })
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal })
            .onActionEnd((event: GestureEvent): void => {
              const offsetX: number = event.offsetX ?? 0;
              if (offsetX > 36) {
                this.selectCalendarOffset(-1);
              } else if (offsetX < -36) {
                this.selectCalendarOffset(1);
              }
            })
        )

        Text('>')
          .fontSize(16)
          .fontColor(this.canSelectCalendarOffset(1) ? this.theme().themeColor : this.theme().textTertiary)
          .width(20)
          .textAlign(TextAlign.Center)
          .opacity(this.canSelectCalendarOffset(1) ? 1 : 0.35)
          .onClick(() => {
            this.selectCalendarOffset(1);
          })
      }
      .width('100%')
      .margin({ top: 5 })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  CalendarBar(): void {
    if (this.calendarItems.length > 0) {
      Column() {
        Scroll(this.calendarScroller) {
          Row() {
            Text('')
              .width(20)
            ForEach(this.calendarItems, (item: HomeCalendarItem, index: number) => {
              Stack({ alignContent: Alignment.TopEnd }) {
                this.CalendarDateItem(item, index)
                if (this.calendarIsEssential(item)) {
                  Circle()
                    .width(8)
                    .height(8)
                    .fill(this.theme().warningColor)
                    .margin({ top: 3, right: 1 })
                }
              }
            }, (item: HomeCalendarItem, index: number) => item.startDate + item.summary + index.toString())
            Text('')
              .width(20)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .onAppear(() => {
          this.scrollCalendarToSelection();
        })

        this.CalendarSummary()
      }
      .width('100%')
      .margin({ top: 5, bottom: 4 })
    } else if (this.calendarError.length > 0) {
      Text(this.calendarError)
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 6, bottom: 6 })
    }
  }

  @Builder
  UpcomingCourseCard(): void {
    AppCard({
      clickable: true,
      surfaceColor: this.hasUpcomingCourse ? this.theme().themeColorUltraLight : this.theme().surfaceAltColor,
      onTap: (): void => {
        this.currentTabIndex = ROOT_TAB_TIMETABLE;
      },
      content: (): void => {
        this.UpcomingCourseContent();
      }
    })
    .margin({ left: 16, right: 16, top: 3, bottom: 10 })
  }

  @Builder
  UpcomingCourseContent(): void {
    Row() {
      Text(this.hasUpcomingCourse ? this.localized('下節課', 'Next class') :
      this.localized('接下來無課程', 'No upcoming class'))
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
        .layoutWeight(1)
      if (this.hasUpcomingCourse) {
        Text(this.upcomingCourse.courseCode + ' ' + this.upcomingCourse.timeFrom)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().themeColor)
      } else {
        Text(this.localized('查看課表', 'Open timetable'))
          .fontSize(13)
          .fontColor(this.theme().textTertiary)
      }
    }
    .width('100%')
  }

  @Builder
  QuickAction(label: string, iconText: string, index: number, action: () => void, symbol?: Resource): void {
    Column() {
      Stack() {
        if (symbol !== undefined) {
          SymbolGlyph(symbol)
            .fontSize(23)
            .fontColor([this.theme().themeColor])
        } else {
          Text(iconText)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().themeColor)
            .textAlign(TextAlign.Center)
        }
      }
      .width(38)
      .height(38)
      .borderRadius(8)
      .backgroundColor(this.quickIconBackground(index))
      Text(label)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme().themeColor)
        .maxLines(2)
        .textAlign(TextAlign.Center)
        .margin({ top: 5 })
        .width('100%')
    }
    .width('20%')
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      action();
    })
  }

  @Builder
  QuickActions(): void {
    AppCard({
      content: (): void => {
        this.QuickActionsContent();
      }
    })
    .margin({ left: 16, right: 16, bottom: 12 })
  }

  @Builder
  QuickActionsContent(): void {
    Row() {
      this.QuickAction(this.localized('校巴', 'Bus'), '巴', 0, (): void => {
        this.pathStack.pushPathByName(ROUTE_BUS, null);
      }, $r('sys.symbol.bus_fill'))
      this.QuickAction('Moodle', 'M', 1, (): void => {
        this.openExternal(UM_MOODLE);
      })
      this.QuickAction(this.localized('新想法', 'New'), '+', 2, (): void => {
        this.openExternal(ARK_HARBOR_NEW_TOPIC);
      })
      this.QuickAction(this.localized('支持', 'Donate'), '$', 3, (): void => {
        this.openExternal(AFD_UMACARK);
      })
      this.QuickAction(this.localized('登入', 'Login'), 'In', 4, (): void => {
        this.openExternal(ARK_HARBOR_LOGIN);
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  SectionTitle(title: string, actionText: string, action: () => void): void {
    Row() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textTertiary)
        .layoutWeight(1)
      if (actionText.length > 0) {
        Button(actionText)
          .height(30)
          .borderRadius(8)
          .fontSize(12)
          .fontColor(this.theme().themeColor)
          .backgroundColor(this.theme().surfaceAltColor)
          .onClick(() => {
            action();
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .margin({ top: 8, bottom: 8 })
  }

  @Builder
  UpdateCard(): void {
    if (this.updateAvailable) {
      AppCard({
        content: (): void => {
          this.UpdateCardContent();
        }
      })
      .margin({ left: 16, right: 16, bottom: 12 })
    } else if (this.appInfoError.length > 0) {
      Text(this.appInfoError)
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
        .width('100%')
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 8 })
    }
  }

  @Builder
  UpdateCardContent(): void {
    Column() {
      Text(this.localized('新版本可用', 'Update available'))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().secondThemeColor)
        .width('100%')
      Text(this.localized('最新版本：', 'Latest: ') + this.latestVersion + ' / ' +
      this.localized('當前版本：', 'Current: ') + this.localVersion)
        .fontSize(13)
        .fontColor(this.theme().textSecondary)
        .lineHeight(19)
        .width('100%')
        .margin({ top: 6 })
      if (this.versionInfo.length > 0) {
        Text(this.versionInfo)
          .fontSize(13)
          .fontColor(this.theme().textTertiary)
          .lineHeight(19)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 6 })
      }
    }
    .width('100%')
  }

  @Builder
  EventPreviewRow(item: UmEventItem): void {
    AppCard({
      clickable: true,
      onTap: (): void => {
        this.openEvent(item);
      },
      content: (): void => {
        this.EventPreviewRowContent(item);
      }
    })
    .margin({ left: 16, right: 16, bottom: 10 })
  }

  @Builder
  EventPreviewRowContent(item: UmEventItem): void {
    Row() {
      Column() {
        Text(this.titleForEvent(item))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .lineHeight(20)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(InfoFeedService.formatEventTimeRange(item))
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .lineHeight(17)
          .margin({ top: 6 })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ right: item.common.posterUrl ? 12 : 0 })
      if (item.common.posterUrl) {
        AppNetworkImage({
          src: InfoFeedService.normalizeImageUrl(item.common.posterUrl),
          alt: this.localized('活動海報', 'Event poster'),
          imageHeight: 76,
          radius: 8
        })
        .width(76)
      }
    }
    .width('100%')
  }

  @Builder
  EventsPreview(): void {
    this.SectionTitle(this.localized('近期澳大活動', 'Upcoming UM Events'), this.localized('校曆', 'Calendar'), (): void => {
      this.openExternal(UM_CALENDAR);
    })
    if (this.eventError.length > 0) {
      AppCard({
        content: (): void => {
          this.EventErrorContent();
        }
      })
      .margin({ left: 16, right: 16, bottom: 14 })
    } else {
      ForEach(this.eventPreview, (item: UmEventItem) => {
        this.EventPreviewRow(item);
      }, (item: UmEventItem, index: number) => item._id + index.toString())
    }
  }

  @Builder
  EventErrorContent(): void {
    Text(this.eventError)
      .fontSize(13)
      .fontColor(this.theme().textTertiary)
      .lineHeight(19)
      .width('100%')
  }

  @Builder
  FooterActions(): void {
    AppCard({
      cardPadding: 0,
      content: (): void => {
        this.FooterActionsContent();
      }
    })
    .margin({ left: 16, right: 16, top: 4, bottom: 26 })
  }

  @Builder
  FooterActionsContent(): void {
    Column() {
      AppListItem({
        title: this.localized('聯絡我們', 'Contact us'),
        subtitle: ARK_SUPPORT_MAIL,
        clickable: true,
        showChevron: true,
        showDivider: false,
        onTap: (): void => {
          this.openExternal('mailto:' + ARK_SUPPORT_MAIL);
        }
      })
    }
    .width('100%')
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          this.topContent()
          if (this.loading) {
            Column() {
              AppLoading({
                title: this.localized('正在整理首頁', 'Loading home'),
                compact: false
              })
            }
            .height(360)
            .justifyContent(FlexAlign.Center)
            .padding({ left: 18, right: 18 })
          } else {
            this.HomeSearchBar()
            this.CalendarBar()
            this.UpcomingCourseCard()
            this.QuickActions()
            this.UpdateCard()
            this.EventsPreview()
            this.FooterActions()
          }
          Blank()
            .height(ROOT_CONTENT_BOTTOM_PADDING)
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bgColor)
    .bindSheet($$this.showSearchSheet, this.SearchSheetContent(), {
      height: SheetSize.MEDIUM,
      mode: SheetMode.OVERLAY,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      title: {
        title: this.localized('搜索', 'Search')
      },
      backgroundColor: this.theme().bgColor,
      showClose: true
    })
  }
}
