import { common } from '@kit.AbilityKit';
import { InfoNavigationState } from '../../common/navigation/InfoNavigationState';
import {
  INFO_TOP_TAB_NEWS,
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

  private isEnglish(): boolean {
    return I18nService.normalizeLanguage(this.language) === LANGUAGE_EN;
  }

  private localized(tcText: string, enText: string): string {
    return this.isEnglish() ? enText : tcText;
  }

  private preferredLocale(): string {
    return this.isEnglish() ? OPEN_DATA_LOCALE_EN_US : OPEN_DATA_LOCALE_ZH_TW;
  }

  private titleFor(item: NewsItem): string {
    const detail: NewsDetail | undefined = InfoFeedService.findDetail<NewsDetail>(item.details, this.preferredLocale());
    return detail?.title ?? this.localized('無標題', 'Untitled');
  }

  private secondaryTitleFor(item: NewsItem): string {
    const secondaryLocale: string = this.isEnglish() ? OPEN_DATA_LOCALE_ZH_TW : OPEN_DATA_LOCALE_EN_US;
    const detail: NewsDetail | undefined = InfoFeedService.findDetail<NewsDetail>(item.details, secondaryLocale);
    return detail?.title ?? '';
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
        AppToast.show(this.getUIContext(), this.localized('新聞已刷新', 'News refreshed'), AppToastType.Success);
      }
    } else {
      this.errorMessage = result.error?.message ?? this.localized('澳大新聞讀取失敗', 'Failed to load UM news');
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

  @Builder
  Header(): void {
    Row() {
      Text(this.localized('澳大新聞', 'UM News'))
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
        alt: this.localized('新聞圖片', 'News image'),
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
  NewsRow(item: NewsItem): void {
    AppCard({
      clickable: true,
      onTap: (): void => {
        this.openNews(item);
      },
      content: (): void => {
        this.NewsRowContent(item);
      }
    })
    .margin({ left: 16, right: 16, bottom: 10 })
  }

  @Builder
  NewsRowContent(item: NewsItem): void {
    Row() {
      Column() {
        Text(this.titleFor(item))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .lineHeight(21)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
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
        Text('@ ' + InfoFeedService.formatMonthDay(item.common.publishDate))
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textTertiary)
          .margin({ top: 9 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ right: this.firstImage(item).length > 0 ? 12 : 0 })

      if (this.firstImage(item).length > 0) {
        AppNetworkImage({
          src: this.firstImage(item),
          alt: this.localized('新聞圖片', 'News image'),
          imageHeight: 104,
          radius: 8
        })
        .width(88)
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
                title: this.localized('正在讀取新聞', 'Loading news'),
                message: 'data.um.edu.mo'
              })
            }
            .height(360)
            .justifyContent(FlexAlign.Center)
            .padding({ left: 18, right: 18 })
          } else if (this.errorMessage.length > 0) {
            Column() {
              AppEmptyState({
                title: this.localized('新聞暫不可用', 'News unavailable'),
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
            this.TopStory()
            ForEach(this.newsList, (item: NewsItem) => {
              this.NewsRow(item);
            }, (item: NewsItem, index: number) => item._id + index.toString())
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
