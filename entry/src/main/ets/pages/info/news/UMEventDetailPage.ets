import { common } from '@kit.AbilityKit';
import { ROOT_CONTENT_TOP_PADDING } from '../../../common/constants/LayoutMetrics';
import { InfoNavigationState } from '../../../common/navigation/InfoNavigationState';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../../../common/theme/AppTheme';
import { I18nService, LANGUAGE_EN } from '../../../common/i18n/I18nService';
import { OpenLink } from '../../../common/utils/OpenLink';
import { AppCard } from '../../../components/AppCard';
import { AppEmptyState } from '../../../components/AppEmptyState';
import { AppHdsPage } from '../../../components/AppHdsPage';
import { AppListItem } from '../../../components/AppListItem';
import { AppNetworkImage } from '../../../components/AppNetworkImage';
import {
  AppSegmentOption,
  AppSegmentedControl
} from '../../../components/AppSegmentedControl';
import { AppToast } from '../../../components/AppToast';
import {
  HtmlLink,
  InfoFeedService,
  OpenDataLocaleOption
} from '../../../services/InfoFeedService';
import { AnalyticsParams, AnalyticsService } from '../../../services/AnalyticsService';
import {
  UmEventDetail,
  UmEventItem
} from '../../../models/Event';
import {
  OPEN_DATA_LOCALE_EN_US,
  OPEN_DATA_LOCALE_ZH_TW
} from '../../../models/News';

function emptyEventItem(): UmEventItem {
  return {
    _id: '',
    common: {
      dateFrom: ''
    },
    details: []
  };
}

@Component
export struct UMEventDetailPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State eventItem: UmEventItem = emptyEventItem();
  @State hasEvent: boolean = false;
  @State selectedLocale: string = OPEN_DATA_LOCALE_ZH_TW;

  aboutToAppear(): void {
    const selected: UmEventItem | null = InfoNavigationState.getSelectedUmEvent();
    if (selected) {
      this.eventItem = selected;
      this.hasEvent = true;
      const preferred: string = this.preferredLocale();
      const detail: UmEventDetail | undefined = InfoFeedService.findDetail<UmEventDetail>(selected.details, preferred);
      this.selectedLocale = detail ? preferred : (selected.details.length > 0 ? selected.details[0].locale : preferred);
    }
    const params: AnalyticsParams = new AnalyticsParams();
    params.routeName = 'UMEventDetail';
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

  private preferredLocale(): string {
    return this.isEnglish() ? OPEN_DATA_LOCALE_EN_US : OPEN_DATA_LOCALE_ZH_TW;
  }

  private getContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private currentDetail(): UmEventDetail | undefined {
    return InfoFeedService.findDetail<UmEventDetail>(this.eventItem.details, this.selectedLocale);
  }

  private localeOptions(): OpenDataLocaleOption[] {
    return InfoFeedService.getLocaleOptions(this.eventItem.details);
  }

  private segmentOptions(): AppSegmentOption[] {
    const options: OpenDataLocaleOption[] = this.localeOptions();
    const result: AppSegmentOption[] = [];
    for (let i = 0; i < options.length; i++) {
      result.push({
        key: options[i].key,
        label: options[i].label
      });
    }
    return result;
  }

  private selectedIndex(): number {
    const options: OpenDataLocaleOption[] = this.localeOptions();
    for (let i = 0; i < options.length; i++) {
      if (options[i].locale === this.selectedLocale) {
        return i;
      }
    }
    return 0;
  }

  private title(): string {
    return this.currentDetail()?.title ?? this.localized('澳大活動詳情', 'UM Event Detail');
  }

  private speaker(): string {
    const detail: UmEventDetail | undefined = this.currentDetail();
    return detail?.speakers ?? detail?.speaker ?? '';
  }

  private venue(): string {
    const detail: UmEventDetail | undefined = this.currentDetail();
    return detail?.venues ?? detail?.venue ?? '';
  }

  private targetAudience(): string {
    const detail: UmEventDetail | undefined = this.currentDetail();
    return detail?.targetAudiences ?? detail?.targetAudience ?? '';
  }

  private organiser(): string {
    const detail: UmEventDetail | undefined = this.currentDetail();
    return detail?.organizedBys ?? detail?.organiser ?? '';
  }

  private coorganiser(): string {
    const detail: UmEventDetail | undefined = this.currentDetail();
    return detail?.coorganizers ?? detail?.coorganiser ?? '';
  }

  private remark(): string {
    return this.currentDetail()?.remark ?? '';
  }

  private contentText(): string {
    return InfoFeedService.simplifyHtml(this.currentDetail()?.content).text;
  }

  private contentLinks(): HtmlLink[] {
    return InfoFeedService.simplifyHtml(this.currentDetail()?.content).links;
  }

  private contactName(): string {
    return this.currentDetail()?.contactName ?? '';
  }

  private contactPhone(): string {
    return this.currentDetail()?.contactPhone ?? '';
  }

  private contactFax(): string {
    return this.currentDetail()?.contactFax ?? '';
  }

  private contactEmail(): string {
    return this.currentDetail()?.contactEmail ?? '';
  }

  private languageText(): string {
    const value: string[] | string | undefined = this.currentDetail()?.languages;
    if (!value) {
      return '';
    }
    if (typeof value === 'string') {
      return value;
    }
    return value.join(', ');
  }

  private hasContact(): boolean {
    return this.contactName().length > 0 || this.contactPhone().length > 0 ||
      this.contactFax().length > 0 || this.contactEmail().length > 0;
  }

  private async openExternal(url: string): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), url);
    if (!success) {
      AppToast.showError(this.getUIContext(), this.localized('無法打開鏈接', 'Unable to open link'));
    }
  }

  @Builder
  LanguagePicker(): void {
    if (this.localeOptions().length > 1) {
      AppSegmentedControl({
        options: this.segmentOptions(),
        selectedIndex: this.selectedIndex(),
        onChange: (index: number): void => {
          const options: OpenDataLocaleOption[] = this.localeOptions();
          if (index >= 0 && index < options.length) {
            this.selectedLocale = options[index].locale;
          }
        }
      })
      .margin({ left: 16, right: 16, top: 10, bottom: 12 })
    }
  }

  @Builder
  Hero(): void {
    if ((this.eventItem.common.posterUrl ?? '').length > 0) {
      AppNetworkImage({
        src: InfoFeedService.normalizeImageUrl(this.eventItem.common.posterUrl),
        alt: this.localized('活動海報', 'Event poster'),
        imageHeight: 270,
        radius: 0
      })
    }
  }

  @Builder
  InfoRow(label: string, value: string): void {
    if (value.length > 0) {
      Row() {
        Text(label)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().themeColor)
          .width(96)
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
    .margin({ left: 16, right: 16, top: 12 })
  }

  @Builder
  EventInfoCardContent(): void {
    Column() {
      this.InfoRow(this.localized('日期', 'Date'), InfoFeedService.formatEventTimeRange(this.eventItem))
      this.InfoRow(this.localized('地點', 'Venue'), this.venue())
      this.InfoRow(this.localized('講者', 'Speaker'), this.speaker())
      this.InfoRow(this.localized('語言', 'Language'), this.languageText())
      this.InfoRow(this.localized('對象', 'Audience'), this.targetAudience())
      this.InfoRow(this.localized('主辦', 'Organiser'), this.organiser())
      this.InfoRow(this.localized('協辦', 'Co-organiser'), this.coorganiser())
      this.InfoRow(this.localized('備註', 'Remark'), this.remark())
    }
    .width('100%')
  }

  @Builder
  ContentCard(): void {
    AppCard({
      content: (): void => {
        this.ContentCardContent();
      }
    })
    .margin({ left: 16, right: 16, top: 12 })
  }

  @Builder
  ContentCardContent(): void {
    Column() {
      Text(this.localized('詳情', 'Details'))
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().themeColor)
        .width('100%')
        .margin({ bottom: 8 })
      Text(this.contentText().length > 0 ? this.contentText() :
      this.localized('暫無活動正文', 'No event content available'))
        .fontSize(15)
        .fontColor(this.theme().textSecondary)
        .lineHeight(23)
        .width('100%')
        .copyOption(CopyOptions.InApp)
    }
    .width('100%')
  }

  @Builder
  ContactCard(): void {
    if (this.hasContact()) {
      AppCard({
        cardPadding: 0,
        content: (): void => {
          this.ContactCardContent();
        }
      })
      .margin({ left: 16, right: 16, top: 12 })
    }
  }

  @Builder
  ContactCardContent(): void {
    Column() {
      AppListItem({
        title: this.localized('聯絡人', 'Contact'),
        value: this.contactName(),
        showDivider: this.contactPhone().length > 0 || this.contactFax().length > 0 ||
        this.contactEmail().length > 0
      })
      if (this.contactPhone().length > 0) {
        AppListItem({
          title: this.localized('電話', 'Phone'),
          value: this.contactPhone(),
          showDivider: this.contactFax().length > 0 || this.contactEmail().length > 0
        })
      }
      if (this.contactFax().length > 0) {
        AppListItem({
          title: this.localized('傳真', 'Fax'),
          value: this.contactFax(),
          showDivider: this.contactEmail().length > 0
        })
      }
      if (this.contactEmail().length > 0) {
        AppListItem({
          title: 'Email',
          value: this.contactEmail(),
          clickable: true,
          showChevron: true,
          showDivider: false,
          onTap: (): void => {
            this.openExternal('mailto:' + this.contactEmail());
          }
        })
      }
    }
    .width('100%')
  }

  @Builder
  LinkList(): void {
    if (this.contentLinks().length > 0) {
      Text(this.localized('鏈接', 'Links'))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textTertiary)
        .width('100%')
        .padding({ left: 16, right: 16 })
        .margin({ top: 16, bottom: 8 })
      AppCard({
        cardPadding: 0,
        content: (): void => {
          this.LinkListContent();
        }
      })
      .margin({ left: 16, right: 16, bottom: 24 })
    }
  }

  @Builder
  LinkListContent(): void {
    Column() {
      ForEach(this.contentLinks(), (link: HtmlLink, index: number) => {
        AppListItem({
          title: link.label,
          subtitle: link.url,
          clickable: true,
          showChevron: true,
          showDivider: index !== this.contentLinks().length - 1,
          onTap: (): void => {
            this.openExternal(link.url);
          }
        })
      }, (link: HtmlLink, index: number) => link.url + index.toString())
    }
    .width('100%')
  }

  @Builder
  Content(): void {
    Scroll() {
      Column() {
        Blank()
          .height(ROOT_CONTENT_TOP_PADDING)
        this.Hero()
        this.LanguagePicker()
        Text(this.title())
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .lineHeight(30)
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ top: 8 })

        this.EventInfoCard()
        this.ContentCard()
        this.ContactCard()
        this.LinkList()
      }
      .width('100%')
      .padding({ bottom: 16 })
    }
    .layoutWeight(1)
  }

  @Builder
  PageContent(): void {
    if (!this.hasEvent) {
      Column() {
        AppEmptyState({
          title: this.localized('沒有活動資料', 'No event data'),
          description: this.localized('請從活動列表重新打開。', 'Open an event from the list again.'),
          actionText: this.localized('返回', 'Back'),
          onAction: (): void => {
            this.pathStack.pop();
          }
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      this.Content()
    }
  }

  build() {
    AppHdsPage({
      title: this.localized('活動詳情', 'Event Detail'),
      backLabel: this.localized('返回', 'Back'),
      onBack: (): void => {
        this.pathStack.pop();
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
