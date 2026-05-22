import { common } from '@kit.AbilityKit';
import {
  UM_PRE_ENROLMENT_EXCEL,
  buildOfficialCourseUrl,
  buildWikiSearchUrl
} from '../../common/constants/ApiEndpoints';
import {
  ROUTE_LOCAL_COURSE
} from '../../common/constants/RouteNames';
import {
  ROOT_CONTENT_BOTTOM_PADDING,
  ROOT_CONTENT_TOP_PADDING
} from '../../common/constants/LayoutMetrics';
import { ROOT_TAB_TIMETABLE } from '../../common/constants/TabIndexes';
import { I18nService, LANGUAGE_EN } from '../../common/i18n/I18nService';
import { CourseSimNavigationState } from '../../common/navigation/CourseSimNavigationState';
import { LocalCourseNavigationState } from '../../common/navigation/LocalCourseNavigationState';
import { ServiceResult } from '../../common/net/HttpClient';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../../common/theme/AppTheme';
import { OpenLink } from '../../common/utils/OpenLink';
import { AppCard } from '../../components/AppCard';
import { AppEmptyState } from '../../components/AppEmptyState';
import { AppListItem } from '../../components/AppListItem';
import { AppLoading } from '../../components/AppLoading';
import { AppSearchField } from '../../components/AppSearchField';
import {
  AppSegmentOption,
  AppSegmentedControl
} from '../../components/AppSegmentedControl';
import { AppToast, AppToastType } from '../../components/AppToast';
import {
  CourseCatalogItem,
  CourseCatalogState,
  CourseFilterOptions,
  CourseFilterResult,
  CourseLinkBundle,
  CoursePlanFile,
  CourseSearchResult
} from '../../models/Course';
import { AnalyticsParams, AnalyticsService } from '../../services/AnalyticsService';
import {
  COURSE_FILTER_OPTION_CMRE,
  COURSE_FILTER_OPTION_GE,
  COURSE_MODE_ADD_DROP,
  COURSE_MODE_LABELS_EN,
  COURSE_MODE_LABELS_TC,
  COURSE_MODE_PRE_ENROLL,
  CourseCatalogService,
  CourseCodeLabel
} from '../../services/CourseCatalogService';
import { CourseDataService, CourseUpdateSummary } from '../../services/CourseDataService';
import { UmehHostService, UmehHostState } from '../../services/UmehHostService';

const COURSE_FILTER_OPTIONS: AppSegmentOption[] = [
  { key: COURSE_FILTER_OPTION_CMRE, label: 'CMRE' },
  { key: COURSE_FILTER_OPTION_GE, label: 'GE' }
];
const COURSE_LIST_HORIZONTAL_PADDING: number = 16;
const COURSE_GRID_COLUMN_GAP: number = 10;
const COURSE_GRID_TWO_COLUMN_MIN_WIDTH: number = 640;
const COURSE_GRID_THREE_COLUMN_MIN_WIDTH: number = 960;

function safeText(value: string | undefined): string {
  return value ?? '';
}

@Component
export struct What2RegPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @Consume('appCurrentTabIndex') currentTabIndex: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @StorageLink('what2RegUpdateSheetVisible') showUpdateSheet: boolean = false;
  @State loading: boolean = true;
  @State updating: boolean = false;
  @State errorMessage: string = '';
  @State searchText: string = '';
  @State searchActive: boolean = false;
  @State filterOptions: CourseFilterOptions = CourseCatalogService.defaultFilterOptions();
  @State facultyList: string[] = [];
  @State geList: string[] = [];
  @State departmentList: string[] = [];
  @State displayCourses: CourseCatalogItem[] = [];
  @State allCourseCount: number = 0;
  @State addDropVersion: string = '-';
  @State preEnrollVersion: string = '-';
  @State currentUmehHost: string = UmehHostService.getCurrentHost();
  @State showCourseSheet: boolean = false;
  @State showSearchSheet: boolean = false;
  @State selectedCourseCode: string = '';
  @State selectedCourseTitle: string = '';
  @State selectedCourseTitleChi: string = '';
  @State selectedCourseUnit: string = '';
  @State selectedCourseDepartment: string = '';
  @State private courseGridWidth: number = 0;
  private catalogState: CourseCatalogState | null = null;

  aboutToAppear(): void {
    const params: AnalyticsParams = new AnalyticsParams();
    params.routeName = 'What2Reg';
    AnalyticsService.log('openPage', params);
    this.loadPage(false);
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

  private courseCode(item: CourseCatalogItem): string {
    return item.courseCode;
  }

  private courseTitle(item: CourseCatalogItem): string {
    return item.courseTitle;
  }

  private modeIsPreEnroll(): boolean {
    return this.filterOptions.mode === COURSE_MODE_PRE_ENROLL;
  }

  private activeColor(): string {
    return this.modeIsPreEnroll() ? this.theme().secondThemeColor : this.theme().themeColor;
  }

  private modeOptions(): AppSegmentOption[] {
    const labels: CourseCodeLabel[] = this.isEnglish() ? COURSE_MODE_LABELS_EN : COURSE_MODE_LABELS_TC;
    const result: AppSegmentOption[] = [];
    for (let i = 0; i < labels.length; i++) {
      result.push({
        key: labels[i].code,
        label: labels[i].label
      });
    }
    return result;
  }

  private facultyOptions(): AppSegmentOption[] {
    const result: AppSegmentOption[] = [];
    for (let i = 0; i < this.facultyList.length; i++) {
      result.push({
        key: this.facultyList[i],
        label: this.facultyList[i]
      });
    }
    return result;
  }

  private departmentOptions(): AppSegmentOption[] {
    const result: AppSegmentOption[] = [];
    for (let i = 0; i < this.departmentList.length; i++) {
      result.push({
        key: this.departmentList[i],
        label: this.departmentList[i]
      });
    }
    return result;
  }

  private geOptions(): AppSegmentOption[] {
    const result: AppSegmentOption[] = [];
    for (let i = 0; i < this.geList.length; i++) {
      result.push({
        key: this.geList[i],
        label: this.geList[i]
      });
    }
    return result;
  }

  private indexFor(options: AppSegmentOption[], key: string): number {
    for (let i = 0; i < options.length; i++) {
      if (options[i].key === key) {
        return i;
      }
    }
    return 0;
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

  private updateCourseGridWidth(value: Length): void {
    const listWidth = this.lengthToNumber(value);
    if (listWidth <= 0) {
      return;
    }
    const nextWidth: number = Math.max(0, listWidth - COURSE_LIST_HORIZONTAL_PADDING * 2);
    if (Math.abs(nextWidth - this.courseGridWidth) >= 1) {
      this.courseGridWidth = nextWidth;
    }
  }

  private courseGridColumnCount(): number {
    if (this.courseGridWidth >= COURSE_GRID_THREE_COLUMN_MIN_WIDTH) {
      return 3;
    }
    if (this.courseGridWidth >= COURSE_GRID_TWO_COLUMN_MIN_WIDTH) {
      return 2;
    }
    return 1;
  }

  private courseGridColumnIndexes(): number[] {
    const columns: number = this.courseGridColumnCount();
    const result: number[] = [];
    for (let index = 0; index < columns; index++) {
      result.push(index);
    }
    return result;
  }

  private courseGridRowIndexes(): number[] {
    const columns: number = this.courseGridColumnCount();
    const result: number[] = [];
    for (let index = 0; index < this.displayCourses.length; index += columns) {
      result.push(index);
    }
    return result;
  }

  private hasCourseGridCell(rowStart: number, columnOffset: number): boolean {
    return rowStart + columnOffset < this.displayCourses.length;
  }

  private departmentListFor(state: CourseCatalogState, facultyName: string): string[] {
    for (let i = 0; i < state.facultyDepartments.length; i++) {
      if (state.facultyDepartments[i].facultyName === facultyName) {
        return state.facultyDepartments[i].departments;
      }
    }
    return [];
  }

  private formatVersionSummary(): string {
    return this.localized('Add/Drop：', 'Add/Drop: ') + this.addDropVersion + '\n' +
    this.localized('PreEnroll：', 'PreEnroll: ') + this.preEnrollVersion + '\n' +
    this.localized('目前站點：', 'Current host: ') + this.currentUmehHost;
  }

  private updateStateFromCatalog(state: CourseCatalogState): void {
    this.catalogState = state;
    this.filterOptions = {
      mode: state.normalizedFilterOptions.mode,
      option: state.normalizedFilterOptions.option,
      facultyName: state.normalizedFilterOptions.facultyName,
      depaName: state.normalizedFilterOptions.depaName,
      GE: state.normalizedFilterOptions.GE
    };
    this.facultyList = state.facultyList;
    this.geList = state.geList;
    this.departmentList = this.departmentListFor(state, state.normalizedFilterOptions.facultyName);
    this.allCourseCount = state.offerCourseList.length;
    this.addDropVersion = state.courseVersion.adddrop.updateTime;
    this.preEnrollVersion = state.courseVersion.pre.updateTime;
    this.applySearch();
  }

  private async loadPage(showToast: boolean): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      const hostState: UmehHostState = await UmehHostService.refreshHost(this.getContext());
      this.currentUmehHost = hostState.currentHost;
    } catch (error) {
      this.currentUmehHost = UmehHostService.getCurrentHost();
    }

    const result: ServiceResult<CourseCatalogState> = await CourseCatalogService.loadCatalog(this.getContext());
    if (result.ok && result.data) {
      this.updateStateFromCatalog(result.data);
      if (showToast) {
        AppToast.show(this.getUIContext(), this.localized('課程資料已刷新', 'Course data refreshed'),
          AppToastType.Success);
      }
    } else {
      this.errorMessage = result.error?.message ?? this.localized('課程資料讀取失敗', 'Failed to load course data');
      this.displayCourses = [];
      if (showToast) {
        AppToast.showError(this.getUIContext(), this.errorMessage);
      }
    }
    this.loading = false;
  }

  private async applyFilterOptions(nextOptions: CourseFilterOptions): Promise<void> {
    if (this.catalogState === null) {
      return;
    }
    const state: CourseCatalogState = this.catalogState;
    const offerCourseList: CourseCatalogItem[] =
      CourseCatalogService.getCourseListForMode(nextOptions.mode, state.coursePlanData, state.offerCoursesData);
    const filterResult: CourseFilterResult = CourseCatalogService.buildFilterResult(offerCourseList, nextOptions);
    const nextState: CourseCatalogState = {
      courseMode: filterResult.normalizedFilterOptions.mode,
      courseVersion: state.courseVersion,
      offerCoursesData: state.offerCoursesData,
      coursePlanData: state.coursePlanData,
      coursePlanTimeData: state.coursePlanTimeData,
      offerCourseList: filterResult.offerCourseList,
      facultyList: filterResult.facultyList,
      geList: filterResult.geList,
      facultyDepartments: filterResult.facultyDepartments,
      normalizedFilterOptions: filterResult.normalizedFilterOptions,
      filterCourseList: filterResult.filterCourseList
    };
    this.updateStateFromCatalog(nextState);
    await CourseCatalogService.saveFilterOptions(this.getContext(), this.filterOptions);
  }

  private applySearch(): void {
    if (this.catalogState === null) {
      this.searchActive = false;
      this.displayCourses = [];
      return;
    }

    const timetableCourses: CourseCatalogItem[] =
      CourseCatalogService.timetableCoursesToCatalogItems(this.catalogState.coursePlanTimeData as CoursePlanFile);
    const searchResult: CourseSearchResult =
      CourseCatalogService.buildSearchResults(this.searchText, this.catalogState.offerCourseList, timetableCourses);
    this.searchActive = searchResult.active;
    this.displayCourses = searchResult.active ? searchResult.results : this.catalogState.filterCourseList;
  }

  private makeNextOptions(mode: string, option: string, facultyName: string, depaName: string,
    ge: string): CourseFilterOptions {
    return {
      mode: mode,
      option: option,
      facultyName: facultyName,
      depaName: depaName,
      GE: ge
    };
  }

  private async setCourseMode(mode: string): Promise<void> {
    await this.applyFilterOptions(this.makeNextOptions(mode, this.filterOptions.option, this.filterOptions.facultyName,
      this.filterOptions.depaName, this.filterOptions.GE));
  }

  private async setFilterType(option: string): Promise<void> {
    await this.applyFilterOptions(this.makeNextOptions(this.filterOptions.mode, option, this.filterOptions.facultyName,
      this.filterOptions.depaName, this.filterOptions.GE));
  }

  private async setFaculty(facultyName: string): Promise<void> {
    await this.applyFilterOptions(this.makeNextOptions(this.filterOptions.mode, this.filterOptions.option, facultyName,
      this.filterOptions.depaName, this.filterOptions.GE));
  }

  private async setDepartment(departmentName: string): Promise<void> {
    await this.applyFilterOptions(this.makeNextOptions(this.filterOptions.mode, this.filterOptions.option,
      this.filterOptions.facultyName, departmentName, this.filterOptions.GE));
  }

  private async setGE(ge: string): Promise<void> {
    await this.applyFilterOptions(this.makeNextOptions(this.filterOptions.mode, this.filterOptions.option,
      this.filterOptions.facultyName, this.filterOptions.depaName, ge));
  }

  private selectCourse(item: CourseCatalogItem): void {
    this.selectedCourseCode = this.courseCode(item);
    this.selectedCourseTitle = this.courseTitle(item);
    this.selectedCourseTitleChi = safeText(item.courseTitleChi);
    this.selectedCourseUnit = item.offeringUnit;
    this.selectedCourseDepartment = item.offeringDepartment;
    this.showCourseSheet = true;
  }

  private async openExternal(url: string): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), url);
    if (!success) {
      AppToast.showError(this.getUIContext(), this.localized('無法打開鏈接', 'Unable to open link'));
    }
  }

  private logCourseAction(action: string, value: string): void {
    const params: AnalyticsParams = new AnalyticsParams();
    params.value = action + ':' + value;
    AnalyticsService.log('checkCourse', params);
  }

  private async openCourseAction(action: string): Promise<void> {
    const courseCode: string = this.selectedCourseCode;
    if (courseCode.length === 0) {
      return;
    }
    this.showCourseSheet = false;
    await UmehHostService.refreshHost(this.getContext());
    this.currentUmehHost = UmehHostService.getCurrentHost();
    const links: CourseLinkBundle = CourseCatalogService.buildCourseLinks(courseCode);
    this.logCourseAction(action, courseCode);
    if (action === 'wiki') {
      await this.openExternal(links.wikiUrl);
    } else if (action === 'what2reg') {
      await this.openExternal(links.what2RegUrl);
    } else if (action === 'official') {
      await this.openExternal(links.officialCourseUrl);
    } else if (action === 'local') {
      LocalCourseNavigationState.setPendingCourseCode(courseCode);
      this.pathStack.pushPathByName(ROUTE_LOCAL_COURSE, null);
    } else if (action === 'timetable') {
      CourseSimNavigationState.setPendingKeyword(courseCode);
      this.currentTabIndex = ROOT_TAB_TIMETABLE;
    }
  }

  private async openSearchAction(action: string): Promise<void> {
    const keyword: string = this.searchText.trim();
    if (keyword.length === 0) {
      AppToast.showError(this.getUIContext(), this.localized('請先輸入關鍵字', 'Enter a keyword first'));
      return;
    }
    this.showSearchSheet = false;
    await UmehHostService.refreshHost(this.getContext());
    this.currentUmehHost = UmehHostService.getCurrentHost();
    this.logCourseAction(action, keyword);
    if (action === 'wiki') {
      await this.openExternal(buildWikiSearchUrl(keyword));
    } else if (action === 'what2reg') {
      await this.openExternal(UmehHostService.buildSearchUrl(keyword));
    } else {
      await this.openExternal(buildOfficialCourseUrl(keyword));
    }
  }

  private async manualUpdateCourses(): Promise<void> {
    this.showUpdateSheet = false;
    this.updating = true;
    const result: ServiceResult<CourseUpdateSummary> =
      await CourseDataService.checkCloudCourseVersion(this.getContext());
    if (result.ok && result.data) {
      await this.loadPage(false);
      AppToast.show(this.getUIContext(), result.data.message, AppToastType.Success);
    } else {
      AppToast.showError(this.getUIContext(), result.error?.message ??
      this.localized('課程更新失敗', 'Course update failed'));
    }
    this.updating = false;
  }

  private listTitle(): string {
    if (this.searchActive) {
      return this.localized('搜尋結果', 'Search results') + ' ' + this.displayCourses.length.toString();
    }
    if (this.filterOptions.option === COURSE_FILTER_OPTION_GE) {
      return this.filterOptions.GE + ' ' + this.displayCourses.length.toString();
    }
    return this.filterOptions.facultyName + ' / ' + this.filterOptions.depaName + ' ' +
    this.displayCourses.length.toString();
  }

  @Builder
  SearchBar(horizontalInset: number): void {
    Row() {
      AppSearchField({
        placeholder: this.localized('試試 ECE / Electrical / 電機', 'Try ECE / Electrical / 電機'),
        value: this.searchText,
        accentColor: this.activeColor(),
        onChange: (value: string): void => {
          this.searchText = value;
          this.applySearch();
        },
        onSubmit: (value: string): void => {
          this.searchText = value;
          this.applySearch();
        }
      })
        .layoutWeight(1)

      Button(this.localized('搜尋', 'Links'))
        .width(64)
        .height(38)
        .borderRadius(8)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(this.searchText.trim().length > 0 ? this.activeColor() : this.theme().disabledColor)
        .enabled(this.searchText.trim().length > 0)
        .margin({ left: 8 })
        .onClick(() => {
          this.showSearchSheet = true;
        })
    }
    .width('100%')
    .padding({ left: horizontalInset, right: horizontalInset, top: 4, bottom: 8 })
  }

  @Builder
  FilterTitle(title: string, value: string): void {
    Row() {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textTertiary)
        .layoutWeight(1)
      if (value.length > 0) {
        Text(value)
          .fontSize(12)
          .fontColor(this.activeColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '68%' })
      }
    }
    .width('100%')
    .margin({ top: 12, bottom: 8 })
  }

  @Builder
  FilterPanel(horizontalInset: number): void {
    AppCard({
      content: (): void => {
        this.FilterPanelContent();
      }
    })
    .margin({ left: horizontalInset, right: horizontalInset, bottom: 10 })
  }

  @Builder
  FilterPanelContent(): void {
    Column() {
      this.FilterTitle(this.localized('課程模式', 'Course mode'), '')
      AppSegmentedControl({
        options: this.modeOptions(),
        selectedIndex: this.indexFor(this.modeOptions(), this.filterOptions.mode),
        disabled: this.loading || this.updating,
        onChange: (index: number): void => {
          this.setCourseMode(this.modeOptions()[index].key);
        }
      })

      this.FilterTitle(this.localized('類型', 'Type'),
        this.filterOptions.option === COURSE_FILTER_OPTION_GE ?
        this.localized('通識課', 'General Education') :
        this.localized('必修 / 選修', 'Required / Elective'))
      AppSegmentedControl({
        options: COURSE_FILTER_OPTIONS,
        selectedIndex: this.indexFor(COURSE_FILTER_OPTIONS, this.filterOptions.option),
        disabled: this.loading || this.updating,
        onChange: (index: number): void => {
          this.setFilterType(COURSE_FILTER_OPTIONS[index].key);
        }
      })

      if (this.filterOptions.option === COURSE_FILTER_OPTION_GE) {
        this.FilterTitle('GE', CourseCatalogService.geLabel(this.filterOptions.GE))
        AppSegmentedControl({
          options: this.geOptions(),
          selectedIndex: this.indexFor(this.geOptions(), this.filterOptions.GE),
          disabled: this.loading || this.updating || this.geList.length === 0,
          wrap: true,
          onChange: (index: number): void => {
            this.setGE(this.geOptions()[index].key);
          }
        })
      } else {
        this.FilterTitle(this.localized('學院', 'Faculty'),
          CourseCatalogService.unitLabel(this.filterOptions.facultyName))
        AppSegmentedControl({
          options: this.facultyOptions(),
          selectedIndex: this.indexFor(this.facultyOptions(), this.filterOptions.facultyName),
          disabled: this.loading || this.updating || this.facultyList.length === 0,
          wrap: true,
          onChange: (index: number): void => {
            this.setFaculty(this.facultyOptions()[index].key);
          }
        })

        if (this.departmentList.length > 0) {
          this.FilterTitle(this.localized('學系', 'Department'),
            CourseCatalogService.departmentLabel(this.filterOptions.depaName))
          AppSegmentedControl({
            options: this.departmentOptions(),
            selectedIndex: this.indexFor(this.departmentOptions(), this.filterOptions.depaName),
            disabled: this.loading || this.updating,
            wrap: true,
            onChange: (index: number): void => {
              this.setDepartment(this.departmentOptions()[index].key);
            }
          })
        }
      }
    }
    .width('100%')
  }

  @Builder
  CourseCodeBadge(code: string): void {
    Text(code)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor(Color.White)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .borderRadius(8)
      .backgroundColor(this.activeColor())
      .maxLines(1)
  }

  @Builder
  CourseMetaPill(text: string, color: string): void {
    if (text.length > 0) {
      Text(text)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
        .padding({ left: 7, right: 7, top: 3, bottom: 3 })
        .borderRadius(8)
        .backgroundColor(this.theme().surfaceAltColor)
        .margin({ right: 6, bottom: 6 })
        .maxLines(1)
    }
  }

  @Builder
  CourseCard(item: CourseCatalogItem): void {
    AppCard({
      clickable: true,
      cardPadding: 12,
      onTap: (): void => {
        this.selectCourse(item);
      },
      content: (): void => {
        this.CourseCardContent(item);
      }
    })
  }

  @Builder
  CourseGridCell(rowStart: number, columnOffset: number): void {
    if (this.hasCourseGridCell(rowStart, columnOffset)) {
      Column() {
        this.CourseCard(this.displayCourses[rowStart + columnOffset]);
      }
      .layoutWeight(1)
    } else {
      Column() {
      }
      .layoutWeight(1)
      .height(1)
    }
  }

  @Builder
  CourseGridRow(rowStart: number): void {
    Row({ space: COURSE_GRID_COLUMN_GAP }) {
      ForEach(this.courseGridColumnIndexes(), (columnOffset: number) => {
        this.CourseGridCell(rowStart, columnOffset);
      }, (columnOffset: number) => rowStart.toString() + '-' + columnOffset.toString())
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  CourseCardContent(item: CourseCatalogItem): void {
    Column() {
      Row() {
        this.CourseCodeBadge(this.courseCode(item))
        if (this.modeIsPreEnroll()) {
          Text('PreEnroll')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().secondThemeColor)
            .margin({ left: 8 })
        }
        Text(this.localized('操作', 'Actions'))
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .layoutWeight(1)
          .textAlign(TextAlign.End)
      }
      .width('100%')

      Text(this.courseTitle(item))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme().textPrimary)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 9 })

      if (safeText(item.courseTitleChi).length > 0) {
        Text(safeText(item.courseTitleChi))
          .fontSize(14)
          .fontColor(this.theme().textSecondary)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
      }

      Text(item.offeringUnit + ' / ' + item.offeringDepartment)
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 7 })

      Flex({ wrap: FlexWrap.Wrap }) {
        this.CourseMetaPill(safeText(item.creditUnits).length > 0 ?
        safeText(item.creditUnits) + ' Credit' : '', this.theme().secondThemeColor)
        this.CourseMetaPill(safeText(item.section).length > 0 ? 'Section ' + safeText(item.section) : '',
          this.theme().textSecondary)
        this.CourseMetaPill(safeText(item.day), this.theme().textSecondary)
        this.CourseMetaPill(safeText(item.timeFrom).length > 0 ?
        safeText(item.timeFrom) + '-' + safeText(item.timeTo) : '', this.theme().textSecondary)
      }
      .width('100%')
      .margin({ top: 8 })

      if (safeText(item.teacherInformation).length > 0) {
        Text(safeText(item.teacherInformation))
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ListHeader(horizontalInset: number): void {
    Column() {
      Row() {
        Text(this.listTitle())
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textTertiary)
          .layoutWeight(1)
        if (this.updating) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(this.activeColor())
        }
      }
      .width('100%')

      if (this.searchText.length > 0 && !this.searchActive) {
        Text(this.localized('中文輸入會即時搜尋；英文或課程代碼至少輸入 3 個字符。', 'Chinese searches immediately. English or course code needs at least 3 characters.'))
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .lineHeight(18)
          .width('100%')
          .margin({ top: 6 })
      }
    }
    .width('100%')
    .padding({ left: horizontalInset, right: horizontalInset, bottom: 8 })
  }

  @Builder
  FooterNote(): void {
    Column() {
      Text((this.modeIsPreEnroll() ? this.localized('預選課程', 'PreEnroll courses') :
      this.localized('開設課程', 'Add/Drop courses')) + ': ' + this.allCourseCount.toString())
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
        .textAlign(TextAlign.Center)
        .width('100%')
      Text(this.localized('數據日期版本：', 'Data version: ') +
      (this.modeIsPreEnroll() ? this.preEnrollVersion : this.addDropVersion))
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 4 })
      Text(this.localized('以官方課表 Excel 為準；知識無價，評論只供參考。', 'Use the official timetable Excel as the source of truth. Reviews are for reference.'))
        .fontSize(12)
        .fontColor(this.activeColor())
        .lineHeight(18)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 4 })
    }
    .width('100%')
    .padding({ top: 4, bottom: 20 })
  }

  @Builder
  CourseList(): void {
    List({ space: 10 }) {
      ListItem() {
        Column() {
          Blank()
            .height(ROOT_CONTENT_TOP_PADDING)
        }
      }

      ListItem() {
        this.SearchBar(0)
      }

      ListItem() {
        this.FilterPanel(0)
      }

      ListItem() {
        this.ListHeader(0)
      }

      if (this.displayCourses.length === 0) {
        ListItem() {
          Column() {
            AppEmptyState({
              title: this.searchActive ?
              this.localized('沒有搜尋結果', 'No search results') :
              this.localized('沒有課程', 'No courses'),
              description: this.searchActive ?
              this.localized('請換一個課程代碼、英文名或中文名。', 'Try another course code, English title or Chinese title.') :
              this.localized('請切換學院、學系或 GE 篩選。', 'Try another faculty, department or GE filter.'),
              actionText: this.searchActive ? this.localized('清除搜尋', 'Clear search') : '',
              onAction: (): void => {
                this.searchText = '';
                this.applySearch();
              }
            })
          }
          .height(360)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 16, right: 16 })
        }
      } else {
        ForEach(this.courseGridRowIndexes(), (rowStart: number) => {
          ListItem() {
            this.CourseGridRow(rowStart);
          }
        }, (rowStart: number) => rowStart.toString())

        ListItem() {
          this.FooterNote();
        }
      }

      ListItem() {
        Column() {
          Blank()
            .height(ROOT_CONTENT_BOTTOM_PADDING)
        }
      }
    }
    .layoutWeight(1)
    .padding({ left: COURSE_LIST_HORIZONTAL_PADDING, right: COURSE_LIST_HORIZONTAL_PADDING })
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(this.theme().bgColor)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateCourseGridWidth(newValue.width);
    })
  }

  @Builder
  LoadingStateContent(): void {
    Scroll() {
      Column() {
        Blank()
          .height(ROOT_CONTENT_TOP_PADDING)
        this.SearchBar(16)
        Column() {
          AppLoading({
            title: this.localized('載入課程資料', 'Loading course data'),
            message: this.localized('正在讀取本地課程 JSON 與篩選偏好', 'Reading local course JSON and filters')
          })
        }
        .height(360)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 16, right: 16 })
        Blank()
          .height(ROOT_CONTENT_BOTTOM_PADDING)
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
    }
    .layoutWeight(1)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(this.theme().bgColor)
  }

  @Builder
  ErrorStateContent(): void {
    Scroll() {
      Column() {
        Blank()
          .height(ROOT_CONTENT_TOP_PADDING)
        this.SearchBar(16)
        Column() {
          AppEmptyState({
            title: this.localized('無法讀取課程', 'Unable to load courses'),
            description: this.errorMessage,
            actionText: this.localized('重試', 'Retry'),
            onAction: (): void => {
              this.loadPage(true);
            }
          })
        }
        .height(360)
        .justifyContent(FlexAlign.Center)
        Blank()
          .height(ROOT_CONTENT_BOTTOM_PADDING)
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
    }
    .layoutWeight(1)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(this.theme().bgColor)
  }

  @Builder
  CourseActionSheetContent(): void {
    Scroll() {
      Column() {
        AppCard({
          cardPadding: 0,
          content: (): void => {
            this.CourseActionCardContent();
          }
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 18 })
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  CourseActionCardContent(): void {
    Column() {
      AppListItem({
        title: this.selectedCourseCode,
        subtitle: this.selectedCourseTitleChi.length > 0 ?
        this.selectedCourseTitle + '\n' + this.selectedCourseTitleChi : this.selectedCourseTitle,
        value: this.selectedCourseUnit + '/' + this.selectedCourseDepartment
      })
      AppListItem({
        title: this.localized('寫 Wiki', 'Write Wiki'),
        subtitle: buildWikiSearchUrl(this.selectedCourseCode),
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.openCourseAction('wiki');
        }
      })
      AppListItem({
        title: this.localized('查選咩課', 'Open What2Reg'),
        subtitle: this.currentUmehHost,
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.openCourseAction('what2reg');
        }
      })
      AppListItem({
        title: this.localized('查官方課程', 'Open official course'),
        subtitle: buildOfficialCourseUrl(this.selectedCourseCode),
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.openCourseAction('official');
        }
      })
      if (!this.modeIsPreEnroll()) {
        AppListItem({
          title: this.localized('查 Section', 'Open sections'),
          subtitle: this.localized('本地課節頁後續補齊', 'Local course page will be implemented later'),
          clickable: true,
          showChevron: true,
          onTap: (): void => {
            this.openCourseAction('local');
          }
        })
        AppListItem({
          title: this.localized('查模擬課表', 'Open timetable'),
          subtitle: this.localized('用此課程代碼打開加課面板', 'Open add panel with this course code'),
          clickable: true,
          showChevron: true,
          showDivider: false,
          onTap: (): void => {
            this.openCourseAction('timetable');
          }
        })
      }
    }
    .width('100%')
  }

  @Builder
  SearchActionSheetContent(): void {
    Scroll() {
      Column() {
        AppCard({
          cardPadding: 0,
          content: (): void => {
            this.SearchActionCardContent();
          }
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 18 })
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  SearchActionCardContent(): void {
    Column() {
      AppListItem({
        title: this.localized('寫 Wiki', 'Search Wiki'),
        subtitle: buildWikiSearchUrl(this.searchText.trim()),
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.openSearchAction('wiki');
        }
      })
      AppListItem({
        title: this.localized('查選咩課', 'Search What2Reg'),
        subtitle: UmehHostService.buildSearchUrl(this.searchText.trim()),
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.openSearchAction('what2reg');
        }
      })
      AppListItem({
        title: this.localized('查官方課程', 'Open official course'),
        subtitle: buildOfficialCourseUrl(this.searchText.trim()),
        clickable: true,
        showChevron: true,
        showDivider: false,
        onTap: (): void => {
          this.openSearchAction('official');
        }
      })
    }
    .width('100%')
  }

  @Builder
  UpdateActionItem(title: string, subtitle: string, symbol: Resource, enabled: boolean, onTap: () => void): void {
    AppCard({
      clickable: true,
      disabled: !enabled,
      cardPadding: 0,
      onTap: (): void => {
        onTap();
      },
      content: (): void => {
        this.UpdateActionCardContent(title, subtitle, symbol, enabled);
      }
    })
  }

  @Builder
  UpdateActionCardContent(title: string, subtitle: string, symbol: Resource, enabled: boolean): void {
    Row({ space: 12 }) {
      Stack() {
        if (!enabled && this.updating) {
          LoadingProgress()
            .width(22)
            .height(22)
            .color(this.activeColor())
        } else {
          SymbolGlyph(symbol)
            .fontSize(22)
            .fontColor([this.activeColor()])
        }
      }
      .width(42)
      .height(42)
      .borderRadius(8)
      .backgroundColor(this.theme().surfaceAltColor)

      Column() {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme().textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(subtitle)
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .lineHeight(17)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('>')
        .fontSize(18)
        .fontColor(this.theme().textTertiary)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  UpdateVersionCardContent(): void {
    Column() {
      Text(this.formatVersionSummary())
        .fontSize(13)
        .fontColor(this.theme().textSecondary)
        .lineHeight(20)
        .textAlign(TextAlign.Center)
        .width('100%')
      Text(this.localized('點擊下方按鈕檢查作者是否上傳最新數據；如官方日期已更新但 App 未更新，可重啟 App 或聯絡作者。', 'Use the actions below to check whether the latest data has been uploaded. If the official date changed but the app did not, restart the app or contact the maintainer.'))
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
        .lineHeight(18)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 10 })
    }
    .width('100%')
  }

  @Builder
  UpdateSheetContent(): void {
    Scroll() {
      Column({ space: 10 }) {
        AppCard({
          content: (): void => {
            this.UpdateVersionCardContent();
          }
        })

        this.UpdateActionItem(
          this.updating ? this.localized('更新中', 'Updating') :
          this.localized('手動檢查課表數據更新', 'Check course data update'),
          this.localized('從課程 Worker 拉取最新版本並刷新本地緩存', 'Fetch the latest course data and refresh local cache'),
          $r('sys.symbol.arrow_clockwise'),
          !this.updating,
          (): void => {
            this.manualUpdateCourses();
          }
        )

        this.UpdateActionItem(
          this.localized('檢查官方 SharePoint 版本', 'Open official SharePoint'),
          UM_PRE_ENROLMENT_EXCEL,
          $r('sys.symbol.doc_plaintext'),
          true,
          (): void => {
            this.showUpdateSheet = false;
            this.openExternal(UM_PRE_ENROLMENT_EXCEL);
          }
        )
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 18 })
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring)
  }

  build() {
    Stack() {
      Column() {
      }
      .width(1)
      .height(1)
      .opacity(0)
      .bindSheet($$this.showCourseSheet, this.CourseActionSheetContent(), {
        height: SheetSize.MEDIUM,
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        preferType: SheetType.BOTTOM,
        mode: SheetMode.OVERLAY,
        scrollSizeMode: ScrollSizeMode.CONTINUOUS,
        title: {
          title: this.selectedCourseCode.length > 0 ? this.selectedCourseCode :
          this.localized('課程操作', 'Course actions')
        },
        backgroundColor: this.theme().bgColor,
        showClose: true
      })

      Column() {
      }
      .width(1)
      .height(1)
      .opacity(0)
      .bindSheet($$this.showSearchSheet, this.SearchActionSheetContent(), {
        height: SheetSize.MEDIUM,
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        preferType: SheetType.BOTTOM,
        mode: SheetMode.OVERLAY,
        scrollSizeMode: ScrollSizeMode.CONTINUOUS,
        title: {
          title: this.searchText.trim().length > 0 ? this.searchText.trim() :
          this.localized('搜尋鏈接', 'Search links')
        },
        backgroundColor: this.theme().bgColor,
        showClose: true
      })

      Column() {
      }
      .width(1)
      .height(1)
      .opacity(0)
      .bindSheet($$this.showUpdateSheet, this.UpdateSheetContent(), {
        height: SheetSize.MEDIUM,
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        preferType: SheetType.BOTTOM,
        mode: SheetMode.OVERLAY,
        scrollSizeMode: ScrollSizeMode.CONTINUOUS,
        title: {
          title: this.localized('課程數據更新', 'Course data update')
        },
        backgroundColor: this.theme().bgColor,
        showClose: true
      })

      Column() {
        if (this.loading && this.displayCourses.length === 0) {
          this.LoadingStateContent()
        } else if (this.errorMessage.length > 0 && this.displayCourses.length === 0) {
          this.ErrorStateContent()
        } else {
          this.CourseList()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme().bgColor)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bgColor)
  }
}
