import { common } from '@kit.AbilityKit';
import { UM_MAP } from '../../common/constants/ApiEndpoints';
import { ROOT_CONTENT_TOP_PADDING } from '../../common/constants/LayoutMetrics';
import { I18nService, LANGUAGE_EN } from '../../common/i18n/I18nService';
import { ServiceResult } from '../../common/net/HttpClient';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../../common/theme/AppTheme';
import { OpenLink } from '../../common/utils/OpenLink';
import { AppBottomSheet } from '../../components/AppBottomSheet';
import { AppCard } from '../../components/AppCard';
import { AppEmptyState } from '../../components/AppEmptyState';
import { AppHdsPage } from '../../components/AppHdsPage';
import { AppLoading } from '../../components/AppLoading';
import { AppToast, AppToastType } from '../../components/AppToast';
import {
  BusLoopState,
  BusPositionInfo,
  BusStopInfo
} from '../../models/Bus';
import { AnalyticsParams, AnalyticsService } from '../../services/AnalyticsService';
import {
  BUS_REFRESH_INTERVAL_MS,
  BUS_STOP_INFOS,
  BusService
} from '../../services/BusService';

const BUS_LAYOUT_BREAKPOINT_MD: number = 600;
const BUS_LAYOUT_BREAKPOINT_LG: number = 840;
const BUS_ROUTE_MAP_WIDTH: number = 310;
const BUS_ROUTE_MAP_HEIGHT: number = 600;
const BUS_ROUTE_CARD_WIDTH: number = 338;
const BUS_LAYOUT_GAP: number = 12;

@Component
export struct BusPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State loopState: BusLoopState = BusService.emptyState();
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State errorMessage: string = '';
  @State showStopSheet: boolean = false;
  @State selectedStopCode: string = 'PGH';
  @State selectedStopTitle: string = 'PGH';
  @State pageViewportWidth: number = 0;
  private timerId: number = -1;

  aboutToAppear(): void {
    const params: AnalyticsParams = new AnalyticsParams();
    params.routeName = 'Bus';
    AnalyticsService.log('openPage', params);
    this.startAutoRefresh();
  }

  aboutToDisappear(): void {
    this.stopAutoRefresh();
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

  private lengthToNumber(value: Length): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      const parsed: number = Number.parseFloat(value);
      return Number.isFinite(parsed) ? parsed : 0;
    }
    return 0;
  }

  private updatePageViewportWidth(value: Length): void {
    const nextWidth: number = this.lengthToNumber(value);
    if (nextWidth > 0 && Math.abs(nextWidth - this.pageViewportWidth) >= 1) {
      this.pageViewportWidth = nextWidth;
    }
  }

  private isPhoneLayout(): boolean {
    return this.pageViewportWidth <= 0 || this.pageViewportWidth < BUS_LAYOUT_BREAKPOINT_MD;
  }

  private isFoldLayout(): boolean {
    return this.pageViewportWidth >= BUS_LAYOUT_BREAKPOINT_MD &&
      this.pageViewportWidth < BUS_LAYOUT_BREAKPOINT_LG;
  }

  private stopButtonWidth(): string {
    if (this.isPhoneLayout()) {
      return '48%';
    }
    if (this.isFoldLayout()) {
      return '23.5%';
    }
    return this.pageViewportWidth >= 1100 ? '48%' : '100%';
  }

  private positionsColumnWidth(): number {
    return this.pageViewportWidth >= 1000 ? 260 : 220;
  }

  private getContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private startAutoRefresh(): void {
    if (this.timerId >= 0) {
      return;
    }
    this.refreshBus(false);
    this.timerId = setInterval(() => {
      this.refreshBus(true);
    }, BUS_REFRESH_INTERVAL_MS);
  }

  private stopAutoRefresh(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private async refreshBus(autoRefresh: boolean): Promise<void> {
    if (!autoRefresh) {
      this.refreshing = true;
    }
    if (this.loopState.lastUpdatedAt === 0) {
      this.loading = true;
    }
    const result: ServiceResult<BusLoopState> = await BusService.fetchLoop(this.isEnglish());
    if (result.ok && result.data) {
      this.loopState = result.data;
      this.errorMessage = '';
      if (!autoRefresh) {
        if (result.data.positions.length === 0) {
          AppToast.show(this.getUIContext(), this.localized('當前沒有巴士', 'No bus is currently shown'),
            AppToastType.Success);
        } else {
          AppToast.show(this.getUIContext(), this.localized('巴士資料已刷新', 'Bus data refreshed'),
            AppToastType.Success);
        }
      }
    } else {
      this.errorMessage = result.error?.message ?? this.localized('巴士資料讀取失敗', 'Failed to load bus data');
      if (!autoRefresh) {
        AppToast.showError(this.getUIContext(), this.errorMessage);
      }
    }
    this.loading = false;
    this.refreshing = false;
  }

  private formatUpdateTime(timestamp: number): string {
    if (timestamp <= 0) {
      return '-';
    }
    const date: Date = new Date(timestamp);
    const hours: string = date.getHours() < 10 ? '0' + date.getHours().toString() : date.getHours().toString();
    const minutes: string = date.getMinutes() < 10 ? '0' + date.getMinutes().toString() : date.getMinutes().toString();
    const seconds: string = date.getSeconds() < 10 ? '0' + date.getSeconds().toString() : date.getSeconds().toString();
    return hours + ':' + minutes + ':' + seconds;
  }

  private stopTitle(stop: BusStopInfo): string {
    return stop.code + ' ' + (this.isEnglish() ? stop.nameEn : stop.nameTc);
  }

  private stopHasBus(stop: BusStopInfo): boolean {
    for (let i = 0; i < this.loopState.positions.length; i++) {
      if (this.loopState.positions[i].index === stop.positionIndex) {
        return true;
      }
    }
    return false;
  }

  private busLeft(index: number): number {
    const values: number[] = [255, 255, 255, 255, 255, 160, 75, 30, 30, 30, 30, 30, 30, 30, 190, 255];
    if (index >= 0 && index < values.length) {
      return values[index];
    }
    return 255;
  }

  private busTop(index: number): number {
    const values: number[] = [450, 380, 300, 200, 80, 30, 58, 120, 155, 210, 265, 330, 390, 500, 493, 500];
    if (index >= 0 && index < values.length) {
      return values[index];
    }
    return 450;
  }

  private stopLeft(stopCode: string): number {
    if (stopCode === 'PGH') {
      return 100;
    }
    if (stopCode === 'E4' || stopCode === 'N2') {
      return 145;
    }
    if (stopCode === 'N6') {
      return 45;
    }
    if (stopCode === 'E11' || stopCode === 'E21' || stopCode === 'E32' || stopCode === 'S4') {
      return stopCode === 'S4' ? 80 : 79;
    }
    return 100;
  }

  private stopTop(stopCode: string): number {
    if (stopCode === 'PGH') {
      return 455;
    }
    if (stopCode === 'E4') {
      return 302;
    }
    if (stopCode === 'N2') {
      return 82;
    }
    if (stopCode === 'N6') {
      return 90;
    }
    if (stopCode === 'E11') {
      return 160;
    }
    if (stopCode === 'E21') {
      return 267;
    }
    if (stopCode === 'E32') {
      return 395;
    }
    return 547;
  }

  private async openMap(): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), UM_MAP);
    if (!success) {
      AppToast.showError(this.getUIContext(), this.localized('無法打開校園地圖', 'Unable to open campus map'));
    }
  }

  private showStop(stop: BusStopInfo): void {
    this.selectedStopCode = stop.code;
    this.selectedStopTitle = this.stopTitle(stop);
    this.showStopSheet = true;
  }

  @Builder
  InfoCardContent(): void {
    Column() {
      Row() {
        Text('Data from: cmdo.um.edu.mo')
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .layoutWeight(1)
        Button(this.localized('校園地圖', 'Map'))
          .height(30)
          .borderRadius(8)
          .fontSize(12)
          .fontColor(this.theme().themeColor)
          .backgroundColor(this.theme().themeColorUltraLight)
          .onClick(() => {
            this.openMap();
          })
      }
      .width('100%')

      Text(this.localized('自動刷新：7 秒；最後刷新：', 'Auto refresh: 7 seconds. Last refresh: ') +
      this.formatUpdateTime(this.loopState.lastUpdatedAt))
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
        .width('100%')
        .margin({ top: 8 })

      if (this.loopState.infoLines.length > 0) {
        Column() {
          ForEach(this.loopState.infoLines, (line: string, index: number) => {
            Text(line)
              .fontSize(13)
              .fontColor(this.theme().textSecondary)
              .width('100%')
              .lineHeight(19)
          }, (line: string, index: number) => index.toString() + line)
        }
        .width('100%')
        .margin({ top: 10 })
      }
    }
    .width('100%')
  }

  @Builder
  InfoCard(): void {
    AppCard({
      content: (): void => {
        this.InfoCardContent();
      }
    })
  }

  @Builder
  RouteCardContent(): void {
    Column() {
      Stack() {
        Image($rawfile('img/Bus/bus_route.png'))
          .width(BUS_ROUTE_MAP_WIDTH)
          .height(BUS_ROUTE_MAP_HEIGHT)
          .objectFit(ImageFit.Contain)

        this.MapCountdown()

        ForEach(this.loopState.positions, (position: BusPositionInfo, index: number) => {
          this.MapBusIcon(position)
        }, (position: BusPositionInfo, index: number) => position.busId + index.toString())

        ForEach(BUS_STOP_INFOS, (stop: BusStopInfo) => {
          this.MapStopLabel(stop)
        }, (stop: BusStopInfo) => stop.code)
      }
      .width(BUS_ROUTE_MAP_WIDTH)
      .height(BUS_ROUTE_MAP_HEIGHT)
      .alignContent(Alignment.TopStart)

      this.MapInfoPanel()
      this.MapDataSource()

      Text(this.localized('點擊站點可查看站點圖；點擊巴士圖標可手動刷新。', 'Tap a stop to view its photo. Tap a bus icon to refresh.'))
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
        .lineHeight(18)
        .textAlign(TextAlign.Center)
        .width(BUS_ROUTE_MAP_WIDTH)
        .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  MapInfoPanel(): void {
    Column() {
      if (this.loopState.infoLines.length > 0) {
        ForEach(this.loopState.infoLines, (line: string, index: number) => {
          Text(line)
            .fontSize(10)
            .fontColor(this.theme().textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }, (line: string, index: number) => index.toString() + line)
      } else {
        Text(this.localized('暫無巴士資訊', 'No bus info'))
          .fontSize(10)
          .fontColor(this.theme().textTertiary)
      }
    }
    .width(BUS_ROUTE_MAP_WIDTH)
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .borderRadius(8)
    .backgroundColor(this.theme().surfaceAltColor)
    .margin({ top: 12 })
  }

  @Builder
  MapDataSource(): void {
    Row() {
      Text('Data From: cmdo.um.edu.mo')
        .fontSize(11)
        .fontColor(this.theme().textTertiary)
        .layoutWeight(1)
      Button(this.localized('校園地圖', 'Map'))
        .height(28)
        .borderRadius(8)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().themeColor)
        .backgroundColor(this.theme().themeColorUltraLight)
        .padding({ left: 8, right: 8 })
        .onClick(() => {
          this.openMap();
        })
    }
    .width(BUS_ROUTE_MAP_WIDTH)
    .margin({ top: 10 })
  }

  @Builder
  MapCountdown(): void {
    Text(this.refreshing ? '...' : '7')
      .width(36)
      .height(36)
      .borderRadius(18)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.theme().textTertiary)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.theme().surfaceColor)
      .border({ width: 3, color: this.theme().themeColor })
      .position({ x: 130, y: 5 })
  }

  @Builder
  MapBusIcon(position: BusPositionInfo): void {
    Image($r('app.media.bus_icon'))
      .width(30)
      .height(30)
      .objectFit(ImageFit.Contain)
      .position({ x: this.busLeft(position.index), y: this.busTop(position.index) })
      .onClick(() => {
        this.refreshBus(false);
      })
  }

  @Builder
  MapStopLabel(stop: BusStopInfo): void {
    Text(stop.code + ' ' + (this.isEnglish() ? stop.nameEn : stop.nameTc))
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.stopHasBus(stop) ? this.theme().secondThemeColor : this.theme().themeColor)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: 5, right: 5, top: 2, bottom: 2 })
      .borderRadius(14)
      .border({ width: 2, color: this.stopHasBus(stop) ? this.theme().secondThemeColor : this.theme().themeColor })
      .backgroundColor(this.theme().surfaceColor)
      .constraintSize({ maxWidth: 160 })
      .position({ x: this.stopLeft(stop.code), y: this.stopTop(stop.code) })
      .onClick(() => {
        this.showStop(stop);
      })
  }

  @Builder
  RouteCard(): void {
    AppCard({
      content: (): void => {
        this.RouteCardContent();
      }
    })
  }

  @Builder
  PositionRow(position: BusPositionInfo): void {
    Row() {
      Image($r('app.media.bus_icon'))
        .width(26)
        .height(26)
        .objectFit(ImageFit.Contain)
        .margin({ right: 10 })
      Column() {
        Text(position.busId)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .width('100%')
        Text(position.stopName)
          .fontSize(13)
          .fontColor(this.theme().textTertiary)
          .width('100%')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 1 }, color: this.theme().borderColor })
  }

  @Builder
  PositionsCardContent(): void {
    Column() {
      Text(this.localized('當前巴士', 'Current buses'))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
        .width('100%')
      if (this.loopState.positions.length === 0) {
        Text(this.localized('當前沒有巴士服務或官方頁面未返回車牌。', 'No bus service is currently shown, or the official page returned no plate number.'))
          .fontSize(13)
          .fontColor(this.theme().textTertiary)
          .lineHeight(19)
          .width('100%')
          .margin({ top: 10 })
      } else {
        ForEach(this.loopState.positions, (position: BusPositionInfo, index: number) => {
          this.PositionRow(position);
        }, (position: BusPositionInfo, index: number) => position.busId + index.toString())
      }
    }
    .width('100%')
  }

  @Builder
  PositionsCard(): void {
    AppCard({
      content: (): void => {
        this.PositionsCardContent();
      }
    })
  }

  @Builder
  StopButton(stop: BusStopInfo): void {
    Column() {
      Text(stop.code)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.stopHasBus(stop) ? Color.White : this.theme().themeColor)
      Text(this.isEnglish() ? stop.nameEn : stop.nameTc)
        .fontSize(11)
        .fontColor(this.stopHasBus(stop) ? Color.White : this.theme().textSecondary)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 3 })
    }
    .width(this.stopButtonWidth())
    .height(72)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 8, right: 8 })
    .borderRadius(8)
    .backgroundColor(this.stopHasBus(stop) ? this.theme().secondThemeColor : this.theme().surfaceAltColor)
    .margin({ bottom: 8 })
    .onClick(() => {
      this.showStop(stop);
    })
  }

  @Builder
  StopsCardContent(): void {
    Column() {
      Text(this.localized('站點', 'Stops'))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
        .width('100%')
        .margin({ bottom: 10 })
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(BUS_STOP_INFOS, (stop: BusStopInfo) => {
          this.StopButton(stop);
        }, (stop: BusStopInfo) => stop.code)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  StopsCard(): void {
    AppCard({
      content: (): void => {
        this.StopsCardContent();
      }
    })
  }

  @Builder
  PhoneBusLayout(): void {
    Column({ space: BUS_LAYOUT_GAP }) {
      this.RouteCard()
      this.StopsCard()
      this.PositionsCard()
    }
    .width('100%')
  }

  @Builder
  FoldBusLayout(): void {
    Column({ space: BUS_LAYOUT_GAP }) {
      Row({ space: BUS_LAYOUT_GAP }) {
        Column() {
          this.RouteCard()
        }
        .width(BUS_ROUTE_CARD_WIDTH)

        Column() {
          this.StopsCard()
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      this.PositionsCard()
    }
    .width('100%')
  }

  @Builder
  ExpandedBusLayout(): void {
    Row({ space: BUS_LAYOUT_GAP }) {
      Column() {
        this.RouteCard()
      }
      .width(BUS_ROUTE_CARD_WIDTH)

      Column() {
        this.StopsCard()
      }
      .layoutWeight(1)

      Column() {
        this.PositionsCard()
      }
      .width(this.positionsColumnWidth())
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  ResponsiveBusLayout(): void {
    if (this.isPhoneLayout()) {
      this.PhoneBusLayout()
    } else if (this.isFoldLayout()) {
      this.FoldBusLayout()
    } else {
      this.ExpandedBusLayout()
    }
  }

  @Builder
  StopRawImage(): void {
    if (this.selectedStopCode === 'PGH') {
      Image($rawfile('img/Bus/stopImg/PGH.jpg')).width('100%').height(260).objectFit(ImageFit.Contain)
    } else if (this.selectedStopCode === 'E4') {
      Image($rawfile('img/Bus/stopImg/E4.jpg')).width('100%').height(260).objectFit(ImageFit.Contain)
    } else if (this.selectedStopCode === 'N2') {
      Image($rawfile('img/Bus/stopImg/N2.jpg')).width('100%').height(260).objectFit(ImageFit.Contain)
    } else if (this.selectedStopCode === 'N6') {
      Image($rawfile('img/Bus/stopImg/N6.jpg')).width('100%').height(260).objectFit(ImageFit.Contain)
    } else if (this.selectedStopCode === 'E11') {
      Image($rawfile('img/Bus/stopImg/E11.jpg')).width('100%').height(260).objectFit(ImageFit.Contain)
    } else if (this.selectedStopCode === 'E21') {
      Image($rawfile('img/Bus/stopImg/E21.jpg')).width('100%').height(260).objectFit(ImageFit.Contain)
    } else if (this.selectedStopCode === 'E32') {
      Image($rawfile('img/Bus/stopImg/E32.jpg')).width('100%').height(260).objectFit(ImageFit.Contain)
    } else {
      Image($rawfile('img/Bus/stopImg/S4.jpg')).width('100%').height(260).objectFit(ImageFit.Contain)
    }
  }

  @Builder
  StopSheetContent(): void {
    AppCard({
      content: (): void => {
        this.StopRawImage();
      }
    })
  }

  @Builder
  PageContent(): void {
    if (this.loading && this.loopState.lastUpdatedAt === 0) {
      Column() {
        AppLoading({
          title: this.localized('載入巴士資料', 'Loading bus data'),
          message: this.localized('正在讀取校園巴士報站頁', 'Reading the campus bus page')
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ left: 16, right: 16 })
    } else if (this.errorMessage.length > 0 && this.loopState.lastUpdatedAt === 0) {
      Column() {
        AppEmptyState({
          title: this.localized('無法讀取巴士', 'Unable to load bus data'),
          description: this.errorMessage,
          actionText: this.localized('重試', 'Retry'),
          onAction: (): void => {
            this.refreshBus(false);
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
          this.InfoCard()
          Column() {
            this.ResponsiveBusLayout()
          }
          .width('100%')
          .margin({ top: BUS_LAYOUT_GAP })
          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(12)
              .fontColor(this.theme().dangerColor)
              .width('100%')
              .lineHeight(18)
              .margin({ top: 12 })
          }
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start)
        .padding({ left: 16, right: 16, bottom: 16 })
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.updatePageViewportWidth(newValue.width);
        })
      }
      .layoutWeight(1)
    }
  }

  build() {
    Stack() {
      AppHdsPage({
        title: this.localized('校園巴士', 'Campus Bus'),
        backLabel: this.localized('返回', 'Back'),
        primaryActionLabel: this.refreshing ? this.localized('刷新中', 'Refreshing') : this.localized('刷新', 'Refresh'),
        primaryActionSymbol: $r('sys.symbol.arrow_clockwise'),
        primaryActionEnabled: !this.refreshing,
        onBack: (): void => {
          this.pathStack.pop();
        },
        onPrimaryAction: (): void => {
          this.refreshBus(false);
        },
        content: (): void => {
          this.PageContent()
        }
      })
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme().bgColor)

      AppBottomSheet({
        visible: $showStopSheet,
        title: this.selectedStopTitle,
        closeText: this.localized('返回', 'Back'),
        content: (): void => {
          this.StopSheetContent();
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bgColor)
  }
}
