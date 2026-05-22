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
import { AppCard } from '../../components/AppCard';
import { AppEmptyState } from '../../components/AppEmptyState';
import { AppHdsPage } from '../../components/AppHdsPage';
import { AppLoading } from '../../components/AppLoading';
import { AppSearchField } from '../../components/AppSearchField';
import { AppToast, AppToastType } from '../../components/AppToast';
import {
  UmOrgSubUnit,
  UmOrgUnit
} from '../../models/Organization';
import { AnalyticsParams, AnalyticsService } from '../../services/AnalyticsService';
import { OrganizationService } from '../../services/OrganizationService';

@Component
export struct UMOrgPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State orgData: UmOrgUnit[] = [];
  @State displayOrgData: UmOrgUnit[] = [];
  @State collapsedUnitCodes: string[] = [];
  @State searchText: string = '';
  @State loading: boolean = true;
  @State errorMessage: string = '';

  aboutToAppear(): void {
    const params: AnalyticsParams = new AnalyticsParams();
    params.routeName = 'UMOrg';
    AnalyticsService.log('openPage', params);
    this.refresh(false);
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

  private async refresh(showToast: boolean): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    const result: ServiceResult<UmOrgUnit[]> = await OrganizationService.fetchAll();
    if (result.ok && result.data) {
      this.orgData = result.data;
      this.applySearch();
      if (showToast) {
        AppToast.show(this.getUIContext(), this.localized('部門資料已刷新', 'Organization data refreshed'),
          AppToastType.Success);
      }
    } else {
      this.errorMessage = result.error?.message ?? this.localized('部門資料讀取失敗', 'Failed to load organizations');
      this.displayOrgData = [];
      if (showToast) {
        AppToast.showError(this.getUIContext(), this.errorMessage);
      }
    }
    this.loading = false;
  }

  private applySearch(): void {
    this.displayOrgData = OrganizationService.filterUnits(this.orgData, this.searchText);
  }

  private safeSubUnits(unit: UmOrgUnit): UmOrgSubUnit[] {
    return unit.subUnit ?? [];
  }

  private hasMultipleSubUnits(unit: UmOrgUnit): boolean {
    return this.safeSubUnits(unit).length > 1;
  }

  private isCollapsed(unitCode: string): boolean {
    return this.collapsedUnitCodes.includes(unitCode);
  }

  private toggleUnit(unit: UmOrgUnit): void {
    if (!this.hasMultipleSubUnits(unit)) {
      this.openSearch(unit.unitName);
      return;
    }
    if (this.isCollapsed(unit.unitCode)) {
      this.collapsedUnitCodes = this.collapsedUnitCodes.filter((code: string) => code !== unit.unitCode);
    } else {
      const next: string[] = this.collapsedUnitCodes.slice();
      next.push(unit.unitCode);
      this.collapsedUnitCodes = next;
    }
  }

  private async openSearch(query: string): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), OrganizationService.buildSearchUrl(query));
    if (!success) {
      AppToast.showError(this.getUIContext(), this.localized('無法打開搜尋', 'Unable to open search'));
    }
  }

  private async openMap(): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), UM_MAP);
    if (!success) {
      AppToast.showError(this.getUIContext(), this.localized('無法打開校園地圖', 'Unable to open campus map'));
    }
  }

  @Builder
  SearchBar(): void {
    Column() {
      AppSearchField({
        placeholder: this.localized('搜尋部門、子部門或代碼', 'Search units, sub-units or code'),
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

      Row() {
        Text(this.localized('Data from: data.um.edu.mo', 'Data from: data.um.edu.mo'))
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
      .margin({ top: 8 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 10 })
  }

  @Builder
  UnitTitle(unit: UmOrgUnit): void {
    Row() {
      Column() {
        Row() {
          Text(unit.chinUnitName)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(unit.unitCode)
            .fontSize(12)
            .fontColor(this.isCollapsed(unit.unitCode) ? this.theme().themeColor : this.theme().textTertiary)
            .margin({ left: 6 })
        }
        .width('100%')

        Text(OrganizationService.titleCase(unit.unitName))
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .onClick(() => {
        this.toggleUnit(unit);
      })

      Button(this.localized('搜', 'Go'))
        .width(44)
        .height(34)
        .borderRadius(8)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().themeColor)
        .backgroundColor(this.theme().surfaceAltColor)
        .margin({ left: 10 })
        .onClick(() => {
          this.openSearch(unit.unitName);
        })
    }
    .width('100%')
  }

  @Builder
  SubUnitPill(subUnit: UmOrgSubUnit): void {
    Column() {
      Text(subUnit.chinSubUnitName + ' ' + subUnit.subUnitCode)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme().textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(OrganizationService.titleCase(subUnit.subUnitName))
        .fontSize(11)
        .fontColor(this.theme().textTertiary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .borderRadius(8)
    .backgroundColor(this.theme().surfaceAltColor)
    .margin({ right: 8, bottom: 8 })
    .onClick(() => {
      this.openSearch(subUnit.subUnitName);
    })
  }

  @Builder
  OrgCardContent(unit: UmOrgUnit): void {
    Column() {
      this.UnitTitle(unit)
      if (this.hasMultipleSubUnits(unit)) {
        Text(this.isCollapsed(unit.unitCode) ?
        this.localized('已折疊子部門，點擊部門名稱展開', 'Sub-units hidden. Tap the unit name to expand') :
        this.localized('子部門', 'Sub-units'))
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .width('100%')
          .margin({ top: 10, bottom: this.isCollapsed(unit.unitCode) ? 0 : 8 })
        if (!this.isCollapsed(unit.unitCode)) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.safeSubUnits(unit), (subUnit: UmOrgSubUnit, index: number) => {
              this.SubUnitPill(subUnit);
            }, (subUnit: UmOrgSubUnit, index: number) => subUnit.subUnitCode + index.toString())
          }
          .width('100%')
        }
      }
    }
    .width('100%')
  }

  @Builder
  OrgCard(unit: UmOrgUnit): void {
    AppCard({
      content: (): void => {
        this.OrgCardContent(unit);
      }
    })
  }

  @Builder
  PageContent(): void {
    this.SearchBar()

    if (this.loading && this.orgData.length === 0) {
      Column() {
        AppLoading({
          title: this.localized('載入部門資料', 'Loading organizations'),
          message: this.localized('正在讀取 UM Open Data', 'Reading UM Open Data')
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ left: 16, right: 16 })
    } else if (this.errorMessage.length > 0 && this.orgData.length === 0) {
      Column() {
        AppEmptyState({
          title: this.localized('無法讀取部門', 'Unable to load organizations'),
          description: this.errorMessage,
          actionText: this.localized('重試', 'Retry'),
          onAction: (): void => {
            this.refresh(true);
          }
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.displayOrgData.length === 0) {
      Column() {
        AppEmptyState({
          title: this.localized('沒有搜尋結果', 'No results found'),
          description: this.localized('請換一個關鍵字，或刷新部門資料。', 'Try another keyword or refresh the organization data.'),
          actionText: this.localized('清除搜尋', 'Clear search'),
          onAction: (): void => {
            this.searchText = '';
            this.applySearch();
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
          ForEach(this.displayOrgData, (unit: UmOrgUnit, index: number) => {
            this.OrgCard(unit);
          }, (unit: UmOrgUnit, index: number) => unit.unitCode + index.toString())
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
      title: this.localized('澳大部門', 'UM Organizations'),
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
