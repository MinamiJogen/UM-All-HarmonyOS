import { common } from '@kit.AbilityKit';
import { InfoNavigationState } from '../../common/navigation/InfoNavigationState';
import {
  INFO_TOP_TAB_NEWS,
  InfoRefreshHandler,
  InfoRefreshRegistry
} from '../../common/navigation/InfoRefreshRegistry';
import { ServiceResult } from '../../common/net/HttpClient';
import { I18nService, LANGUAGE_PT } from '../../common/i18n/I18nService';
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
import { ROUTE_NEWS_DETAIL } from '../../common/constants/RouteNames';
import {
  InfoFeedService,
  NewsFeedState
} from '../../services/InfoFeedService';
import { AnalyticsParams, AnalyticsService } from '../../services/AnalyticsService';
import {
  NewsDetail,
  NewsItem,
  OPEN_DATA_LOCALE_EN_US,
  OPEN_DATA_LOCALE_PT_PT,
  OPEN_DATA_LOCALE_ZH_TW
} from '../../models/News';

function emptyNewsItem(): NewsItem {
  return {
    _id: '',
    common: {
      publishDate: ''
    },
    details: []
  };
}

const NEWS_WATERFALL_MIN_COLUMNS: number = 2;
const NEWS_WATERFALL_COLUMN_GAP: number = 10;
const NEWS_WATERFALL_ROW_GAP: number = 12;
const NEWS_WATERFALL_PREFERRED_ITEM_WIDTH: number = 176;
const NEWS_CARD_IMAGE_HEIGHT: number = 118;

@Component
export struct NewsPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State topNews: NewsItem = emptyNewsItem();
  @State hasTopNews: boolean = false;
  @State newsList: NewsItem[] = [];
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
    InfoRefreshRegistry.register(INFO_TOP_TAB_NEWS, this.refreshHandler);
    const params: AnalyticsParams = new AnalyticsParams();
    params.routeName = 'UMNews';
    AnalyticsService.log('openPage', params);
    if (!this.loaded) {
      this.loaded = true;
      this.refresh(false);
    }
  }

  aboutToDisappear(): void {
    InfoRefreshRegistry.unregister(INFO_TOP_TAB_NEWS, this.refreshHandler);
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

  private preferredDetail(item: NewsItem): NewsDetail | undefined {
    const preferredLocale: string = this.preferredLocale();
    let detail: NewsDetail | undefined = InfoFeedService.findDetail<NewsDetail>(item.details, preferredLocale);
    if (detail) {
      return detail;
    }
    if (preferredLocale !== OPEN_DATA_LOCALE_EN_US) {
      detail = InfoFeedService.findDetail<NewsDetail>(item.details, OPEN_DATA_LOCALE_EN_US);
      if (detail) {
        return detail;
      }
    }
    if (preferredLocale !== OPEN_DATA_LOCALE_ZH_TW) {
      detail = InfoFeedService.findDetail<NewsDetail>(item.details, OPEN_DATA_LOCALE_ZH_TW);
      if (detail) {
        return detail;
      }
    }
    return item.details.length > 0 ? item.details[0] : undefined;
  }

  private titleFor(item: NewsItem): string {
    const detail: NewsDetail | undefined = this.preferredDetail(item);
    return detail ? this.openDataText(detail.title, detail.locale) : this.localized('無標題', 'Untitled', 'Sem título');
  }

  private secondaryTitleFor(item: NewsItem): string {
    const secondaryLocale: string =
      this.preferredLocale() === OPEN_DATA_LOCALE_EN_US ? OPEN_DATA_LOCALE_ZH_TW : OPEN_DATA_LOCALE_EN_US;
    const detail: NewsDetail | undefined = InfoFeedService.findDetail<NewsDetail>(item.details, secondaryLocale);
    return detail ? this.openDataText(detail.title, detail.locale) : '';
  }

  private firstImage(item: NewsItem): string {
    const images: string[] = InfoFeedService.imageUrlsForNews(item);
    return images.length > 0 ? images[0] : '';
  }

  private async refresh(showToast: boolean): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    const result: ServiceResult<NewsFeedState> = await InfoFeedService.fetchNews();
    if (result.ok && result.data) {
      this.topNews = result.data.topNews ?? emptyNewsItem();
      this.hasTopNews = result.data.topNews !== undefined;
      this.newsList = result.data.newsList;
      if (showToast) {
        AppToast.show(this.getUIContext(), this.localized('新聞已刷新', 'News refreshed', 'Notícias atualizadas'),
          AppToastType.Success);
      }
    } else {
      this.errorMessage = result.error?.message ??
      this.localized('澳大新聞讀取失敗', 'Failed to load UM news', 'Falha ao carregar notícias da UM');
      if (showToast) {
        AppToast.showError(this.getUIContext(), this.errorMessage);
      }
    }
    this.loading = false;
  }

  private openNews(item: NewsItem): void {
    if (item._id.length === 0) {
      return;
    }
    InfoNavigationState.setSelectedNews(item);
    this.pathStack.pushPathByName(ROUTE_NEWS_DETAIL, null);
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
    return (width - NEWS_WATERFALL_COLUMN_GAP * (columns - 1)) / columns;
  }

  private waterfallColumnCount(): number {
    if (this.waterfallWidth <= 0) {
      return NEWS_WATERFALL_MIN_COLUMNS;
    }
    let bestColumns = NEWS_WATERFALL_MIN_COLUMNS;
    let bestDistance = Math.abs(this.itemWidthForColumns(this.waterfallWidth, bestColumns) -
      NEWS_WATERFALL_PREFERRED_ITEM_WIDTH);
    const widestUsefulColumns = Math.max(
      NEWS_WATERFALL_MIN_COLUMNS,
      Math.ceil((this.waterfallWidth + NEWS_WATERFALL_COLUMN_GAP) /
        (NEWS_WATERFALL_PREFERRED_ITEM_WIDTH + NEWS_WATERFALL_COLUMN_GAP)) + 1
    );
    for (let columns = NEWS_WATERFALL_MIN_COLUMNS + 1; columns <= widestUsefulColumns; columns++) {
      const distance = Math.abs(this.itemWidthForColumns(this.waterfallWidth, columns) -
        NEWS_WATERFALL_PREFERRED_ITEM_WIDTH);
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

  private newsCardHeight(item: NewsItem): number {
    const hasImage: boolean = this.firstImage(item).length > 0;
    const hasSecondaryTitle: boolean = this.secondaryTitleFor(item).length > 0;
    if (hasImage) {
      return hasSecondaryTitle ? 286 : 244;
    }
    return hasSecondaryTitle ? 166 : 132;
  }

  private newsWaterfallHeight(): number {
    const columns = this.waterfallColumnCount();
    const columnHeights: number[] = [];
    for (let index = 0; index < columns; index++) {
      columnHeights.push(0);
    }
    for (let itemIndex = 0; itemIndex < this.newsList.length; itemIndex++) {
      let targetColumn = 0;
      for (let columnIndex = 1; columnIndex < columns; columnIndex++) {
        if (columnHeights[columnIndex] < columnHeights[targetColumn]) {
          targetColumn = columnIndex;
        }
      }
      if (columnHeights[targetColumn] > 0) {
        columnHeights[targetColumn] += NEWS_WATERFALL_ROW_GAP;
      }
      columnHeights[targetColumn] += this.newsCardHeight(this.newsList[itemIndex]);
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
  TopStory(): void {
    if (this.hasTopNews) {
      AppCard({
        clickable: true,
        cardPadding: 0,
        onTap: (): void => {
          this.openNews(this.topNews);
        },
        content: (): void => {
          this.TopStoryContent();
        }
      })
      .margin({ left: 16, right: 16, bottom: 10 })
    }
  }

  @Builder
  TopStoryContent(): void {
    Stack({ alignContent: Alignment.BottomStart }) {
      AppNetworkImage({
        src: this.firstImage(this.topNews),
        alt: this.localized('新聞圖片', 'News image', 'Imagem da notícia'),
        imageHeight: 210,
        radius: 8
      })
      Column() {
      }
      .width('100%')
      .height(210)
      .backgroundColor('#66000000')

      Column() {
        Text('Top Story @ UM')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ bottom: 8 })
        Text(this.titleFor(this.topNews))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .lineHeight(24)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.secondaryTitleFor(this.topNews).length > 0) {
          Text(this.secondaryTitleFor(this.topNews))
            .fontSize(13)
            .fontColor(Color.White)
            .lineHeight(18)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
            .width('100%')
        }
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height(210)
    .borderRadius(8)
    .clip(true)
  }

  @Builder
  NewsCard(item: NewsItem): void {
    AppCard({
      clickable: true,
      cardPadding: 0,
      onTap: (): void => {
        this.openNews(item);
      },
      content: (): void => {
        this.NewsCardContent(item);
      }
    })
    .height(this.newsCardHeight(item))
  }

  @Builder
  NewsCardContent(item: NewsItem): void {
    Column() {
      if (this.firstImage(item).length > 0) {
        AppNetworkImage({
          src: this.firstImage(item),
          alt: this.localized('新聞圖片', 'News image', 'Imagem da notícia'),
          imageHeight: NEWS_CARD_IMAGE_HEIGHT,
          radius: 8
        })
        .width('100%')
      }

      Text(this.titleFor(item))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
        .lineHeight(21)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: this.firstImage(item).length > 0 ? 10 : 0 })
        .width('100%')

      if (this.secondaryTitleFor(item).length > 0) {
        Text(this.secondaryTitleFor(item))
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .lineHeight(18)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 5 })
          .width('100%')
      }

      Blank()
        .layoutWeight(1)

      Text('@ ' + InfoFeedService.formatMonthDay(item.common.publishDate))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textTertiary)
        .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  NewsWaterfall(): void {
    if (this.newsList.length > 0) {
      Column() {
        WaterFlow() {
          ForEach(this.newsList, (item: NewsItem) => {
            FlowItem() {
              this.NewsCard(item);
            }
            .width('100%')
          }, (item: NewsItem, index: number) => item._id + index.toString())
        }
        .width('100%')
        .height(this.newsWaterfallHeight())
        .columnsTemplate(this.waterfallColumnsTemplate())
        .columnsGap(NEWS_WATERFALL_COLUMN_GAP)
        .rowsGap(NEWS_WATERFALL_ROW_GAP)
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
                title: this.localized('正在讀取新聞', 'Loading news', 'A carregar notícias'),
                message: 'data.um.edu.mo'
              })
            }
            .height(360)
            .justifyContent(FlexAlign.Center)
            .padding({ left: 18, right: 18 })
          } else if (this.errorMessage.length > 0) {
            Column() {
              AppEmptyState({
                title: this.localized('新聞暫不可用', 'News unavailable', 'Notícias indisponíveis'),
                description: this.errorMessage,
                actionText: this.localized('重試', 'Retry', 'Tentar novamente'),
                onAction: (): void => {
                  this.refresh(false);
                }
              })
            }
            .height(360)
            .justifyContent(FlexAlign.Center)
          } else {
            this.SourceLabel()
            this.TopStory()
            this.NewsWaterfall()
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
