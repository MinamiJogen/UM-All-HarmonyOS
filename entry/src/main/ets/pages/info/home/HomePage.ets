import { common } from '@kit.AbilityKit';
import {
  AFD_UMACARK,
  ARK_HARBOR_LOGIN,
  ARK_HARBOR_NEW_TOPIC,
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
  ROUTE_EVENT_DETAIL,
  ROUTE_WEBVIEWER
} from '../../../common/constants/RouteNames';
import { ROOT_CONTENT_BOTTOM_PADDING } from '../../../common/constants/LayoutMetrics';
import { ROOT_TAB_TIMETABLE } from '../../../common/constants/TabIndexes';
import { ClubNavigationState } from '../../../common/navigation/ClubNavigationState';
import {
  INFO_TOP_TAB_HOME,
  InfoRefreshHandler,
  InfoRefreshRegistry
} from '../../../common/navigation/InfoRefreshRegistry';
import { WebNavigationState } from '../../../common/navigation/WebNavigationState';
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
import { AppInfoService } from '../../../services/AppInfoService';
import { AnalyticsParams, AnalyticsService } from '../../../services/AnalyticsService';
import { ClubService } from '../../../services/ClubService';
import {
  HarborTopic,
  HOME_FEED_KIND_HARBOR,
  HomeFeedItem,
  HomeFeedPage,
  HomeFeedService
} from '../../../services/HomeFeedService';
import { InfoFeedService } from '../../../services/InfoFeedService';
import { UmehHostService, UmehHostState } from '../../../services/UmehHostService';
import { TimetableHomeCacheItem } from '../../../models/Course';
import { ClubActivity } from '../../../models/Event';
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

const HOME_FEED_PAGE_SIZE: number = 10;
const HOME_LAYOUT_BREAKPOINT_MD: number = 600;
const HOME_LAYOUT_BREAKPOINT_LG: number = 840;
const HOME_LAYOUT_GAP: number = 12;
const HOME_CARD_VERTICAL_PADDING: number = 28;
const HOME_UPCOMING_PANEL_WIDTH: number = 210;
const HOME_UPDATE_PANEL_WIDTH: number = 300;
const HOME_UPDATE_PANEL_WIDE_WIDTH: number = 360;
const HOME_WATERFALL_MIN_COLUMNS: number = 2;
const HOME_WATERFALL_COLUMN_GAP: number = 10;
const HOME_WATERFALL_ROW_GAP: number = 12;
const HOME_WATERFALL_PREFERRED_ITEM_WIDTH: number = 176;
const HOME_EVENT_IMAGE_HEIGHT: number = 126;
const HOME_HARBOR_AVATAR_SIZE: number = 18;
const HARMONYOS_BETA_FEEDBACK_URL: string = '';

@Component
export struct HomePage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @Consume('appCurrentTabIndex') currentTabIndex: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State loading: boolean = true;
  @State localVersion: string = '';
  @State hasUpcomingCourse: boolean = false;
  @State upcomingCourse: TimetableHomeCacheItem = emptyHomeCourse();
  @State calendarItems: HomeCalendarItem[] = [];
  @State selectedCalendarIndex: number = 0;
  @State calendarError: string = '';
  @State searchText: string = '';
  @State showSearchSheet: boolean = false;
  @State featureResults: ServiceFeatureItem[] = [];
  @State homeFeedItems: HomeFeedItem[] = [];
  @State homeFeedPage: number = 1;
  @State homeFeedNoMore: boolean = false;
  @State homeFeedLoading: boolean = false;
  @State homeFeedError: string = '';
  @State private pageViewportWidth: number = 0;
  @State private waterfallWidth: number = 0;
  @State private upcomingPanelContentHeight: number = 20;
  @State private quickActionsPanelContentHeight: number = 66;
  @State private updatePanelContentHeight: number = 100;
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
    await this.reloadUpcomingCourse();
    await this.loadCalendar();
    this.localVersion = await AppInfoService.getLocalVersion();

    await this.refreshHomeFeed();

    this.loading = false;
    if (showToast) {
      AppToast.show(this.getUIContext(), this.localized('首頁已刷新', 'Home refreshed'), AppToastType.Success);
    }
  }

  private async refreshHomeFeed(): Promise<void> {
    this.homeFeedLoading = true;
    this.homeFeedError = '';
    this.homeFeedPage = 1;
    this.homeFeedNoMore = false;
    this.homeFeedItems = [];
    const result: ServiceResult<HomeFeedPage> = await HomeFeedService.fetchFirstPage(HOME_FEED_PAGE_SIZE);
    if (result.ok && result.data) {
      this.homeFeedPage = result.data.page;
      this.homeFeedNoMore = result.data.noMore;
      this.homeFeedItems = result.data.items;
    } else {
      this.homeFeedError = result.error?.message ?? this.localized('動態資料讀取失敗', 'Failed to load feed');
      this.homeFeedNoMore = true;
    }
    this.homeFeedLoading = false;
  }

  private async loadMoreHomeFeed(): Promise<void> {
    if (this.loading || this.homeFeedLoading || this.homeFeedNoMore) {
      return;
    }
    this.homeFeedLoading = true;
    this.homeFeedError = '';
    const targetPage: number = this.homeFeedPage + 1;
    const result: ServiceResult<HomeFeedPage> = await HomeFeedService.fetchNextPage(targetPage, HOME_FEED_PAGE_SIZE);
    if (result.ok && result.data) {
      this.homeFeedPage = result.data.page;
      this.homeFeedNoMore = result.data.noMore || result.data.items.length === 0;
      this.homeFeedItems = this.appendHomeFeedItems(result.data.items);
    } else {
      this.homeFeedError = result.error?.message ?? this.localized('更多動態讀取失敗', 'Failed to load more feed');
      AppToast.showError(this.getUIContext(), this.homeFeedError);
    }
    this.homeFeedLoading = false;
  }

  private appendHomeFeedItems(items: HomeFeedItem[]): HomeFeedItem[] {
    const result: HomeFeedItem[] = [];
    for (let i = 0; i < this.homeFeedItems.length; i++) {
      result.push(this.homeFeedItems[i]);
    }
    for (let i = 0; i < items.length; i++) {
      let exists: boolean = false;
      for (let j = 0; j < result.length; j++) {
        if (result[j].key === items[i].key) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        result.push(items[i]);
      }
    }
    return result;
  }

  private async openExternal(url: string): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), url);
    if (!success) {
      AppToast.showError(this.getUIContext(), this.localized('無法打開鏈接', 'Unable to open link'));
    }
  }

  private async openHarmonyOsBetaFeedback(): Promise<void> {
    if (HARMONYOS_BETA_FEEDBACK_URL.length === 0) {
      AppToast.show(this.getUIContext(), this.localized('暫未開放', 'Not available yet'), AppToastType.Info);
      return;
    }
    await this.openExternal(HARMONYOS_BETA_FEEDBACK_URL);
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

  private openClubActivity(event: ClubActivity): void {
    if ((event.type ?? '') === 'WEBSITE' && (event.link ?? '').length > 0) {
      WebNavigationState.setLink({
        url: event.link ?? '',
        title: event.title ?? this.localized('網頁', 'Web')
      });
      this.pathStack.pushPathByName(ROUTE_WEBVIEWER, null);
      return;
    }
    ClubNavigationState.setSelectedEvent(event);
    this.pathStack.pushPathByName(ROUTE_EVENT_DETAIL, null);
  }

  private async openHarborTopic(topic: HarborTopic): Promise<void> {
    const url: string = HomeFeedService.harborTopicUrl(topic);
    if (url.length === 0) {
      return;
    }
    await this.openExternal(url);
  }

  private lengthToNumber(value: Length): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value);
      return Number.isFinite(parsed) ? parsed : 0;
    }
    return 0;
  }

  private updateWaterfallWidth(value: Length): void {
    const nextWidth = this.lengthToNumber(value);
    if (nextWidth <= 0) {
      return;
    }
    if (Math.abs(nextWidth - this.waterfallWidth) >= 1) {
      this.waterfallWidth = nextWidth;
    }
  }

  private updatePageViewportWidth(value: Length): void {
    const nextWidth: number = this.lengthToNumber(value);
    if (nextWidth > 0 && Math.abs(nextWidth - this.pageViewportWidth) >= 1) {
      this.pageViewportWidth = nextWidth;
    }
  }

  private isPhoneLayout(): boolean {
    return this.pageViewportWidth <= 0 || this.pageViewportWidth < HOME_LAYOUT_BREAKPOINT_MD;
  }

  private isFoldLayout(): boolean {
    return this.pageViewportWidth >= HOME_LAYOUT_BREAKPOINT_MD &&
      this.pageViewportWidth < HOME_LAYOUT_BREAKPOINT_LG;
  }

  private updatePanelWidth(): number {
    return this.pageViewportWidth >= 1000 ? HOME_UPDATE_PANEL_WIDE_WIDTH : HOME_UPDATE_PANEL_WIDTH;
  }

  private resolveMeasuredContentHeight(value: Length, current: number): number {
    const nextHeight: number = this.lengthToNumber(value);
    if (nextHeight <= 0 || Math.abs(nextHeight - current) < 1) {
      return current;
    }
    return nextHeight;
  }

  private updateUpcomingPanelContentHeight(value: Length): void {
    this.upcomingPanelContentHeight = this.resolveMeasuredContentHeight(value, this.upcomingPanelContentHeight);
  }

  private updateQuickActionsPanelContentHeight(value: Length): void {
    this.quickActionsPanelContentHeight =
      this.resolveMeasuredContentHeight(value, this.quickActionsPanelContentHeight);
  }

  private updateUpdatePanelContentHeight(value: Length): void {
    this.updatePanelContentHeight = this.resolveMeasuredContentHeight(value, this.updatePanelContentHeight);
  }

  private panelHeight(contentHeight: number): number {
    return contentHeight + HOME_CARD_VERTICAL_PADDING;
  }

  private foldTopCardsRowHeight(): number {
    return Math.max(
      this.panelHeight(this.upcomingPanelContentHeight),
      this.panelHeight(this.quickActionsPanelContentHeight)
    );
  }

  private expandedCardsRowHeight(): number {
    return Math.max(
      this.panelHeight(this.upcomingPanelContentHeight),
      this.panelHeight(this.quickActionsPanelContentHeight),
      this.panelHeight(this.updatePanelContentHeight)
    );
  }

  private itemWidthForColumns(width: number, columns: number): number {
    if (columns <= 0) {
      return width;
    }
    return (width - HOME_WATERFALL_COLUMN_GAP * (columns - 1)) / columns;
  }

  private waterfallColumnCount(): number {
    if (this.waterfallWidth <= 0) {
      return HOME_WATERFALL_MIN_COLUMNS;
    }
    let bestColumns = HOME_WATERFALL_MIN_COLUMNS;
    let bestDistance = Math.abs(this.itemWidthForColumns(this.waterfallWidth, bestColumns) -
      HOME_WATERFALL_PREFERRED_ITEM_WIDTH);
    const widestUsefulColumns = Math.max(
      HOME_WATERFALL_MIN_COLUMNS,
      Math.ceil((this.waterfallWidth + HOME_WATERFALL_COLUMN_GAP) /
        (HOME_WATERFALL_PREFERRED_ITEM_WIDTH + HOME_WATERFALL_COLUMN_GAP)) + 1
    );
    for (let columns = HOME_WATERFALL_MIN_COLUMNS + 1; columns <= widestUsefulColumns; columns++) {
      const distance = Math.abs(this.itemWidthForColumns(this.waterfallWidth, columns) -
        HOME_WATERFALL_PREFERRED_ITEM_WIDTH);
      if (distance < bestDistance) {
        bestColumns = columns;
        bestDistance = distance;
      }
    }
    return bestColumns;
  }

  private waterfallColumnIndexes(): number[] {
    const columns = this.waterfallColumnCount();
    const indexes: number[] = [];
    for (let index = 0; index < columns; index++) {
      indexes.push(index);
    }
    return indexes;
  }

  private homeFeedItemsForColumn(targetColumn: number): HomeFeedItem[] {
    const columns = this.waterfallColumnCount();
    const result: HomeFeedItem[] = [];
    for (let index = 0; index < this.homeFeedItems.length; index++) {
      if (index % columns === targetColumn) {
        result.push(this.homeFeedItems[index]);
      }
    }
    return result;
  }

  private eventBadgeText(event: ClubActivity): string {
    if ((event.type ?? '') === 'WEBSITE') {
      return 'WEB';
    }
    if (ClubService.eventIsPast(event)) {
      return this.localized('已過', 'Past');
    }
    if (ClubService.eventIsAlmostEnd(event)) {
      return this.localized('將結束', 'Ending');
    }
    return this.localized('進行中', 'Active');
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
  UpcomingCoursePanel(targetHeight: number): void {
    if (targetHeight > 0) {
      AppCard({
        clickable: true,
        contentJustifyContent: FlexAlign.Center,
        surfaceColor: this.hasUpcomingCourse ? this.theme().themeColorUltraLight : this.theme().surfaceAltColor,
        onTap: (): void => {
          this.currentTabIndex = ROOT_TAB_TIMETABLE;
        },
        content: (): void => {
          this.UpcomingCourseContent();
        }
      })
      .height(targetHeight)
    } else {
      AppCard({
        clickable: true,
        contentJustifyContent: FlexAlign.Center,
        surfaceColor: this.hasUpcomingCourse ? this.theme().themeColorUltraLight : this.theme().surfaceAltColor,
        onTap: (): void => {
          this.currentTabIndex = ROOT_TAB_TIMETABLE;
        },
        content: (): void => {
          this.UpcomingCourseContent();
        }
      })
    }
  }

  @Builder
  UpcomingCourseCard(): void {
    Column() {
      this.UpcomingCoursePanel(0)
    }
    .width('100%')
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
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      if (this.hasUpcomingCourse) {
        Text(this.upcomingCourse.courseCode + ' ' + this.upcomingCourse.timeFrom)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().themeColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        Text(this.localized('查看課表', 'Open timetable'))
          .fontSize(13)
          .fontColor(this.theme().textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateUpcomingPanelContentHeight(newValue.height);
    })
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
  QuickActionsPanel(targetHeight: number): void {
    if (targetHeight > 0) {
      AppCard({
        contentJustifyContent: FlexAlign.Center,
        content: (): void => {
          this.QuickActionsContent();
        }
      })
      .height(targetHeight)
    } else {
      AppCard({
        contentJustifyContent: FlexAlign.Center,
        content: (): void => {
          this.QuickActionsContent();
        }
      })
    }
  }

  @Builder
  QuickActions(): void {
    Column() {
      this.QuickActionsPanel(0)
    }
    .width('100%')
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
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateQuickActionsPanelContentHeight(newValue.height);
    })
  }

  @Builder
  UpdatePanel(targetHeight: number): void {
    if (targetHeight > 0) {
      AppCard({
        content: (): void => {
          this.UpdateCardContent();
        }
      })
      .height(targetHeight)
    } else {
      AppCard({
        content: (): void => {
          this.UpdateCardContent();
        }
      })
    }
  }

  @Builder
  UpdateCard(): void {
    Column() {
      this.UpdatePanel(0)
    }
    .width('100%')
    .margin({ left: 16, right: 16, bottom: 12 })
  }

  @Builder
  UpdateCardContent(): void {
    Column() {
      Row() {
        Text(this.localized('HarmonyOS 內測版本', 'HarmonyOS Beta Version'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().secondThemeColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Button(this.localized('點擊反饋', 'Send Feedback'))
          .height(28)
          .borderRadius(8)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(this.theme().themeColor)
          .padding({ left: 8, right: 8 })
          .margin({ left: 8 })
          .onClick(() => {
            this.openHarmonyOsBetaFeedback();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text(this.localized('當前版本號：', 'Current version: ') + (this.localVersion.length > 0 ? this.localVersion : '-'))
        .fontSize(12)
        .fontColor(this.theme().textSecondary)
        .lineHeight(16)
        .width('100%')
        .margin({ top: 4 })
      Text(this.localized('當前版本為 HarmonyOS 內測版本，適配 HarmonyOS 6.1.0 及更新系統。\n' +
      '內測版本可能存在功能不完整/Bug，可點擊後在 GitHub 的 Issue 進行反饋。',
        'HarmonyOS beta for HarmonyOS 6.1.0 and later.\n' +
        'Beta features may be incomplete or buggy. Tap to report via GitHub Issues.'))
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
        .lineHeight(16)
        .width('100%')
        .margin({ top: 4 })
    }
    .width('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateUpdatePanelContentHeight(newValue.height);
    })
  }

  @Builder
  ResponsiveHomeCardsLayout(): void {
    if (this.isPhoneLayout()) {
      Column({ space: HOME_LAYOUT_GAP }) {
        this.UpcomingCoursePanel(0)
        this.QuickActionsPanel(0)
        this.UpdatePanel(0)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .margin({ top: 3, bottom: 12 })
    } else if (this.isFoldLayout()) {
      Column({ space: HOME_LAYOUT_GAP }) {
        Row({ space: HOME_LAYOUT_GAP }) {
          Column() {
            this.UpcomingCoursePanel(this.foldTopCardsRowHeight())
          }
          .width(HOME_UPCOMING_PANEL_WIDTH)

          Column() {
            this.QuickActionsPanel(this.foldTopCardsRowHeight())
          }
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        this.UpdatePanel(0)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .margin({ top: 3, bottom: 12 })
    } else {
      Row({ space: HOME_LAYOUT_GAP }) {
        Column() {
          this.UpcomingCoursePanel(this.expandedCardsRowHeight())
        }
        .width(HOME_UPCOMING_PANEL_WIDTH)

        Column() {
          this.QuickActionsPanel(this.expandedCardsRowHeight())
        }
        .layoutWeight(1)

        Column() {
          this.UpdatePanel(this.expandedCardsRowHeight())
        }
        .width(this.updatePanelWidth())
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: 16, right: 16 })
      .margin({ top: 3, bottom: 12 })
    }
  }

  @Builder
  FeedCard(item: HomeFeedItem): void {
    if (item.kind === HOME_FEED_KIND_HARBOR && item.harbor) {
      this.HarborCard(item.harbor);
    } else if (item.event) {
      this.HomeFeedEventCard(item.event);
    }
  }

  @Builder
  HomeFeedEventCard(event: ClubActivity): void {
    AppCard({
      clickable: true,
      cardPadding: 0,
      onTap: (): void => {
        this.openClubActivity(event);
      },
      content: (): void => {
        this.HomeFeedEventCardContent(event);
      }
    })
  }

  @Builder
  HomeFeedEventCardContent(event: ClubActivity): void {
    Column() {
      if ((event.cover_image_url ?? '').length > 0) {
        AppNetworkImage({
          src: event.cover_image_url ?? '',
          alt: event.title ?? '',
          imageHeight: HOME_EVENT_IMAGE_HEIGHT,
          radius: 8
        })
        .width('100%')
      }

      Column() {
        Text(event.title ?? this.localized('未命名活動', 'Untitled event'))
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(ClubService.eventIsPast(event) ? this.theme().textTertiary : this.theme().textPrimary)
          .lineHeight(18)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row() {
          this.HomeFeedEventBadge(event)
          Text(event.club_name ?? '')
            .fontSize(11)
            .fontColor(this.theme().textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 5 })
        }
        .width('100%')
        .margin({ top: 7 })

        Text(ClubService.formatEventRange(event))
          .fontSize(11)
          .fontColor(this.theme().textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 5 })
      }
      .width('100%')
      .padding(10)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  HomeFeedEventBadge(event: ClubActivity): void {
    Text(this.eventBadgeText(event))
      .fontSize(10)
      .fontWeight(FontWeight.Bold)
      .fontColor(ClubService.eventIsPast(event) ? this.theme().textTertiary : this.theme().secondThemeColor)
      .padding({ left: 6, right: 6, top: 3, bottom: 3 })
      .borderRadius(8)
      .backgroundColor(this.theme().surfaceAltColor)
  }

  @Builder
  HarborCard(topic: HarborTopic): void {
    AppCard({
      clickable: true,
      cardPadding: 0,
      surfaceColor: this.theme().themeColorUltraLight,
      onTap: (): void => {
        this.openHarborTopic(topic);
      },
      content: (): void => {
        this.HarborCardContent(topic);
      }
    })
  }

  @Builder
  HarborCardContent(topic: HarborTopic): void {
    Column() {
      if (HomeFeedService.harborExcerpt(topic).length > 0) {
        Text(HomeFeedService.harborExcerpt(topic))
          .fontSize(12)
          .fontColor(this.theme().themeColor)
          .lineHeight(17)
          .maxLines(5)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 10, right: 10, top: 12, bottom: 6 })
      }

      Column() {
        Text(HomeFeedService.harborTitle(topic))
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .lineHeight(18)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row() {
          AppNetworkImage({
            src: HomeFeedService.harborAvatar(topic),
            alt: HomeFeedService.harborAuthor(topic),
            imageHeight: HOME_HARBOR_AVATAR_SIZE,
            radius: HOME_HARBOR_AVATAR_SIZE / 2
          })
          .width(HOME_HARBOR_AVATAR_SIZE)
          Text(HomeFeedService.harborAuthor(topic))
            .fontSize(10)
            .fontColor(this.theme().textTertiary)
            .fontStyle(FontStyle.Italic)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 5 })
          Text((topic.like_count ?? 0).toString() + ' / ' + (topic.highest_post_number ?? 0).toString() +
          ' / ' + (topic.views ?? 0).toString())
            .fontSize(10)
            .fontColor(this.theme().textTertiary)
            .maxLines(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 8 })
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 9, bottom: 10 })
      .borderRadius(8)
      .backgroundColor(this.theme().surfaceColor)
    }
    .width('100%')
  }

  @Builder
  HomeFeedWaterfall(): void {
    if (this.homeFeedError.length > 0 && this.homeFeedItems.length === 0) {
      AppCard({
        content: (): void => {
          this.HomeFeedErrorContent();
        }
      })
      .margin({ left: 16, right: 16, top: 2, bottom: 14 })
    } else if (this.homeFeedItems.length > 0) {
      Column() {
        Row({ space: HOME_WATERFALL_COLUMN_GAP }) {
          ForEach(this.waterfallColumnIndexes(), (columnIndex: number) => {
            this.HomeFeedColumn(columnIndex);
          }, (columnIndex: number) => columnIndex.toString())
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.updateWaterfallWidth(newValue.width);
        })
        this.HomeFeedFooter()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 2 })
    }
  }

  @Builder
  HomeFeedColumn(columnIndex: number): void {
    Column({ space: HOME_WATERFALL_ROW_GAP }) {
      ForEach(this.homeFeedItemsForColumn(columnIndex), (item: HomeFeedItem) => {
        this.FeedCard(item);
      }, (item: HomeFeedItem) => item.key)
    }
    .layoutWeight(1)
  }

  @Builder
  HomeFeedErrorContent(): void {
    Column() {
      Text(this.homeFeedError)
        .fontSize(13)
        .fontColor(this.theme().textTertiary)
        .lineHeight(19)
        .width('100%')
      Button(this.localized('重試', 'Retry'))
        .height(34)
        .borderRadius(8)
        .fontSize(12)
        .fontColor(Color.White)
        .backgroundColor(this.theme().themeColor)
        .margin({ top: 10 })
        .onClick(() => {
          this.refreshHomeFeed();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  HomeFeedFooter(): void {
    Column() {
      if (this.homeFeedLoading) {
        LoadingProgress()
          .width(24)
          .height(24)
          .color(this.theme().themeColor)
          .margin({ top: 14, bottom: 8 })
        Text(this.localized('載入中', 'Loading'))
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
      } else if (this.homeFeedError.length > 0) {
        Text(this.homeFeedError)
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .textAlign(TextAlign.Center)
          .margin({ top: 12, bottom: 8 })
        Button(this.localized('重試', 'Retry'))
          .height(34)
          .borderRadius(8)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor(this.theme().themeColor)
          .onClick(() => {
            this.loadMoreHomeFeed();
          })
      } else if (this.homeFeedNoMore) {
        Text(this.localized('沒有更多內容了', 'No more content'))
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .margin({ top: 14, bottom: 4 })
      } else {
        Button(this.localized('載入更多', 'Load more'))
          .height(36)
          .borderRadius(8)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor(this.theme().themeColor)
          .margin({ top: 14, bottom: 4 })
          .onClick(() => {
            this.loadMoreHomeFeed();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: 20 })
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
            this.ResponsiveHomeCardsLayout()
            this.HomeFeedWaterfall()
          }
          Blank()
            .height(ROOT_CONTENT_BOTTOM_PADDING)
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.updatePageViewportWidth(newValue.width);
        })
      }
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring)
      .onReachEnd(() => {
        this.loadMoreHomeFeed();
      })
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
