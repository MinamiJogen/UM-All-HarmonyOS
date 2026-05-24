import { common } from '@kit.AbilityKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import {
  STORAGE_NEXT_CLASS_FORM_IDS,
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
  WeekTimetableHomeCache
} from '../models/Course';
import { CourseDataService } from './CourseDataService';

const MIN_NEXT_REFRESH_MINUTES: number = 5;
const MAX_NEXT_REFRESH_MINUTES: number = 24 * 60;
const DEFAULT_NEXT_REFRESH_MINUTES: number = 6 * 60;

export class NextClassCardData {
  hasCourse: string = '0';
  title: string = '下节课';
  courseCode: string = '暂无课程';
  timeText: string = '--:--';
  locationText: string = '地点未定';
  nextRefreshMinutes: number = DEFAULT_NEXT_REFRESH_MINUTES;
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

function minutesUntilMeeting(day: string | undefined, timeFrom: string | undefined, now: Date): number {
  const today: string = getDateDayCode(now);
  const currentMinutes: number = getDateClockMinutes(now);
  const startMinutes: number = parseClockTimeToMinutes(timeFrom);
  const offset: number = meetingOffsetFromNow(day, timeFrom, today, currentMinutes);
  if (offset < 0 || startMinutes < 0) {
    return DEFAULT_NEXT_REFRESH_MINUTES;
  }

  return offset * 24 * 60 + startMinutes - currentMinutes;
}

function normalizeNextRefreshMinutes(minutes: number): number {
  if (minutes < MIN_NEXT_REFRESH_MINUTES) {
    return MIN_NEXT_REFRESH_MINUTES;
  }
  if (minutes > MAX_NEXT_REFRESH_MINUTES) {
    return MAX_NEXT_REFRESH_MINUTES;
  }
  return Math.ceil(minutes);
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

function makeHomeCourse(source: CoursePlanItem, section: string, color: number): TimetableHomeCacheItem {
  return {
    courseCode: normalizeCourseCode(source.courseCode),
    section: normalizeSection(section),
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
    data.nextRefreshMinutes = normalizeNextRefreshMinutes(minutesUntilMeeting(hydratedCourse.day,
      hydratedCourse.timeFrom, new Date()) + 1);
    return data;
  }

  private static async readUpcomingCourse(context: common.Context): Promise<TimetableHomeCacheItem | null> {
    return await NextClassCardService.readUpcomingCourseFromHomeCache(context);
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
        return makeHomeCourse(source, source.section ?? course.section, course.color);
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
    const items: TimetableHomeCacheItem[] = homeCacheItems(cache, today) ?? [];
    let result: TimetableHomeCacheItem | null = null;
    let resultStartMinutes: number = 24 * 60;
    for (let i = 0; i < items.length; i++) {
      const startMinutes: number = parseClockTimeToMinutes(items[i].timeFrom);
      if (startMinutes > currentMinutes && startMinutes < resultStartMinutes) {
        result = copyHomeCourseWithDay(items[i], today);
        resultStartMinutes = startMinutes;
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
      await NextClassCardService.scheduleNextRefresh(id, data.nextRefreshMinutes);
    } catch (error) {
      Logger.warn('Next class form update failed: ' + id + ', ' + String(error));
    }
  }

  private static async scheduleNextRefresh(formId: string, minutes: number): Promise<void> {
    const nextMinutes: number = normalizeNextRefreshMinutes(minutes);
    try {
      await formProvider.setFormNextRefreshTime(formId, nextMinutes);
    } catch (error) {
      Logger.warn('Next class form next refresh failed: ' + formId + ', ' + String(error));
    }
  }

  static async updateAllForms(context: common.Context): Promise<void> {
    const ids: string[] = await NextClassCardService.readFormIds(context);
    for (let i = 0; i < ids.length; i++) {
      await NextClassCardService.updateForm(context, ids[i]);
    }
  }
}
