import { common } from '@kit.AbilityKit';
import { ServiceResult } from '../common/net/HttpClient';
import { Logger } from '../common/utils/Logger';
import { AppInfoUpdateState, AppInfoService } from '../services/AppInfoService';
import { AnalyticsParams, AnalyticsService } from '../services/AnalyticsService';
import { CourseDataService, CourseDataSummary, CourseUpdateSummary } from '../services/CourseDataService';
import { AppStartupState, StartupTaskResult } from './AppState';

function pushTask(tasks: StartupTaskResult[], name: string, ok: boolean, message: string): void {
  tasks.push({
    name: name,
    ok: ok,
    message: message
  });
}

export class AppBootstrap {
  static async initialize(context: common.UIAbilityContext): Promise<AppStartupState> {
    const tasks: StartupTaskResult[] = [];
    let hasWarning: boolean = false;
    let message: string = '启动初始化完成';
    let courseSummary: CourseDataSummary | undefined = undefined;
    let courseUpdateSummary: CourseUpdateSummary | undefined = undefined;
    let localVersion: string = '';
    let latestVersion: string = '';
    let appUpdateAvailable: boolean = false;

    const cacheResult: ServiceResult<CourseDataSummary> =
      await CourseDataService.ensureBuiltInCourseCache(context);
    if (cacheResult.ok && cacheResult.data) {
      courseSummary = cacheResult.data;
      pushTask(tasks, 'course-cache', true, '课程缓存初始化完成');
    } else {
      hasWarning = true;
      pushTask(tasks, 'course-cache', false, cacheResult.error?.message ?? '课程缓存初始化失败');
    }

    const builtInRefreshResult: ServiceResult<CourseUpdateSummary> =
      await CourseDataService.refreshBuiltInCourseCacheIfNewer(context);
    if (builtInRefreshResult.ok && builtInRefreshResult.data) {
      courseUpdateSummary = builtInRefreshResult.data;
      pushTask(tasks, 'course-built-in-version', true, builtInRefreshResult.data.message);
    } else {
      hasWarning = true;
      pushTask(tasks, 'course-built-in-version', false,
        builtInRefreshResult.error?.message ?? '内置课程版本校准失败');
    }

    const cloudResult: ServiceResult<CourseUpdateSummary> =
      await CourseDataService.checkCloudCourseVersionIfNeeded(context);
    if (cloudResult.ok && cloudResult.data) {
      courseUpdateSummary = cloudResult.data;
      pushTask(tasks, 'course-cloud-version', true, cloudResult.data.message);
    } else {
      hasWarning = true;
      pushTask(tasks, 'course-cloud-version', false, cloudResult.error?.message ?? '云端课程版本检查失败');
    }

    const appInfoResult: ServiceResult<AppInfoUpdateState> = await AppInfoService.checkUpdateState(context);
    if (appInfoResult.data) {
      localVersion = appInfoResult.data.localVersion;
      latestVersion = appInfoResult.data.latestVersion;
      appUpdateAvailable = appInfoResult.data.updateAvailable;
    }
    if (appInfoResult.ok) {
      pushTask(tasks, 'app-info', true, 'AppInfo 同步完成');
    } else {
      hasWarning = true;
      pushTask(tasks, 'app-info', false, appInfoResult.error?.message ?? 'AppInfo 同步失败');
    }

    try {
      AnalyticsService.setEnabled(true);
      const analyticsParams: AnalyticsParams = new AnalyticsParams();
      analyticsParams.warning = hasWarning;
      analyticsParams.taskCount = tasks.length;
      AnalyticsService.log('app_bootstrap_finished', analyticsParams);
    } catch (error) {
      Logger.warn('Analytics bootstrap hook failed: ' + String(error));
    }

    if (hasWarning) {
      message = '部分启动任务失败，可继续使用';
    }

    return {
      running: false,
      ready: true,
      hasWarning: hasWarning,
      message: message,
      localVersion: localVersion,
      latestVersion: latestVersion,
      appUpdateAvailable: appUpdateAvailable,
      courseSummary: courseSummary,
      courseUpdateSummary: courseUpdateSummary,
      appInfo: appInfoResult.data?.appInfo,
      tasks: tasks
    };
  }
}
