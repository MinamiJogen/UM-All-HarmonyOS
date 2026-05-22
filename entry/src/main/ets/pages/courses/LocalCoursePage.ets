import { common } from '@kit.AbilityKit';
import { ROOT_CONTENT_TOP_PADDING } from '../../common/constants/LayoutMetrics';
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
import {
  compareClockTime,
  dayCodeOrder
} from '../../common/utils/DateTime';
import { OpenLink } from '../../common/utils/OpenLink';
import { AppBottomSheet } from '../../components/AppBottomSheet';
import { AppCard } from '../../components/AppCard';
import { AppDialog } from '../../components/AppDialog';
import { AppEmptyState } from '../../components/AppEmptyState';
import { AppHdsPage } from '../../components/AppHdsPage';
import { AppListItem } from '../../components/AppListItem';
import { AppLoading } from '../../components/AppLoading';
import {
  AppSegmentOption,
  AppSegmentedControl
} from '../../components/AppSegmentedControl';
import { AppToast, AppToastType } from '../../components/AppToast';
import { CoursePlanFile, CoursePlanItem, TimetableBuildResult } from '../../models/Course';
import { CourseCatalogService } from '../../services/CourseCatalogService';
import { CourseDataService } from '../../services/CourseDataService';
import { CourseTimetableService } from '../../services/CourseTimetableService';
import { UmehHostService } from '../../services/UmehHostService';

const GROUP_BY_SECTION: string = 'section';
const GROUP_BY_TEACHER: string = 'teacher';

const GROUP_BY_OPTIONS: AppSegmentOption[] = [
  { key: GROUP_BY_SECTION, label: 'Section' },
  { key: GROUP_BY_TEACHER, label: 'Teacher' }
];

interface LocalCourseSectionGroup {
  section: string;
  title: string;
  slots: CoursePlanItem[];
}

interface LocalCourseTeacherGroup {
  teacherName: string;
  sectionCodes: string[];
}

function emptyCoursePlanItem(): CoursePlanItem {
  return {
    offeringUnit: '',
    offeringDepartment: '',
    courseCode: '',
    courseTitle: '',
    section: ''
  };
}

function safeText(value: string | undefined): string {
  return value ?? '';
}

function normalizedCode(value: string | undefined): string {
  return (value ?? '').trim().toUpperCase();
}

function compareString(left: string, right: string): number {
  if (left < right) {
    return -1;
  }
  if (left > right) {
    return 1;
  }
  return 0;
}

function sortSlots(source: CoursePlanItem[]): CoursePlanItem[] {
  const result: CoursePlanItem[] = source.slice();
  result.sort((left: CoursePlanItem, right: CoursePlanItem): number => {
    const dayDiff: number = dayCodeOrder(left.day) - dayCodeOrder(right.day);
    if (dayDiff !== 0) {
      return dayDiff;
    }
    const timeDiff: number = compareClockTime(left.timeFrom, right.timeFrom);
    if (timeDiff !== 0) {
      return timeDiff;
    }
    return compareString(safeText(left.classroom), safeText(right.classroom));
  });
  return result;
}

@Component
export struct LocalCoursePage {
  @State courseCode: string = '';
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @Consume('appCurrentTabIndex') currentTabIndex: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State groupBy: string = GROUP_BY_SECTION;
  @State sectionGroups: LocalCourseSectionGroup[] = [];
  @State teacherGroups: LocalCourseTeacherGroup[] = [];
  @State courseInfo: CoursePlanItem = emptyCoursePlanItem();
  @State selectedSlots: CoursePlanItem[] = [];
  @State selectedCourseRow: CoursePlanItem = emptyCoursePlanItem();
  @State showOfferingSheet: boolean = false;
  private initialized: boolean = false;

  aboutToAppear(): void {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    this.courseCode = LocalCourseNavigationState.consumePendingCourseCode();
    this.loadCourse();
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

  private groupByIndex(): number {
    return this.groupBy === GROUP_BY_SECTION ? 0 : 1;
  }

  private normalizedCourseCode(): string {
    return normalizedCode(this.courseCode);
  }

  private async loadCourse(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    const code: string = this.normalizedCourseCode();
    if (code.length === 0) {
      this.errorMessage = this.localized('未指定課程編號', 'Course code is missing');
      this.loading = false;
      return;
    }

    const result: ServiceResult<CoursePlanFile> = await CourseDataService.getCoursePlanTime(this.getContext());
    if (!result.ok || !result.data) {
      this.errorMessage = result.error?.message ?? this.localized('課節資料讀取失敗', 'Failed to load course sections');
      this.loading = false;
      return;
    }

    const related: CoursePlanItem[] = [];
    for (let i = 0; i < result.data.Courses.length; i++) {
      const item: CoursePlanItem = result.data.Courses[i];
      if (normalizedCode(item.courseCode).includes(code)) {
        related.push(item);
      }
    }

    if (related.length === 0) {
      this.courseInfo = emptyCoursePlanItem();
      this.sectionGroups = [];
      this.teacherGroups = [];
      this.errorMessage = this.localized('課表時間表中沒有找到此課程，可能只有預選資料。', 'This course is not in the timetable data.');
      this.loading = false;
      return;
    }

    this.courseInfo = related[0];
    this.sectionGroups = this.buildSectionGroups(related);
    this.teacherGroups = this.buildTeacherGroups(related);
    this.loading = false;
  }

  private buildSectionGroups(items: CoursePlanItem[]): LocalCourseSectionGroup[] {
    const groups: LocalCourseSectionGroup[] = [];
    for (let i = 0; i < items.length; i++) {
      const item: CoursePlanItem = items[i];
      const section: string = safeText(item.section);
      let targetIndex: number = -1;
      for (let j = 0; j < groups.length; j++) {
        if (groups[j].section === section) {
          targetIndex = j;
          break;
        }
      }
      if (targetIndex < 0) {
        groups.push({
          section: section,
          title: this.sectionTitle(item),
          slots: [item]
        });
      } else {
        groups[targetIndex].slots.push(item);
      }
    }

    for (let i = 0; i < groups.length; i++) {
      groups[i].slots = sortSlots(groups[i].slots);
    }
    groups.sort((left: LocalCourseSectionGroup, right: LocalCourseSectionGroup): number =>
      compareString(left.section, right.section));
    return groups;
  }

  private buildTeacherGroups(items: CoursePlanItem[]): LocalCourseTeacherGroup[] {
    const groups: LocalCourseTeacherGroup[] = [];
    for (let i = 0; i < items.length; i++) {
      const item: CoursePlanItem = items[i];
      const teacher: string = safeText(item.teacherInformation);
      const section: string = safeText(item.section);
      if (teacher.length === 0 || section.length === 0) {
        continue;
      }

      let targetIndex: number = -1;
      for (let j = 0; j < groups.length; j++) {
        if (groups[j].teacherName === teacher) {
          targetIndex = j;
          break;
        }
      }
      if (targetIndex < 0) {
        groups.push({
          teacherName: teacher,
          sectionCodes: [section]
        });
      } else if (!groups[targetIndex].sectionCodes.includes(section)) {
        groups[targetIndex].sectionCodes.push(section);
      }
    }

    for (let i = 0; i < groups.length; i++) {
      groups[i].sectionCodes.sort((left: string, right: string): number => compareString(left, right));
    }
    groups.sort((left: LocalCourseTeacherGroup, right: LocalCourseTeacherGroup): number =>
      compareString(left.teacherName, right.teacherName));
    return groups;
  }

  private sectionTitle(item: CoursePlanItem): string {
    const medium: string = safeText(item.mediumOfInstruction);
    if (medium.length > 0) {
      return 'Section ' + safeText(item.section) + ' - ' + medium;
    }
    return 'Section ' + safeText(item.section);
  }

  private findSectionGroup(section: string): LocalCourseSectionGroup {
    for (let i = 0; i < this.sectionGroups.length; i++) {
      if (this.sectionGroups[i].section === section) {
        return this.sectionGroups[i];
      }
    }
    return {
      section: section,
      title: 'Section ' + section,
      slots: []
    };
  }

  private selectOffering(slots: CoursePlanItem[]): void {
    if (slots.length === 0) {
      return;
    }
    this.selectedSlots = slots;
    this.selectedCourseRow = slots[0];
    this.showOfferingSheet = true;
  }

  private firstSlot(slots: CoursePlanItem[]): CoursePlanItem {
    if (slots.length > 0) {
      return slots[0];
    }
    return emptyCoursePlanItem();
  }

  private offeringSectionLabel(slots: CoursePlanItem[]): string {
    const first: CoursePlanItem = this.firstSlot(slots);
    const medium: string = safeText(first.mediumOfInstruction);
    return safeText(first.section) + (medium.length > 0 ? ' - ' + medium : '');
  }

  private isPeCourse(slots: CoursePlanItem[]): boolean {
    const courseCode: string = safeText(this.firstSlot(slots).courseCode);
    return courseCode === 'CPED1001' || courseCode === 'CPED1002';
  }

  private async openExternal(url: string): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), url);
    if (!success) {
      AppToast.showError(this.getUIContext(), this.localized('無法打開鏈接', 'Unable to open link'));
    }
  }

  private async openSelectedWiki(): Promise<void> {
    this.showOfferingSheet = false;
    const teacher: string = safeText(this.selectedCourseRow.teacherInformation);
    const query: string = teacher.length > 0 ? teacher : safeText(this.selectedCourseRow.courseCode);
    await this.openExternal(CourseCatalogService.buildCourseLinks(query).wikiUrl);
  }

  private async openSelectedWhat2Reg(): Promise<void> {
    this.showOfferingSheet = false;
    await UmehHostService.refreshHost(this.getContext());
    const courseCode: string = safeText(this.selectedCourseRow.courseCode);
    const teacher: string = safeText(this.selectedCourseRow.teacherInformation);
    if (teacher.length > 0) {
      await this.openExternal(UmehHostService.getCurrentHost() + '/reviews/' + encodeURIComponent(courseCode) +
        '/' + encodeURIComponent(teacher));
      return;
    }
    await this.openExternal(UmehHostService.buildCourseUrl(courseCode));
  }

  private checkSelectedInTimetable(): void {
    this.showOfferingSheet = false;
    CourseSimNavigationState.setPendingKeyword(safeText(this.selectedCourseRow.courseCode));
    this.currentTabIndex = ROOT_TAB_TIMETABLE;
    if (this.pathStack.size() > 0) {
      this.pathStack.pop();
    }
  }

  private async addSelectedToTimetable(): Promise<void> {
    const confirmed: boolean = await AppDialog.confirm(this.getUIContext(), {
      title: this.localized('ARK搵課提示', 'ARK Course'),
      message: this.localized('確定添加此課程到模擬課表嗎？', 'Add this section to the timetable?'),
      confirmText: this.localized('確定', 'Yes'),
      cancelText: this.localized('取消', 'No')
    });
    if (!confirmed) {
      return;
    }

    this.showOfferingSheet = false;
    const result: ServiceResult<TimetableBuildResult> = await CourseTimetableService.addCourseSection(this.getContext(), {
      courseCode: safeText(this.selectedCourseRow.courseCode),
      section: safeText(this.selectedCourseRow.section)
    });
    if (!result.ok) {
      AppToast.showError(this.getUIContext(), result.error?.message ?? this.localized('添加失敗', 'Failed to add section'));
      return;
    }
    AppToast.show(this.getUIContext(), this.localized('已添加至模擬課表', 'Added to timetable'), AppToastType.Success);
    this.currentTabIndex = ROOT_TAB_TIMETABLE;
    if (this.pathStack.size() > 0) {
      this.pathStack.pop();
    }
  }

  @Builder
  CourseInfoCard(): void {
    AppCard({
      content: (): void => {
        this.CourseInfoCardContent();
      }
    })
  }

  @Builder
  CourseInfoCardContent(): void {
    Column() {
      Text(safeText(this.courseInfo.courseTitle))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme().textPrimary)
        .textAlign(TextAlign.Center)
        .width('100%')
        .lineHeight(21)

      if (safeText(this.courseInfo.courseTitleChi).length > 0) {
        Text(safeText(this.courseInfo.courseTitleChi))
          .fontSize(14)
          .fontColor(this.theme().textSecondary)
          .textAlign(TextAlign.Center)
          .width('100%')
          .lineHeight(20)
          .margin({ top: 4 })
      }

      Text(safeText(this.courseInfo.offeringUnit) +
      (safeText(this.courseInfo.offeringDepartment).length > 0 ? ' - ' + safeText(this.courseInfo.offeringDepartment) : ''))
        .fontSize(12)
        .fontColor(this.theme().textTertiary)
        .textAlign(TextAlign.Center)
        .width('100%')
        .lineHeight(18)
        .margin({ top: 6 })

      if (safeText(this.courseInfo.classForInfo).length > 0) {
        Text(safeText(this.courseInfo.classForInfo))
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .textAlign(TextAlign.Center)
          .width('100%')
          .lineHeight(18)
          .margin({ top: 4 })
      }

      if (safeText(this.courseInfo.courseType).length > 0) {
        Text(safeText(this.courseInfo.courseType))
          .fontSize(12)
          .fontColor(this.theme().themeColor)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ top: 4 })
      }
    }
    .width('100%')
  }

  @Builder
  GroupSwitch(): void {
    Row() {
      Text('Group By:')
        .fontSize(13)
        .fontColor(this.theme().textTertiary)
        .margin({ right: 10 })
      Column() {
        AppSegmentedControl({
          options: GROUP_BY_OPTIONS,
          selectedIndex: this.groupByIndex(),
          onChange: (index: number): void => {
            this.groupBy = GROUP_BY_OPTIONS[index].key;
          }
        })
      }
      .width(180)
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .margin({ top: 12, bottom: 6 })
  }

  @Builder
  SectionHeader(title: string, first: boolean): void {
    Row() {
      Column()
        .width(3)
        .height(18)
        .borderRadius(2)
        .backgroundColor(this.theme().themeColor)
        .margin({ right: 10 })
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .height(40)
    .padding({ top: first ? 6 : 14, bottom: 6 })
  }

  @Builder
  SlotChip(slot: CoursePlanItem): void {
    Column() {
      Text(safeText(slot.day))
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textSecondary)
        .maxLines(1)
      if (safeText(slot.classroom).length > 0) {
        Text(safeText(slot.classroom))
          .fontSize(11)
          .fontColor(this.theme().textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
      if (safeText(slot.timeFrom).length > 0) {
        Text(safeText(slot.timeFrom) + ' ~ ' + safeText(slot.timeTo))
          .fontSize(11)
          .fontColor(this.theme().textTertiary)
          .maxLines(1)
          .margin({ top: 2 })
      }
    }
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .borderRadius(8)
    .backgroundColor(this.theme().surfaceAltColor)
    .margin({ right: 6, bottom: 6 })
  }

  @Builder
  OfferingCard(slots: CoursePlanItem[], variant: string): void {
    AppCard({
      clickable: true,
      cardPadding: 10,
      content: (): void => {
        this.OfferingCardContent(slots, variant);
      },
      onTap: (): void => {
        this.selectOffering(slots);
      }
    })
      .margin({ top: 4, bottom: 8 })
  }

  @Builder
  OfferingCardContent(slots: CoursePlanItem[], variant: string): void {
    Column() {
      if (variant !== GROUP_BY_SECTION) {
        Text(this.offeringSectionLabel(slots))
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      if (this.isPeCourse(slots)) {
        Text(safeText(this.firstSlot(slots).courseTitle))
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .lineHeight(18)
          .margin({ top: 3 })
        Text(safeText(this.firstSlot(slots).courseTitleChi))
          .fontSize(13)
          .fontColor(this.theme().textSecondary)
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .lineHeight(18)
      }

      if (variant === GROUP_BY_SECTION && safeText(this.firstSlot(slots).teacherInformation).length > 0) {
        Text(safeText(this.firstSlot(slots).teacherInformation))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme().themeColor)
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .lineHeight(18)
          .margin({ bottom: 6 })
      }

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(slots, (slot: CoursePlanItem, index: number) => {
          this.SlotChip(slot)
        }, (slot: CoursePlanItem, index: number) =>
          safeText(slot.day) + safeText(slot.classroom) + safeText(slot.timeFrom) + index.toString())
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Center)
    .width('100%')
  }

  @Builder
  SectionGroups(): void {
    ForEach(this.sectionGroups, (group: LocalCourseSectionGroup, index: number) => {
      this.SectionHeader(group.title, index === 0)
      this.OfferingCard(group.slots, GROUP_BY_SECTION)
    }, (group: LocalCourseSectionGroup) => group.section)
  }

  @Builder
  TeacherGroups(): void {
    if (this.teacherGroups.length === 0) {
      AppEmptyState({
        title: this.localized('暫無教師分組', 'No teacher group'),
        description: this.localized('此課程資料未提供教師資訊。', 'Teacher information is not available for this course.')
      })
        .margin({ top: 24 })
    } else {
      Row() {
        Text(this.localized('班別列可左右滑動瀏覽', 'Swipe horizontally to browse sections'))
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 8, bottom: 4 })

      ForEach(this.teacherGroups, (group: LocalCourseTeacherGroup, index: number) => {
        this.SectionHeader(group.teacherName, index === 0)
        Scroll() {
          Row({ space: 10 }) {
            ForEach(group.sectionCodes, (section: string) => {
              Column() {
                this.OfferingCard(this.findSectionGroup(section).slots, GROUP_BY_TEACHER)
              }
              .width(260)
            }, (section: string) => group.teacherName + section)
          }
          .alignItems(VerticalAlign.Top)
        }
        .scrollable(ScrollDirection.Horizontal)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
      }, (group: LocalCourseTeacherGroup) => group.teacherName)
    }
  }

  @Builder
  OfferingSheetContent(): void {
    AppListItem({
      title: this.localized('寫 Wiki', 'Write Wiki'),
      subtitle: safeText(this.selectedCourseRow.teacherInformation).length > 0 ?
      safeText(this.selectedCourseRow.teacherInformation) : safeText(this.selectedCourseRow.courseCode),
      clickable: true,
      showChevron: true,
      onTap: (): void => {
        this.openSelectedWiki();
      }
    })
    AppListItem({
      title: this.localized('查 選咩課', 'Open What2Reg'),
      subtitle: safeText(this.selectedCourseRow.courseCode),
      clickable: true,
      showChevron: true,
      onTap: (): void => {
        this.openSelectedWhat2Reg();
      }
    })
    AppListItem({
      title: this.localized('查 模擬課表', 'Check timetable'),
      subtitle: safeText(this.selectedCourseRow.courseCode),
      clickable: true,
      showChevron: true,
      onTap: (): void => {
        this.checkSelectedInTimetable();
      }
    })
    AppListItem({
      title: this.localized('添加至模擬課表', 'Add to timetable'),
      subtitle: safeText(this.selectedCourseRow.courseCode) + ' ' + safeText(this.selectedCourseRow.section),
      clickable: true,
      showChevron: true,
      showDivider: false,
      onTap: (): void => {
        this.addSelectedToTimetable();
      }
    })
  }

  @Builder
  Content(): void {
    if (this.loading) {
      Column() {
        AppLoading({
          title: this.localized('載入課節資料', 'Loading sections'),
          message: this.normalizedCourseCode()
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ left: 16, right: 16 })
    } else if (this.sectionGroups.length === 0) {
      Column() {
        AppEmptyState({
          title: this.localized('沒有可顯示課節', 'No section found'),
          description: this.errorMessage,
          actionText: 'Wiki',
          onAction: (): void => {
            this.openExternal(CourseCatalogService.buildCourseLinks(this.normalizedCourseCode()).wikiUrl);
          }
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ left: 16, right: 16 })
    } else {
      Scroll() {
        Column() {
          Blank()
            .height(ROOT_CONTENT_TOP_PADDING)
          this.CourseInfoCard()
          this.GroupSwitch()
          if (this.groupBy === GROUP_BY_SECTION) {
            this.SectionGroups()
          } else {
            this.TeacherGroups()
          }
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
    Stack() {
      AppHdsPage({
        title: this.normalizedCourseCode(),
        backLabel: this.localized('返回', 'Back'),
        primaryActionLabel: this.localized('Wiki', 'Wiki'),
        primaryActionSymbol: $r('sys.symbol.doc_plaintext'),
        onBack: (): void => {
          this.pathStack.pop();
        },
        onPrimaryAction: (): void => {
          this.openExternal(CourseCatalogService.buildCourseLinks(this.normalizedCourseCode()).wikiUrl);
        },
        content: (): void => {
          this.Content()
        }
      })
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme().bgColor)

      AppBottomSheet({
        visible: $showOfferingSheet,
        title: safeText(this.selectedCourseRow.courseCode) + ' ' + safeText(this.selectedCourseRow.section),
        closeText: this.localized('返回', 'Back'),
        content: (): void => {
          this.OfferingSheetContent();
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bgColor)
  }
}
