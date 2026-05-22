import { common } from '@kit.AbilityKit';
import { ARK_SUPPORT_MAIL } from '../../../common/constants/ApiEndpoints';
import {
  ROUTE_CLUB_DETAIL,
  ROUTE_WEBVIEWER
} from '../../../common/constants/RouteNames';
import { ROOT_CONTENT_TOP_PADDING } from '../../../common/constants/LayoutMetrics';
import { ClubNavigationState } from '../../../common/navigation/ClubNavigationState';
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
import { AppDialog } from '../../../components/AppDialog';
import { AppEmptyState } from '../../../components/AppEmptyState';
import { AppHdsPage } from '../../../components/AppHdsPage';
import { AppListItem } from '../../../components/AppListItem';
import { AppLoading } from '../../../components/AppLoading';
import { AppNetworkImage } from '../../../components/AppNetworkImage';
import { AppToast } from '../../../components/AppToast';
import { ClubService } from '../../../services/ClubService';
import {
  HtmlLink,
  InfoFeedService
} from '../../../services/InfoFeedService';
import { AnalyticsParams, AnalyticsService } from '../../../services/AnalyticsService';
import { ClubInfo } from '../../../models/Club';
import { ClubActivity } from '../../../models/Event';

function emptyEvent(): ClubActivity {
  return {
    _id: '',
    title: ''
  };
}

function emptyClub(): ClubInfo {
  return {
    club_num: -1,
    name: ''
  };
}

@Component
export struct ClubEventDetailPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State eventItem: ClubActivity = emptyEvent();
  @State club: ClubInfo = emptyClub();
  private loadedEventId: string = '';

  aboutToAppear(): void {
    const selected: ClubActivity | null = ClubNavigationState.getSelectedEvent();
    const selectedId: string = selected?._id ?? '';
    if (selected && selectedId !== this.loadedEventId) {
      this.eventItem = selected;
      this.loadedEventId = selectedId;
      this.load(selected, false);
    }
    const params: AnalyticsParams = new AnalyticsParams();
    params.routeName = 'ClubEventDetail';
    AnalyticsService.log('openPage', params);
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

  private async load(seed: ClubActivity, showToast: boolean): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    const eventId: string = seed._id ?? '';
    let loadedEvent: ClubActivity = seed;
    if (eventId.length > 0) {
      const eventResult: ServiceResult<ClubActivity> = await ClubService.fetchEvent(eventId);
      if (eventResult.ok && eventResult.data) {
        loadedEvent = eventResult.data;
      } else {
        this.errorMessage = eventResult.error?.message ?? this.localized('活動資料讀取失敗', 'Failed to load event');
      }
    }
    this.eventItem = loadedEvent;
    const clubNum: number = loadedEvent.created_by ?? loadedEvent.club_num ?? -1;
    if (clubNum >= 0) {
      const clubResult: ServiceResult<ClubInfo> = await ClubService.fetchClub(clubNum);
      if (clubResult.ok && clubResult.data) {
        this.club = clubResult.data;
      }
    }
    if (showToast && this.errorMessage.length === 0) {
      AppToast.show(this.getUIContext(), this.localized('活動資料已刷新', 'Event refreshed'));
    } else if (showToast && this.errorMessage.length > 0) {
      AppToast.showError(this.getUIContext(), this.errorMessage);
    }
    this.loading = false;
  }

  private title(): string {
    return this.eventItem.title ?? this.localized('活動詳情', 'Event Detail');
  }

  private introText(): string {
    return this.eventItem.introduction ?? this.eventItem.content ?? '';
  }

  private introLinks(): HtmlLink[] {
    return InfoFeedService.simplifyHtml(this.introText()).links;
  }

  private relatedImages(): string[] {
    return this.eventItem.relate_image_url ?? [];
  }

  private async openExternal(url: string): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), url);
    if (!success) {
      AppToast.showError(this.getUIContext(), this.localized('無法打開鏈接', 'Unable to open link'));
    }
  }

  private openClub(): void {
    if (this.club.club_num < 0) {
      return;
    }
    ClubNavigationState.setSelectedClub(this.club);
    this.pathStack.pushPathByName(ROUTE_CLUB_DETAIL, null);
  }

  private openWebsiteEvent(): void {
    const url: string = this.eventItem.link ?? '';
    if (url.length === 0) {
      return;
    }
    WebNavigationState.setLink({
      url: url,
      title: this.title()
    });
    this.pathStack.pushPathByName(ROUTE_WEBVIEWER, null);
  }

  private async reportEvent(): Promise<void> {
    const confirmed: boolean = await AppDialog.confirm(this.getUIContext(), {
      title: this.localized('舉報活動', 'Report event'),
      message: this.localized('請在郵件中說明需舉報活動的標題和原因。', 'Please describe the event title and reason in the email.'),
      confirmText: this.localized('發送郵件', 'Email'),
      cancelText: this.localized('取消', 'Cancel')
    });
    if (confirmed) {
      this.openExternal('mailto:' + ARK_SUPPORT_MAIL);
    }
  }

  @Builder
  Hero(): void {
    AppNetworkImage({
      src: this.eventItem.cover_image_url ?? '',
      alt: this.title(),
      imageHeight: 270,
      radius: 0
    })
  }

  @Builder
  InfoRow(label: string, value: string): void {
    if (value.length > 0) {
      Row() {
        Text(label)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().themeColor)
          .width(76)
        Text(value)
          .fontSize(14)
          .fontColor(this.theme().textSecondary)
          .lineHeight(21)
          .layoutWeight(1)
          .copyOption(CopyOptions.InApp)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ top: 8, bottom: 8 })
      .border({ width: { bottom: 1 }, color: this.theme().borderColor })
    }
  }

  @Builder
  EventInfoCard(): void {
    AppCard({
      content: (): void => {
        this.EventInfoCardContent();
      }
    })
    .margin({ left: 16, right: 16, top: 14 })
  }

  @Builder
  EventInfoCardContent(): void {
    Column() {
      Text(this.title())
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
        .lineHeight(27)
        .width('100%')
        .copyOption(CopyOptions.InApp)
        .margin({ bottom: 8 })
      this.InfoRow(this.localized('地點', 'Venue'), this.eventItem.location ?? '')
      this.InfoRow(this.localized('時間', 'Time'), ClubService.formatEventRange(this.eventItem))
      this.InfoRow(this.localized('類型', 'Type'), this.eventItem.type ?? '')
      if ((this.eventItem.type ?? '') === 'WEBSITE' && (this.eventItem.link ?? '').length > 0) {
        Button(this.localized('打開活動鏈接', 'Open event link'))
          .height(38)
          .borderRadius(8)
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor(this.theme().themeColor)
          .margin({ top: 12 })
          .onClick(() => {
            this.openWebsiteEvent();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  OrganizerCard(): void {
    if (this.club.club_num >= 0) {
      AppCard({
        clickable: true,
        onTap: (): void => {
          this.openClub();
        },
        content: (): void => {
          this.OrganizerCardContent();
        }
      })
      .margin({ left: 16, right: 16, top: 10 })
    }
  }

  @Builder
  OrganizerCardContent(): void {
    Row() {
      AppNetworkImage({
        src: this.club.logo_url ?? '',
        alt: this.club.name,
        imageHeight: 46,
        fitContain: true,
        radius: 23
      })
      .width(46)
      Column() {
        Text(this.localized('主辦方', 'Organizer'))
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
        Text(this.club.name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      Text('>')
        .fontSize(18)
        .fontColor(this.theme().textTertiary)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  IntroCard(): void {
    if (this.introText().length > 0) {
      AppCard({
        content: (): void => {
          this.IntroCardContent();
        }
      })
      .margin({ left: 16, right: 16, top: 10 })
    }
  }

  @Builder
  IntroCardContent(): void {
    Column() {
      Text(this.localized('活動詳情', 'Event Details'))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().themeColor)
        .width('100%')
        .margin({ bottom: 10 })
      Text(this.introText())
        .fontSize(14)
        .fontColor(this.theme().textSecondary)
        .lineHeight(21)
        .copyOption(CopyOptions.InApp)
        .width('100%')
      if (this.introLinks().length > 0) {
        ForEach(this.introLinks(), (link: HtmlLink, index: number) => {
          AppListItem({
            title: link.label,
            subtitle: link.url,
            clickable: true,
            showChevron: true,
            showDivider: index !== this.introLinks().length - 1,
            onTap: (): void => {
              this.openExternal(link.url);
            }
          })
          .margin({ top: 8 })
        }, (link: HtmlLink, index: number) => link.url + index.toString())
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RelatedPhotos(): void {
    if (this.relatedImages().length > 0) {
      AppCard({
        content: (): void => {
          this.RelatedPhotosContent();
        }
      })
      .margin({ left: 16, right: 16, top: 10 })
    }
  }

  @Builder
  RelatedPhotosContent(): void {
    Column() {
      Text(this.localized('相關照片', 'Related Photos'))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().themeColor)
        .width('100%')
        .margin({ bottom: 10 })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.relatedImages(), (url: string, index: number) => {
          AppNetworkImage({
            src: url,
            alt: this.localized('活動照片', 'Event photo'),
            imageHeight: 92,
            radius: 8
          })
          .width('31%')
          .margin({ right: 6, bottom: 8 })
        }, (url: string, index: number) => url + index.toString())
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  PageContent(): void {
    if (this.loading && (this.eventItem._id ?? '').length === 0) {
      Column() {
        AppLoading({
          title: this.localized('正在讀取活動', 'Loading event'),
          message: 'umall.one'
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.errorMessage.length > 0 && (this.eventItem._id ?? '').length === 0) {
      Column() {
        AppEmptyState({
          title: this.localized('活動暫不可用', 'Event unavailable'),
          description: this.errorMessage,
          actionText: this.localized('返回', 'Back'),
          onAction: (): void => {
            this.pathStack.pop();
          }
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Scroll() {
        Column() {
          Blank()
            .height(ROOT_CONTENT_TOP_PADDING)
          this.Hero()
          this.EventInfoCard()
          this.OrganizerCard()
          this.IntroCard()
          this.RelatedPhotos()
          Button(this.localized('向管理員舉報該活動', 'Report this event'))
            .height(36)
            .borderRadius(8)
            .fontSize(12)
            .fontColor(this.theme().textTertiary)
            .backgroundColor(Color.Transparent)
            .margin({ top: 16, bottom: 16 })
            .onClick(() => {
              this.reportEvent();
            })
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
  }

  build() {
    AppHdsPage({
      title: this.localized('活動詳情', 'Event Detail'),
      backLabel: this.localized('返回', 'Back'),
      primaryActionLabel: this.localized('刷新', 'Refresh'),
      primaryActionSymbol: $r('sys.symbol.arrow_clockwise'),
      primaryActionEnabled: !this.loading && (this.eventItem._id ?? '').length > 0,
      onBack: (): void => {
        this.pathStack.pop();
      },
      onPrimaryAction: (): void => {
        this.load(this.eventItem, true);
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
