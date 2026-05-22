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
  NewsDetail,
  NewsItem,
  OPEN_DATA_LOCALE_EN_US,
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

  aboutToAppear(): void {
    const selected: NewsItem | null = InfoNavigationState.getSelectedNews();
    if (selected) {
      this.news = selected;
      this.hasNews = true;
      const preferred: string = this.preferredLocale();
      const detail: NewsDetail | undefined = InfoFeedService.findDetail<NewsDetail>(selected.details, preferred);
      this.selectedLocale = detail ? preferred : (selected.details.length > 0 ? selected.details[0].locale : preferred);
    }
    const params: AnalyticsParams = new AnalyticsParams();
    params.routeName = 'NewsDetail';
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

  private title(): string {
    return this.currentDetail()?.title ?? this.localized('新聞詳情', 'News Detail');
  }

  private contentText(): string {
    return InfoFeedService.simplifyHtml(this.currentDetail()?.content).text;
  }

  private contentLinks(): HtmlLink[] {
    return InfoFeedService.simplifyHtml(this.currentDetail()?.content).links;
  }

  private imageUrls(): string[] {
    return InfoFeedService.imageUrlsForNews(this.news);
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
            alt: this.localized('新聞圖片', 'News image'),
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

        Text(this.localized('Update: ', 'Update: ') +
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
      .padding({ bottom: 16 })
    }
    .layoutWeight(1)
  }

  @Builder
  BodyCardContent(): void {
    Text(this.contentText().length > 0 ? this.contentText() :
    this.localized('暫無正文內容', 'No content available'))
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
          title: this.localized('沒有新聞資料', 'No news data'),
          description: this.localized('請從新聞列表重新打開。', 'Open a news item from the list again.'),
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
      title: this.localized('新聞詳情', 'News Detail'),
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
