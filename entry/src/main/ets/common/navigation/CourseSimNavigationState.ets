export class CourseSimNavigationState {
  private static pendingKeyword: string = '';

  static setPendingKeyword(keyword: string): void {
    CourseSimNavigationState.pendingKeyword = keyword.trim().toUpperCase();
  }

  static consumePendingKeyword(): string {
    const keyword: string = CourseSimNavigationState.pendingKeyword;
    CourseSimNavigationState.pendingKeyword = '';
    return keyword;
  }
}
