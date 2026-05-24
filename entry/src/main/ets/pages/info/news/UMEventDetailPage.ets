import { common } from '@kit.AbilityKit';
import { ROOT_CONTENT_TOP_PADDING } from '../../../common/constants/LayoutMetrics';
import { InfoNavigationState } from '../../../common/navigation/InfoNavigationState';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../../../common/theme/AppTheme';
import { I18nService, LANGUAGE_PT } from '../../../common/i18n/I18nService';
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
  OPEN_DATA_LOCALE_PT_PT,
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
  @State detailContentText: string = '';
  @State detailContentLinks: HtmlLink[] = [];

  aboutToAppear(): void {
    const selected: UmEventItem | null = InfoNavigationState.getSelectedUmEvent();
    if (selected) {
      this.eventItem = selected;
      this.hasEvent = true;
      this.selectedLocale = this.initialSelectedLocale(selected);
      this.refreshSimplifiedContent();
    }
    const params: AnalyticsParams = new AnalyticsParams();
    params.routeName = 'UMEventDetail';
    AnalyticsService.log('openPage', params);
  }

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private isPortuguese(): boolean {
    return I18nService.normalizeLanguage(this.language) === LANGUAGE_PT;
  }

  private localized(tcText: string, enText: string, ptText: string = '', jaText: string = ''): string {
    return I18nService.localizeText(this.language, tcText, enText, ptText, jaText);
  }

  private preferredLocale(): string {
    if (this.isPortuguese()) {
      return OPEN_DATA_LOCALE_PT_PT;
    }
    return I18nService.isEnglishLike(this.language) ? OPEN_DATA_LOCALE_EN_US : OPEN_DATA_LOCALE_ZH_TW;
  }

  private openDataText(text: string, locale: string): string {
    return locale === OPEN_DATA_LOCALE_ZH_TW ? I18nService.localizeDataText(this.language, text, text) : text;
  }

  private currentLocaleText(text: string): string {
    return this.openDataText(text, this.selectedLocale);
  }

  private initialSelectedLocale(item: UmEventItem): string {
    const preferred: string = this.preferredLocale();
    if (InfoFeedService.findDetail<UmEventDetail>(item.details, preferred)) {
      return preferred;
    }
    if (preferred !== OPEN_DATA_LOCALE_EN_US &&
      InfoFeedService.findDetail<UmEventDetail>(item.details, OPEN_DATA_LOCALE_EN_US)) {
      return OPEN_DATA_LOCALE_EN_US;
    }
    if (preferred !== OPEN_DATA_LOCALE_ZH_TW &&
      InfoFeedService.findDetail<UmEventDetail>(item.details, OPEN_DATA_LOCALE_ZH_TW)) {
      return OPEN_DATA_LOCALE_ZH_TW;
    }
    return item.details.length > 0 ? item.details[0].locale : preferred;
  }

  private getContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private currentDetail(): UmEventDetail | undefined {
    return InfoFeedService.findDetail<UmEventDetail>(this.eventItem.details, this.selectedLocale);
  }

  private cleanStringText(value: string): string {
    const lines: string[] = value.replace(/\u0000/g, '').split('\n');
    const result: string[] = [];
    for (let index = 0; index < lines.length; index++) {
      const line: string = lines[index].trim();
      if (line.length > 0) {
        result.push(line);
      }
    }
    return result.join('\n');
  }

  private cleanText(value: string | string[] | undefined | null): string {
    if (value === undefined || value === null) {
      return '';
    }
    if (typeof value === 'string') {
      return this.cleanStringText(value);
    }
    if (Array.isArray(value)) {
      const result: string[] = [];
      for (let index = 0; index < value.length; index++) {
        const rawValue = value[index];
        if (typeof rawValue === 'string') {
          const text: string = this.cleanStringText(rawValue);
          if (text.length > 0) {
            result.push(text);
          }
        }
      }
      return result.join('\n');
    }
    return '';
  }

  private refreshSimplifiedContent(): void {
    const simplified = InfoFeedService.simplifyHtml(this.currentDetail()?.content);
    this.detailContentText = this.cleanText(simplified.text);
    this.detailContentLinks = simplified.links;
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
    const title: string = this.cleanText(this.currentDetail()?.title);
    return title.length > 0 ? this.currentLocaleText(title) :
    this.localized('澳大活動詳情', 'UM Event Detail', 'Detalhes do evento da UM');
  }

  private speaker(): string {
    const detail: UmEventDetail | undefined = this.currentDetail();
    return this.currentLocaleText(this.cleanText(detail?.speakers ?? detail?.speaker));
  }

  private venue(): string {
    const detail: UmEventDetail | undefined = this.currentDetail();
    return this.currentLocaleText(this.cleanText(detail?.venues ?? detail?.venue));
  }

  private targetAudience(): string {
    const detail: UmEventDetail | undefined = this.currentDetail();
    return this.currentLocaleText(this.cleanText(detail?.targetAudiences ?? detail?.targetAudience));
  }

  private organiser(): string {
    const detail: UmEventDetail | undefined = this.currentDetail();
    return this.currentLocaleText(this.cleanText(detail?.organizedBys ?? detail?.organiser));
  }

  private coorganiser(): string {
    const detail: UmEventDetail | undefined = this.currentDetail();
    return this.currentLocaleText(this.cleanText(detail?.coorganizers ?? detail?.coorganiser));
  }

  private remark(): string {
    return this.currentLocaleText(this.cleanText(this.currentDetail()?.remark));
  }

  private contentText(): string {
    return this.currentLocaleText(this.detailContentText);
  }

  private contentLinks(): HtmlLink[] {
    if (this.selectedLocale !== OPEN_DATA_LOCALE_ZH_TW) {
      return this.detailContentLinks;
    }
    const result: HtmlLink[] = [];
    for (let i = 0; i < this.detailContentLinks.length; i++) {
      result.push({
        label: this.currentLocaleText(this.detailContentLinks[i].label),
        url: this.detailContentLinks[i].url
      });
    }
    return result;
  }

  private contactName(): string {
    return this.currentLocaleText(this.cleanText(this.currentDetail()?.contactName));
  }

  private contactPhone(): string {
    return this.cleanText(this.currentDetail()?.contactPhone);
  }

  private contactFax(): string {
    return this.cleanText(this.currentDetail()?.contactFax);
  }

  private contactEmail(): string {
    return this.cleanText(this.currentDetail()?.contactEmail);
  }

  private languageText(): string {
    const value: string[] | string | undefined = this.currentDetail()?.languages;
    if (!value) {
      return '';
    }
    if (typeof value === 'string') {
      return this.currentLocaleText(this.cleanText(value));
    }
    if (!Array.isArray(value)) {
      return '';
    }
    const result: string[] = [];
    for (let index = 0; index < value.length; index++) {
      const text: string = this.cleanText(value[index]);
      if (text.length > 0) {
        result.push(this.currentLocaleText(text));
      }
    }
    return result.join(', ');
  }

  private hasContact(): boolean {
    return this.contactName().length > 0 || this.contactPhone().length > 0 ||
      this.contactFax().length > 0 || this.contactEmail().length > 0;
  }

  private async openExternal(url: string): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), url);
    if (!success) {
      AppToast.showError(this.getUIContext(),
        this.localized('無法打開鏈接', 'Unable to open link', 'Não foi possível abrir a ligação'));
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
            this.refreshSimplifiedContent();
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
        alt: this.localized('活動海報', 'Event poster', 'Cartaz do evento'),
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
      this.InfoRow(this.localized('日期', 'Date', 'Data'), InfoFeedService.formatEventTimeRange(this.eventItem))
      this.InfoRow(this.localized('地點', 'Venue', 'Local'), this.venue())
      this.InfoRow(this.localized('講者', 'Speaker', 'Orador'), this.speaker())
      this.InfoRow(this.localized('語言', 'Language', 'Idioma'), this.languageText())
      this.InfoRow(this.localized('對象', 'Audience', 'Público'), this.targetAudience())
      this.InfoRow(this.localized('主辦', 'Organiser', 'Organizador'), this.organiser())
      this.InfoRow(this.localized('協辦', 'Co-organiser', 'Coorganizador'), this.coorganiser())
      this.InfoRow(this.localized('備註', 'Remark', 'Observação'), this.remark())
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
      Text(this.localized('詳情', 'Details', 'Detalhes'))
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().themeColor)
        .width('100%')
        .margin({ bottom: 8 })
      Text(this.contentText().length > 0 ? this.contentText() :
      this.localized('暫無活動正文', 'No event content available', 'Sem conteúdo do evento disponível'))
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
        title: this.localized('聯絡人', 'Contact', 'Contacto'),
        value: this.contactName(),
        showDivider: this.contactPhone().length > 0 || this.contactFax().length > 0 ||
        this.contactEmail().length > 0
      })
      if (this.contactPhone().length > 0) {
        AppListItem({
          title: this.localized('電話', 'Phone', 'Telefone'),
          value: this.contactPhone(),
          showDivider: this.contactFax().length > 0 || this.contactEmail().length > 0
        })
      }
      if (this.contactFax().length > 0) {
        AppListItem({
          title: this.localized('傳真', 'Fax', 'Fax'),
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
      Text(this.localized('鏈接', 'Links', 'Ligações'))
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
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
      .padding({ bottom: 16 })
    }
    .layoutWeight(1)
  }

  @Builder
  PageContent(): void {
    if (!this.hasEvent) {
      Column() {
        AppEmptyState({
          title: this.localized('沒有活動資料', 'No event data', 'Sem dados do evento'),
          description: this.localized('請從活動列表重新打開。', 'Open an event from the list again.',
            'Abra novamente a partir da lista de eventos.'),
          actionText: this.localized('返回', 'Back', 'Voltar'),
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
      title: this.localized('活動詳情', 'Event Detail', 'Detalhes do evento'),
      backLabel: this.localized('返回', 'Back', 'Voltar'),
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
