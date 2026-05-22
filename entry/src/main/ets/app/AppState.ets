import { AppInfo } from '../models/AppInfo';
import { CourseDataSummary, CourseUpdateSummary } from '../services/CourseDataService';

export interface StartupTaskResult {
  name: string;
  ok: boolean;
  message: string;
}

export interface AppStartupState {
  running: boolean;
  ready: boolean;
  backgroundRunning: boolean;
  hasWarning: boolean;
  message: string;
  localVersion: string;
  appUpdateAvailable: boolean;
  latestVersion: string;
  courseSummary?: CourseDataSummary;
  courseUpdateSummary?: CourseUpdateSummary;
  appInfo?: AppInfo;
  tasks: StartupTaskResult[];
}

export function createInitialStartupState(): AppStartupState {
  return {
    running: true,
    ready: false,
    backgroundRunning: false,
    hasWarning: false,
    message: 'ARK ALL 正在初始化',
    localVersion: '',
    appUpdateAvailable: false,
    latestVersion: '',
    tasks: []
  };
}
