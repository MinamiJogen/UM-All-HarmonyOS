export interface CourseVersionEntry {
  updateTime: string;
  academicYear: string;
  sem: string;
}

export interface CourseVersion {
  pre: CourseVersionEntry;
  adddrop: CourseVersionEntry;
}

export interface CourseBase {
  offeringUnit: string;
  offeringDepartment: string;
  courseCode: string;
  courseTitle: string;
  courseTitleChi?: string;
  courseType?: string;
}

export interface CoursePlanItem extends CourseBase {
  section: string;
  mediumOfInstruction?: string;
  notesForCourseEnrolment?: string;
  teacherInformation?: string;
  lectureLab?: string;
  labInformation?: string;
  day?: string;
  timeFrom?: string;
  timeTo?: string;
  classroom?: string;
  classForInfo?: string;
}

export interface OfferCourseItem extends CourseBase {
  creditUnits?: string;
  forIncomingExchangeStudents?: string;
  courseForInfo?: string;
  enrolledYearLevel?: string;
  remarks?: string;
}

export interface CoursePlanFile {
  Courses: CoursePlanItem[];
}

export interface OfferCoursesFile {
  Courses: OfferCourseItem[];
  updateTime?: string;
  academicYear?: string;
  sem?: string;
  remark?: string;
  preEn?: string;
}

export interface TimetableSelection {
  courseCode: string;
  section: string;
}

export interface TimetableHomeCacheItem {
  courseCode: string;
  section: string;
  courseTitle?: string;
  courseTitleChi?: string;
  day?: string;
  timeFrom: string;
  timeTo?: string;
  classroom?: string;
  color: number;
}

export interface WeekTimetableHomeCache {
  MON: TimetableHomeCacheItem[];
  TUE: TimetableHomeCacheItem[];
  WED: TimetableHomeCacheItem[];
  THU: TimetableHomeCacheItem[];
  FRI: TimetableHomeCacheItem[];
  SAT: TimetableHomeCacheItem[];
  SUN: TimetableHomeCacheItem[];
}

export interface TimetableCourseMeeting extends CoursePlanItem {
  selectionIndex: number;
  color: number;
  startsAtMinutes: number;
  endsAtMinutes: number;
  breakBeforeMinutes: number;
  conflict: boolean;
  conflictWithPrevious: boolean;
  periodHint: string;
}

export interface WeekTimetable {
  MON: TimetableCourseMeeting[];
  TUE: TimetableCourseMeeting[];
  WED: TimetableCourseMeeting[];
  THU: TimetableCourseMeeting[];
  FRI: TimetableCourseMeeting[];
  SAT: TimetableCourseMeeting[];
  SUN: TimetableCourseMeeting[];
}

export interface TimetableBuildResult {
  selections: TimetableSelection[];
  allMeetings: TimetableCourseMeeting[];
  weekTimetable: WeekTimetable;
  homeCache: WeekTimetableHomeCache;
  missingSelections: TimetableSelection[];
  hasConflict: boolean;
}

export interface TimetableImportResult {
  selections: TimetableSelection[];
  importedCount: number;
  ignoredDuplicateCount: number;
}

export interface TimetableSectionSummary {
  section: string;
  teacherInformation: string;
  meetings: TimetableCourseMeeting[];
  hasConflict: boolean;
}

export interface TimetableCourseSummary extends CourseBase {
  sections: TimetableSectionSummary[];
}

export interface TimetableSearchFilter {
  day: string;
  timeFrom: string;
  timeTo: string;
}

export interface TimetableSearchResult {
  active: boolean;
  keyword: string;
  results: TimetableCourseSummary[];
}

export interface CourseFilterOptions {
  mode: string;
  option: string;
  facultyName: string;
  depaName: string;
  GE: string;
}

export interface CourseCatalogItem extends CourseBase {
  section?: string;
  creditUnits?: string;
  forIncomingExchangeStudents?: string;
  courseForInfo?: string;
  enrolledYearLevel?: string;
  remarks?: string;
  mediumOfInstruction?: string;
  notesForCourseEnrolment?: string;
  teacherInformation?: string;
  lectureLab?: string;
  labInformation?: string;
  day?: string;
  timeFrom?: string;
  timeTo?: string;
  classroom?: string;
  classForInfo?: string;
}

export interface CourseFacultyDepartments {
  facultyName: string;
  departments: string[];
}

export interface CourseFilterResult {
  offerCourseList: CourseCatalogItem[];
  facultyList: string[];
  geList: string[];
  facultyDepartments: CourseFacultyDepartments[];
  normalizedFilterOptions: CourseFilterOptions;
  filterCourseList: CourseCatalogItem[];
}

export interface CourseSearchResult {
  active: boolean;
  keyword: string;
  results: CourseCatalogItem[];
}

export interface CourseCatalogState extends CourseFilterResult {
  courseMode: string;
  courseVersion: CourseVersion;
  offerCoursesData: OfferCoursesFile;
  coursePlanData: CoursePlanFile;
  coursePlanTimeData: CoursePlanFile;
}

export interface CourseLinkBundle {
  wikiUrl: string;
  what2RegUrl: string;
  officialCourseUrl: string;
}
