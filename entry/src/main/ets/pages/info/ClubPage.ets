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
import { I18nService } from '../../common/i18n/I18nService';
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

const CLUB_WATERFALL_MIN_COLUMNS: number = 2;
const CLUB_WATERFALL_COLUMN_GAP: number = 10;
const CLUB_WATERFALL_ROW_GAP: number = 12;
const CLUB_WATERFALL_PREFERRED_ITEM_WIDTH: number = 104;
const CLUB_TILE_HEIGHT: number = 124;

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

  private localized(tcText: string, enText: string, ptText: string = '', jaText: string = ''): string {
    return I18nService.localizeText(this.language, tcText, enText, ptText, jaText);
  }

  private dataText(tcText: string, enText: string = ''): string {
    return I18nService.localizeDataText(this.language, tcText, enText);
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
    return (width - CLUB_WATERFALL_COLUMN_GAP * (columns - 1)) / columns;
  }

  private waterfallColumnCount(): number {
    if (this.waterfallWidth <= 0) {
      return CLUB_WATERFALL_MIN_COLUMNS;
    }
    let bestColumns = CLUB_WATERFALL_MIN_COLUMNS;
    let bestDistance = Math.abs(this.itemWidthForColumns(this.waterfallWidth, bestColumns) -
      CLUB_WATERFALL_PREFERRED_ITEM_WIDTH);
    const widestUsefulColumns = Math.max(
      CLUB_WATERFALL_MIN_COLUMNS,
      Math.ceil((this.waterfallWidth + CLUB_WATERFALL_COLUMN_GAP) /
        (CLUB_WATERFALL_PREFERRED_ITEM_WIDTH + CLUB_WATERFALL_COLUMN_GAP)) + 1
    );
    for (let columns = CLUB_WATERFALL_MIN_COLUMNS + 1; columns <= widestUsefulColumns; columns++) {
      const distance = Math.abs(this.itemWidthForColumns(this.waterfallWidth, columns) -
        CLUB_WATERFALL_PREFERRED_ITEM_WIDTH);
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

  private sectionWaterfallHeight(section: ClubSection): number {
    const columns = this.waterfallColumnCount();
    const columnHeights: number[] = [];
    for (let index = 0; index < columns; index++) {
      columnHeights.push(0);
    }
    for (let itemIndex = 0; itemIndex < section.clubs.length; itemIndex++) {
      let targetColumn = 0;
      for (let columnIndex = 1; columnIndex < columns; columnIndex++) {
        if (columnHeights[columnIndex] < columnHeights[targetColumn]) {
          targetColumn = columnIndex;
        }
      }
      if (columnHeights[targetColumn] > 0) {
        columnHeights[targetColumn] += CLUB_WATERFALL_ROW_GAP;
      }
      columnHeights[targetColumn] += CLUB_TILE_HEIGHT;
    }
    let total = 0;
    for (let index = 0; index < columnHeights.length; index++) {
      total = Math.max(total, columnHeights[index]);
    }
    return Math.max(CLUB_TILE_HEIGHT, total);
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
      Text(this.dataText(ClubService.tagLabel(section.title), ClubService.tagLabel(section.title)))
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
    .height(CLUB_TILE_HEIGHT)
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
  SectionWaterfall(section: ClubSection): void {
    Column() {
      WaterFlow() {
        ForEach(section.clubs, (club: ClubInfo) => {
          FlowItem() {
            this.ClubTile(club);
          }
          .width('100%')
        }, (club: ClubInfo, index: number) => (club._id ?? club.club_num.toString()) + index.toString())
      }
      .width('100%')
      .height(this.sectionWaterfallHeight(section))
      .columnsTemplate(this.waterfallColumnsTemplate())
      .columnsGap(CLUB_WATERFALL_COLUMN_GAP)
      .rowsGap(CLUB_WATERFALL_ROW_GAP)
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.updateWaterfallWidth(newValue.width);
      })
      .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  SectionView(section: ClubSection): void {
    Column() {
      this.SectionHeader(section)
      this.SectionWaterfall(section)
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
        .justifyContent(FlexAlign.Start)
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
      mode: SheetMode.OVERLAY,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      title: {
        title: this.selectedClubName.length > 0 ? this.selectedClubName : this.localized('組織詳情', 'Club Detail')
      },
      backgroundColor: this.theme().bgColor,
      showClose: true
    })
  }
}
