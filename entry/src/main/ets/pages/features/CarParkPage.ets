import {
  CAR_PARK_FILTER_ALL,
  CAR_PARK_TARGET_MONTHLY_PASS,
  CAR_PARK_TARGET_STAFF,
  CAR_PARK_TARGET_VISITOR,
  CAR_PARK_VEHICLE_LIGHT,
  CAR_PARK_VEHICLE_MOTORCYCLE,
  CarParkAvailabilityItem,
  CarParkRecord
} from '../../models/Parking';
import { ROOT_CONTENT_TOP_PADDING } from '../../common/constants/LayoutMetrics';
import { ServiceResult } from '../../common/net/HttpClient';
import { I18nService } from '../../common/i18n/I18nService';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../../common/theme/AppTheme';
import { AppCard } from '../../components/AppCard';
import { AppEmptyState } from '../../components/AppEmptyState';
import { AppHdsPage } from '../../components/AppHdsPage';
import { AppLoading } from '../../components/AppLoading';
import {
  AppSegmentOption,
  AppSegmentedControl
} from '../../components/AppSegmentedControl';
import { AppToast, AppToastType } from '../../components/AppToast';
import { AnalyticsParams, AnalyticsService } from '../../services/AnalyticsService';
import { CarParkService } from '../../services/CarParkService';

const CAR_PARK_TARGET_OPTIONS: AppSegmentOption[] = [
  { key: CAR_PARK_FILTER_ALL, label: 'All' },
  { key: CAR_PARK_TARGET_STAFF, label: 'Staff' },
  { key: CAR_PARK_TARGET_MONTHLY_PASS, label: 'Monthly Pass' },
  { key: CAR_PARK_TARGET_VISITOR, label: 'Visitor' }
];

const CAR_PARK_VEHICLE_OPTIONS: AppSegmentOption[] = [
  { key: CAR_PARK_FILTER_ALL, label: 'All' },
  { key: CAR_PARK_VEHICLE_LIGHT, label: 'Light Vehicle' },
  { key: CAR_PARK_VEHICLE_MOTORCYCLE, label: 'Motorcycle' }
];

@Component
export struct CarParkPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State carParks: CarParkAvailabilityItem[] = [];
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State targetFilter: string = CAR_PARK_FILTER_ALL;
  @State vehicleFilter: string = CAR_PARK_FILTER_ALL;

  aboutToAppear(): void {
    const params: AnalyticsParams = new AnalyticsParams();
    params.routeName = 'CarPark';
    AnalyticsService.log('openPage', params);
    this.refresh(false);
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

  private parkingTargetText(value: string): string {
    if (value === CAR_PARK_FILTER_ALL) {
      return this.localized('全部', 'All', 'Todos', 'すべて');
    }
    if (value === CAR_PARK_TARGET_STAFF) {
      return this.localized('職員', 'Staff', 'Funcionários', '職員');
    }
    if (value === CAR_PARK_TARGET_MONTHLY_PASS) {
      return this.localized('月票', 'Monthly Pass', 'Passe mensal', '月極');
    }
    if (value === CAR_PARK_TARGET_VISITOR) {
      return this.localized('訪客', 'Visitor', 'Visitante', '来訪者');
    }
    return this.dataText(value, value);
  }

  private vehicleTypeText(value: string): string {
    if (value === CAR_PARK_FILTER_ALL) {
      return this.localized('全部', 'All', 'Todos', 'すべて');
    }
    if (value === CAR_PARK_VEHICLE_LIGHT) {
      return this.localized('輕型車', 'Light Vehicle', 'Veículo ligeiro', '普通車');
    }
    if (value === CAR_PARK_VEHICLE_MOTORCYCLE) {
      return this.localized('電單車', 'Motorcycle', 'Motociclo', 'バイク');
    }
    return this.dataText(value, value);
  }

  private targetOptions(): AppSegmentOption[] {
    const result: AppSegmentOption[] = [];
    for (let i = 0; i < CAR_PARK_TARGET_OPTIONS.length; i++) {
      result.push({
        key: CAR_PARK_TARGET_OPTIONS[i].key,
        label: this.parkingTargetText(CAR_PARK_TARGET_OPTIONS[i].key)
      });
    }
    return result;
  }

  private vehicleOptions(): AppSegmentOption[] {
    const result: AppSegmentOption[] = [];
    for (let i = 0; i < CAR_PARK_VEHICLE_OPTIONS.length; i++) {
      result.push({
        key: CAR_PARK_VEHICLE_OPTIONS[i].key,
        label: this.vehicleTypeText(CAR_PARK_VEHICLE_OPTIONS[i].key)
      });
    }
    return result;
  }

  private placeDescription(code: string): string {
    return this.dataText(CarParkService.getPlaceDescription(code, false), CarParkService.getPlaceDescription(code, true));
  }

  private targetIndex(): number {
    for (let i = 0; i < CAR_PARK_TARGET_OPTIONS.length; i++) {
      if (CAR_PARK_TARGET_OPTIONS[i].key === this.targetFilter) {
        return i;
      }
    }
    return 0;
  }

  private vehicleIndex(): number {
    for (let i = 0; i < CAR_PARK_VEHICLE_OPTIONS.length; i++) {
      if (CAR_PARK_VEHICLE_OPTIONS[i].key === this.vehicleFilter) {
        return i;
      }
    }
    return 0;
  }

  private recordVisible(record: CarParkRecord): boolean {
    const targetMatched: boolean = this.targetFilter === CAR_PARK_FILTER_ALL ||
      record.parkingType === this.targetFilter;
    const vehicleMatched: boolean = this.vehicleFilter === CAR_PARK_FILTER_ALL ||
      record.vehicleType === this.vehicleFilter;
    return targetMatched && vehicleMatched;
  }

  private visibleRecordCount(item: CarParkAvailabilityItem): number {
    let count: number = 0;
    for (let i = 0; i < item.records.length; i++) {
      if (this.recordVisible(item.records[i])) {
        count++;
      }
    }
    return count;
  }

  private async refresh(showToast: boolean): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    const result: ServiceResult<CarParkAvailabilityItem[]> = await CarParkService.fetchLatest();
    if (result.ok && result.data) {
      this.carParks = result.data;
      if (showToast) {
        AppToast.show(this.getUIContext(), this.localized('車位資料已刷新', 'Car park data refreshed'),
          AppToastType.Success);
      }
    } else {
      this.errorMessage = result.error?.message ?? this.localized('車位資料讀取失敗', 'Failed to load car park data');
      if (showToast) {
        AppToast.showError(this.getUIContext(), this.errorMessage);
      }
    }
    this.loading = false;
  }

  @Builder
  SectionTitle(title: string): void {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.theme().textTertiary)
      .width('100%')
      .margin({ top: 16, bottom: 8 })
  }

  @Builder
  FilterSection(): void {
    this.SectionTitle(this.localized('提供對象', 'Parking target'))
    AppSegmentedControl({
      options: this.targetOptions(),
      selectedIndex: this.targetIndex(),
      disabled: this.loading,
      wrap: true,
      onChange: (index: number): void => {
        this.targetFilter = CAR_PARK_TARGET_OPTIONS[index].key;
      }
    })

    this.SectionTitle(this.localized('車輛類型', 'Vehicle type'))
    AppSegmentedControl({
      options: this.vehicleOptions(),
      selectedIndex: this.vehicleIndex(),
      disabled: this.loading,
      wrap: true,
      onChange: (index: number): void => {
        this.vehicleFilter = CAR_PARK_VEHICLE_OPTIONS[index].key;
      }
    })
  }

  @Builder
  RecordRow(record: CarParkRecord): void {
    Column() {
      Row() {
        Text(this.localized('對象：', 'For ', 'Para ', '対象: ') + this.parkingTargetText(record.parkingType))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().themeColor)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (record.noOfAvailableSpace <= 10) {
          Text(this.localized('緊張', 'Tight'))
            .fontSize(11)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(8)
            .backgroundColor(this.theme().dangerColor)
        }
      }
      .width('100%')

      Text(this.vehicleTypeText(record.vehicleType))
        .fontSize(13)
        .fontColor(this.theme().secondThemeColor)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ top: 4 })

      Text(this.localized('剩餘車位：', 'Available spaces: ') + record.noOfAvailableSpace.toString())
        .fontSize(15)
        .fontColor(this.theme().textPrimary)
        .width('100%')
        .margin({ top: 5 })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 1 }, color: this.theme().borderColor })
  }

  @Builder
  ParkCardContent(item: CarParkAvailabilityItem): void {
    Column() {
      Text(item.carParkCode)
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
        .width('100%')

      Text(this.localized('地點：', 'Location: ') +
      this.placeDescription(item.carParkCode))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme().textSecondary)
        .lineHeight(21)
        .width('100%')
        .margin({ top: 4, bottom: 8 })

      if (this.visibleRecordCount(item) === 0) {
        Text(this.localized('當前篩選沒有可顯示記錄', 'No record matches the current filters'))
          .fontSize(13)
          .fontColor(this.theme().textTertiary)
          .width('100%')
          .padding({ top: 12, bottom: 8 })
      } else {
        ForEach(item.records, (record: CarParkRecord, index: number) => {
          if (this.recordVisible(record)) {
            this.RecordRow(record);
          }
        }, (record: CarParkRecord, index: number) => record.parkingType + record.vehicleType + index.toString())
      }
    }
    .width('100%')
  }

  @Builder
  ParkCard(item: CarParkAvailabilityItem): void {
    AppCard({
      content: (): void => {
        this.ParkCardContent(item);
      }
    })
  }

  @Builder
  DataSummary(): void {
    Column() {
      Text('Data from: data.um.edu.mo')
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
        .width('100%')
        .textAlign(TextAlign.Center)

      if (this.carParks.length > 0) {
        Text(this.localized('數據更新時間：', 'Last updated: ', 'Última atualização: ', '最終更新: ') +
        CarParkService.formatRecordDate(this.carParks[0].recordDate))
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }

  @Builder
  PageContent(): void {
    if (this.loading && this.carParks.length === 0) {
      Column() {
        AppLoading({
          title: this.localized('載入車位資料', 'Loading car park data'),
          message: this.localized('正在讀取 UM Open Data', 'Reading UM Open Data')
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ left: 16, right: 16 })
    } else if (this.errorMessage.length > 0 && this.carParks.length === 0) {
      Column() {
        AppEmptyState({
          title: this.localized('無法讀取車位', 'Unable to load car parks'),
          description: this.errorMessage,
          actionText: this.localized('重試', 'Retry'),
          onAction: (): void => {
            this.refresh(true);
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
          this.DataSummary()
          this.FilterSection()
          ForEach(this.carParks, (item: CarParkAvailabilityItem) => {
            this.ParkCard(item);
          }, (item: CarParkAvailabilityItem) => item.carParkCode + item.recordDate)
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start)
        .padding({ left: 16, right: 16, bottom: 16 })
      }
      .layoutWeight(1)
    }
  }

  build() {
    AppHdsPage({
      title: this.localized('車位', 'Car Park'),
      backLabel: this.localized('返回', 'Back'),
      primaryActionLabel: this.localized('刷新', 'Refresh'),
      primaryActionSymbol: $r('sys.symbol.arrow_clockwise'),
      primaryActionEnabled: !this.loading,
      onBack: (): void => {
        this.pathStack.pop();
      },
      onPrimaryAction: (): void => {
        this.refresh(true);
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
