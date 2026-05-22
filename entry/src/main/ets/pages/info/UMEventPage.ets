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

@Component
export struct UMEventPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State events: UmEventItem[] = [];
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

  private titleFor(item: UmEventItem): string {
    const detail: UmEventDetail | undefined =
      InfoFeedService.findDetail<UmEventDetail>(item.details, this.preferredLocale());
    return detail?.title ?? this.localized('無標題活動', 'Untitled event');
  }

  private venueFor(item: UmEventItem): string {
    const detail: UmEventDetail | undefined =
      InfoFeedService.findDetail<UmEventDetail>(item.details, this.preferredLocale());
    return detail?.venues ?? detail?.venue ?? '';
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

  @Builder
  Header(): void {
    Row() {
      Text(this.localized('澳大活動', 'UM Events'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 6 })
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
  EventRow(item: UmEventItem): void {
    AppCard({
      clickable: true,
      onTap: (): void => {
        this.openEvent(item);
      },
      content: (): void => {
        this.EventRowContent(item);
      }
    })
    .margin({ left: 16, right: 16, bottom: 10 })
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
  EventRowContent(item: UmEventItem): void {
    Row() {
      Column() {
        Row() {
          Text('@ ' + InfoFeedService.formatMonthDay(item.common.dateFrom))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.eventIsPast(item) ? this.theme().textTertiary : this.theme().secondThemeColor)
            .layoutWeight(1)
          this.EventBadge(item)
        }
        .width('100%')

        Text(this.titleFor(item))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .lineHeight(21)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 8 })
          .width('100%')

        Text(InfoFeedService.formatEventTimeRange(item))
          .fontSize(12)
          .fontColor(this.theme().textSecondary)
          .lineHeight(17)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 7 })
          .width('100%')

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
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ right: item.common.posterUrl ? 12 : 0 })

      if (item.common.posterUrl) {
        AppNetworkImage({
          src: InfoFeedService.normalizeImageUrl(item.common.posterUrl),
          alt: this.localized('活動海報', 'Event poster'),
          imageHeight: 116,
          radius: 8
        })
        .width(90)
      }
    }
    .width('100%')
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          this.topContent()
          this.Header()
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
            ForEach(this.events, (item: UmEventItem) => {
              this.EventRow(item);
            }, (item: UmEventItem, index: number) => item._id + index.toString())
          }
          Blank()
            .height(ROOT_CONTENT_BOTTOM_PADDING)
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
      }
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bgColor)
  }
}
