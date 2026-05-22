import { common } from '@kit.AbilityKit';
import { ARK_FAQ } from '../../common/constants/ApiEndpoints';
import { ROOT_CONTENT_BOTTOM_PADDING } from '../../common/constants/LayoutMetrics';
import { ClubNavigationState } from '../../common/navigation/ClubNavigationState';
import {
  INFO_TOP_TAB_CLUB,
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
import { OpenLink } from '../../common/utils/OpenLink';
import { AppCard } from '../../components/AppCard';
import { AppEmptyState } from '../../components/AppEmptyState';
import { AppLoading } from '../../components/AppLoading';
import { AppNetworkImage } from '../../components/AppNetworkImage';
import { AppSearchField } from '../../components/AppSearchField';
import { AppToast, AppToastType } from '../../components/AppToast';
import { AnalyticsParams, AnalyticsService } from '../../services/AnalyticsService';
import { ClubService } from '../../services/ClubService';
import { ClubDetailPage } from './club/ClubDetailPage';
import {
  ClubInfo,
  ClubSection
} from '../../models/Club';

@Component
export struct ClubPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State searchText: string = '';
  @State clubs: ClubInfo[] = [];
  @State sections: ClubSection[] = [];
  @State showClubSheet: boolean = false;
  @State selectedClubName: string = '';
  @BuilderParam topContent: () => void = this.EmptySlot;
  private loaded: boolean = false;
  private refreshHandler: InfoRefreshHandler = (): void => {
    this.refresh(true);
  };

  @Builder
  private EmptySlot(): void {
  }

  aboutToAppear(): void {
    InfoRefreshRegistry.register(INFO_TOP_TAB_CLUB, this.refreshHandler);
    const params: AnalyticsParams = new AnalyticsParams();
    params.routeName = 'ClubPage';
    AnalyticsService.log('openPage', params);
    if (!this.loaded) {
      this.loaded = true;
      this.refresh(false);
    }
  }

  aboutToDisappear(): void {
    InfoRefreshRegistry.unregister(INFO_TOP_TAB_CLUB, this.refreshHandler);
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

  private applySearch(): void {
    this.sections = ClubService.buildSections(ClubService.filterClubs(this.clubs, this.searchText));
  }

  private async refresh(showToast: boolean): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    const result: ServiceResult<ClubInfo[]> = await ClubService.fetchClubs();
    if (result.ok && result.data) {
      this.clubs = result.data;
      this.applySearch();
      if (showToast) {
        AppToast.show(this.getUIContext(), this.localized('組織已刷新', 'Clubs refreshed'), AppToastType.Success);
      }
    } else {
      this.errorMessage = result.error?.message ?? this.localized('組織資料讀取失敗', 'Failed to load clubs');
      if (showToast) {
        AppToast.showError(this.getUIContext(), this.errorMessage);
      }
    }
    this.loading = false;
  }

  private async openFaq(): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), ARK_FAQ);
    if (!success) {
      AppToast.showError(this.getUIContext(), this.localized('無法打開鏈接', 'Unable to open link'));
    }
  }

  private openClub(club: ClubInfo): void {
    ClubNavigationState.setSelectedClub(club);
    this.selectedClubName = club.name;
    this.showClubSheet = true;
  }

  @Builder
  Header(): void {
    Row() {
      Text(this.localized('組織', 'Clubs'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 6 })
  }

  @Builder
  SearchBar(): void {
    Column() {
      AppSearchField({
        placeholder: this.localized('搜尋組織名稱或分類', 'Search club name or category'),
        value: this.searchText,
        onChange: (value: string): void => {
          this.searchText = value;
          this.applySearch();
        },
        onSubmit: (value: string): void => {
          this.searchText = value;
          this.applySearch();
        }
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 10 })
  }

  @Builder
  SectionHeader(section: ClubSection): void {
    Row() {
      Column() {
      }
        .width(3)
        .height(18)
        .borderRadius(2)
        .backgroundColor(this.theme().themeColor)
        .margin({ right: 10 })
      Text(ClubService.tagLabel(section.title))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textSecondary)
        .layoutWeight(1)
      Text(section.clubs.length.toString())
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 16, bottom: 8 })
  }

  @Builder
  ClubTile(club: ClubInfo): void {
    AppCard({
      clickable: true,
      cardPadding: 10,
      onTap: (): void => {
        this.openClub(club);
      },
      content: (): void => {
        this.ClubTileContent(club);
      }
    })
    .width('31%')
    .margin({ right: 6, bottom: 8 })
  }

  @Builder
  ClubTileContent(club: ClubInfo): void {
    Column() {
      AppNetworkImage({
        src: club.logo_url ?? '',
        alt: club.name,
        imageHeight: 58,
        fitContain: true,
        radius: 29
      })
      .width(58)
      Text(club.name)
        .fontSize(11)
        .fontColor(this.theme().textPrimary)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .lineHeight(15)
        .width('100%')
        .height(32)
        .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  SectionView(section: ClubSection): void {
    Column() {
      this.SectionHeader(section)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(section.clubs, (club: ClubInfo) => {
          this.ClubTile(club);
        }, (club: ClubInfo, index: number) => (club._id ?? club.club_num.toString()) + index.toString())
      }
      .width('100%')
      .padding({ left: 16, right: 10 })
    }
    .width('100%')
  }

  @Builder
  Footer(): void {
    Column() {
      Text(this.localized('已有 ', 'Already ') + this.clubs.length.toString() +
      this.localized(' 個組織進駐', ' clubs joined'))
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
        .textAlign(TextAlign.Center)
      Button(this.localized('沒有賬號？進駐 ARK ALL', 'No account? Join ARK ALL'))
        .height(34)
        .borderRadius(8)
        .fontSize(12)
        .fontColor(this.theme().themeColor)
        .backgroundColor(this.theme().surfaceAltColor)
        .margin({ top: 8 })
        .onClick(() => {
          this.openFaq();
        })
    }
    .width('100%')
    .padding({ top: 26, bottom: 36 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ClubDetailSheetContent(): void {
    ClubDetailPage({
      embeddedInSheet: true,
      onSheetClose: (): void => {
        this.showClubSheet = false;
      }
    })
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          this.topContent()
          this.Header()
          this.SearchBar()
          if (this.loading && this.clubs.length === 0) {
            Column() {
              AppLoading({
                title: this.localized('正在讀取組織', 'Loading clubs'),
                message: 'umall.one'
              })
            }
            .height(360)
            .justifyContent(FlexAlign.Center)
          } else if (this.errorMessage.length > 0 && this.clubs.length === 0) {
            Column() {
              AppEmptyState({
                title: this.localized('組織暫不可用', 'Clubs unavailable'),
                description: this.errorMessage,
                actionText: this.localized('重試', 'Retry'),
                onAction: (): void => {
                  this.refresh(false);
                }
              })
            }
            .height(360)
            .justifyContent(FlexAlign.Center)
          } else if (this.sections.length === 0) {
            Column() {
              AppEmptyState({
                title: this.localized('沒有搜尋結果', 'No results found'),
                description: this.localized('請換一個關鍵字，或刷新組織資料。', 'Try another keyword or refresh club data.'),
                actionText: this.localized('清除搜尋', 'Clear search'),
                onAction: (): void => {
                  this.searchText = '';
                  this.applySearch();
                }
              })
            }
            .height(360)
            .justifyContent(FlexAlign.Center)
          } else {
            ForEach(this.sections, (section: ClubSection) => {
              this.SectionView(section);
            }, (section: ClubSection, index: number) => section.title + index.toString())
            this.Footer()
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
    .bindSheet($$this.showClubSheet, this.ClubDetailSheetContent(), {
      height: SheetSize.LARGE,
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      preferType: SheetType.BOTTOM,
      scrollSizeMode: ScrollSizeMode.FOLLOW_DETENT,
      title: {
        title: this.selectedClubName.length > 0 ? this.selectedClubName : this.localized('組織詳情', 'Club Detail')
      },
      backgroundColor: this.theme().bgColor,
      showClose: true
    })
  }
}
