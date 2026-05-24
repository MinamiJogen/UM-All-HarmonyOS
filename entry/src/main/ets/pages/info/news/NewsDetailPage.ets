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
  NewsDetail,
  NewsItem,
  OPEN_DATA_LOCALE_EN_US,
  OPEN_DATA_LOCALE_PT_PT,
  OPEN_DATA_LOCALE_ZH_TW
} from '../../../models/News';

function emptyNewsItem(): NewsItem {
  return {
    _id: '',
    common: {
      publishDate: ''
    },
    details: []
  };
}

@Component
export struct NewsDetailPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State news: NewsItem = emptyNewsItem();
  @State hasNews: boolean = false;
  @State selectedLocale: string = OPEN_DATA_LOCALE_ZH_TW;
  @State detailContentText: string = '';
  @State detailContentLinks: HtmlLink[] = [];

  aboutToAppear(): void {
    const selected: NewsItem | null = InfoNavigationState.getSelectedNews();
    if (selected) {
      this.news = selected;
      this.hasNews = true;
      this.selectedLocale = this.initialSelectedLocale(selected);
      this.refreshSimplifiedContent();
    }
    const params: AnalyticsParams = new AnalyticsParams();
    params.routeName = 'NewsDetail';
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

  private initialSelectedLocale(item: NewsItem): string {
    const preferred: string = this.preferredLocale();
    if (InfoFeedService.findDetail<NewsDetail>(item.details, preferred)) {
      return preferred;
    }
    if (preferred !== OPEN_DATA_LOCALE_EN_US &&
      InfoFeedService.findDetail<NewsDetail>(item.details, OPEN_DATA_LOCALE_EN_US)) {
      return OPEN_DATA_LOCALE_EN_US;
    }
    if (preferred !== OPEN_DATA_LOCALE_ZH_TW &&
      InfoFeedService.findDetail<NewsDetail>(item.details, OPEN_DATA_LOCALE_ZH_TW)) {
      return OPEN_DATA_LOCALE_ZH_TW;
    }
    return item.details.length > 0 ? item.details[0].locale : preferred;
  }

  private getContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private localeOptions(): OpenDataLocaleOption[] {
    return InfoFeedService.getLocaleOptions(this.news.details);
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

  private currentDetail(): NewsDetail | undefined {
    return InfoFeedService.findDetail<NewsDetail>(this.news.details, this.selectedLocale);
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

  private title(): string {
    const title: string = this.cleanText(this.currentDetail()?.title);
    return title.length > 0 ? this.openDataText(title, this.selectedLocale) :
    this.localized('新聞詳情', 'News Detail', 'Detalhes da notícia');
  }

  private contentText(): string {
    return this.openDataText(this.detailContentText, this.selectedLocale);
  }

  private contentLinks(): HtmlLink[] {
    if (this.selectedLocale !== OPEN_DATA_LOCALE_ZH_TW) {
      return this.detailContentLinks;
    }
    const result: HtmlLink[] = [];
    for (let i = 0; i < this.detailContentLinks.length; i++) {
      result.push({
        label: this.openDataText(this.detailContentLinks[i].label, this.selectedLocale),
        url: this.detailContentLinks[i].url
      });
    }
    return result;
  }

  private imageUrls(): string[] {
    return InfoFeedService.imageUrlsForNews(this.news);
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
      .margin({ left: 16, right: 16, top: 6, bottom: 10 })
    }
  }

  @Builder
  ImageList(): void {
    if (this.imageUrls().length > 0) {
      Column() {
        ForEach(this.imageUrls(), (url: string, index: number) => {
          AppNetworkImage({
            src: url,
            alt: this.localized('新聞圖片', 'News image', 'Imagem da notícia'),
            imageHeight: this.imageUrls().length === 1 ? 230 : 170,
            radius: 8
          })
          .margin({ bottom: 10 })
        }, (url: string, index: number) => url + index.toString())
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
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
      .margin({ left: 16, right: 16, bottom: 22 })
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
        this.LanguagePicker()
        Text(this.title())
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().themeColor)
          .lineHeight(30)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ top: 4 })

        Text(this.localized('Update: ', 'Update: ', 'Atualização: ') +
        InfoFeedService.formatDate(InfoFeedService.publishDateForNews(this.news)))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme().secondThemeColor)
          .textAlign(TextAlign.End)
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ top: 8, bottom: 12 })

        this.ImageList()

        AppCard({
          content: (): void => {
            this.BodyCardContent();
          }
        })
        .margin({ left: 16, right: 16, top: 2 })

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
  BodyCardContent(): void {
    Text(this.contentText().length > 0 ? this.contentText() :
    this.localized('暫無正文內容', 'No content available', 'Sem conteúdo disponível'))
      .fontSize(15)
      .fontColor(this.theme().textSecondary)
      .lineHeight(23)
      .width('100%')
      .copyOption(CopyOptions.InApp)
  }

  @Builder
  PageContent(): void {
    if (!this.hasNews) {
      Column() {
        AppEmptyState({
          title: this.localized('沒有新聞資料', 'No news data', 'Sem dados da notícia'),
          description: this.localized('請從新聞列表重新打開。', 'Open a news item from the list again.',
            'Abra novamente a partir da lista de notícias.'),
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
      title: this.localized('新聞詳情', 'News Detail', 'Detalhes da notícia'),
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
