import { common } from '@kit.AbilityKit';
import {
  buildOfficialCourseUrl,
  buildWikiSearchUrl
} from '../common/constants/ApiEndpoints';
import { STORAGE_COURSE_FILTER_OPTIONS } from '../common/constants/StorageKeys';
import { errorResult, ServiceResult } from '../common/net/HttpClient';
import { JsonStore } from '../common/storage/JsonStore';
import {
  hasChinese,
  normalizeSimplifiedChinese
} from '../common/utils/ChineseText';
import {
  CourseCatalogItem,
  CourseCatalogState,
  CourseFacultyDepartments,
  CourseFilterOptions,
  CourseFilterResult,
  CourseLinkBundle,
  CoursePlanFile,
  CoursePlanItem,
  CourseSearchResult,
  CourseVersion,
  OfferCourseItem,
  OfferCoursesFile
} from '../models/Course';
import { CourseDataService } from './CourseDataService';
import { UmehHostService } from './UmehHostService';

export const COURSE_MODE_ADD_DROP: string = 'ad';
export const COURSE_MODE_PRE_ENROLL: string = 'preEnroll';
export const COURSE_FILTER_OPTION_CMRE: string = 'CMRE';
export const COURSE_FILTER_OPTION_GE: string = 'GE';

export interface CourseCodeLabel {
  code: string;
  label: string;
}

export const DEFAULT_COURSE_FILTER_OPTIONS: CourseFilterOptions = {
  mode: COURSE_MODE_ADD_DROP,
  option: COURSE_FILTER_OPTION_CMRE,
  facultyName: 'FST',
  depaName: 'ECE',
  GE: 'GEST'
};

export const COURSE_MODE_LABELS_TC: CourseCodeLabel[] = [
  { code: COURSE_MODE_ADD_DROP, label: '增退選' },
  { code: COURSE_MODE_PRE_ENROLL, label: '預選課' }
];

export const COURSE_MODE_LABELS_EN: CourseCodeLabel[] = [
  { code: COURSE_MODE_ADD_DROP, label: 'Add Drop' },
  { code: COURSE_MODE_PRE_ENROLL, label: 'Pre Enroll' }
];

export const COURSE_UNIT_LABELS: CourseCodeLabel[] = [
  { code: 'FAH', label: '人文學院 - Arts and Humanities' },
  { code: 'FBA', label: '工商管理學院 - Business Administration' },
  { code: 'FED', label: '教育學院 - Education' },
  { code: 'FST', label: '科技學院 - Science and Technology' },
  { code: 'FHS', label: '健康科學學院 - Health Sciences' },
  { code: 'FSS', label: '社會科學學院 - Social Sciences' },
  { code: 'FLL', label: '法學院 - Law' },
  { code: 'IAPME', label: '應用物理及材料工程研究院 - Institute of Applied Physics and Materials Engineering' },
  { code: 'ICMS', label: '中華醫藥研究院 - Institute of Chinese Medical Sciences' },
  { code: 'IME', label: '微電子研究院 - Institute of Microelectronics' },
  { code: 'MSC', label: ' - ' },
  { code: 'RC', label: '書院 - Residential College' },
  { code: 'HC', label: '榮譽學院 - Honours College' }
];

export const COURSE_DEPARTMENT_LABELS: CourseCodeLabel[] = [
  { code: 'CCHC', label: '中國歷史文化中心' },
  { code: 'DAD', label: '藝術設計系' },
  { code: 'DCH', label: '中國語言文學系' },
  { code: 'DENG', label: '英文系' },
  { code: 'DHIST', label: '歷史系' },
  { code: 'DJP', label: '日文系' },
  { code: 'CJS', label: '日本研究中心' },
  { code: 'DPT', label: '葡文系' },
  { code: 'ELC', label: '英語中心' },
  { code: 'DPHIL', label: '哲學及宗教學系' },
  { code: 'PHIL', label: '哲學及宗教學系' },
  { code: 'AIM', label: '會計及資訊管理學系' },
  { code: 'DRTM', label: '綜合度假村及旅遊管理學系' },
  { code: 'FBE', label: '金融及商業經濟學系' },
  { code: 'MMI', label: '管理及市場學系' },
  { code: 'DBS', label: '生物醫學系' },
  { code: 'DPS', label: '藥物科學系' },
  { code: 'DPM', label: '藥學系' },
  { code: 'GLS', label: '環球法律學系' },
  { code: 'MLS', label: '澳門法學系' },
  { code: 'CAD', label: '藝術與設計中心' },
  { code: 'DCOM', label: '傳播系' },
  { code: 'DECO', label: '經濟學系' },
  { code: 'DGPA', label: '政府與行政學系' },
  { code: 'DPSY', label: '心理學系' },
  { code: 'DSOC', label: '社會學系' },
  { code: 'CEE', label: '土木及環境工程系' },
  { code: 'CIS', label: '電腦及資訊科學系' },
  { code: 'CSG', label: '化學支持小組' },
  { code: 'DPC', label: '物理及化學系' },
  { code: 'ECE', label: '電機及電腦工程系' },
  { code: 'EME', label: '機電工程系' },
  { code: 'MAT', label: '數學系' },
  { code: 'OST', label: '海洋科學與技術系' }
];

export const COURSE_GE_LABELS: CourseCodeLabel[] = [
  { code: 'GEGA', label: '全球意識 - Global Awareness' },
  { code: 'GELH', label: '文學與人文 - Literature and Humanities' },
  { code: 'GESB', label: '社會與行為 - Society and Behaviour' },
  { code: 'GEST', label: '科學和技術 - Science and Technology' }
];

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

function sortedCopy(values: string[]): string[] {
  const nextValues: string[] = [];
  for (let i = 0; i < values.length; i++) {
    nextValues.push(values[i]);
  }
  nextValues.sort((left: string, right: string): number => compareString(left, right));
  return nextValues;
}

function containsValue(values: string[], value: string): boolean {
  for (let i = 0; i < values.length; i++) {
    if (values[i] === value) {
      return true;
    }
  }
  return false;
}

function pushUnique(values: string[], value: string): void {
  if (value.length === 0 || containsValue(values, value)) {
    return;
  }
  values.push(value);
}

function uniqueSorted(values: string[]): string[] {
  const result: string[] = [];
  for (let i = 0; i < values.length; i++) {
    pushUnique(result, values[i]);
  }
  return sortedCopy(result);
}

function normalizeCourseMode(mode: string): string {
  if (mode === COURSE_MODE_PRE_ENROLL) {
    return COURSE_MODE_PRE_ENROLL;
  }
  return COURSE_MODE_ADD_DROP;
}

function normalizeCourseFilterOption(option: string): string {
  if (option === COURSE_FILTER_OPTION_GE) {
    return COURSE_FILTER_OPTION_GE;
  }
  return COURSE_FILTER_OPTION_CMRE;
}

function mergeFilterOptions(options: CourseFilterOptions): CourseFilterOptions {
  return {
    mode: normalizeCourseMode(options.mode),
    option: normalizeCourseFilterOption(options.option),
    facultyName: options.facultyName && options.facultyName.length > 0 ?
    options.facultyName : DEFAULT_COURSE_FILTER_OPTIONS.facultyName,
    depaName: options.depaName && options.depaName.length > 0 ?
    options.depaName : DEFAULT_COURSE_FILTER_OPTIONS.depaName,
    GE: options.GE && options.GE.length > 0 ? options.GE : DEFAULT_COURSE_FILTER_OPTIONS.GE
  };
}

function planItemsToCatalogItems(source: CoursePlanItem[]): CourseCatalogItem[] {
  const result: CourseCatalogItem[] = [];
  for (let i = 0; i < source.length; i++) {
    result.push({
      offeringUnit: source[i].offeringUnit,
      offeringDepartment: source[i].offeringDepartment,
      courseCode: source[i].courseCode,
      courseTitle: source[i].courseTitle,
      courseTitleChi: source[i].courseTitleChi,
      courseType: source[i].courseType,
      section: source[i].section,
      mediumOfInstruction: source[i].mediumOfInstruction,
      notesForCourseEnrolment: source[i].notesForCourseEnrolment,
      teacherInformation: source[i].teacherInformation,
      lectureLab: source[i].lectureLab,
      labInformation: source[i].labInformation,
      day: source[i].day,
      timeFrom: source[i].timeFrom,
      timeTo: source[i].timeTo,
      classroom: source[i].classroom,
      classForInfo: source[i].classForInfo
    });
  }
  return result;
}

function offerItemsToCatalogItems(source: OfferCourseItem[]): CourseCatalogItem[] {
  const result: CourseCatalogItem[] = [];
  for (let i = 0; i < source.length; i++) {
    result.push({
      offeringUnit: source[i].offeringUnit,
      offeringDepartment: source[i].offeringDepartment,
      courseCode: source[i].courseCode,
      courseTitle: source[i].courseTitle,
      courseTitleChi: source[i].courseTitleChi,
      courseType: source[i].courseType,
      creditUnits: source[i].creditUnits,
      forIncomingExchangeStudents: source[i].forIncomingExchangeStudents,
      courseForInfo: source[i].courseForInfo,
      enrolledYearLevel: source[i].enrolledYearLevel,
      remarks: source[i].remarks
    });
  }
  return result;
}

function courseCode(item: CourseCatalogItem): string {
  return item.courseCode;
}

function courseStartsWithGE(item: CourseCatalogItem): boolean {
  return courseCode(item).startsWith('GE');
}

function geName(item: CourseCatalogItem): string {
  const code: string = courseCode(item);
  if (code.length >= 4) {
    return code.substring(0, 4);
  }
  return '';
}

function getFacultyList(courses: CourseCatalogItem[]): string[] {
  const values: string[] = [];
  for (let i = 0; i < courses.length; i++) {
    pushUnique(values, courses[i].offeringUnit);
  }
  return sortedCopy(values);
}

function getGeList(courses: CourseCatalogItem[]): string[] {
  const values: string[] = [];
  for (let i = 0; i < courses.length; i++) {
    if (courseStartsWithGE(courses[i])) {
      pushUnique(values, geName(courses[i]));
    }
  }
  return sortedCopy(values);
}

function getDepartmentsForFaculty(courses: CourseCatalogItem[], facultyName: string): string[] {
  const values: string[] = [];
  for (let i = 0; i < courses.length; i++) {
    if (courses[i].offeringUnit === facultyName) {
      pushUnique(values, courses[i].offeringDepartment);
    }
  }
  return sortedCopy(values);
}

function getFacultyDepartments(courses: CourseCatalogItem[], facultyList: string[]): CourseFacultyDepartments[] {
  const result: CourseFacultyDepartments[] = [];
  for (let i = 0; i < facultyList.length; i++) {
    result.push({
      facultyName: facultyList[i],
      departments: getDepartmentsForFaculty(courses, facultyList[i])
    });
  }
  return result;
}

function getCoursesByFaculty(courses: CourseCatalogItem[], facultyName: string): CourseCatalogItem[] {
  const result: CourseCatalogItem[] = [];
  for (let i = 0; i < courses.length; i++) {
    if (courses[i].offeringUnit === facultyName) {
      result.push(courses[i]);
    }
  }
  return result;
}

function getCoursesByDepartment(courses: CourseCatalogItem[], departmentName: string): CourseCatalogItem[] {
  const result: CourseCatalogItem[] = [];
  for (let i = 0; i < courses.length; i++) {
    if (courses[i].offeringDepartment === departmentName) {
      result.push(courses[i]);
    }
  }
  return result;
}

function getCoursesByGE(courses: CourseCatalogItem[], selectedGE: string): CourseCatalogItem[] {
  const result: CourseCatalogItem[] = [];
  for (let i = 0; i < courses.length; i++) {
    if (geName(courses[i]) === selectedGE) {
      result.push(courses[i]);
    }
  }
  return result;
}

function normalizeFilterOptions(courses: CourseCatalogItem[], options: CourseFilterOptions): CourseFilterOptions {
  const mergedOptions: CourseFilterOptions = mergeFilterOptions(options);
  const facultyList: string[] = getFacultyList(courses);
  if (facultyList.length === 0) {
    return mergedOptions;
  }

  let facultyName: string = mergedOptions.facultyName;
  if (!containsValue(facultyList, facultyName)) {
    facultyName = facultyList[0];
  }

  let depaName: string = mergedOptions.depaName;
  const depaList: string[] = getDepartmentsForFaculty(courses, facultyName);
  if (mergedOptions.option === COURSE_FILTER_OPTION_CMRE && depaList.length > 0 &&
    !containsValue(depaList, depaName)) {
    depaName = depaList[0];
  }

  let selectedGE: string = mergedOptions.GE;
  const geList: string[] = getGeList(courses);
  if (mergedOptions.option === COURSE_FILTER_OPTION_GE && geList.length > 0 &&
    !containsValue(geList, selectedGE)) {
    selectedGE = geList[0];
  }

  return {
    mode: mergedOptions.mode,
    option: mergedOptions.option,
    facultyName: facultyName,
    depaName: depaName,
    GE: selectedGE
  };
}

function selectFilteredCourses(courses: CourseCatalogItem[], options: CourseFilterOptions): CourseCatalogItem[] {
  if (options.option === COURSE_FILTER_OPTION_GE) {
    return getCoursesByGE(courses, options.GE);
  }

  const depaList: string[] = getDepartmentsForFaculty(courses, options.facultyName);
  if (depaList.length > 0) {
    return getCoursesByDepartment(courses, options.depaName);
  }
  return getCoursesByFaculty(courses, options.facultyName);
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

function courseMatchesOfferSearch(item: CourseCatalogItem, keyword: string, upperKeyword: string,
  traditionalKeyword: string): boolean {
  return containsUpper(item.courseCode, upperKeyword) ||
  containsUpper(item.courseTitle, upperKeyword) ||
  containsChineseText(item.courseTitleChi, keyword, traditionalKeyword);
}

function courseMatchesTimetableSearch(item: CourseCatalogItem, keyword: string, upperKeyword: string,
  traditionalKeyword: string): boolean {
  return containsUpper(item.courseCode, upperKeyword) ||
  containsUpper(item.courseTitle, upperKeyword) ||
  containsUpper(item.teacherInformation, upperKeyword) ||
  containsUpper(item.day, upperKeyword) ||
  containsUpper(item.offeringDepartment, upperKeyword) ||
  containsUpper(item.offeringUnit, upperKeyword) ||
  containsChineseText(item.courseTitleChi, keyword, traditionalKeyword);
}

function hasCourseCode(courses: CourseCatalogItem[], code: string): boolean {
  for (let i = 0; i < courses.length; i++) {
    if (courseCode(courses[i]) === code) {
      return true;
    }
  }
  return false;
}

function sortCoursesByCode(courses: CourseCatalogItem[]): CourseCatalogItem[] {
  const result: CourseCatalogItem[] = [];
  for (let i = 0; i < courses.length; i++) {
    result.push(courses[i]);
  }
  result.sort((left: CourseCatalogItem, right: CourseCatalogItem): number =>
  compareString(courseCode(left), courseCode(right)));
  return result;
}

function findLabel(labels: CourseCodeLabel[], code: string): string {
  for (let i = 0; i < labels.length; i++) {
    if (labels[i].code === code) {
      return labels[i].label;
    }
  }
  return code;
}

export class CourseCatalogService {
  static defaultFilterOptions(): CourseFilterOptions {
    return {
      mode: DEFAULT_COURSE_FILTER_OPTIONS.mode,
      option: DEFAULT_COURSE_FILTER_OPTIONS.option,
      facultyName: DEFAULT_COURSE_FILTER_OPTIONS.facultyName,
      depaName: DEFAULT_COURSE_FILTER_OPTIONS.depaName,
      GE: DEFAULT_COURSE_FILTER_OPTIONS.GE
    };
  }

  static getCourseListForMode(mode: string, coursePlanData: CoursePlanFile,
    offerCoursesData: OfferCoursesFile): CourseCatalogItem[] {
    const normalizedMode: string = normalizeCourseMode(mode);
    if (normalizedMode === COURSE_MODE_PRE_ENROLL) {
      return offerItemsToCatalogItems(offerCoursesData.Courses);
    }
    return planItemsToCatalogItems(coursePlanData.Courses);
  }

  static buildFilterResult(offerCourseList: CourseCatalogItem[],
    filterOptions: CourseFilterOptions): CourseFilterResult {
    const facultyList: string[] = getFacultyList(offerCourseList);
    const geList: string[] = getGeList(offerCourseList);
    const facultyDepartments: CourseFacultyDepartments[] = getFacultyDepartments(offerCourseList, facultyList);
    const normalizedFilterOptions: CourseFilterOptions = normalizeFilterOptions(offerCourseList, filterOptions);
    return {
      offerCourseList: offerCourseList,
      facultyList: facultyList,
      geList: geList,
      facultyDepartments: facultyDepartments,
      normalizedFilterOptions: normalizedFilterOptions,
      filterCourseList: selectFilteredCourses(offerCourseList, normalizedFilterOptions)
    };
  }

  static shouldSearch(keyword: string): boolean {
    const normalizedKeyword: string = keyword.trim();
    if (hasChinese(normalizedKeyword)) {
      return normalizedKeyword.length > 0;
    }
    return normalizedKeyword.length > 2;
  }

  static buildSearchResults(keyword: string, offerCourseList: CourseCatalogItem[],
    coursePlanTimeCourses: CourseCatalogItem[]): CourseSearchResult {
    const normalizedKeyword: string = keyword.trim();
    if (!CourseCatalogService.shouldSearch(normalizedKeyword)) {
      return {
        active: false,
        keyword: normalizedKeyword,
        results: []
      };
    }

    const upperKeyword: string = normalizedKeyword.toUpperCase();
    const traditionalKeyword: string = normalizeSimplifiedChinese(normalizedKeyword);
    const result: CourseCatalogItem[] = [];
    for (let i = 0; i < offerCourseList.length; i++) {
      if (courseMatchesOfferSearch(offerCourseList[i], normalizedKeyword, upperKeyword, traditionalKeyword)) {
        const code: string = courseCode(offerCourseList[i]);
        if (!hasCourseCode(result, code)) {
          result.push(offerCourseList[i]);
        }
      }
    }

    for (let i = 0; i < coursePlanTimeCourses.length; i++) {
      if (courseMatchesTimetableSearch(coursePlanTimeCourses[i], normalizedKeyword, upperKeyword,
        traditionalKeyword)) {
        const code: string = courseCode(coursePlanTimeCourses[i]);
        if (!hasCourseCode(result, code)) {
          result.push(coursePlanTimeCourses[i]);
        }
      }
    }

    return {
      active: true,
      keyword: normalizedKeyword,
      results: sortCoursesByCode(result)
    };
  }

  static async readFilterOptions(context: common.Context): Promise<CourseFilterOptions> {
    const cachedOptions: CourseFilterOptions | null =
      await JsonStore.getOptionalObject<CourseFilterOptions>(context, STORAGE_COURSE_FILTER_OPTIONS);
    if (cachedOptions === null) {
      return CourseCatalogService.defaultFilterOptions();
    }
    return mergeFilterOptions(cachedOptions);
  }

  static async saveFilterOptions(context: common.Context, filterOptions: CourseFilterOptions): Promise<void> {
    await JsonStore.setObject<CourseFilterOptions>(context, STORAGE_COURSE_FILTER_OPTIONS,
      mergeFilterOptions(filterOptions));
  }

  static async loadCatalog(context: common.Context): Promise<ServiceResult<CourseCatalogState>> {
    const versionResult: ServiceResult<CourseVersion> = await CourseDataService.getCourseVersion(context);
    if (!versionResult.ok || !versionResult.data) {
      return errorResult<CourseCatalogState>('COURSE_VERSION_READ_FAILED',
        versionResult.error?.message ?? '读取课程版本失败', versionResult.response);
    }

    const offerResult: ServiceResult<OfferCoursesFile> = await CourseDataService.getOfferCourses(context);
    if (!offerResult.ok || !offerResult.data) {
      return errorResult<CourseCatalogState>('OFFER_COURSES_READ_FAILED',
        offerResult.error?.message ?? '读取 PreEnroll 课程失败', offerResult.response);
    }

    const coursePlanResult: ServiceResult<CoursePlanFile> = await CourseDataService.getCoursePlan(context);
    if (!coursePlanResult.ok || !coursePlanResult.data) {
      return errorResult<CourseCatalogState>('COURSE_PLAN_READ_FAILED',
        coursePlanResult.error?.message ?? '读取 Add/Drop 课程失败', coursePlanResult.response);
    }

    const coursePlanTimeResult: ServiceResult<CoursePlanFile> = await CourseDataService.getCoursePlanTime(context);
    if (!coursePlanTimeResult.ok || !coursePlanTimeResult.data) {
      return errorResult<CourseCatalogState>('COURSE_PLAN_TIME_READ_FAILED',
        coursePlanTimeResult.error?.message ?? '读取课程时间表失败', coursePlanTimeResult.response);
    }

    const storedFilterOptions: CourseFilterOptions = await CourseCatalogService.readFilterOptions(context);
    const offerCourseList: CourseCatalogItem[] =
      CourseCatalogService.getCourseListForMode(storedFilterOptions.mode, coursePlanResult.data, offerResult.data);
    const filterResult: CourseFilterResult =
      CourseCatalogService.buildFilterResult(offerCourseList, storedFilterOptions);
    const state: CourseCatalogState = {
      courseMode: filterResult.normalizedFilterOptions.mode,
      courseVersion: versionResult.data,
      offerCoursesData: offerResult.data,
      coursePlanData: coursePlanResult.data,
      coursePlanTimeData: coursePlanTimeResult.data,
      offerCourseList: filterResult.offerCourseList,
      facultyList: filterResult.facultyList,
      geList: filterResult.geList,
      facultyDepartments: filterResult.facultyDepartments,
      normalizedFilterOptions: filterResult.normalizedFilterOptions,
      filterCourseList: filterResult.filterCourseList
    };
    return okResult<CourseCatalogState>(state);
  }

  static buildCourseLinks(courseCode: string): CourseLinkBundle {
    return {
      wikiUrl: buildWikiSearchUrl(courseCode),
      what2RegUrl: UmehHostService.buildCourseUrl(courseCode),
      officialCourseUrl: buildOfficialCourseUrl(courseCode)
    };
  }

  static modeLabel(code: string, english: boolean): string {
    return findLabel(english ? COURSE_MODE_LABELS_EN : COURSE_MODE_LABELS_TC, code);
  }

  static unitLabel(code: string): string {
    return findLabel(COURSE_UNIT_LABELS, code);
  }

  static departmentLabel(code: string): string {
    return findLabel(COURSE_DEPARTMENT_LABELS, code);
  }

  static geLabel(code: string): string {
    return findLabel(COURSE_GE_LABELS, code);
  }

  static timetableCoursesToCatalogItems(source: CoursePlanFile): CourseCatalogItem[] {
    return planItemsToCatalogItems(source.Courses);
  }
}
