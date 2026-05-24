import { common } from '@kit.AbilityKit';
import { ARK_SUPPORT_MAIL } from '../../../common/constants/ApiEndpoints';
import {
  ROUTE_ALL_EVENTS,
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
import { AppBottomSheet } from '../../../components/AppBottomSheet';
import { AppCard } from '../../../components/AppCard';
import { AppDialog } from '../../../components/AppDialog';
import { AppEmptyState } from '../../../components/AppEmptyState';
import { AppHdsPage } from '../../../components/AppHdsPage';
import { AppListItem } from '../../../components/AppListItem';
import { AppLoading } from '../../../components/AppLoading';
import { AppNetworkImage } from '../../../components/AppNetworkImage';
import { AppToast } from '../../../components/AppToast';
import {
  ClubActivityPage,
  ClubService
} from '../../../services/ClubService';
import {
  HtmlLink,
  InfoFeedService
} from '../../../services/InfoFeedService';
import { AnalyticsParams, AnalyticsService } from '../../../services/AnalyticsService';
import {
  ClubContact,
  ClubInfo
} from '../../../models/Club';
import { ClubActivity } from '../../../models/Event';

function emptyClub(): ClubInfo {
  return {
    club_num: -1,
    name: ''
  };
}

@Component
export struct ClubDetailPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State club: ClubInfo = emptyClub();
  @State events: ClubActivity[] = [];
  @State showPhotoSheet: boolean = false;
  embeddedInSheet: boolean = false;
  onSheetClose: () => void = (): void => {};
  private loadedClubNum: number = -1;

  aboutToAppear(): void {
    const selected: ClubInfo | null = ClubNavigationState.getSelectedClub();
    if (selected && selected.club_num !== this.loadedClubNum) {
      this.club = selected;
      this.loadedClubNum = selected.club_num;
      this.load(selected.club_num, false);
    }
    const params: AnalyticsParams = new AnalyticsParams();
    params.routeName = 'ClubDetail';
    AnalyticsService.log('openPage', params);
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

  private async load(clubNum: number, showToast: boolean): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    const clubResult: ServiceResult<ClubInfo> = await ClubService.fetchClub(clubNum);
    if (clubResult.ok && clubResult.data) {
      this.club = clubResult.data;
      const eventResult: ServiceResult<ClubActivityPage> = await ClubService.fetchClubEvents(clubNum, 1, 5);
      if (eventResult.ok && eventResult.data) {
        this.events = eventResult.data.events;
      } else {
        this.events = [];
      }
      if (showToast) {
        AppToast.show(this.getUIContext(), this.localized('組織資料已刷新', 'Club refreshed'));
      }
    } else {
      this.errorMessage = clubResult.error?.message ?? this.localized('組織資料讀取失敗', 'Failed to load club');
      if (showToast) {
        AppToast.showError(this.getUIContext(), this.errorMessage);
      }
    }
    this.loading = false;
  }

  private firstHeroImage(): string {
    const photos: string[] = this.club.club_photos_list ?? [];
    if (photos.length > 0) {
      return photos[0];
    }
    return this.club.logo_url ?? '';
  }

  private contacts(): ClubContact[] {
    return this.club.contact ?? [];
  }

  private visibleContacts(): ClubContact[] {
    const result: ClubContact[] = [];
    const source: ClubContact[] = this.contacts();
    for (let i = 0; i < source.length; i++) {
      if ((source[i].num ?? '').trim().length > 0) {
        result.push(source[i]);
      }
    }
    return result;
  }

  private introText(): string {
    return this.club.intro ?? '';
  }

  private introLinks(): HtmlLink[] {
    return InfoFeedService.simplifyHtml(this.introText()).links;
  }

  private eventPreview(): ClubActivity[] {
    const result: ClubActivity[] = [];
    const count: number = this.events.length > 4 ? 4 : this.events.length;
    for (let i = 0; i < count; i++) {
      result.push(this.events[i]);
    }
    return result;
  }

  private contactUrl(contact: ClubContact): string {
    const value: string = (contact.num ?? '').trim();
    const type: string = (contact.type ?? '').toLowerCase();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (type.includes('email') || value.includes('@')) {
      return 'mailto:' + value;
    }
    if (type.includes('phone')) {
      return 'tel:' + value;
    }
    return '';
  }

  private canOpenContact(contact: ClubContact): boolean {
    return this.contactUrl(contact).length > 0;
  }

  private async openExternal(url: string): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), url);
    if (!success) {
      AppToast.showError(this.getUIContext(), this.localized('無法打開鏈接', 'Unable to open link'));
    }
  }

  private closePage(): void {
    if (this.embeddedInSheet) {
      this.onSheetClose();
      return;
    }
    this.pathStack.pop();
  }

  private closeSheetBeforeNavigate(): void {
    if (this.embeddedInSheet) {
      this.onSheetClose();
    }
  }

  private openEvent(event: ClubActivity): void {
    if ((event.type ?? '') === 'WEBSITE' && (event.link ?? '').length > 0) {
      WebNavigationState.setLink({
        url: event.link ?? '',
        title: event.title ? this.dataText(event.title, event.title) : this.localized('網頁', 'Web')
      });
      this.closeSheetBeforeNavigate();
      this.pathStack.pushPathByName(ROUTE_WEBVIEWER, null);
      return;
    }
    ClubNavigationState.setSelectedEvent(event);
    this.closeSheetBeforeNavigate();
    this.pathStack.pushPathByName(ROUTE_EVENT_DETAIL, null);
  }

  private async reportClub(): Promise<void> {
    const confirmed: boolean = await AppDialog.confirm(this.getUIContext(), {
      title: this.localized('舉報組織', 'Report club'),
      message: this.localized('請在郵件中說明需舉報組織、舉報原因。', 'Please describe the club and reason in the email.'),
      confirmText: this.localized('發送郵件', 'Email'),
      cancelText: this.localized('取消', 'Cancel')
    });
    if (confirmed) {
      this.openExternal('mailto:' + ARK_SUPPORT_MAIL);
    }
  }

  @Builder
  Hero(): void {
    Column() {
      AppNetworkImage({
        src: this.firstHeroImage(),
        alt: this.dataText(this.club.name, this.club.name),
        imageHeight: 220,
        radius: 0
      })
      Stack({ alignContent: Alignment.Center }) {
        AppNetworkImage({
          src: this.club.logo_url ?? '',
          alt: this.dataText(this.club.name, this.club.name),
          imageHeight: 82,
          fitContain: true,
          radius: 41
        })
        .width(82)
      }
      .width(88)
      .height(88)
      .margin({ top: -44, bottom: 4 })
      .borderRadius(44)
      .backgroundColor(this.theme().bgColor)
      .zIndex(1)

      Text(this.dataText(this.club.name, this.club.name))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ left: 18, right: 18 })
        .margin({ top: 8 })
      Text('#' + this.dataText(ClubService.tagLabel(this.club.tag), ClubService.tagLabel(this.club.tag)))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme().themeColor)
        .margin({ top: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  SectionTitle(title: string): void {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.theme().themeColor)
      .width('100%')
      .margin({ bottom: 10 })
  }

  @Builder
  ContactCard(): void {
    AppCard({
      cardPadding: 0,
      content: (): void => {
        this.ContactCardContent();
      }
    })
    .margin({ left: 16, right: 16, top: 14 })
  }

  @Builder
  ContactCardContent(): void {
    Column() {
      Text(this.localized('聯繫方式', 'Contact'))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().themeColor)
        .width('100%')
        .padding({ left: 14, right: 14, top: 14, bottom: 4 })
      if (this.visibleContacts().length > 0) {
        ForEach(this.visibleContacts(), (contact: ClubContact, index: number) => {
          AppListItem({
            title: contact.type,
            subtitle: contact.num,
            clickable: this.canOpenContact(contact),
            showChevron: this.canOpenContact(contact),
            showDivider: index !== this.visibleContacts().length - 1,
            onTap: (): void => {
              this.openExternal(this.contactUrl(contact));
            }
          })
        }, (contact: ClubContact, index: number) => contact.type + contact.num + index.toString())
      } else {
        Text(this.localized('這個組織還未留下聯繫方式', 'This club has not left contact information yet'))
          .fontSize(13)
          .fontColor(this.theme().textTertiary)
          .lineHeight(19)
          .padding({ left: 14, right: 14, bottom: 14 })
          .width('100%')
      }
    }
    .width('100%')
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
      this.SectionTitle(this.localized('簡介', 'Introduction'))
      Text(this.introText())
        .fontSize(14)
        .fontColor(this.theme().textSecondary)
        .lineHeight(21)
        .copyOption(CopyOptions.InApp)
        .width('100%')
      if (this.introLinks().length > 0) {
        ForEach(this.introLinks(), (link: HtmlLink, index: number) => {
          Button(link.label)
            .height(34)
            .borderRadius(8)
            .fontSize(12)
            .fontColor(this.theme().themeColor)
            .backgroundColor(this.theme().surfaceAltColor)
            .margin({ top: 8 })
            .onClick(() => {
              this.openExternal(link.url);
            })
        }, (link: HtmlLink, index: number) => link.url + index.toString())
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  PhotoCard(): void {
    if ((this.club.club_photos_list ?? []).length > 1) {
      AppCard({
        content: (): void => {
          this.PhotoCardContent();
        }
      })
      .margin({ left: 16, right: 16, top: 10 })
    }
  }

  @Builder
  PhotoCardContent(): void {
    Column() {
      Row() {
        this.SectionTitle(this.localized('照片', 'Photos'))
        Button(this.localized('查看', 'View'))
          .height(30)
          .borderRadius(8)
          .fontSize(12)
          .fontColor(this.theme().themeColor)
          .backgroundColor(this.theme().surfaceAltColor)
          .onClick(() => {
            this.showPhotoSheet = true;
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 8 })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.club.club_photos_list ?? [], (url: string, index: number) => {
          if (index > 0) {
            AppNetworkImage({
              src: url,
              alt: this.localized('組織照片', 'Club photo'),
              imageHeight: 78,
              radius: 8
            })
            .width('31%')
            .margin({ right: 6, bottom: 8 })
          }
        }, (url: string, index: number) => url + index.toString())
      }
      .width('100%')
    }
    .width('100%')
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
        imageHeight: 132,
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
          Text(event.club_name ? this.dataText(event.club_name, event.club_name) :
          this.dataText(this.club.name, this.club.name))
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
  EventPreview(): void {
    if (this.eventPreview().length > 0) {
      Column() {
        Row() {
          Text(this.localized('舉辦的活動', 'Events'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
            .layoutWeight(1)
          if (this.events.length > 4) {
            Button(this.localized('查看全部', 'All'))
              .height(32)
              .borderRadius(8)
              .fontSize(12)
              .fontColor(this.theme().themeColor)
              .backgroundColor(this.theme().surfaceAltColor)
              .onClick(() => {
                ClubNavigationState.setSelectedClub(this.club);
                this.closeSheetBeforeNavigate();
                this.pathStack.pushPathByName(ROUTE_ALL_EVENTS, null);
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 18, bottom: 8 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.eventPreview(), (event: ClubActivity) => {
            this.EventCard(event);
          }, (event: ClubActivity, index: number) => (event._id ?? '') + index.toString())
        }
        .width('100%')
        .padding({ left: 16, right: 8 })
      }
      .width('100%')
    }
  }

  @Builder
  PhotoSheetContent(): void {
    Column() {
      ForEach(this.club.club_photos_list ?? [], (url: string, index: number) => {
        AppNetworkImage({
          src: url,
          alt: this.localized('組織照片', 'Club photo'),
          imageHeight: 210,
          radius: 8
        })
        .margin({ bottom: 10 })
      }, (url: string, index: number) => url + index.toString())
    }
    .width('100%')
  }

  @Builder
  PageContent(): void {
    if (this.loading && this.club.club_num < 0) {
      Column() {
        AppLoading({
          title: this.localized('正在讀取組織', 'Loading club'),
          message: 'umall.one'
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.errorMessage.length > 0 && this.club.club_num < 0) {
      Column() {
        AppEmptyState({
          title: this.localized('組織暫不可用', 'Club unavailable'),
          description: this.errorMessage,
          actionText: this.localized('返回', 'Back'),
          onAction: (): void => {
            this.closePage();
          }
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Scroll() {
        Column() {
          if (!this.embeddedInSheet) {
            Blank()
              .height(ROOT_CONTENT_TOP_PADDING)
          }
          this.Hero()
          this.PhotoCard()
          this.ContactCard()
          this.IntroCard()
          this.EventPreview()
          Button(this.localized('向管理員舉報該組織', 'Report this club'))
            .height(36)
            .borderRadius(8)
            .fontSize(12)
            .fontColor(this.theme().textTertiary)
            .backgroundColor(Color.Transparent)
            .margin({ top: 16, bottom: 16 })
            .onClick(() => {
              this.reportClub();
            })
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start)
      }
      .layoutWeight(1)
    }
  }

  build() {
    Stack() {
      if (this.embeddedInSheet) {
        Column() {
          this.PageContent()
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme().bgColor)
      } else {
        AppHdsPage({
          title: this.club.name.length > 0 ? this.dataText(this.club.name, this.club.name) :
          this.localized('組織詳情', 'Club Detail'),
          backLabel: this.localized('返回', 'Back'),
          primaryActionLabel: this.localized('刷新', 'Refresh'),
          primaryActionSymbol: $r('sys.symbol.arrow_clockwise'),
          primaryActionEnabled: !this.loading && this.club.club_num >= 0,
          onBack: (): void => {
            this.closePage();
          },
          onPrimaryAction: (): void => {
            this.load(this.club.club_num, true);
          },
          content: (): void => {
            this.PageContent()
          }
        })
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme().bgColor)
      }

      AppBottomSheet({
        visible: $showPhotoSheet,
        title: this.localized('照片', 'Photos'),
        closeText: this.localized('關閉', 'Close'),
        maxHeightPercent: 82,
        content: (): void => {
          this.PhotoSheetContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
