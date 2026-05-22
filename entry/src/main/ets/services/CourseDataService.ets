import { common } from '@kit.AbilityKit';
import {
  COURSE_API_ADD_DROP,
  COURSE_API_PRE,
  COURSE_API_TIMETABLE,
  COURSE_API_VERSION
} from '../common/constants/ApiEndpoints';
import {
  RAWFILE_COURSE_PLAN,
  RAWFILE_COURSE_PLAN_TIME,
  RAWFILE_COURSE_VERSION,
  RAWFILE_OFFER_COURSES
} from '../common/constants/ResourcePaths';
import {
  STORAGE_COURSE_PLAN,
  STORAGE_COURSE_PLAN_TIME,
  STORAGE_COURSE_VERSION,
  STORAGE_LAST_VERSION_CHECK_TIMESTAMP,
  STORAGE_OFFER_COURSES
} from '../common/constants/StorageKeys';
import { ApiClient } from '../common/net/ApiClient';
import { errorResult, ServiceResult } from '../common/net/HttpClient';
import { JsonStore } from '../common/storage/JsonStore';
import { PreferencesStore } from '../common/storage/PreferencesStore';
import { RawFileReader } from '../common/resources/RawFileReader';
import { Logger } from '../common/utils/Logger';
import {
  CoursePlanFile,
  CourseVersionEntry,
  CourseVersion,
  OfferCoursesFile
} from '../models/Course';

export interface CourseDataSummary {
  courseVersionReady: boolean;
  offerCoursesReady: boolean;
  coursePlanReady: boolean;
  coursePlanTimeReady: boolean;
  offerCourseCount: number;
  coursePlanCount: number;
  coursePlanTimeCount: number;
}

export interface CourseUpdateSummary {
  checkedCloud: boolean;
  skippedByInterval: boolean;
  updatedPreEnroll: boolean;
  updatedAddDrop: boolean;
  sourceUpdatedPreEnroll: boolean;
  sourceUpdatedAddDrop: boolean;
  message: string;
}

const COURSE_CHECK_INTERVAL_MS: number = 6 * 60 * 60 * 1000;

function okResult<T>(data: T): ServiceResult<T> {
  return {
    ok: true,
    data: data
  };
}

function makeCourseUpdateSummary(message: string): CourseUpdateSummary {
  return {
    checkedCloud: false,
    skippedByInterval: false,
    updatedPreEnroll: false,
    updatedAddDrop: false,
    sourceUpdatedPreEnroll: false,
    sourceUpdatedAddDrop: false,
    message: message
  };
}

function parseUpdateTime(updateTime: string): number {
  const parsed: number = Date.parse(updateTime);
  if (Number.isNaN(parsed)) {
    return 0;
  }
  return parsed;
}

function isCourseVersionEntryNewer(origin: CourseVersionEntry | undefined,
  target: CourseVersionEntry | undefined): boolean {
  if (!target || target.updateTime.length === 0) {
    return false;
  }
  if (!origin || origin.updateTime.length === 0) {
    return true;
  }

  const originTime: number = parseUpdateTime(origin.updateTime);
  const targetTime: number = parseUpdateTime(target.updateTime);
  if (originTime > 0 && targetTime > 0) {
    return targetTime > originTime;
  }
  return target.updateTime > origin.updateTime;
}

function normalizeCourseJsonKeys(text: string): string {
  return text
    .replace(/"Offering Unit"\s*:/g, '"offeringUnit":')
    .replace(/"Offering Department"\s*:/g, '"offeringDepartment":')
    .replace(/"Course Code"\s*:/g, '"courseCode":')
    .replace(/"Course Title Chi"\s*:/g, '"courseTitleChi":')
    .replace(/"Course Title"\s*:/g, '"courseTitle":')
    .replace(/"Course Type"\s*:/g, '"courseType":')
    .replace(/"Credit Units"\s*:/g, '"creditUnits":')
    .replace(/"For Incoming Exchange Students"\s*:/g, '"forIncomingExchangeStudents":')
    .replace(/"Course For Info"\s*:/g, '"courseForInfo":')
    .replace(/"Enrolled Year Level \(on or above\)"\s*:/g, '"enrolledYearLevel":')
    .replace(/"Remarks"\s*:/g, '"remarks":')
    .replace(/"Section"\s*:/g, '"section":')
    .replace(/"Medium of Instruction"\s*:/g, '"mediumOfInstruction":')
    .replace(/"Notes for Course Enrolment"\s*:/g, '"notesForCourseEnrolment":')
    .replace(/"Teacher Information"\s*:/g, '"teacherInformation":')
    .replace(/"Lecture \/ Lab"\s*:/g, '"lectureLab":')
    .replace(/"Lab Information"\s*:/g, '"labInformation":')
    .replace(/"Day"\s*:/g, '"day":')
    .replace(/"Time From"\s*:/g, '"timeFrom":')
    .replace(/"Time To"\s*:/g, '"timeTo":')
    .replace(/"Classroom"\s*:/g, '"classroom":')
    .replace(/"\\"Class For \/ Class Not For\\" Information"\s*:/g, '"classForInfo":');
}

function normalizeCourseObject<T>(value: T): T {
  return JSON.parse(normalizeCourseJsonKeys(JSON.stringify(value))) as T;
}

export class CourseDataService {
  private static async readRawJson<T>(context: common.Context, path: string): Promise<ServiceResult<T>> {
    const textResult: ServiceResult<string> = await RawFileReader.readText(context, path);
    if (!textResult.ok || !textResult.data) {
      return {
        ok: false,
        error: textResult.error
      };
    }

    try {
      return okResult<T>(JSON.parse(normalizeCourseJsonKeys(textResult.data)) as T);
    } catch (error) {
      Logger.error('Course rawfile JSON parse failed: ' + path + ', ' + String(error));
      return errorResult<T>('COURSE_JSON_PARSE_ERROR', '课程 JSON 解析失败：' + path);
    }
  }

  private static async readCachedOrRaw<T>(context: common.Context, key: string,
    rawPath: string): Promise<ServiceResult<T>> {
    const hasCache: boolean = await PreferencesStore.has(context, key);
    if (hasCache) {
      const cached: T | null = await JsonStore.getOptionalObject<T>(context, key);
      if (cached !== null) {
        return okResult<T>(normalizeCourseObject<T>(cached));
      }
    }

    const rawResult: ServiceResult<T> = await CourseDataService.readRawJson<T>(context, rawPath);
    if (hasCache && rawResult.ok && rawResult.data) {
      await CourseDataService.writeObject<T>(context, key, rawResult.data);
    }
    return rawResult;
  }

  private static async writeObject<T>(context: common.Context, key: string, value: T): Promise<void> {
    await JsonStore.setObject<T>(context, key, normalizeCourseObject<T>(value));
  }

  private static async cacheRawIfMissing<T>(context: common.Context, key: string,
    rawPath: string): Promise<ServiceResult<T>> {
    if (await PreferencesStore.has(context, key)) {
      return await CourseDataService.readCachedOrRaw<T>(context, key, rawPath);
    }

    const rawResult: ServiceResult<T> = await CourseDataService.readRawJson<T>(context, rawPath);
    if (rawResult.ok && rawResult.data) {
      await CourseDataService.writeObject<T>(context, key, rawResult.data);
    }
    return rawResult;
  }

  static async readBuiltInCourseVersion(context: common.Context): Promise<ServiceResult<CourseVersion>> {
    return await CourseDataService.readRawJson<CourseVersion>(context, RAWFILE_COURSE_VERSION);
  }

  static async readBuiltInOfferCourses(context: common.Context): Promise<ServiceResult<OfferCoursesFile>> {
    return await CourseDataService.readRawJson<OfferCoursesFile>(context, RAWFILE_OFFER_COURSES);
  }

  static async readBuiltInCoursePlan(context: common.Context): Promise<ServiceResult<CoursePlanFile>> {
    return await CourseDataService.readRawJson<CoursePlanFile>(context, RAWFILE_COURSE_PLAN);
  }

  static async readBuiltInCoursePlanTime(context: common.Context): Promise<ServiceResult<CoursePlanFile>> {
    return await CourseDataService.readRawJson<CoursePlanFile>(context, RAWFILE_COURSE_PLAN_TIME);
  }

  static async getCourseVersion(context: common.Context): Promise<ServiceResult<CourseVersion>> {
    return await CourseDataService.readCachedOrRaw<CourseVersion>(context, STORAGE_COURSE_VERSION,
      RAWFILE_COURSE_VERSION);
  }

  static async getOfferCourses(context: common.Context): Promise<ServiceResult<OfferCoursesFile>> {
    return await CourseDataService.readCachedOrRaw<OfferCoursesFile>(context, STORAGE_OFFER_COURSES,
      RAWFILE_OFFER_COURSES);
  }

  static async getCoursePlan(context: common.Context): Promise<ServiceResult<CoursePlanFile>> {
    return await CourseDataService.readCachedOrRaw<CoursePlanFile>(context, STORAGE_COURSE_PLAN,
      RAWFILE_COURSE_PLAN);
  }

  static async getCoursePlanTime(context: common.Context): Promise<ServiceResult<CoursePlanFile>> {
    return await CourseDataService.readCachedOrRaw<CoursePlanFile>(context, STORAGE_COURSE_PLAN_TIME,
      RAWFILE_COURSE_PLAN_TIME);
  }

  static async saveCourseVersion(context: common.Context, value: CourseVersion): Promise<void> {
    await CourseDataService.writeObject<CourseVersion>(context, STORAGE_COURSE_VERSION, value);
  }

  static async saveOfferCourses(context: common.Context, value: OfferCoursesFile): Promise<void> {
    await CourseDataService.writeObject<OfferCoursesFile>(context, STORAGE_OFFER_COURSES, value);
  }

  static async saveCoursePlan(context: common.Context, value: CoursePlanFile): Promise<void> {
    await CourseDataService.writeObject<CoursePlanFile>(context, STORAGE_COURSE_PLAN, value);
  }

  static async saveCoursePlanTime(context: common.Context, value: CoursePlanFile): Promise<void> {
    await CourseDataService.writeObject<CoursePlanFile>(context, STORAGE_COURSE_PLAN_TIME, value);
  }

  static async ensureBuiltInCourseCache(context: common.Context): Promise<ServiceResult<CourseDataSummary>> {
    const versionResult: ServiceResult<CourseVersion> =
      await CourseDataService.cacheRawIfMissing<CourseVersion>(context, STORAGE_COURSE_VERSION,
        RAWFILE_COURSE_VERSION);
    if (!versionResult.ok || !versionResult.data) {
      return errorResult<CourseDataSummary>('COURSE_VERSION_INIT_FAILED',
        versionResult.error?.message ?? '课程版本初始化失败');
    }

    const offerResult: ServiceResult<OfferCoursesFile> =
      await CourseDataService.cacheRawIfMissing<OfferCoursesFile>(context, STORAGE_OFFER_COURSES,
        RAWFILE_OFFER_COURSES);
    if (!offerResult.ok || !offerResult.data) {
      return errorResult<CourseDataSummary>('OFFER_COURSES_INIT_FAILED',
        offerResult.error?.message ?? '预选课程初始化失败');
    }

    const coursePlanResult: ServiceResult<CoursePlanFile> =
      await CourseDataService.cacheRawIfMissing<CoursePlanFile>(context, STORAGE_COURSE_PLAN,
        RAWFILE_COURSE_PLAN);
    if (!coursePlanResult.ok || !coursePlanResult.data) {
      return errorResult<CourseDataSummary>('COURSE_PLAN_INIT_FAILED',
        coursePlanResult.error?.message ?? 'Add/Drop 课程初始化失败');
    }

    const coursePlanTimeResult: ServiceResult<CoursePlanFile> =
      await CourseDataService.cacheRawIfMissing<CoursePlanFile>(context, STORAGE_COURSE_PLAN_TIME,
        RAWFILE_COURSE_PLAN_TIME);
    if (!coursePlanTimeResult.ok || !coursePlanTimeResult.data) {
      return errorResult<CourseDataSummary>('COURSE_PLAN_TIME_INIT_FAILED',
        coursePlanTimeResult.error?.message ?? '课程时间表初始化失败');
    }

    const summary: CourseDataSummary = {
      courseVersionReady: true,
      offerCoursesReady: true,
      coursePlanReady: true,
      coursePlanTimeReady: true,
      offerCourseCount: offerResult.data.Courses.length,
      coursePlanCount: coursePlanResult.data.Courses.length,
      coursePlanTimeCount: coursePlanTimeResult.data.Courses.length
    };
    return okResult<CourseDataSummary>(summary);
  }

  static async refreshBuiltInCourseCacheIfNewer(context: common.Context): Promise<ServiceResult<CourseUpdateSummary>> {
    const localVersionResult: ServiceResult<CourseVersion> = await CourseDataService.getCourseVersion(context);
    if (!localVersionResult.ok || !localVersionResult.data) {
      return errorResult<CourseUpdateSummary>('COURSE_VERSION_READ_FAILED',
        localVersionResult.error?.message ?? '读取课程版本失败');
    }

    const builtInVersionResult: ServiceResult<CourseVersion> = await CourseDataService.readBuiltInCourseVersion(context);
    if (!builtInVersionResult.ok || !builtInVersionResult.data) {
      return errorResult<CourseUpdateSummary>('BUILT_IN_COURSE_VERSION_READ_FAILED',
        builtInVersionResult.error?.message ?? '读取内置课程版本失败');
    }

    const summary: CourseUpdateSummary = makeCourseUpdateSummary('内置课程版本无需更新');
    const nextVersion: CourseVersion = {
      pre: localVersionResult.data.pre,
      adddrop: localVersionResult.data.adddrop
    };

    if (isCourseVersionEntryNewer(localVersionResult.data.pre, builtInVersionResult.data.pre)) {
      const offerCoursesResult: ServiceResult<OfferCoursesFile> =
        await CourseDataService.readBuiltInOfferCourses(context);
      if (!offerCoursesResult.ok || !offerCoursesResult.data) {
        return errorResult<CourseUpdateSummary>('BUILT_IN_PRE_ENROLL_READ_FAILED',
          offerCoursesResult.error?.message ?? '读取内置 PreEnroll 课程失败');
      }
      await CourseDataService.saveOfferCourses(context, offerCoursesResult.data);
      nextVersion.pre = builtInVersionResult.data.pre;
      summary.sourceUpdatedPreEnroll = true;
    }

    if (isCourseVersionEntryNewer(localVersionResult.data.adddrop, builtInVersionResult.data.adddrop)) {
      const coursePlanResult: ServiceResult<CoursePlanFile> = await CourseDataService.readBuiltInCoursePlan(context);
      if (!coursePlanResult.ok || !coursePlanResult.data) {
        return errorResult<CourseUpdateSummary>('BUILT_IN_ADD_DROP_READ_FAILED',
          coursePlanResult.error?.message ?? '读取内置 Add/Drop 课程失败');
      }
      const coursePlanTimeResult: ServiceResult<CoursePlanFile> =
        await CourseDataService.readBuiltInCoursePlanTime(context);
      if (!coursePlanTimeResult.ok || !coursePlanTimeResult.data) {
        return errorResult<CourseUpdateSummary>('BUILT_IN_TIMETABLE_READ_FAILED',
          coursePlanTimeResult.error?.message ?? '读取内置课程时间表失败');
      }
      await CourseDataService.saveCoursePlan(context, coursePlanResult.data);
      await CourseDataService.saveCoursePlanTime(context, coursePlanTimeResult.data);
      nextVersion.adddrop = builtInVersionResult.data.adddrop;
      summary.sourceUpdatedAddDrop = true;
    }

    if (summary.sourceUpdatedPreEnroll || summary.sourceUpdatedAddDrop) {
      await CourseDataService.saveCourseVersion(context, nextVersion);
      summary.message = '内置课程数据已覆盖旧缓存';
    }
    return okResult<CourseUpdateSummary>(summary);
  }

  static async checkCloudCourseVersion(context: common.Context): Promise<ServiceResult<CourseUpdateSummary>> {
    const cloudVersionResult: ServiceResult<CourseVersion> =
      await ApiClient.getCourse<CourseVersion>(COURSE_API_VERSION);
    if (!cloudVersionResult.ok || !cloudVersionResult.data) {
      return errorResult<CourseUpdateSummary>('CLOUD_COURSE_VERSION_FAILED',
        cloudVersionResult.error?.message ?? '云端课程版本检查失败', cloudVersionResult.response);
    }

    const localVersionResult: ServiceResult<CourseVersion> = await CourseDataService.getCourseVersion(context);
    if (!localVersionResult.ok || !localVersionResult.data) {
      return errorResult<CourseUpdateSummary>('COURSE_VERSION_READ_FAILED',
        localVersionResult.error?.message ?? '读取本地课程版本失败');
    }

    const summary: CourseUpdateSummary = makeCourseUpdateSummary('课程数据已是最新');
    summary.checkedCloud = true;
    const nextVersion: CourseVersion = {
      pre: localVersionResult.data.pre,
      adddrop: localVersionResult.data.adddrop
    };

    if (isCourseVersionEntryNewer(localVersionResult.data.pre, cloudVersionResult.data.pre)) {
      const preResult: ServiceResult<OfferCoursesFile> =
        await ApiClient.getCourse<OfferCoursesFile>(COURSE_API_PRE);
      if (!preResult.ok || !preResult.data) {
        return errorResult<CourseUpdateSummary>('CLOUD_PRE_ENROLL_FAILED',
          preResult.error?.message ?? '云端 PreEnroll 课程下载失败', preResult.response);
      }
      await CourseDataService.saveOfferCourses(context, preResult.data);
      nextVersion.pre = cloudVersionResult.data.pre;
      summary.updatedPreEnroll = true;
    }

    if (isCourseVersionEntryNewer(localVersionResult.data.adddrop, cloudVersionResult.data.adddrop)) {
      const addDropResult: ServiceResult<CoursePlanFile> =
        await ApiClient.getCourse<CoursePlanFile>(COURSE_API_ADD_DROP);
      if (!addDropResult.ok || !addDropResult.data) {
        return errorResult<CourseUpdateSummary>('CLOUD_ADD_DROP_FAILED',
          addDropResult.error?.message ?? '云端 Add/Drop 课程下载失败', addDropResult.response);
      }

      const timetableResult: ServiceResult<CoursePlanFile> =
        await ApiClient.getCourse<CoursePlanFile>(COURSE_API_TIMETABLE);
      if (!timetableResult.ok || !timetableResult.data) {
        return errorResult<CourseUpdateSummary>('CLOUD_TIMETABLE_FAILED',
          timetableResult.error?.message ?? '云端课程时间表下载失败', timetableResult.response);
      }

      await CourseDataService.saveCoursePlan(context, addDropResult.data);
      await CourseDataService.saveCoursePlanTime(context, timetableResult.data);
      nextVersion.adddrop = cloudVersionResult.data.adddrop;
      summary.updatedAddDrop = true;
    }

    if (summary.updatedPreEnroll || summary.updatedAddDrop) {
      await CourseDataService.saveCourseVersion(context, nextVersion);
      summary.message = '云端课程数据已更新';
    }

    return okResult<CourseUpdateSummary>(summary);
  }

  static async checkCloudCourseVersionIfNeeded(context: common.Context): Promise<ServiceResult<CourseUpdateSummary>> {
    const lastCheckTimestamp: number =
      await PreferencesStore.getNumber(context, STORAGE_LAST_VERSION_CHECK_TIMESTAMP, 0);
    const now: number = Date.now();
    if (lastCheckTimestamp > 0 && now - lastCheckTimestamp < COURSE_CHECK_INTERVAL_MS) {
      const skippedSummary: CourseUpdateSummary = makeCourseUpdateSummary('课程云端检查仍在 6 小时间隔内');
      skippedSummary.skippedByInterval = true;
      return okResult<CourseUpdateSummary>(skippedSummary);
    }

    const result: ServiceResult<CourseUpdateSummary> = await CourseDataService.checkCloudCourseVersion(context);
    try {
      await PreferencesStore.set(context, STORAGE_LAST_VERSION_CHECK_TIMESTAMP, now);
    } catch (error) {
      Logger.warn('Save course version check timestamp failed: ' + String(error));
    }
    return result;
  }
}
