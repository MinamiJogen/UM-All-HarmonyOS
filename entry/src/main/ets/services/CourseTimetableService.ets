import { common } from '@kit.AbilityKit';
import { STORAGE_TIMETABLE, STORAGE_WEEK_TIMETABLE } from '../common/constants/StorageKeys';
import { errorResult, ServiceResult } from '../common/net/HttpClient';
import { JsonStore } from '../common/storage/JsonStore';
import {
  dayCodeOrder,
  normalizeDayCode,
  parseClockTimeToMinutes,
  WEEK_DAY_CODES
} from '../common/utils/DateTime';
import {
  hasChinese,
  normalizeSimplifiedChinese
} from '../common/utils/ChineseText';
import {
  CoursePlanFile,
  CoursePlanItem,
  TimetableBuildResult,
  TimetableCourseMeeting,
  TimetableCourseSummary,
  TimetableHomeCacheItem,
  TimetableImportResult,
  TimetableSearchFilter,
  TimetableSearchResult,
  TimetableSectionSummary,
  TimetableSelection,
  WeekTimetable,
  WeekTimetableHomeCache
} from '../models/Course';
import { CourseDataService } from './CourseDataService';

export const TIMETABLE_PERIOD_DAY: string = 'day';
export const TIMETABLE_PERIOD_AFTERNOON: string = 'afternoon';
export const TIMETABLE_PERIOD_EVENING: string = 'evening';

const DEFAULT_FILTER_TIME_FROM: string = '00:00';
const DEFAULT_FILTER_TIME_TO: string = '23:59';

function okResult<T>(data: T): ServiceResult<T> {
  return {
    ok: true,
    data: data
  };
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

function normalizeSelectionJsonKeys(text: string): string {
  return text
    .replace(/"Course Code"\s*:/g, '"courseCode":')
    .replace(/"Section"\s*:/g, '"section":');
}

function normalizeCourseCode(code: string | undefined): string {
  return (code ?? '').trim().toUpperCase();
}

function normalizeSection(section: string | undefined): string {
  return (section ?? '').trim().toUpperCase();
}

function selectionsEqual(left: TimetableSelection, right: TimetableSelection): boolean {
  return left.courseCode === right.courseCode && left.section === right.section;
}

function hasSelection(selections: TimetableSelection[], target: TimetableSelection): boolean {
  for (let i = 0; i < selections.length; i++) {
    if (selectionsEqual(selections[i], target)) {
      return true;
    }
  }
  return false;
}

function normalizeSelections(source: TimetableSelection[]): TimetableSelection[] {
  const result: TimetableSelection[] = [];
  for (let i = 0; i < source.length; i++) {
    const selection: TimetableSelection = {
      courseCode: normalizeCourseCode(source[i].courseCode),
      section: normalizeSection(source[i].section)
    };
    if (selection.courseCode.length > 0 && selection.section.length > 0 && !hasSelection(result, selection)) {
      result.push(selection);
    }
  }
  return result;
}

function normalizeStoredSelections(source: TimetableSelection[] | null): TimetableSelection[] {
  if (source === null) {
    return [];
  }

  try {
    const normalizedText: string = normalizeSelectionJsonKeys(JSON.stringify(source));
    return normalizeSelections(JSON.parse(normalizedText) as TimetableSelection[]);
  } catch (error) {
    return [];
  }
}

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

function getMeetingsForDay(week: WeekTimetable, day: string): TimetableCourseMeeting[] {
  if (day === 'MON') {
    return week.MON;
  }
  if (day === 'TUE') {
    return week.TUE;
  }
  if (day === 'WED') {
    return week.WED;
  }
  if (day === 'THU') {
    return week.THU;
  }
  if (day === 'FRI') {
    return week.FRI;
  }
  if (day === 'SAT') {
    return week.SAT;
  }
  return week.SUN;
}

function getHomeCacheForDay(cache: WeekTimetableHomeCache, day: string): TimetableHomeCacheItem[] {
  if (day === 'MON') {
    return cache.MON;
  }
  if (day === 'TUE') {
    return cache.TUE;
  }
  if (day === 'WED') {
    return cache.WED;
  }
  if (day === 'THU') {
    return cache.THU;
  }
  if (day === 'FRI') {
    return cache.FRI;
  }
  if (day === 'SAT') {
    return cache.SAT;
  }
  return cache.SUN;
}

function compareMeetings(left: TimetableCourseMeeting, right: TimetableCourseMeeting): number {
  const dayDiff: number = dayCodeOrder(left.day) - dayCodeOrder(right.day);
  if (dayDiff !== 0) {
    return dayDiff;
  }
  if (left.startsAtMinutes !== right.startsAtMinutes) {
    return left.startsAtMinutes - right.startsAtMinutes;
  }
  if (left.endsAtMinutes !== right.endsAtMinutes) {
    return left.endsAtMinutes - right.endsAtMinutes;
  }
  const codeDiff: number = compareString(left.courseCode, right.courseCode);
  if (codeDiff !== 0) {
    return codeDiff;
  }
  return compareString(left.section, right.section);
}

function periodHintForTime(startsAtMinutes: number): string {
  if (startsAtMinutes >= 18 * 60) {
    return TIMETABLE_PERIOD_EVENING;
  }
  if (startsAtMinutes > 12 * 60) {
    return TIMETABLE_PERIOD_AFTERNOON;
  }
  return TIMETABLE_PERIOD_DAY;
}

function makeMeeting(source: CoursePlanItem, selectionIndex: number, color: number): TimetableCourseMeeting {
  const startsAtMinutes: number = parseClockTimeToMinutes(source.timeFrom);
  const endsAtMinutes: number = parseClockTimeToMinutes(source.timeTo);
  return {
    offeringUnit: source.offeringUnit,
    offeringDepartment: source.offeringDepartment,
    courseCode: source.courseCode,
    courseTitle: source.courseTitle,
    courseTitleChi: source.courseTitleChi,
    courseType: source.courseType,
    section: source.section,
    mediumOfInstruction: source.mediumOfInstruction,
    notesForCourseEnrolment: source.notesForCourseEnrolment,
    teacherInformation: source.teacherInformation,
    lectureLab: source.lectureLab,
    labInformation: source.labInformation,
    day: normalizeDayCode(source.day),
    timeFrom: source.timeFrom,
    timeTo: source.timeTo,
    classroom: source.classroom,
    classForInfo: source.classForInfo,
    selectionIndex: selectionIndex,
    color: color,
    startsAtMinutes: startsAtMinutes,
    endsAtMinutes: endsAtMinutes,
    breakBeforeMinutes: 0,
    conflict: false,
    conflictWithPrevious: false,
    periodHint: periodHintForTime(startsAtMinutes)
  };
}

function meetingHasValidTime(meeting: TimetableCourseMeeting): boolean {
  return normalizeDayCode(meeting.day).length > 0 && meeting.startsAtMinutes >= 0 && meeting.endsAtMinutes >= 0;
}

function markConflicts(dayMeetings: TimetableCourseMeeting[]): boolean {
  let hasConflict: boolean = false;
  dayMeetings.sort((left: TimetableCourseMeeting, right: TimetableCourseMeeting): number => compareMeetings(left, right));

  for (let i = 0; i < dayMeetings.length; i++) {
    dayMeetings[i].breakBeforeMinutes = 0;
    dayMeetings[i].conflict = false;
    dayMeetings[i].conflictWithPrevious = false;
    if (i === 0) {
      continue;
    }

    const previous: TimetableCourseMeeting = dayMeetings[i - 1];
    const gapMinutes: number = dayMeetings[i].startsAtMinutes - previous.endsAtMinutes;
    dayMeetings[i].breakBeforeMinutes = gapMinutes;
    if (gapMinutes < 0) {
      dayMeetings[i].conflict = true;
      dayMeetings[i].conflictWithPrevious = true;
      previous.conflict = true;
      hasConflict = true;
    }
  }
  return hasConflict;
}

function buildHomeCache(weekTimetable: WeekTimetable): WeekTimetableHomeCache {
  const cache: WeekTimetableHomeCache = emptyHomeCache();
  for (let i = 0; i < WEEK_DAY_CODES.length; i++) {
    const day: string = WEEK_DAY_CODES[i];
    const meetings: TimetableCourseMeeting[] = getMeetingsForDay(weekTimetable, day);
    const cacheItems: TimetableHomeCacheItem[] = getHomeCacheForDay(cache, day);
    for (let j = 0; j < meetings.length; j++) {
      cacheItems.push({
        courseCode: meetings[j].courseCode,
        section: meetings[j].section,
        timeFrom: meetings[j].timeFrom ?? '',
        color: meetings[j].color
      });
    }
  }
  return cache;
}

function courseCodeColorIndex(selections: TimetableSelection[], courseCode: string): number {
  for (let i = 0; i < selections.length; i++) {
    if (selections[i].courseCode === courseCode) {
      return i;
    }
  }
  return 0;
}

function removeCourseCode(selections: TimetableSelection[], courseCode: string): TimetableSelection[] {
  const normalizedCode: string = normalizeCourseCode(courseCode);
  const result: TimetableSelection[] = [];
  for (let i = 0; i < selections.length; i++) {
    if (selections[i].courseCode !== normalizedCode) {
      result.push(selections[i]);
    }
  }
  return result;
}

function removeCourseSection(selections: TimetableSelection[], selection: TimetableSelection): TimetableSelection[] {
  const normalizedSelections: TimetableSelection[] = normalizeSelections([selection]);
  if (normalizedSelections.length === 0) {
    return normalizeSelections(selections);
  }
  const normalizedSelection: TimetableSelection = normalizedSelections[0];
  const result: TimetableSelection[] = [];
  for (let i = 0; i < selections.length; i++) {
    if (!selectionsEqual(selections[i], normalizedSelection)) {
      result.push(selections[i]);
    }
  }
  return result;
}

function containsUpper(source: string | undefined, keyword: string): boolean {
  if (!source || keyword.length === 0) {
    return false;
  }
  return source.toUpperCase().includes(keyword);
}

function containsChineseText(source: string | undefined, keyword: string, traditionalKeyword: string): boolean {
  if (!source || keyword.length === 0) {
    return false;
  }
  return source.includes(keyword) || source.includes(traditionalKeyword);
}

function courseMatchesSearch(item: CoursePlanItem, keyword: string, upperKeyword: string,
  traditionalKeyword: string): boolean {
  return containsUpper(item.courseCode, upperKeyword) ||
  containsUpper(item.courseTitle, upperKeyword) ||
  containsUpper(item.teacherInformation, upperKeyword) ||
  containsUpper(item.day, upperKeyword) ||
  containsUpper(item.offeringDepartment, upperKeyword) ||
  containsUpper(item.offeringUnit, upperKeyword) ||
  containsChineseText(item.courseTitleChi, keyword, traditionalKeyword);
}

function hasCourseSummary(summaries: TimetableCourseSummary[], courseCode: string): boolean {
  for (let i = 0; i < summaries.length; i++) {
    if (summaries[i].courseCode === courseCode) {
      return true;
    }
  }
  return false;
}

function filterAllowsMeeting(meeting: TimetableCourseMeeting, filter?: TimetableSearchFilter): boolean {
  if (!filter) {
    return true;
  }

  const filterDay: string = normalizeDayCode(filter.day);
  if (filterDay.length > 0 && meeting.day !== filterDay) {
    return false;
  }

  const filterStart: number = parseClockTimeToMinutes(filter.timeFrom.length > 0 ?
    filter.timeFrom : DEFAULT_FILTER_TIME_FROM);
  const filterEnd: number = parseClockTimeToMinutes(filter.timeTo.length > 0 ? filter.timeTo : DEFAULT_FILTER_TIME_TO);
  if (filterStart < 0 || filterEnd < 0 || filterEnd <= filterStart) {
    return true;
  }

  return meeting.startsAtMinutes < filterEnd && meeting.endsAtMinutes > filterStart;
}

function buildSectionSummaries(courseCode: string, coursePlanTimeData: CoursePlanFile,
  filter?: TimetableSearchFilter): TimetableSectionSummary[] {
  const sectionCodes: string[] = [];
  for (let i = 0; i < coursePlanTimeData.Courses.length; i++) {
    const item: CoursePlanItem = coursePlanTimeData.Courses[i];
    if (normalizeCourseCode(item.courseCode) === courseCode) {
      const section: string = normalizeSection(item.section);
      if (section.length > 0 && !sectionCodes.includes(section)) {
        sectionCodes.push(section);
      }
    }
  }
  sectionCodes.sort((left: string, right: string): number => compareString(left, right));

  const summaries: TimetableSectionSummary[] = [];
  for (let i = 0; i < sectionCodes.length; i++) {
    const buildResult: TimetableBuildResult =
      CourseTimetableService.buildTimetable([{ courseCode: courseCode, section: sectionCodes[i] }], coursePlanTimeData);
    const meetings: TimetableCourseMeeting[] = [];
    for (let j = 0; j < buildResult.allMeetings.length; j++) {
      if (filterAllowsMeeting(buildResult.allMeetings[j], filter)) {
        meetings.push(buildResult.allMeetings[j]);
      }
    }
    if (meetings.length === 0) {
      continue;
    }

    summaries.push({
      section: sectionCodes[i],
      teacherInformation: meetings[0].teacherInformation ?? '',
      meetings: meetings,
      hasConflict: buildResult.hasConflict
    });
  }
  return summaries;
}

function makeCourseSummary(item: CoursePlanItem, sections: TimetableSectionSummary[]): TimetableCourseSummary {
  return {
    offeringUnit: item.offeringUnit,
    offeringDepartment: item.offeringDepartment,
    courseCode: item.courseCode,
    courseTitle: item.courseTitle,
    courseTitleChi: item.courseTitleChi,
    courseType: item.courseType,
    sections: sections
  };
}

function sortCourseSummaries(summaries: TimetableCourseSummary[]): TimetableCourseSummary[] {
  const result: TimetableCourseSummary[] = [];
  for (let i = 0; i < summaries.length; i++) {
    result.push(summaries[i]);
  }
  result.sort((left: TimetableCourseSummary, right: TimetableCourseSummary): number =>
  compareString(left.courseCode, right.courseCode));
  return result;
}

export class CourseTimetableService {
  static parseImportData(inputText: string): TimetableSelection[] {
    const matches = inputText.toUpperCase().match(/[A-Z]{4}[0-9]{4}((\/[0-9]{4})+)?\s?\([0-9]{3}\)/g);
    if (!matches || matches.length === 0) {
      return [];
    }

    const result: TimetableSelection[] = [];
    for (let i = 0; i < matches.length; i++) {
      const text: string = matches[i].replace(/\s/g, '');
      const leftBracketIndex: number = text.indexOf('(');
      const rightBracketIndex: number = text.indexOf(')');
      const slashIndex: number = text.indexOf('/');
      const courseCodeBound: number = slashIndex === -1 ? leftBracketIndex : slashIndex;
      if (leftBracketIndex <= 0 || rightBracketIndex <= leftBracketIndex || courseCodeBound <= 0) {
        continue;
      }

      const selection: TimetableSelection = {
        courseCode: text.substring(0, courseCodeBound),
        section: text.substring(leftBracketIndex + 1, rightBracketIndex)
      };
      if (!hasSelection(result, selection)) {
        result.push(selection);
      }
    }
    return normalizeSelections(result);
  }

  static parseImportText(inputText: string): ServiceResult<TimetableImportResult> {
    const matches = inputText.toUpperCase().match(/[A-Z]{4}[0-9]{4}((\/[0-9]{4})+)?\s?\([0-9]{3}\)/g);
    const matchCount: number = matches ? matches.length : 0;
    const selections: TimetableSelection[] = CourseTimetableService.parseImportData(inputText);
    if (selections.length === 0) {
      return errorResult<TimetableImportResult>('TIMETABLE_IMPORT_EMPTY', '未能从文本中解析课程和 Section');
    }

    return okResult<TimetableImportResult>({
      selections: selections,
      importedCount: selections.length,
      ignoredDuplicateCount: Math.max(0, matchCount - selections.length)
    });
  }

  static buildTimetable(selections: TimetableSelection[], coursePlanTimeData: CoursePlanFile): TimetableBuildResult {
    const normalizedSelections: TimetableSelection[] = normalizeSelections(selections);
    const allMeetings: TimetableCourseMeeting[] = [];
    const missingSelections: TimetableSelection[] = [];

    for (let i = 0; i < normalizedSelections.length; i++) {
      const selection: TimetableSelection = normalizedSelections[i];
      let matchedCount: number = 0;
      const color: number = courseCodeColorIndex(normalizedSelections, selection.courseCode);
      for (let j = 0; j < coursePlanTimeData.Courses.length; j++) {
        const source: CoursePlanItem = coursePlanTimeData.Courses[j];
        if (normalizeCourseCode(source.courseCode) === selection.courseCode &&
          normalizeSection(source.section) === selection.section) {
          const meeting: TimetableCourseMeeting = makeMeeting(source, i, color);
          if (meetingHasValidTime(meeting)) {
            allMeetings.push(meeting);
            matchedCount++;
          }
        }
      }
      if (matchedCount === 0) {
        missingSelections.push(selection);
      }
    }

    allMeetings.sort((left: TimetableCourseMeeting, right: TimetableCourseMeeting): number =>
    compareMeetings(left, right));
    const weekTimetable: WeekTimetable = emptyWeekTimetable();
    for (let i = 0; i < allMeetings.length; i++) {
      getMeetingsForDay(weekTimetable, allMeetings[i].day ?? '').push(allMeetings[i]);
    }

    let hasConflict: boolean = false;
    for (let i = 0; i < WEEK_DAY_CODES.length; i++) {
      if (markConflicts(getMeetingsForDay(weekTimetable, WEEK_DAY_CODES[i]))) {
        hasConflict = true;
      }
    }
    allMeetings.sort((left: TimetableCourseMeeting, right: TimetableCourseMeeting): number =>
    compareMeetings(left, right));

    return {
      selections: normalizedSelections,
      allMeetings: allMeetings,
      weekTimetable: weekTimetable,
      homeCache: buildHomeCache(weekTimetable),
      missingSelections: missingSelections,
      hasConflict: hasConflict
    };
  }

  static buildSearchResults(keyword: string, coursePlanData: CoursePlanFile, coursePlanTimeData: CoursePlanFile,
    filter?: TimetableSearchFilter): TimetableSearchResult {
    const normalizedKeyword: string = keyword.trim();
    const shouldSearch: boolean = hasChinese(normalizedKeyword) ? normalizedKeyword.length > 0 :
      normalizedKeyword.length > 2;
    if (!shouldSearch) {
      return {
        active: false,
        keyword: normalizedKeyword,
        results: []
      };
    }

    const upperKeyword: string = normalizedKeyword.toUpperCase();
    const traditionalKeyword: string = normalizeSimplifiedChinese(normalizedKeyword);
    const summaries: TimetableCourseSummary[] = [];
    for (let i = 0; i < coursePlanData.Courses.length; i++) {
      const item: CoursePlanItem = coursePlanData.Courses[i];
      if (!courseMatchesSearch(item, normalizedKeyword, upperKeyword, traditionalKeyword) ||
        hasCourseSummary(summaries, item.courseCode)) {
        continue;
      }

      const sections: TimetableSectionSummary[] =
        buildSectionSummaries(normalizeCourseCode(item.courseCode), coursePlanTimeData, filter);
      if (sections.length > 0) {
        summaries.push(makeCourseSummary(item, sections));
      }
    }

    return {
      active: true,
      keyword: normalizedKeyword,
      results: sortCourseSummaries(summaries)
    };
  }

  static async readSelections(context: common.Context): Promise<TimetableSelection[]> {
    const cachedSelections: TimetableSelection[] | null =
      await JsonStore.getOptionalObject<TimetableSelection[]>(context, STORAGE_TIMETABLE);
    return normalizeStoredSelections(cachedSelections);
  }

  private static async saveBuildResult(context: common.Context, result: TimetableBuildResult): Promise<void> {
    await JsonStore.setObject<TimetableSelection[]>(context, STORAGE_TIMETABLE, result.selections);
    await JsonStore.setObject<WeekTimetableHomeCache>(context, STORAGE_WEEK_TIMETABLE, result.homeCache);
  }

  private static async saveSelectionsWithCoursePlanTime(context: common.Context, selections: TimetableSelection[],
    coursePlanTimeData: CoursePlanFile): Promise<ServiceResult<TimetableBuildResult>> {
    const result: TimetableBuildResult = CourseTimetableService.buildTimetable(selections, coursePlanTimeData);
    await CourseTimetableService.saveBuildResult(context, result);
    return okResult<TimetableBuildResult>(result);
  }

  static async replaceSelections(context: common.Context,
    selections: TimetableSelection[]): Promise<ServiceResult<TimetableBuildResult>> {
    const coursePlanTimeResult: ServiceResult<CoursePlanFile> = await CourseDataService.getCoursePlanTime(context);
    if (!coursePlanTimeResult.ok || !coursePlanTimeResult.data) {
      return errorResult<TimetableBuildResult>('COURSE_PLAN_TIME_READ_FAILED',
        coursePlanTimeResult.error?.message ?? '读取课程时间表失败', coursePlanTimeResult.response);
    }
    return await CourseTimetableService.saveSelectionsWithCoursePlanTime(context, selections, coursePlanTimeResult.data);
  }

  static async loadTimetable(context: common.Context): Promise<ServiceResult<TimetableBuildResult>> {
    const selections: TimetableSelection[] = await CourseTimetableService.readSelections(context);
    return await CourseTimetableService.replaceSelections(context, selections);
  }

  static async importFromText(context: common.Context, inputText: string): Promise<ServiceResult<TimetableBuildResult>> {
    const importResult: ServiceResult<TimetableImportResult> = CourseTimetableService.parseImportText(inputText);
    if (!importResult.ok || !importResult.data) {
      return errorResult<TimetableBuildResult>(importResult.error?.code ?? 'TIMETABLE_IMPORT_FAILED',
        importResult.error?.message ?? '课表导入失败');
    }
    return await CourseTimetableService.replaceSelections(context, importResult.data.selections);
  }

  static async addCourseSection(context: common.Context,
    selection: TimetableSelection): Promise<ServiceResult<TimetableBuildResult>> {
    const currentSelections: TimetableSelection[] = await CourseTimetableService.readSelections(context);
    const normalized: TimetableSelection[] = normalizeSelections([selection]);
    if (normalized.length === 0) {
      return errorResult<TimetableBuildResult>('TIMETABLE_SELECTION_INVALID', '课程或 Section 为空');
    }

    const nextSelections: TimetableSelection[] = removeCourseCode(currentSelections, normalized[0].courseCode);
    nextSelections.push(normalized[0]);
    return await CourseTimetableService.replaceSelections(context, nextSelections);
  }

  static async addAllSectionsForCourse(context: common.Context,
    courseCode: string): Promise<ServiceResult<TimetableBuildResult>> {
    const coursePlanTimeResult: ServiceResult<CoursePlanFile> = await CourseDataService.getCoursePlanTime(context);
    if (!coursePlanTimeResult.ok || !coursePlanTimeResult.data) {
      return errorResult<TimetableBuildResult>('COURSE_PLAN_TIME_READ_FAILED',
        coursePlanTimeResult.error?.message ?? '读取课程时间表失败', coursePlanTimeResult.response);
    }

    const normalizedCode: string = normalizeCourseCode(courseCode);
    const sectionCodes: string[] = [];
    for (let i = 0; i < coursePlanTimeResult.data.Courses.length; i++) {
      const item: CoursePlanItem = coursePlanTimeResult.data.Courses[i];
      if (normalizeCourseCode(item.courseCode) === normalizedCode) {
        const section: string = normalizeSection(item.section);
        if (section.length > 0 && !sectionCodes.includes(section)) {
          sectionCodes.push(section);
        }
      }
    }
    if (sectionCodes.length === 0) {
      return errorResult<TimetableBuildResult>('TIMETABLE_COURSE_NOT_FOUND', '课程不存在或没有可用 Section');
    }
    sectionCodes.sort((left: string, right: string): number => compareString(left, right));

    const currentSelections: TimetableSelection[] = await CourseTimetableService.readSelections(context);
    const nextSelections: TimetableSelection[] = removeCourseCode(currentSelections, normalizedCode);
    for (let i = 0; i < sectionCodes.length; i++) {
      nextSelections.push({
        courseCode: normalizedCode,
        section: sectionCodes[i]
      });
    }
    return await CourseTimetableService.saveSelectionsWithCoursePlanTime(context, nextSelections,
      coursePlanTimeResult.data);
  }

  static async dropCourseSection(context: common.Context,
    selection: TimetableSelection): Promise<ServiceResult<TimetableBuildResult>> {
    const currentSelections: TimetableSelection[] = await CourseTimetableService.readSelections(context);
    return await CourseTimetableService.replaceSelections(context, removeCourseSection(currentSelections, selection));
  }

  static async dropCourse(context: common.Context, courseCode: string): Promise<ServiceResult<TimetableBuildResult>> {
    const currentSelections: TimetableSelection[] = await CourseTimetableService.readSelections(context);
    return await CourseTimetableService.replaceSelections(context, removeCourseCode(currentSelections, courseCode));
  }

  static async clearTimetable(context: common.Context): Promise<ServiceResult<TimetableBuildResult>> {
    const result: TimetableBuildResult = CourseTimetableService.buildTimetable([], { Courses: [] });
    await CourseTimetableService.saveBuildResult(context, result);
    return okResult<TimetableBuildResult>(result);
  }
}
