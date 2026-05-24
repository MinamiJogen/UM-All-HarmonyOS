import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppBootstrap } from '../app/AppBootstrap';
import {
  APP_STORAGE_LAUNCH_SEQUENCE,
  APP_STORAGE_LAUNCH_TARGET,
  LAUNCH_PARAM_TARGET,
  LAUNCH_TARGET_TIMETABLE
} from '../common/constants/LaunchTargets';

const DOMAIN = 0x0000;
let launchSequence: number = 0;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.applyLaunchTarget(want);
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.applyLaunchTarget(want);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onNewWant');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.applyImmersiveSystemBars(windowStage);
    this.prepareStartupAndLoadContent(windowStage);
  }

  private async prepareStartupAndLoadContent(windowStage: window.WindowStage): Promise<void> {
    try {
      await AppBootstrap.initializeEssential(this.context);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Startup preparation failed. Cause: %{public}s', JSON.stringify(err));
    }
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  private applyImmersiveSystemBars(windowStage: window.WindowStage): void {
    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(true).then(() => {
        return mainWindow.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          navigationBarColor: '#00000000',
          statusBarContentColor: '#111827',
          navigationBarContentColor: '#111827'
        });
      }).catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to apply immersive system bars. Cause: %{public}s',
          JSON.stringify(err));
      });
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to get main window. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private applyLaunchTarget(want: Want): void {
    const target: string = this.getStringParam(want, LAUNCH_PARAM_TARGET);
    if (target !== LAUNCH_TARGET_TIMETABLE) {
      return;
    }

    launchSequence++;
    AppStorage.setOrCreate<string>(APP_STORAGE_LAUNCH_TARGET, LAUNCH_TARGET_TIMETABLE);
    AppStorage.setOrCreate<number>(APP_STORAGE_LAUNCH_SEQUENCE, launchSequence);
  }

  private getStringParam(want: Want, key: string): string {
    if (want.parameters === undefined) {
      return '';
    }

    const value: Object | undefined = want.parameters[key];
    if (value === undefined || value === null) {
      return '';
    }
    return value.toString();
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
