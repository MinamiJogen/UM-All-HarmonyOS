import { InfoNavigationState } from '../../common/navigation/InfoNavigationState';
import {
  INFO_TOP_TAB_EVENT,
  InfoRefreshHandler,
  InfoRefreshRegistry
} from '../../common/navigation/InfoRefreshRegistry';
import { ServiceResult } from '../../common/net/HttpClient';
import { I18nService, LANGUAGE_EN } from '../../common/i18n/I18nService';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../../common/theme/AppTheme';
import { AppCard } from '../../components/AppCard';
import { AppEmptyState } from '../../components/AppEmptyState';
import { AppLoading } from '../../components/AppLoading';
import { AppNetworkImage } from '../../components/AppNetworkImage';
import { AppToast, AppToastType } from '../../components/AppToast';
import { ROOT_CONTENT_BOTTOM_PADDING } from '../../common/constants/LayoutMetrics';
import { ROUTE_UM_EVENT_DETAIL } from '../../common/constants/RouteNames';
import { InfoFeedService } from '../../services/InfoFeedService';
import { AnalyticsParams, AnalyticsService } from '../../services/AnalyticsService';
import {
  UmEventDetail,
  UmEventItem
} from '../../models/Event';
import {
  OPEN_DATA_LOCALE_EN_US,
  OPEN_DATA_LOCALE_ZH_TW
} from '../../models/News';

const EVENT_WATERFALL_MIN_COLUMNS: number = 2;
const EVENT_WATERFALL_COLUMN_GAP: number = 10;
const EVENT_WATERFALL_ROW_GAP: number = 12;
const EVENT_WATERFALL_PREFERRED_ITEM_WIDTH: number = 182;
const EVENT_CARD_POSTER_HEIGHT: number = 116;

@Component
export struct UMEventPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State events: UmEventItem[] = [];
  @State private waterfallWidth: number = 0;
  @BuilderParam topContent: () => void = this.EmptySlot;
  private loaded: boolean = false;
  private refreshHandler: InfoRefreshHandler = (): void => {
    this.refresh(true);
  };

  @Builder
  private EmptySlot(): void {
  }

  aboutToAppear(): void {
    InfoRefreshRegistry.register(INFO_TOP_TAB_EVENT, this.refreshHandler);
    const params: AnalyticsParams = new AnalyticsParams();
    params.routeName = 'UMEvent';
    AnalyticsService.log('openPage', params);
    if (!this.loaded) {
      this.loaded = true;
      this.refresh(false);
    }
  }

  aboutToDisappear(): void {
    InfoRefreshRegistry.unregister(INFO_TOP_TAB_EVENT, this.refreshHandler);
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

  private compactStringLines(value: string): string {
    const lines: string[] = value.split('\n');
    const result: string[] = [];
    for (let index = 0; index < lines.length; index++) {
      const line: string = lines[index].trim();
      if (line.length > 0) {
        result.push(line);
      }
    }
    return result.join('\n');
  }

  private compactLines(value: string | string[] | undefined | null): string {
    if (value === undefined || value === null) {
      return '';
    }
    if (typeof value === 'string') {
      return this.compactStringLines(value);
    }
    if (Array.isArray(value)) {
      const result: string[] = [];
      for (let index = 0; index < value.length; index++) {
        const rawValue = value[index];
        if (typeof rawValue === 'string') {
          const line: string = this.compactStringLines(rawValue);
          if (line.length > 0) {
            result.push(line);
          }
        }
      }
      return result.join('\n');
    }
    return '';
  }

  private titleFor(item: UmEventItem): string {
    const detail: UmEventDetail | undefined =
      InfoFeedService.findDetail<UmEventDetail>(item.details, this.preferredLocale());
    const title: string = this.compactLines(detail?.title ?? '');
    return title.length > 0 ? title : this.localized('無標題活動', 'Untitled event');
  }

  private venueFor(item: UmEventItem): string {
    const detail: UmEventDetail | undefined =
      InfoFeedService.findDetail<UmEventDetail>(item.details, this.preferredLocale());
    return this.compactLines(detail?.venues ?? detail?.venue ?? '');
  }

  private dateLabelFor(item: UmEventItem): string {
    const dateText: string = this.compactLines(InfoFeedService.formatMonthDay(item.common.dateFrom));
    return dateText.length > 0 ? '@ ' + dateText : '';
  }

  private timeRangeFor(item: UmEventItem): string {
    return this.compactLines(InfoFeedService.formatEventTimeRange(item));
  }

  private eventIsPast(item: UmEventItem): boolean {
    const timestamp: number = InfoFeedService.eventDateTimestamp(item);
    return timestamp > 0 && timestamp < Date.now() - 24 * 60 * 60 * 1000;
  }

  private async refresh(showToast: boolean): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    const result: ServiceResult<UmEventItem[]> = await InfoFeedService.fetchUmEvents();
    if (result.ok && result.data) {
      this.events = result.data;
      if (showToast) {
        AppToast.show(this.getUIContext(), this.localized('活動已刷新', 'Events refreshed'), AppToastType.Success);
      }
    } else {
      this.errorMessage = result.error?.message ?? this.localized('澳大活動讀取失敗', 'Failed to load UM events');
      if (showToast) {
        AppToast.showError(this.getUIContext(), this.errorMessage);
      }
    }
    this.loading = false;
  }

  private openEvent(item: UmEventItem): void {
    if (item._id.length === 0) {
      return;
    }
    InfoNavigationState.setSelectedUmEvent(item);
    this.pathStack.pushPathByName(ROUTE_UM_EVENT_DETAIL, null);
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

  private itemWidthForColumns(width: number, columns: number): number {
    if (columns <= 0) {
      return width;
    }
    return (width - EVENT_WATERFALL_COLUMN_GAP * (columns - 1)) / columns;
  }

  private waterfallColumnCount(): number {
    if (this.waterfallWidth <= 0) {
      return EVENT_WATERFALL_MIN_COLUMNS;
    }
    let bestColumns = EVENT_WATERFALL_MIN_COLUMNS;
    let bestDistance = Math.abs(this.itemWidthForColumns(this.waterfallWidth, bestColumns) -
      EVENT_WATERFALL_PREFERRED_ITEM_WIDTH);
    const widestUsefulColumns = Math.max(
      EVENT_WATERFALL_MIN_COLUMNS,
      Math.ceil((this.waterfallWidth + EVENT_WATERFALL_COLUMN_GAP) /
        (EVENT_WATERFALL_PREFERRED_ITEM_WIDTH + EVENT_WATERFALL_COLUMN_GAP)) + 1
    );
    for (let columns = EVENT_WATERFALL_MIN_COLUMNS + 1; columns <= widestUsefulColumns; columns++) {
      const distance = Math.abs(this.itemWidthForColumns(this.waterfallWidth, columns) -
        EVENT_WATERFALL_PREFERRED_ITEM_WIDTH);
      if (distance < bestDistance) {
        bestColumns = columns;
        bestDistance = distance;
      }
    }
    return bestColumns;
  }

  private waterfallColumnsTemplate(): string {
    const columns = this.waterfallColumnCount();
    let template = '';
    for (let index = 0; index < columns; index++) {
      template = template.length > 0 ? `${template} 1fr` : '1fr';
    }
    return template;
  }

  private hasPoster(item: UmEventItem): boolean {
    return item.common.posterUrl !== undefined && item.common.posterUrl.length > 0;
  }

  private eventCardHeight(item: UmEventItem): number {
    let height: number = 24;
    const hasVenue: boolean = this.venueFor(item).length > 0;
    const hasTimeRange: boolean = this.timeRangeFor(item).length > 0;
    if (this.hasPoster(item)) {
      height += EVENT_CARD_POSTER_HEIGHT + 10;
    }
    height += 20 + 8 + 63;
    if (hasTimeRange) {
      height += 41;
    }
    if (hasVenue) {
      height += 38;
    }
    return height;
  }

  private eventWaterfallHeight(): number {
    const columns = this.waterfallColumnCount();
    const columnHeights: number[] = [];
    for (let index = 0; index < columns; index++) {
      columnHeights.push(0);
    }
    for (let itemIndex = 0; itemIndex < this.events.length; itemIndex++) {
      let targetColumn = 0;
      for (let columnIndex = 1; columnIndex < columns; columnIndex++) {
        if (columnHeights[columnIndex] < columnHeights[targetColumn]) {
          targetColumn = columnIndex;
        }
      }
      if (columnHeights[targetColumn] > 0) {
        columnHeights[targetColumn] += EVENT_WATERFALL_ROW_GAP;
      }
      columnHeights[targetColumn] += this.eventCardHeight(this.events[itemIndex]);
    }
    let total = 0;
    for (let index = 0; index < columnHeights.length; index++) {
      total = Math.max(total, columnHeights[index]);
    }
    return Math.max(180, total);
  }

  @Builder
  SourceLabel(): void {
    Text('Data From: data.um.edu.mo')
      .fontSize(12)
      .fontColor(this.theme().textTertiary)
      .textAlign(TextAlign.Center)
      .width('100%')
      .margin({ top: 4, bottom: 8 })
  }

  @Builder
  EventCard(item: UmEventItem): void {
    AppCard({
      clickable: true,
      cardPadding: 0,
      onTap: (): void => {
        this.openEvent(item);
      },
      content: (): void => {
        this.EventCardContent(item);
      }
    })
  }

  @Builder
  EventBadge(item: UmEventItem): void {
    Text(this.eventIsPast(item) ? this.localized('已過', 'Past') : this.localized('即將', 'Upcoming'))
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.eventIsPast(item) ? this.theme().textTertiary : this.theme().secondThemeColor)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(8)
      .backgroundColor(this.theme().surfaceAltColor)
  }

  @Builder
  EventCardContent(item: UmEventItem): void {
    Column() {
      if (this.hasPoster(item)) {
        AppNetworkImage({
          src: InfoFeedService.normalizeImageUrl(item.common.posterUrl),
          alt: this.localized('活動海報', 'Event poster'),
          imageHeight: EVENT_CARD_POSTER_HEIGHT,
          radius: 8
        })
        .width('100%')
      }

      Row() {
        if (this.dateLabelFor(item).length > 0) {
          Text(this.dateLabelFor(item))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.eventIsPast(item) ? this.theme().textTertiary : this.theme().secondThemeColor)
            .layoutWeight(1)
        } else {
          Blank()
            .layoutWeight(1)
        }
        this.EventBadge(item)
      }
      .width('100%')
      .margin({ top: this.hasPoster(item) ? 10 : 0 })

      Text(this.titleFor(item))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
        .lineHeight(21)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 8 })
        .width('100%')

      if (this.timeRangeFor(item).length > 0) {
        Text(this.timeRangeFor(item))
          .fontSize(12)
          .fontColor(this.theme().textSecondary)
          .lineHeight(17)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 7 })
          .width('100%')
      }

      if (this.venueFor(item).length > 0) {
        Text(this.venueFor(item))
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .lineHeight(17)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
          .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  EventWaterfall(): void {
    if (this.events.length > 0) {
      Column() {
        WaterFlow() {
          ForEach(this.events, (item: UmEventItem) => {
            FlowItem() {
              this.EventCard(item);
            }
            .width('100%')
          }, (item: UmEventItem, index: number) => item._id + index.toString())
        }
        .width('100%')
        .height(this.eventWaterfallHeight())
        .columnsTemplate(this.waterfallColumnsTemplate())
        .columnsGap(EVENT_WATERFALL_COLUMN_GAP)
        .rowsGap(EVENT_WATERFALL_ROW_GAP)
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.updateWaterfallWidth(newValue.width);
        })
        .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          this.topContent()
          if (this.loading) {
            Column() {
              AppLoading({
                title: this.localized('正在讀取活動', 'Loading events'),
                message: 'data.um.edu.mo'
              })
            }
            .height(360)
            .justifyContent(FlexAlign.Center)
            .padding({ left: 18, right: 18 })
          } else if (this.errorMessage.length > 0) {
            Column() {
              AppEmptyState({
                title: this.localized('活動暫不可用', 'Events unavailable'),
                description: this.errorMessage,
                actionText: this.localized('重試', 'Retry'),
                onAction: (): void => {
                  this.refresh(false);
                }
              })
            }
            .height(360)
            .justifyContent(FlexAlign.Center)
          } else {
            this.SourceLabel()
            this.EventWaterfall()
          }
          Blank()
            .height(ROOT_CONTENT_BOTTOM_PADDING)
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start)
      }
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bgColor)
  }
}
