import { common } from '@kit.AbilityKit';
import { UmOpenDataConfig } from '../common/config/UmOpenDataConfig';
import { ServiceResult } from '../common/net/HttpClient';
import { Logger } from '../common/utils/Logger';
import { AppInfoUpdateState, AppInfoService } from '../services/AppInfoService';
import { AnalyticsParams, AnalyticsService } from '../services/AnalyticsService';
import { CourseDataService, CourseDataSummary, CourseUpdateSummary } from '../services/CourseDataService';
import { AppStartupState, createInitialStartupState, StartupTaskResult } from './AppState';

function pushTask(tasks: StartupTaskResult[], name: string, ok: boolean, message: string): void {
  tasks.push({
    name: name,
    ok: ok,
    message: message
  });
}

function copyTasks(source: StartupTaskResult[]): StartupTaskResult[] {
  const tasks: StartupTaskResult[] = [];
  for (let index = 0; index < source.length; index++) {
    const task: StartupTaskResult = source[index];
    pushTask(tasks, task.name, task.ok, task.message);
  }
  return tasks;
}

export class AppBootstrap {
  private static startupState: AppStartupState | undefined = undefined;

  static getStartupState(): AppStartupState | undefined {
    return AppBootstrap.startupState;
  }

  private static setStartupState(state: AppStartupState): AppStartupState {
    AppBootstrap.startupState = state;
    return state;
  }

  static async initializeEssential(context: common.UIAbilityContext): Promise<AppStartupState> {
    const tasks: StartupTaskResult[] = [];
    let hasWarning: boolean = false;
    let message: string = '必要初始化完成';
    let courseSummary: CourseDataSummary | undefined = undefined;
    let courseUpdateSummary: CourseUpdateSummary | undefined = undefined;

    try {
      const tokenLoaded: boolean = await UmOpenDataConfig.loadFromEnv(context);
      if (tokenLoaded) {
        pushTask(tasks, 'um-open-data-token', true, 'UM Open Data Token 已加载');
      } else {
        hasWarning = true;
        pushTask(tasks, 'um-open-data-token', false, '缺少 UM Open Data Token/配置');
      }
    } catch (error) {
      hasWarning = true;
      pushTask(tasks, 'um-open-data-token', false, 'UM Open Data Token 加载失败');
      Logger.warn('Load UM Open Data token failed: ' + String(error));
    }

    try {
      const cacheResult: ServiceResult<CourseDataSummary> =
        await CourseDataService.ensureBuiltInCourseCache(context);
      if (cacheResult.ok && cacheResult.data) {
        courseSummary = cacheResult.data;
        pushTask(tasks, 'course-cache', true, '课程缓存初始化完成');
      } else {
        hasWarning = true;
        pushTask(tasks, 'course-cache', false, cacheResult.error?.message ?? '课程缓存初始化失败');
      }
    } catch (error) {
      hasWarning = true;
      pushTask(tasks, 'course-cache', false, '课程缓存初始化异常');
      Logger.warn('Initialize course cache failed: ' + String(error));
    }

    try {
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
    } catch (error) {
      hasWarning = true;
      pushTask(tasks, 'course-built-in-version', false, '内置课程版本校准异常');
      Logger.warn('Refresh built-in course cache failed: ' + String(error));
    }

    if (hasWarning) {
      message = '部分必要初始化失败，可继续使用';
    }

    return AppBootstrap.setStartupState({
      running: false,
      ready: true,
      backgroundRunning: false,
      hasWarning: hasWarning,
      message: message,
      localVersion: '',
      latestVersion: '',
      appUpdateAvailable: false,
      courseSummary: courseSummary,
      courseUpdateSummary: courseUpdateSummary,
      tasks: tasks
    });
  }

  static markBackgroundInitializationRunning(baseState: AppStartupState): AppStartupState {
    const state: AppStartupState = {
      running: false,
      ready: baseState.ready,
      backgroundRunning: true,
      hasWarning: baseState.hasWarning,
      message: baseState.hasWarning ? '必要初始化部分失败，后台同步中' : '必要初始化完成，后台同步中',
      localVersion: baseState.localVersion,
      latestVersion: baseState.latestVersion,
      appUpdateAvailable: baseState.appUpdateAvailable,
      courseSummary: baseState.courseSummary,
      courseUpdateSummary: baseState.courseUpdateSummary,
      appInfo: baseState.appInfo,
      tasks: copyTasks(baseState.tasks)
    };
    return AppBootstrap.setStartupState(state);
  }

  static async initializeBackground(context: common.UIAbilityContext,
    baseState?: AppStartupState): Promise<AppStartupState> {
    const sourceState: AppStartupState = baseState ?? AppBootstrap.startupState ?? createInitialStartupState();
    const tasks: StartupTaskResult[] = copyTasks(sourceState.tasks);
    let hasWarning: boolean = sourceState.hasWarning;
    let message: string = '启动初始化完成';
    let courseSummary: CourseDataSummary | undefined = sourceState.courseSummary;
    let courseUpdateSummary: CourseUpdateSummary | undefined = sourceState.courseUpdateSummary;
    let localVersion: string = sourceState.localVersion;
    let latestVersion: string = sourceState.latestVersion;
    let appUpdateAvailable: boolean = sourceState.appUpdateAvailable;
    let appInfo = sourceState.appInfo;

    try {
      const cloudResult: ServiceResult<CourseUpdateSummary> =
        await CourseDataService.checkCloudCourseVersionIfNeeded(context);
      if (cloudResult.ok && cloudResult.data) {
        courseUpdateSummary = cloudResult.data;
        pushTask(tasks, 'course-cloud-version', true, cloudResult.data.message);
      } else {
        hasWarning = true;
        pushTask(tasks, 'course-cloud-version', false, cloudResult.error?.message ?? '云端课程版本检查失败');
      }
    } catch (error) {
      hasWarning = true;
      pushTask(tasks, 'course-cloud-version', false, '云端课程版本检查异常');
      Logger.warn('Check cloud course version failed: ' + String(error));
    }

    try {
      const appInfoResult: ServiceResult<AppInfoUpdateState> = await AppInfoService.checkUpdateState(context);
      if (appInfoResult.data) {
        localVersion = appInfoResult.data.localVersion;
        latestVersion = appInfoResult.data.latestVersion;
        appUpdateAvailable = appInfoResult.data.updateAvailable;
        appInfo = appInfoResult.data.appInfo;
      }
      if (appInfoResult.ok) {
        pushTask(tasks, 'app-info', true, 'AppInfo 同步完成');
      } else {
        hasWarning = true;
        pushTask(tasks, 'app-info', false, appInfoResult.error?.message ?? 'AppInfo 同步失败');
      }
    } catch (error) {
      hasWarning = true;
      pushTask(tasks, 'app-info', false, 'AppInfo 同步异常');
      Logger.warn('Check AppInfo failed: ' + String(error));
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

    return AppBootstrap.setStartupState({
      running: false,
      ready: true,
      backgroundRunning: false,
      hasWarning: hasWarning,
      message: message,
      localVersion: localVersion,
      latestVersion: latestVersion,
      appUpdateAvailable: appUpdateAvailable,
      courseSummary: courseSummary,
      courseUpdateSummary: courseUpdateSummary,
      appInfo: appInfo,
      tasks: tasks
    });
  }

  static async initialize(context: common.UIAbilityContext): Promise<AppStartupState> {
    const essentialState: AppStartupState = await AppBootstrap.initializeEssential(context);
    const backgroundState: AppStartupState = AppBootstrap.markBackgroundInitializationRunning(essentialState);
    return await AppBootstrap.initializeBackground(context, backgroundState);
  }
}
