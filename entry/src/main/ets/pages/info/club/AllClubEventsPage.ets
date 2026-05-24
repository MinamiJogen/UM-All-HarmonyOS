import { common } from '@kit.AbilityKit';
import {
  ROUTE_EVENT_DETAIL,
  ROUTE_WEBVIEWER
} from '../../../common/constants/RouteNames';
import { ROOT_CONTENT_TOP_PADDING } from '../../../common/constants/LayoutMetrics';
import { ClubNavigationState } from '../../../common/navigation/ClubNavigationState';
import { WebNavigationState } from '../../../common/navigation/WebNavigationState';
import { ServiceResult } from '../../../common/net/HttpClient';
import { I18nService } from '../../../common/i18n/I18nService';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../../../common/theme/AppTheme';
import { OpenLink } from '../../../common/utils/OpenLink';
import { AppCard } from '../../../components/AppCard';
import { AppEmptyState } from '../../../components/AppEmptyState';
import { AppHdsPage } from '../../../components/AppHdsPage';
import { AppLoading } from '../../../components/AppLoading';
import { AppNetworkImage } from '../../../components/AppNetworkImage';
import { AppToast } from '../../../components/AppToast';
import {
  ClubActivityPage,
  ClubService
} from '../../../services/ClubService';
import { ClubInfo } from '../../../models/Club';
import { ClubActivity } from '../../../models/Event';

@Component
export struct AllClubEventsPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State events: ClubActivity[] = [];
  @State page: number = 1;
  @State noMore: boolean = false;
  @State clubName: string = '';
  @State clubNum: number = -1;
  private initialized: boolean = false;
  private pageSize: number = 10;

  aboutToAppear(): void {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    const selected: ClubInfo | null = ClubNavigationState.getSelectedClub();
    if (selected) {
      this.clubNum = selected.club_num;
      this.clubName = selected.name;
      this.refresh(false);
    } else {
      this.loading = false;
      this.errorMessage = this.localized('缺少組織資料', 'Missing club data');
    }
  }

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private localized(tcText: string, enText: string, ptText: string = '', jaText: string = ''): string {
    return I18nService.localizeText(this.language, tcText, enText, ptText, jaText);
  }

  private dataText(tcText: string, enText: string = ''): string {
    return I18nService.localizeDataText(this.language, tcText, enText);
  }

  private getContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async refresh(showToast: boolean): Promise<void> {
    this.page = 1;
    this.noMore = false;
    this.events = [];
    await this.loadPage(1, true, showToast);
  }

  private async loadMore(): Promise<void> {
    if (this.loading || this.noMore) {
      return;
    }
    await this.loadPage(this.page + 1, false, true);
  }

  private async loadPage(targetPage: number, replace: boolean, showToast: boolean): Promise<void> {
    if (this.clubNum < 0) {
      return;
    }
    this.loading = true;
    this.errorMessage = '';
    const result: ServiceResult<ClubActivityPage> =
      await ClubService.fetchClubEvents(this.clubNum, targetPage, this.pageSize);
    if (result.ok && result.data) {
      this.page = targetPage;
      this.noMore = result.data.noMore;
      if (replace) {
        this.events = result.data.events;
      } else {
        this.events = this.events.concat(result.data.events);
      }
      if (showToast && targetPage === 1) {
        AppToast.show(this.getUIContext(), this.localized('活動已刷新', 'Events refreshed'));
      }
    } else {
      this.errorMessage = result.error?.message ?? this.localized('活動資料讀取失敗', 'Failed to load events');
      if (showToast) {
        AppToast.showError(this.getUIContext(), this.errorMessage);
      }
    }
    this.loading = false;
  }

  private async openExternal(url: string): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), url);
    if (!success) {
      AppToast.showError(this.getUIContext(), this.localized('無法打開鏈接', 'Unable to open link'));
    }
  }

  private openEvent(event: ClubActivity): void {
    if ((event.type ?? '') === 'WEBSITE' && (event.link ?? '').length > 0) {
      WebNavigationState.setLink({
        url: event.link ?? '',
        title: event.title ? this.dataText(event.title, event.title) : this.localized('網頁', 'Web')
      });
      this.pathStack.pushPathByName(ROUTE_WEBVIEWER, null);
      return;
    }
    ClubNavigationState.setSelectedEvent(event);
    this.pathStack.pushPathByName(ROUTE_EVENT_DETAIL, null);
  }

  @Builder
  EventCard(event: ClubActivity): void {
    AppCard({
      clickable: true,
      cardPadding: 0,
      onTap: (): void => {
        this.openEvent(event);
      },
      content: (): void => {
        this.EventCardContent(event);
      }
    })
    .width('48%')
    .margin({ right: 8, bottom: 10 })
  }

  @Builder
  EventBadge(event: ClubActivity): void {
    Text((event.type ?? '') === 'WEBSITE' ? 'WEB' :
    (ClubService.eventIsPast(event) ? this.localized('已過', 'Past') :
    (ClubService.eventIsAlmostEnd(event) ? this.localized('將結束', 'Ending') : this.localized('進行中', 'Active'))))
      .fontSize(10)
      .fontWeight(FontWeight.Bold)
      .fontColor(ClubService.eventIsPast(event) ? this.theme().textTertiary : this.theme().secondThemeColor)
      .padding({ left: 6, right: 6, top: 3, bottom: 3 })
      .borderRadius(8)
      .backgroundColor(this.theme().surfaceAltColor)
  }

  @Builder
  EventCardContent(event: ClubActivity): void {
    Column() {
      AppNetworkImage({
        src: event.cover_image_url ?? '',
        alt: event.title ? this.dataText(event.title, event.title) : '',
        imageHeight: 142,
        radius: 8
      })
      Column() {
        Text(event.title ? this.dataText(event.title, event.title) : this.localized('未命名活動', 'Untitled event'))
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(ClubService.eventIsPast(event) ? this.theme().textTertiary : this.theme().textPrimary)
          .lineHeight(18)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Row() {
          this.EventBadge(event)
          Text(ClubService.formatEventRange(event))
            .fontSize(11)
            .fontColor(this.theme().textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 5 })
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .padding(10)
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  LoadMoreFooter(): void {
    Column() {
      if (this.noMore) {
        Text(this.localized('沒有更多活動了', 'No more events'))
          .fontSize(13)
          .fontColor(this.theme().textTertiary)
          .margin({ top: 12, bottom: 16 })
      } else {
        Button(this.loading ? this.localized('載入中', 'Loading') : this.localized('載入更多', 'Load more'))
          .height(38)
          .borderRadius(8)
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor(this.theme().themeColor)
          .enabled(!this.loading)
          .margin({ top: 12, bottom: 16 })
          .onClick(() => {
            this.loadMore();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  PageContent(): void {
    if (this.loading && this.events.length === 0) {
      Column() {
        AppLoading({
          title: this.localized('正在讀取活動', 'Loading events'),
          message: 'umall.one'
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.errorMessage.length > 0 && this.events.length === 0) {
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
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.events.length === 0) {
      Column() {
        AppEmptyState({
          title: this.localized('暫無活動', 'No events'),
          description: this.localized('這個組織暫時沒有活動。', 'This club has no events for now.')
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Scroll() {
        Column() {
          Blank()
            .height(ROOT_CONTENT_TOP_PADDING)
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.events, (event: ClubActivity) => {
              this.EventCard(event);
            }, (event: ClubActivity, index: number) => (event._id ?? '') + index.toString())
          }
          .width('100%')
          .padding({ left: 16, right: 8, top: 10 })
          this.LoadMoreFooter()
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start)
      }
      .layoutWeight(1)
    }
  }

  build() {
    AppHdsPage({
      title: this.clubName.length > 0 ? this.dataText(this.clubName, this.clubName) :
      this.localized('全部活動', 'All Events'),
      backLabel: this.localized('返回', 'Back'),
      primaryActionLabel: this.localized('刷新', 'Refresh'),
      primaryActionSymbol: $r('sys.symbol.arrow_clockwise'),
      primaryActionEnabled: !this.loading,
      onBack: (): void => {
        this.pathStack.pop();
      },
      onPrimaryAction: (): void => {
        this.refresh(true);
      },
      content: (): void => {
        this.PageContent()
      }
    })
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bgColor)
  }
}
