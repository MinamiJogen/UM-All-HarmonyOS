export class LocalCourseNavigationState {
  private static pendingCourseCode: string = '';

  static setPendingCourseCode(courseCode: string): void {
    LocalCourseNavigationState.pendingCourseCode = courseCode.trim().toUpperCase();
  }

  static consumePendingCourseCode(): string {
    const courseCode: string = LocalCourseNavigationState.pendingCourseCode;
    LocalCourseNavigationState.pendingCourseCode = '';
    return courseCode;
  }
}
