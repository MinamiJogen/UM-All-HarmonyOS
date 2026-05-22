import { common } from '@kit.AbilityKit';
import { UM_ISW } from '../../common/constants/ApiEndpoints';
import {
  ROOT_CONTENT_BOTTOM_PADDING,
  ROOT_CONTENT_TOP_PADDING
} from '../../common/constants/LayoutMetrics';
import { I18nService, LANGUAGE_EN } from '../../common/i18n/I18nService';
import {
  CourseSimNavigationState
} from '../../common/navigation/CourseSimNavigationState';
import { ServiceResult } from '../../common/net/HttpClient';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../../common/theme/AppTheme';
import { WEEK_DAY_CODES, getDateDayCode } from '../../common/utils/DateTime';
import { Haptics } from '../../common/utils/Haptics';
import { OpenLink } from '../../common/utils/OpenLink';
import { AppBottomSheet } from '../../components/AppBottomSheet';
import { AppCard } from '../../components/AppCard';
import { AppDialog } from '../../components/AppDialog';
import { AppEmptyState } from '../../components/AppEmptyState';
import { AppHdsPage } from '../../components/AppHdsPage';
import { AppListItem } from '../../components/AppListItem';
import { AppLoading } from '../../components/AppLoading';
import { AppSearchField } from '../../components/AppSearchField';
import {
  AppSegmentOption,
  AppSegmentedControl
} from '../../components/AppSegmentedControl';
import { AppToast, AppToastType } from '../../components/AppToast';
import {
  CourseLinkBundle,
  CoursePlanFile,
  TimetableBuildResult,
  TimetableCourseMeeting,
  TimetableCourseSummary,
  TimetableSearchFilter,
  TimetableSearchResult,
  TimetableSectionSummary,
  TimetableSelection,
  WeekTimetable,
  WeekTimetableHomeCache
} from '../../models/Course';
import { AnalyticsParams, AnalyticsService } from '../../services/AnalyticsService';
import { CourseCatalogService } from '../../services/CourseCatalogService';
import { CourseDataService } from '../../services/CourseDataService';
import { CourseTimetableService } from '../../services/CourseTimetableService';
import { UmehHostService } from '../../services/UmehHostService';

const DAY_FILTER_ALL: string = 'ALL';
const TIME_FILTER_ALL: string = 'all';
const TIME_FILTER_MORNING: string = 'morning';
const TIME_FILTER_AFTERNOON: string = 'afternoon';
const TIME_FILTER_EVENING: string = 'evening';

const TIMETABLE_COLORS: string[] = [
  '#C9E1F5',
  '#FFE1C7',
  '#D6F2DF',
  '#F5D4E8',
  '#E4DCF8',
  '#F5E8B8',
  '#D4EEF3',
  '#FFD6D6'
];

function emptyWeekTimetable(): WeekTimetable {
  return {
    MON: [],
    TUE: [],
    WED: [],
    THU: [],
    FRI: [],
    SAT: [],
    SUN: []
  };
}

function emptyHomeCache(): WeekTimetableHomeCache {
  return {
    MON: [],
    TUE: [],
    WED: [],
    THU: [],
    FRI: [],
    SAT: [],
    SUN: []
  };
}

function emptyBuildResult(): TimetableBuildResult {
  return {
    selections: [],
    allMeetings: [],
    weekTimetable: emptyWeekTimetable(),
    homeCache: emptyHomeCache(),
    missingSelections: [],
    hasConflict: false
  };
}

function emptySearchResult(): TimetableSearchResult {
  return {
    active: false,
    keyword: '',
    results: []
  };
}

function safeText(value: string | undefined): string {
  return value ?? '';
}

function meetingsForDay(weekTimetable: WeekTimetable, day: string): TimetableCourseMeeting[] {
  if (day === 'MON') {
    return weekTimetable.MON;
  }
  if (day === 'TUE') {
    return weekTimetable.TUE;
  }
  if (day === 'WED') {
    return weekTimetable.WED;
  }
  if (day === 'THU') {
    return weekTimetable.THU;
  }
  if (day === 'FRI') {
    return weekTimetable.FRI;
  }
  if (day === 'SAT') {
    return weekTimetable.SAT;
  }
  return weekTimetable.SUN;
}

function colorForIndex(index: number): string {
  if (TIMETABLE_COLORS.length === 0) {
    return '#C9E1F5';
  }
  return TIMETABLE_COLORS[Math.max(0, index) % TIMETABLE_COLORS.length];
}

function timeRange(timeFrom: string | undefined, timeTo: string | undefined): string {
  return safeText(timeFrom) + ' - ' + safeText(timeTo);
}

function selectionKey(selection: TimetableSelection): string {
  return selection.courseCode + '-' + selection.section;
}

@Component
export struct CourseSimPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  showBack: boolean = false;
  @State loading: boolean = true;
  @State busy: boolean = false;
  @State errorMessage: string = '';
  @State importText: string = '';
  @State searchText: string = '';
  @State selectedDayFilter: string = DAY_FILTER_ALL;
  @State selectedTimeFilter: string = TIME_FILTER_ALL;
  @StorageLink('courseSimAddSheetVisible') showAddSheet: boolean = false;
  @State showMeetingSheet: boolean = false;
  @State coursePlanData: CoursePlanFile = { Courses: [] };
  @State coursePlanTimeData: CoursePlanFile = { Courses: [] };
  @State timetableResult: TimetableBuildResult = emptyBuildResult();
  @State searchResult: TimetableSearchResult = emptySearchResult();
  @State selectedCourseCode: string = '';
  @State selectedSection: string = '';
  @State selectedCourseTitle: string = '';
  @State selectedCourseTitleChi: string = '';
  @State selectedTeacher: string = '';
  @State selectedClassroom: string = '';
  @State selectedDay: string = '';
  @State selectedTime: string = '';
  @State selectedConflict: boolean = false;

  aboutToAppear(): void {
    const params: AnalyticsParams = new AnalyticsParams();
    params.routeName = 'CourseSim';
    AnalyticsService.log('openPage', params);
    this.loadPage();
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

  private hasCourseData(): boolean {
    return this.coursePlanData.Courses.length > 0 && this.coursePlanTimeData.Courses.length > 0;
  }

  private hasTimetable(): boolean {
    return this.timetableResult.allMeetings.length > 0;
  }

  private dayMeetings(day: string): TimetableCourseMeeting[] {
    return meetingsForDay(this.timetableResult.weekTimetable, day);
  }

  private dayMeetingCount(day: string): number {
    return this.dayMeetings(day).length;
  }

  private todayCode(): string {
    return getDateDayCode(new Date());
  }

  private dayFilterOptions(): AppSegmentOption[] {
    const result: AppSegmentOption[] = [
      { key: DAY_FILTER_ALL, label: this.localized('全部', 'All') }
    ];
    for (let i = 0; i < WEEK_DAY_CODES.length; i++) {
      result.push({
        key: WEEK_DAY_CODES[i],
        label: WEEK_DAY_CODES[i]
      });
    }
    return result;
  }

  private timeFilterOptions(): AppSegmentOption[] {
    return [
      { key: TIME_FILTER_ALL, label: this.localized('全天', 'All day') },
      { key: TIME_FILTER_MORNING, label: this.localized('上午', 'Morning') },
      { key: TIME_FILTER_AFTERNOON, label: this.localized('下午', 'Afternoon') },
      { key: TIME_FILTER_EVENING, label: this.localized('晚上', 'Evening') }
    ];
  }

  private indexFor(options: AppSegmentOption[], key: string): number {
    for (let i = 0; i < options.length; i++) {
      if (options[i].key === key) {
        return i;
      }
    }
    return 0;
  }

  private searchFilter(): TimetableSearchFilter {
    let timeFrom: string = '00:00';
    let timeTo: string = '23:59';
    if (this.selectedTimeFilter === TIME_FILTER_MORNING) {
      timeFrom = '08:00';
      timeTo = '12:30';
    } else if (this.selectedTimeFilter === TIME_FILTER_AFTERNOON) {
      timeFrom = '12:30';
      timeTo = '18:00';
    } else if (this.selectedTimeFilter === TIME_FILTER_EVENING) {
      timeFrom = '18:00';
      timeTo = '23:59';
    }
    return {
      day: this.selectedDayFilter === DAY_FILTER_ALL ? '' : this.selectedDayFilter,
      timeFrom: timeFrom,
      timeTo: timeTo
    };
  }

  private async loadPage(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      await UmehHostService.refreshHost(this.getContext());
    } catch (error) {
    }

    const coursePlanResult: ServiceResult<CoursePlanFile> = await CourseDataService.getCoursePlan(this.getContext());
    const coursePlanTimeResult: ServiceResult<CoursePlanFile> =
      await CourseDataService.getCoursePlanTime(this.getContext());
    const timetableResult: ServiceResult<TimetableBuildResult> =
      await CourseTimetableService.loadTimetable(this.getContext());

    if (!coursePlanResult.ok || !coursePlanResult.data) {
      this.errorMessage = coursePlanResult.error?.message ?? this.localized('課程資料讀取失敗', 'Failed to load course data');
    } else if (!coursePlanTimeResult.ok || !coursePlanTimeResult.data) {
      this.errorMessage = coursePlanTimeResult.error?.message ??
      this.localized('課程時間表讀取失敗', 'Failed to load course timetable');
    } else if (!timetableResult.ok || !timetableResult.data) {
      this.errorMessage = timetableResult.error?.message ??
      this.localized('模擬課表讀取失敗', 'Failed to load saved timetable');
    } else {
      this.coursePlanData = coursePlanResult.data;
      this.coursePlanTimeData = coursePlanTimeResult.data;
      this.timetableResult = timetableResult.data;
      const pendingKeyword: string = CourseSimNavigationState.consumePendingKeyword();
      if (pendingKeyword.length > 0) {
        this.searchText = pendingKeyword;
        this.showAddSheet = true;
      }
      this.applySearch();
    }
    this.loading = false;
  }

  private closeAddSheetAfterAction(): void {
    this.showAddSheet = false;
  }

  private applySearch(): void {
    if (!this.hasCourseData()) {
      this.searchResult = emptySearchResult();
      return;
    }
    this.searchResult = CourseTimetableService.buildSearchResults(this.searchText, this.coursePlanData,
      this.coursePlanTimeData, this.searchFilter());
  }

  private async applyTimetableServiceResult(result: ServiceResult<TimetableBuildResult>,
    successMessage: string): Promise<void> {
    if (result.ok && result.data) {
      this.timetableResult = result.data;
      this.applySearch();
      if (successMessage.length > 0) {
        AppToast.show(this.getUIContext(), successMessage, AppToastType.Success);
      }
    } else {
      AppToast.showError(this.getUIContext(), result.error?.message ??
      this.localized('課表操作失敗', 'Timetable action failed'));
    }
  }

  private async importTimetable(): Promise<void> {
    if (this.importText.trim().length === 0 || this.busy) {
      return;
    }
    this.busy = true;
    const result: ServiceResult<TimetableBuildResult> =
      await CourseTimetableService.importFromText(this.getContext(), this.importText);
    await this.applyTimetableServiceResult(result, this.localized('課表已導入', 'Timetable imported'));
    if (result.ok) {
      this.importText = '';
      this.closeAddSheetAfterAction();
    }
    this.busy = false;
  }

  private async addSection(courseCode: string, section: string): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    const result: ServiceResult<TimetableBuildResult> = await CourseTimetableService.addCourseSection(this.getContext(), {
      courseCode: courseCode,
      section: section
    });
    await this.applyTimetableServiceResult(result, this.localized('已加入課表', 'Added to timetable'));
    if (result.ok) {
      this.closeAddSheetAfterAction();
    }
    this.busy = false;
  }

  private async addAllSections(courseCode: string): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    const result: ServiceResult<TimetableBuildResult> =
      await CourseTimetableService.addAllSectionsForCourse(this.getContext(), courseCode);
    await this.applyTimetableServiceResult(result, this.localized('已加入所有 Section', 'All sections added'));
    if (result.ok) {
      this.closeAddSheetAfterAction();
    }
    this.busy = false;
  }

  private async dropSelectedSection(): Promise<void> {
    const confirmed: boolean = await AppDialog.confirm(this.getUIContext(), {
      title: this.localized('刪除課節', 'Drop section'),
      message: this.selectedCourseCode + ' ' + this.selectedSection,
      confirmText: this.localized('刪除', 'Drop'),
      cancelText: this.localized('取消', 'Cancel')
    });
    if (!confirmed) {
      return;
    }
    const result: ServiceResult<TimetableBuildResult> = await CourseTimetableService.dropCourseSection(this.getContext(), {
      courseCode: this.selectedCourseCode,
      section: this.selectedSection
    });
    await this.applyTimetableServiceResult(result, this.localized('已刪除課節', 'Section dropped'));
    this.showMeetingSheet = false;
  }

  private async dropCourseByCode(courseCode: string, closeSheets: boolean): Promise<void> {
    const confirmed: boolean = await AppDialog.confirm(this.getUIContext(), {
      title: this.localized('刪除課程', 'Drop course'),
      message: courseCode,
      confirmText: this.localized('刪除全部 Section', 'Drop all sections'),
      cancelText: this.localized('取消', 'Cancel')
    });
    if (!confirmed) {
      return;
    }
    const result: ServiceResult<TimetableBuildResult> =
      await CourseTimetableService.dropCourse(this.getContext(), courseCode);
    await this.applyTimetableServiceResult(result, this.localized('已刪除課程', 'Course dropped'));
    if (closeSheets) {
      this.showMeetingSheet = false;
      this.closeAddSheetAfterAction();
    }
  }

  private async clearTimetable(): Promise<void> {
    const confirmed: boolean = await AppDialog.confirm(this.getUIContext(), {
      title: this.localized('清空課表', 'Clear timetable'),
      message: this.localized('這會刪除目前模擬課表內所有課程。', 'This removes every course in the simulated timetable.'),
      confirmText: this.localized('確定清空', 'Clear'),
      cancelText: this.localized('取消', 'Cancel')
    });
    if (!confirmed) {
      return;
    }
    const result: ServiceResult<TimetableBuildResult> = await CourseTimetableService.clearTimetable(this.getContext());
    await this.applyTimetableServiceResult(result, this.localized('課表已清空', 'Timetable cleared'));
  }

  private async openExternal(url: string): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), url);
    if (!success) {
      AppToast.showError(this.getUIContext(), this.localized('無法打開鏈接', 'Unable to open link'));
    }
  }

  private async openSelectedAction(action: string): Promise<void> {
    if (this.selectedCourseCode.length === 0) {
      return;
    }
    await UmehHostService.refreshHost(this.getContext());
    const links: CourseLinkBundle = CourseCatalogService.buildCourseLinks(this.selectedCourseCode);
    if (action === 'wiki') {
      await this.openExternal(links.wikiUrl);
    } else if (action === 'what2reg') {
      await this.openExternal(links.what2RegUrl);
    } else {
      await this.openExternal(links.officialCourseUrl);
    }
  }

  private openAddSheet(keyword: string): void {
    Haptics.trigger();
    if (keyword.length > 0) {
      this.searchText = keyword;
      this.applySearch();
    }
    this.showAddSheet = true;
  }

  private selectMeeting(meeting: TimetableCourseMeeting): void {
    Haptics.trigger();
    this.selectedCourseCode = meeting.courseCode;
    this.selectedSection = meeting.section;
    this.selectedCourseTitle = meeting.courseTitle;
    this.selectedCourseTitleChi = safeText(meeting.courseTitleChi);
    this.selectedTeacher = safeText(meeting.teacherInformation);
    this.selectedClassroom = safeText(meeting.classroom);
    this.selectedDay = safeText(meeting.day);
    this.selectedTime = timeRange(meeting.timeFrom, meeting.timeTo);
    this.selectedConflict = meeting.conflict;
    this.showMeetingSheet = true;
  }

  private courseSectionCount(courseCode: string): number {
    let count: number = 0;
    for (let i = 0; i < this.timetableResult.selections.length; i++) {
      if (this.timetableResult.selections[i].courseCode === courseCode) {
        count++;
      }
    }
    return count;
  }

  private breakText(meeting: TimetableCourseMeeting): string {
    if (meeting.conflictWithPrevious || meeting.breakBeforeMinutes < 0) {
      return this.localized('課程衝突', 'Schedule conflict');
    }
    if (meeting.breakBeforeMinutes >= 60) {
      const hours: number = Math.floor(meeting.breakBeforeMinutes / 60);
      const minutes: number = meeting.breakBeforeMinutes % 60;
      return minutes > 0 ?
      this.localized('休息 ', 'Break ') + hours.toString() + 'h ' + minutes.toString() + 'm' :
      this.localized('休息 ', 'Break ') + hours.toString() + 'h';
    }
    return this.localized('休息 ', 'Break ') + meeting.breakBeforeMinutes.toString() +
    this.localized(' 分鐘', ' min');
  }

  private periodLabel(meeting: TimetableCourseMeeting): string {
    if (meeting.periodHint === 'evening') {
      return this.localized('晚上', 'Evening');
    }
    if (meeting.periodHint === 'afternoon') {
      return this.localized('下午', 'Afternoon');
    }
    return '';
  }

  private selectedMeetingSubtitle(): string {
    let subtitle: string = this.selectedCourseTitle;
    if (this.selectedCourseTitleChi.length > 0) {
      subtitle += '\n' + this.selectedCourseTitleChi;
    }
    return subtitle;
  }

  private missingSelectionsText(): string {
    const values: string[] = [];
    for (let i = 0; i < this.timetableResult.missingSelections.length; i++) {
      values.push(selectionKey(this.timetableResult.missingSelections[i]));
    }
    return values.join(', ');
  }

  @Builder
  HeaderButton(label: string, enabled: boolean, onTap: () => void): void {
    Button(label)
      .height(34)
      .padding({ left: 10, right: 10 })
      .borderRadius(8)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(enabled ? this.theme().themeColor : this.theme().textTertiary)
      .backgroundColor(this.theme().surfaceAltColor)
      .enabled(enabled)
      .onClick(() => {
        onTap();
      })
  }

  @Builder
  PageHeader(): void {
    if (this.timetableResult.selections.length > 0) {
      Row({ space: 12 }) {
        Row() {
          this.HeaderButton(this.localized('清空', 'Clear'), !this.busy, (): void => {
            this.clearTimetable();
          })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height(46)
      .padding({ left: 16, right: 16, top: 4, bottom: 8 })
    }
  }

  @Builder
  StatPill(label: string, value: string, color: string): void {
    Column() {
      Text(value)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .maxLines(1)
      Text(label)
        .fontSize(11)
        .fontColor(this.theme().textTertiary)
        .margin({ top: 2 })
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(54)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.theme().surfaceAltColor)
    .borderRadius(8)
  }

  @Builder
  SummaryCard(): void {
    AppCard({
      cardPadding: 10,
      content: (): void => {
        this.SummaryCardContent();
      }
    })
    .margin({ left: 16, right: 16, bottom: 10 })
  }

  @Builder
  SummaryCardContent(): void {
    Row({ space: 8 }) {
      this.StatPill(this.localized('課程', 'Courses'), this.timetableResult.selections.length.toString(),
        this.theme().themeColor)
      this.StatPill(this.localized('課節', 'Meetings'), this.timetableResult.allMeetings.length.toString(),
        this.theme().secondThemeColor)
      this.StatPill(this.localized('狀態', 'Status'), this.timetableResult.hasConflict ?
      this.localized('衝突', 'Conflict') : this.localized('正常', 'OK'),
        this.timetableResult.hasConflict ? this.theme().dangerColor : this.theme().successColor)
    }
    .width('100%')
  }

  @Builder
  FirstUseGuide(): void {
    Column() {
      Text(this.localized('如何開始使用模擬課表？', 'How to start your timetable'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 12, bottom: 14 })

      AppCard({
        content: (): void => {
          this.MethodOneCardContent();
        }
      })
      .margin({ bottom: 12 })

      AppCard({
        content: (): void => {
          this.MethodTwoCardContent();
        }
      })

      Text('umacark@gmail.com')
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 18, bottom: 20 })
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: ROOT_CONTENT_TOP_PADDING,
      bottom: this.showBack ? 0 : ROOT_CONTENT_BOTTOM_PADDING
    })
  }

  @Builder
  MethodOneCardContent(): void {
    Column() {
      Text(this.localized('方法 1', 'Method 1'))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().themeColor)
        .width('100%')
      Text(this.localized('用右上角「搵課/加課」搜尋課程，然後加入單個 Section 或該課全部 Section。',
        'Use Add to search courses, then add one section or every section of the course.'))
        .fontSize(14)
        .fontColor(this.theme().textSecondary)
        .lineHeight(21)
        .width('100%')
        .margin({ top: 8 })
      Button(this.localized('手動搵課/加課', 'Search and add manually'))
        .height(40)
        .borderRadius(8)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(this.theme().themeColor)
        .width('100%')
        .margin({ top: 12 })
        .onClick(() => {
          this.openAddSheet('');
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  MethodTwoCardContent(): void {
    Column() {
      Text(this.localized('方法 2', 'Method 2'))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().secondThemeColor)
        .width('100%')
      Text(this.localized('在舊 ISW 複製 Timetable 文字，貼到下方輸入框後一鍵導入。',
        'Copy the Timetable text from old ISW, paste it below, and import it.'))
        .fontSize(14)
        .fontColor(this.theme().textSecondary)
        .lineHeight(21)
        .width('100%')
        .margin({ top: 8 })
      this.ImportForm()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ImportForm(): void {
    Column() {
      Button(this.localized('打開舊 ISW', 'Open old ISW'))
        .height(38)
        .borderRadius(8)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().themeColor)
        .backgroundColor(this.theme().surfaceAltColor)
        .width('100%')
        .margin({ top: 12 })
        .onClick(() => {
          this.openExternal(UM_ISW);
        })

      TextArea({
        placeholder: 'ACCT1000(001)  GESB1001/1002(001) ...',
        text: this.importText
      })
        .height(132)
        .fontSize(13)
        .fontColor(this.theme().textPrimary)
        .placeholderColor(this.theme().textTertiary)
        .backgroundColor(this.theme().surfaceAltColor)
        .borderRadius(8)
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
        .margin({ top: 10 })
        .onChange((value: string) => {
          this.importText = value;
        })

      Button(this.busy ? this.localized('導入中', 'Importing') :
      this.localized('一鍵導入到模擬課表', 'Import to timetable'))
        .height(40)
        .borderRadius(8)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(this.importText.trim().length > 0 ? this.theme().successColor : this.theme().disabledColor)
        .enabled(this.importText.trim().length > 0 && !this.busy)
        .width('100%')
        .margin({ top: 10 })
        .onClick(() => {
          this.importTimetable();
        })
    }
    .width('100%')
  }

  @Builder
  DayColumn(day: string): void {
    Column() {
      Text(day)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.todayCode() === day ? this.theme().themeColor : this.theme().textTertiary)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ bottom: 8 })

      if (this.dayMeetingCount(day) === 0) {
        Column() {
          Text(this.localized('無課', 'Free'))
            .fontSize(13)
            .fontColor(this.theme().textTertiary)
        }
        .height(92)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(this.theme().surfaceColor)
        .borderRadius(8)
        .border({ width: 1, color: this.theme().borderColor })
      } else {
        ForEach(this.dayMeetings(day), (meeting: TimetableCourseMeeting, index: number) => {
          if (index > 0) {
            Text(this.breakText(meeting))
              .fontSize(11)
              .fontWeight(meeting.conflictWithPrevious ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(meeting.conflictWithPrevious ? this.theme().dangerColor : this.theme().textTertiary)
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ top: 4, bottom: 4 })
          }
          this.MeetingCard(meeting)
        }, (meeting: TimetableCourseMeeting, index: number) =>
        meeting.courseCode + meeting.section + meeting.day + safeText(meeting.timeFrom) + index.toString())
      }
    }
    .width(144)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  MeetingCard(meeting: TimetableCourseMeeting): void {
    Column() {
      if (this.periodLabel(meeting).length > 0) {
        Text(this.periodLabel(meeting))
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textSecondary)
          .margin({ bottom: 5 })
      }

      Text(meeting.courseCode.substring(0, 4))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
        .opacity(0.78)
      Text(meeting.courseCode.substring(4))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
      Text(meeting.section)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textSecondary)
        .margin({ top: 2 })
      Text(meeting.courseTitle)
        .fontSize(11)
        .fontColor(this.theme().textSecondary)
        .textAlign(TextAlign.Center)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 6 })
      Text(safeText(meeting.classroom).length > 0 ? safeText(meeting.classroom) : '-')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textSecondary)
        .margin({ top: 6 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row() {
        Text(safeText(meeting.timeFrom))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
        Text('...')
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text(safeText(meeting.timeTo))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
      }
      .width('100%')
      .margin({ top: 7 })

      if (meeting.conflict) {
        Text(this.localized('衝突', 'Conflict'))
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .borderRadius(8)
          .backgroundColor(this.theme().dangerColor)
          .margin({ top: 6 })
      }
    }
    .width('100%')
    .padding(8)
    .borderRadius(8)
    .backgroundColor(meeting.conflict ? '#FFD6D6' : colorForIndex(meeting.color))
    .border({ width: 1, color: meeting.conflict ? this.theme().dangerColor : this.theme().borderColor })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.selectMeeting(meeting);
    })
  }

  @Builder
  TimetableBoard(): void {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(WEEK_DAY_CODES, (day: string) => {
          this.DayColumn(day)
        }, (day: string) => day)
      }
      .padding({ left: 16, right: 16, bottom: 16 })
      .alignItems(VerticalAlign.Top)
    }
    .scrollable(ScrollDirection.Horizontal)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  Reminder(): void {
    Column() {
      if (this.timetableResult.missingSelections.length > 0) {
        Text(this.localized('以下已選 Section 未找到有效時間：', 'Selected sections with no valid time: ') +
        this.missingSelectionsText())
          .fontSize(12)
          .fontColor(this.theme().warningColor)
          .textAlign(TextAlign.Center)
          .lineHeight(18)
          .width('100%')
      }
      Text(this.localized('請以官方課表版本為準；此頁只作模擬。', 'Use the official timetable as the source of truth.'))
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 4, bottom: 8 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 8 })
  }

  @Builder
  SearchBar(): void {
    Row() {
      AppSearchField({
        placeholder: this.localized('搜索課程：ECE, 電氣, AIM...', 'Search courses: ECE, Electrical, AIM...'),
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
        .layoutWeight(1)

      if (this.searchText.length > 0) {
        Button('X')
          .width(38)
          .height(38)
          .borderRadius(8)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().themeColor)
          .backgroundColor(this.theme().surfaceAltColor)
          .margin({ left: 8 })
          .onClick(() => {
            this.searchText = '';
            this.applySearch();
          })
      }
    }
    .width('100%')
  }

  @Builder
  FilterPanel(): void {
    Column() {
      Text(this.localized('星期', 'Day'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textTertiary)
        .width('100%')
        .margin({ top: 10, bottom: 6 })
      AppSegmentedControl({
        options: this.dayFilterOptions(),
        selectedIndex: this.indexFor(this.dayFilterOptions(), this.selectedDayFilter),
        wrap: true,
        onChange: (index: number): void => {
          this.selectedDayFilter = this.dayFilterOptions()[index].key;
          this.applySearch();
        }
      })

      Text(this.localized('時間', 'Time'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textTertiary)
        .width('100%')
        .margin({ top: 10, bottom: 6 })
      AppSegmentedControl({
        options: this.timeFilterOptions(),
        selectedIndex: this.indexFor(this.timeFilterOptions(), this.selectedTimeFilter),
        onChange: (index: number): void => {
          this.selectedTimeFilter = this.timeFilterOptions()[index].key;
          this.applySearch();
        }
      })
    }
    .width('100%')
  }

  @Builder
  SearchResults(): void {
    if (!this.searchResult.active) {
      AppEmptyState({
        title: this.localized('輸入關鍵字', 'Enter a keyword'),
        description: this.localized('中文會即時搜尋；英文或課程代碼至少輸入 3 個字符。',
          'Chinese searches immediately. English or course codes need at least 3 characters.')
      })
      .margin({ top: 18 })
    } else if (this.searchResult.results.length === 0) {
      AppEmptyState({
        title: this.localized('沒有搜尋結果', 'No search results'),
        description: this.localized('請換一個課程代碼、英文名、中文名或老師。',
          'Try another course code, title, Chinese title, or teacher.')
      })
      .margin({ top: 18 })
    } else if (this.searchResult.results.length === 1) {
      this.SingleCourseResult(this.searchResult.results[0])
    } else {
      this.MultiCourseResults()
    }
  }

  @Builder
  MultiCourseResults(): void {
    Column() {
      Text(this.localized('搜尋結果', 'Search results') + ' ' + this.searchResult.results.length.toString())
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textTertiary)
        .width('100%')
        .margin({ top: 12, bottom: 8 })
      ForEach(this.searchResult.results, (course: TimetableCourseSummary) => {
        AppCard({
          clickable: true,
          cardPadding: 10,
          onTap: (): void => {
            this.searchText = course.courseCode;
            this.applySearch();
          },
          content: (): void => {
            this.CourseSummaryCardContent(course);
          }
        })
        .margin({ bottom: 8 })
      }, (course: TimetableCourseSummary) => course.courseCode)
    }
    .width('100%')
  }

  @Builder
  CourseSummaryCardContent(course: TimetableCourseSummary): void {
    Column() {
      Text(course.courseCode)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().themeColor)
        .width('100%')
      Text(course.courseTitle)
        .fontSize(13)
        .fontColor(this.theme().textPrimary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 4 })
      if (safeText(course.courseTitleChi).length > 0) {
        Text(safeText(course.courseTitleChi))
          .fontSize(12)
          .fontColor(this.theme().textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 3 })
      }
      Text(this.localized('Section：', 'Sections: ') + course.sections.length.toString())
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
        .width('100%')
        .margin({ top: 5 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SingleCourseResult(course: TimetableCourseSummary): void {
    Column() {
      AppCard({
        content: (): void => {
          this.SingleCourseHeaderCardContent(course);
        }
      })
      .margin({ top: 12, bottom: 10 })

      Text(this.localized('選取單節', 'Choose a section'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textTertiary)
        .width('100%')
        .margin({ bottom: 8 })

      ForEach(course.sections, (summary: TimetableSectionSummary) => {
        this.SectionCard(course.courseCode, summary)
      }, (summary: TimetableSectionSummary) => course.courseCode + summary.section)
    }
    .width('100%')
  }

  @Builder
  SingleCourseHeaderCardContent(course: TimetableCourseSummary): void {
    Column() {
      Text(course.courseCode)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().themeColor)
        .width('100%')
      Text(course.courseTitle)
        .fontSize(14)
        .fontColor(this.theme().textPrimary)
        .lineHeight(20)
        .width('100%')
        .margin({ top: 6 })
      if (safeText(course.courseTitleChi).length > 0) {
        Text(safeText(course.courseTitleChi))
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .lineHeight(19)
          .width('100%')
          .margin({ top: 4 })
      }
      Row({ space: 8 }) {
        Button(this.localized('全部放入課表', 'Add all sections'))
          .layoutWeight(1)
          .height(38)
          .borderRadius(8)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(this.theme().themeColor)
          .enabled(!this.busy)
          .onClick(() => {
            this.addAllSections(course.courseCode);
          })
        Button(this.localized('刪除此課', 'Drop course'))
          .layoutWeight(1)
          .height(38)
          .borderRadius(8)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().dangerColor)
          .backgroundColor(this.theme().surfaceAltColor)
          .enabled(this.courseSectionCount(course.courseCode) > 0 && !this.busy)
          .onClick(() => {
            this.dropCourseByCode(course.courseCode, false);
          })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SectionCard(courseCode: string, summary: TimetableSectionSummary): void {
    AppCard({
      clickable: true,
      cardPadding: 10,
      onTap: (): void => {
        this.addSection(courseCode, summary.section);
      },
      content: (): void => {
        this.SectionCardContent(summary);
      }
    })
    .margin({ bottom: 8 })
  }

  @Builder
  SectionCardContent(summary: TimetableSectionSummary): void {
    Column() {
      Row() {
        Text(summary.section)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(summary.hasConflict ? this.theme().dangerColor : this.theme().themeColor)
          .layoutWeight(1)
        Text(this.localized('加入', 'Add'))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textTertiary)
      }
      .width('100%')
      if (summary.teacherInformation.length > 0) {
        Text(summary.teacherInformation)
          .fontSize(12)
          .fontColor(this.theme().textSecondary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 4 })
      }
      ForEach(summary.meetings, (meeting: TimetableCourseMeeting, index: number) => {
        Text(safeText(meeting.day) + ' ' + timeRange(meeting.timeFrom, meeting.timeTo) +
          (safeText(meeting.classroom).length > 0 ? ' / ' + safeText(meeting.classroom) : ''))
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 4 })
      }, (meeting: TimetableCourseMeeting, index: number) =>
      safeText(meeting.day) + safeText(meeting.timeFrom) + index.toString())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  AddSheetContent(): void {
    Scroll() {
      Column() {
        this.SearchBar()
        this.FilterPanel()

        AppCard({
          content: (): void => {
            this.ImportSheetCardContent();
          }
        })
        .margin({ top: 12 })

        this.SearchResults()
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 6 })
    }
    .width('100%')
    .constraintSize({ maxHeight: '100%' })
    .edgeEffect(EdgeEffect.Spring)
    .nestedScroll({
      scrollForward: NestedScrollMode.PARENT_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
  }

  @Builder
  ImportSheetCardContent(): void {
    Column() {
      Text(this.localized('ISW 文字導入', 'Import from ISW text'))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textTertiary)
        .width('100%')
      this.ImportForm()
    }
    .width('100%')
  }

  @Builder
  MeetingActionSheetContent(): void {
    AppCard({
      cardPadding: 0,
      content: (): void => {
        this.MeetingActionCardContent();
      }
    })
  }

  @Builder
  MeetingActionCardContent(): void {
    Column() {
      AppListItem({
        title: this.selectedCourseCode + ' ' + this.selectedSection,
        subtitle: this.selectedMeetingSubtitle(),
        value: this.selectedConflict ? this.localized('衝突', 'Conflict') : ''
      })
      AppListItem({
        title: this.localized('時間地點', 'Time and place'),
        subtitle: this.selectedDay + ' ' + this.selectedTime,
        value: this.selectedClassroom
      })
      if (this.selectedTeacher.length > 0) {
        AppListItem({
          title: this.localized('老師', 'Teacher'),
          subtitle: this.selectedTeacher
        })
      }
      AppListItem({
        title: this.localized('寫 Wiki', 'Write Wiki'),
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.openSelectedAction('wiki');
        }
      })
      AppListItem({
        title: this.localized('查選咩課', 'Open What2Reg'),
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.openSelectedAction('what2reg');
        }
      })
      AppListItem({
        title: this.localized('查官方課程', 'Open official course'),
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.openSelectedAction('official');
        }
      })
      if (this.courseSectionCount(this.selectedCourseCode) > 1) {
        AppListItem({
          title: this.localized('刪除所有 Section', 'Drop all sections'),
          subtitle: this.selectedCourseCode,
          clickable: true,
          danger: true,
          onTap: (): void => {
            this.dropCourseByCode(this.selectedCourseCode, true);
          }
        })
      }
      AppListItem({
        title: this.localized('刪除此 Section', 'Drop this section'),
        subtitle: this.selectedCourseCode + ' ' + this.selectedSection,
        clickable: true,
        danger: true,
        showDivider: false,
        onTap: (): void => {
          this.dropSelectedSection();
        }
      })
    }
    .width('100%')
  }

  @Builder
  LoadingStateContent(): void {
    Scroll() {
      Column() {
        Blank()
          .height(ROOT_CONTENT_TOP_PADDING)
        if (this.showBack) {
          this.PageHeader()
        }
        Column() {
          AppLoading({
            title: this.localized('載入課表', 'Loading timetable'),
            message: this.localized('正在讀取課程資料和已保存課表', 'Reading course data and saved selections')
          })
        }
        .height(360)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 16, right: 16 })
        if (!this.showBack) {
          Blank()
            .height(ROOT_CONTENT_BOTTOM_PADDING)
        }
      }
      .width('100%')
    }
    .layoutWeight(1)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  ErrorStateContent(): void {
    Scroll() {
      Column() {
        Blank()
          .height(ROOT_CONTENT_TOP_PADDING)
        if (this.showBack) {
          this.PageHeader()
        }
        Column() {
          AppEmptyState({
            title: this.localized('無法讀取課表', 'Unable to load timetable'),
            description: this.errorMessage,
            actionText: this.localized('重試', 'Retry'),
            onAction: (): void => {
              this.loadPage();
            }
          })
        }
        .height(360)
        .justifyContent(FlexAlign.Center)
        if (!this.showBack) {
          Blank()
            .height(ROOT_CONTENT_BOTTOM_PADDING)
        }
      }
      .width('100%')
    }
    .layoutWeight(1)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  TimetableContent(): void {
    Scroll() {
      Column() {
        Blank()
          .height(ROOT_CONTENT_TOP_PADDING)
        this.PageHeader()
        this.SummaryCard()
        this.TimetableBoard()
        this.Reminder()
        if (!this.showBack) {
          Blank()
            .height(ROOT_CONTENT_BOTTOM_PADDING)
        }
      }
      .width('100%')
    }
    .layoutWeight(1)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  PageShell(): void {
    Stack() {
      Column() {
        if (this.loading) {
          this.LoadingStateContent()
        } else if (this.errorMessage.length > 0) {
          this.ErrorStateContent()
        } else if (!this.hasTimetable()) {
          Scroll() {
            Column() {
              if (this.showBack) {
                this.PageHeader()
              }
              this.FirstUseGuide()
            }
            .width('100%')
          }
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring)
        } else {
          this.TimetableContent()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme().bgColor)

      AppBottomSheet({
        visible: $showMeetingSheet,
        title: this.selectedCourseCode.length > 0 ? this.selectedCourseCode : this.localized('課節操作', 'Meeting actions'),
        closeText: this.localized('返回', 'Back'),
        maxHeightPercent: 82,
        content: (): void => {
          this.MeetingActionSheetContent();
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bgColor)
    .bindSheet($$this.showAddSheet, this.AddSheetContent(), {
      height: SheetSize.MEDIUM,
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      preferType: SheetType.BOTTOM,
      mode: SheetMode.OVERLAY,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      title: {
        title: this.localized('搵課 / 加課', 'Search / Add courses')
      },
      backgroundColor: this.theme().bgColor,
      showClose: true
    })
  }

  build() {
    if (this.showBack) {
      AppHdsPage({
        title: this.localized('課表模擬', 'Timetable'),
        backLabel: this.localized('返回', 'Back'),
        primaryActionLabel: this.showAddSheet ? this.localized('關閉', 'Close') :
        this.localized('搵課/加課', 'Add'),
        primaryActionSymbol: this.showAddSheet ? $r('sys.symbol.xmark_circle_fill') : $r('sys.symbol.plus_circle_fill'),
        primaryActionEnabled: !this.loading,
        onBack: (): void => {
          this.pathStack.pop();
        },
        onPrimaryAction: (): void => {
          this.showAddSheet = !this.showAddSheet;
          if (this.showAddSheet) {
            this.applySearch();
          }
        },
        content: (): void => {
          this.PageShell()
        }
      })
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme().bgColor)
    } else {
      this.PageShell()
    }
  }
}
