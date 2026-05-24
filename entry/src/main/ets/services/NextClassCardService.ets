import { common } from '@kit.AbilityKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import {
  STORAGE_NEXT_CLASS_FORM_IDS,
  STORAGE_TIMETABLE,
  STORAGE_WEEK_TIMETABLE
} from '../common/constants/StorageKeys';
import { JsonStore } from '../common/storage/JsonStore';
import {
  getDateClockMinutes,
  getDateDayCode,
  normalizeDayCode,
  WEEK_DAY_CODES,
  parseClockTimeToMinutes
} from '../common/utils/DateTime';
import { Logger } from '../common/utils/Logger';
import {
  CoursePlanFile,
  CoursePlanItem,
  TimetableHomeCacheItem,
  TimetableSelection,
  WeekTimetableHomeCache
} from '../models/Course';
import { CourseDataService } from './CourseDataService';

export class NextClassCardData {
  hasCourse: string = '0';
  title: string = '下节课';
  courseCode: string = '暂无课程';
  timeText: string = '--:--';
  locationText: string = '地点未定';
}

function normalizeText(value: string | undefined): string {
  return (value ?? '').trim();
}

function normalizeCourseCode(code: string | undefined): string {
  return normalizeText(code).toUpperCase();
}

function normalizeSection(section: string | undefined): string {
  return normalizeText(section).toUpperCase();
}

function formatTime(course: TimetableHomeCacheItem): string {
  const timeFrom: string = normalizeText(course.timeFrom);
  return timeFrom.length > 0 ? timeFrom : '--:--';
}

function normalizeFormIds(ids: string[] | null): string[] {
  const result: string[] = [];
  if (ids === null) {
    return result;
  }
  for (let i = 0; i < ids.length; i++) {
    const id: string = normalizeText(ids[i]);
    if (id.length > 0 && !result.includes(id)) {
      result.push(id);
    }
  }
  return result;
}

function normalizeSelectionJsonKeys(text: string): string {
  return text
    .replace(/"Course Code"\s*:/g, '"courseCode":')
    .replace(/"Section"\s*:/g, '"section":');
}

function normalizeStoredSelections(source: TimetableSelection[] | null): TimetableSelection[] {
  if (source === null) {
    return [];
  }

  let normalizedSource: TimetableSelection[] = [];
  try {
    normalizedSource = JSON.parse(normalizeSelectionJsonKeys(JSON.stringify(source))) as TimetableSelection[];
  } catch (error) {
    return [];
  }

  const result: TimetableSelection[] = [];
  for (let i = 0; i < normalizedSource.length; i++) {
    const selection: TimetableSelection = {
      courseCode: normalizeCourseCode(normalizedSource[i].courseCode),
      section: normalizeSection(normalizedSource[i].section)
    };
    if (selection.courseCode.length > 0 && selection.section.length > 0) {
      result.push(selection);
    }
  }
  return result;
}

function normalizeWeekCache(text: string): string {
  return text
    .replace(/"Course Code"\s*:/g, '"courseCode":')
    .replace(/"Section"\s*:/g, '"section":')
    .replace(/"Course Title"\s*:/g, '"courseTitle":')
    .replace(/"Course Title Chi"\s*:/g, '"courseTitleChi":')
    .replace(/"Day"\s*:/g, '"day":')
    .replace(/"Time From"\s*:/g, '"timeFrom":')
    .replace(/"Time To"\s*:/g, '"timeTo":')
    .replace(/"Classroom"\s*:/g, '"classroom":');
}

function dayIndex(day: string): number {
  const normalized: string = normalizeDayCode(day);
  for (let i = 0; i < WEEK_DAY_CODES.length; i++) {
    if (WEEK_DAY_CODES[i] === normalized) {
      return i;
    }
  }
  return -1;
}

function dayAtOffset(today: string, offset: number): string {
  const index: number = dayIndex(today);
  if (index < 0) {
    return '';
  }
  return WEEK_DAY_CODES[(index + offset) % WEEK_DAY_CODES.length];
}

function meetingOffsetFromNow(day: string | undefined, timeFrom: string | undefined, today: string,
  currentMinutes: number): number {
  const sourceIndex: number = dayIndex(normalizeDayCode(day));
  const todayIndex: number = dayIndex(today);
  const startMinutes: number = parseClockTimeToMinutes(timeFrom);
  if (sourceIndex < 0 || todayIndex < 0 || startMinutes < 0) {
    return -1;
  }

  let offset: number = sourceIndex - todayIndex;
  if (offset < 0) {
    offset += WEEK_DAY_CODES.length;
  }
  if (offset === 0 && startMinutes <= currentMinutes) {
    offset = WEEK_DAY_CODES.length;
  }
  return offset;
}

function homeCacheItems(cache: WeekTimetableHomeCache, day: string): TimetableHomeCacheItem[] {
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

function makeHomeCourse(source: CoursePlanItem, selection: TimetableSelection, color: number): TimetableHomeCacheItem {
  return {
    courseCode: normalizeCourseCode(source.courseCode),
    section: normalizeSection(selection.section),
    courseTitle: source.courseTitle,
    courseTitleChi: source.courseTitleChi,
    day: normalizeDayCode(source.day),
    timeFrom: normalizeText(source.timeFrom),
    timeTo: normalizeText(source.timeTo),
    classroom: normalizeText(source.classroom),
    color: color
  };
}

function copyHomeCourseWithDay(source: TimetableHomeCacheItem, day: string): TimetableHomeCacheItem {
  return {
    courseCode: normalizeCourseCode(source.courseCode),
    section: normalizeSection(source.section),
    courseTitle: source.courseTitle,
    courseTitleChi: source.courseTitleChi,
    day: normalizeDayCode(source.day) || normalizeDayCode(day),
    timeFrom: normalizeText(source.timeFrom),
    timeTo: normalizeText(source.timeTo),
    classroom: normalizeText(source.classroom),
    color: source.color
  };
}

function makeBindingRecord(data: NextClassCardData): Record<string, string> {
  return {
    'hasCourse': data.hasCourse,
    'title': data.title,
    'courseCode': data.courseCode,
    'timeText': data.timeText,
    'locationText': data.locationText
  };
}

function isSameCourseMeeting(source: CoursePlanItem, target: TimetableHomeCacheItem, day: string): boolean {
  const targetSection: string = normalizeSection(target.section);
  const targetTimeFrom: string = normalizeText(target.timeFrom);
  if (normalizeCourseCode(source.courseCode) !== normalizeCourseCode(target.courseCode) ||
    normalizeText(source.day).toUpperCase() !== day) {
    return false;
  }
  if (targetSection.length > 0 && normalizeSection(source.section) !== targetSection) {
    return false;
  }
  if (targetTimeFrom.length > 0 && normalizeText(source.timeFrom) !== targetTimeFrom) {
    return false;
  }
  return true;
}

export class NextClassCardService {
  static emptyData(): NextClassCardData {
    return new NextClassCardData();
  }

  static async loadData(context: common.Context): Promise<NextClassCardData> {
    const data: NextClassCardData = NextClassCardService.emptyData();
    const course: TimetableHomeCacheItem | null = await NextClassCardService.readUpcomingCourse(context);
    if (course === null) {
      return data;
    }

    const hydratedCourse: TimetableHomeCacheItem = await NextClassCardService.hydrateCourseFromPlanTime(context, course);
    data.hasCourse = '1';
    data.courseCode = normalizeText(hydratedCourse.courseCode);
    data.timeText = formatTime(hydratedCourse);
    data.locationText = normalizeText(hydratedCourse.classroom).length > 0 ? normalizeText(hydratedCourse.classroom) :
      '地点未定';
    return data;
  }

  private static async readUpcomingCourse(context: common.Context): Promise<TimetableHomeCacheItem | null> {
    const timetableCourse: TimetableHomeCacheItem | null =
      await NextClassCardService.readUpcomingCourseFromTimetable(context);
    if (timetableCourse !== null) {
      return timetableCourse;
    }
    return await NextClassCardService.readUpcomingCourseFromHomeCache(context);
  }

  private static async readUpcomingCourseFromTimetable(context: common.Context): Promise<TimetableHomeCacheItem | null> {
    const storedSelections: TimetableSelection[] | null =
      await JsonStore.getOptionalObject<TimetableSelection[]>(context, STORAGE_TIMETABLE);
    const selections: TimetableSelection[] = normalizeStoredSelections(storedSelections);
    if (selections.length === 0) {
      return null;
    }

    const coursePlanTimeResult = await CourseDataService.getCoursePlanTime(context);
    if (!coursePlanTimeResult.ok || !coursePlanTimeResult.data) {
      return null;
    }

    const today: string = getDateDayCode(new Date());
    const currentMinutes: number = getDateClockMinutes(new Date());
    let result: TimetableHomeCacheItem | null = null;
    let resultRank: number = 8 * 24 * 60;
    const courses: CoursePlanFile = coursePlanTimeResult.data;
    for (let selectionIndex = 0; selectionIndex < selections.length; selectionIndex++) {
      const selection: TimetableSelection = selections[selectionIndex];
      for (let courseIndex = 0; courseIndex < courses.Courses.length; courseIndex++) {
        const source: CoursePlanItem = courses.Courses[courseIndex];
        if (normalizeCourseCode(source.courseCode) !== selection.courseCode ||
          normalizeSection(source.section) !== selection.section) {
          continue;
        }

        const startMinutes: number = parseClockTimeToMinutes(source.timeFrom);
        const offset: number = meetingOffsetFromNow(source.day, source.timeFrom, today, currentMinutes);
        const rank: number = offset * 24 * 60 + startMinutes;
        if (offset >= 0 && rank < resultRank) {
          result = makeHomeCourse(source, selection, selectionIndex);
          resultRank = rank;
        }
      }
    }
    return result;
  }

  private static async hydrateCourseFromPlanTime(context: common.Context,
    course: TimetableHomeCacheItem): Promise<TimetableHomeCacheItem> {
    if (normalizeText(course.timeTo).length > 0 && normalizeText(course.classroom).length > 0) {
      return course;
    }

    const coursePlanTimeResult = await CourseDataService.getCoursePlanTime(context);
    if (!coursePlanTimeResult.ok || !coursePlanTimeResult.data) {
      return course;
    }

    const day: string = normalizeDayCode(course.day) || getDateDayCode(new Date());
    const courses: CoursePlanFile = coursePlanTimeResult.data;
    for (let i = 0; i < courses.Courses.length; i++) {
      const source: CoursePlanItem = courses.Courses[i];
      if (isSameCourseMeeting(source, course, day)) {
        return makeHomeCourse(source, {
          courseCode: normalizeCourseCode(course.courseCode),
          section: normalizeSection(source.section)
        }, course.color);
      }
    }
    return course;
  }

  private static async readUpcomingCourseFromHomeCache(context: common.Context): Promise<TimetableHomeCacheItem | null> {
    const rawCache: WeekTimetableHomeCache | null =
      await JsonStore.getOptionalObject<WeekTimetableHomeCache>(context, STORAGE_WEEK_TIMETABLE);
    if (rawCache === null) {
      return null;
    }

    let cache: WeekTimetableHomeCache;
    try {
      cache = JSON.parse(normalizeWeekCache(JSON.stringify(rawCache))) as WeekTimetableHomeCache;
    } catch (error) {
      return null;
    }

    const today: string = getDateDayCode(new Date());
    const currentMinutes: number = getDateClockMinutes(new Date());
    let result: TimetableHomeCacheItem | null = null;
    let resultRank: number = 8 * 24 * 60;
    for (let offset = 0; offset <= WEEK_DAY_CODES.length; offset++) {
      const day: string = dayAtOffset(today, offset);
      const items: TimetableHomeCacheItem[] = homeCacheItems(cache, day) ?? [];
      for (let i = 0; i < items.length; i++) {
        const startMinutes: number = parseClockTimeToMinutes(items[i].timeFrom);
        if (startMinutes < 0 || (offset === 0 && startMinutes <= currentMinutes)) {
          continue;
        }
        const rank: number = offset * 24 * 60 + startMinutes;
        if (rank < resultRank) {
          result = copyHomeCourseWithDay(items[i], day);
          resultRank = rank;
        }
      }
    }
    if (result === null) {
      return null;
    }
    return await NextClassCardService.hydrateCourseFromPlanTime(context, result);
  }

  static async readFormIds(context: common.Context): Promise<string[]> {
    const ids: string[] | null = await JsonStore.getOptionalObject<string[]>(context, STORAGE_NEXT_CLASS_FORM_IDS);
    return normalizeFormIds(ids);
  }

  static async registerForm(context: common.Context, formId: string): Promise<void> {
    const id: string = normalizeText(formId);
    if (id.length === 0) {
      return;
    }
    const ids: string[] = await NextClassCardService.readFormIds(context);
    if (!ids.includes(id)) {
      ids.push(id);
      await JsonStore.setObject<string[]>(context, STORAGE_NEXT_CLASS_FORM_IDS, ids);
    }
  }

  static async unregisterForm(context: common.Context, formId: string): Promise<void> {
    const id: string = normalizeText(formId);
    if (id.length === 0) {
      return;
    }
    const ids: string[] = await NextClassCardService.readFormIds(context);
    const nextIds: string[] = [];
    for (let i = 0; i < ids.length; i++) {
      if (ids[i] !== id) {
        nextIds.push(ids[i]);
      }
    }
    await JsonStore.setObject<string[]>(context, STORAGE_NEXT_CLASS_FORM_IDS, nextIds);
  }

  static async updateForm(context: common.Context, formId: string): Promise<void> {
    const id: string = normalizeText(formId);
    if (id.length === 0) {
      return;
    }

    const data: NextClassCardData = await NextClassCardService.loadData(context);
    try {
      await formProvider.updateForm(id, formBindingData.createFormBindingData(makeBindingRecord(data)));
    } catch (error) {
      Logger.warn('Next class form update failed: ' + id + ', ' + String(error));
    }
  }

  static async updateAllForms(context: common.Context): Promise<void> {
    const ids: string[] = await NextClassCardService.readFormIds(context);
    for (let i = 0; i < ids.length; i++) {
      await NextClassCardService.updateForm(context, ids[i]);
    }
  }
}
