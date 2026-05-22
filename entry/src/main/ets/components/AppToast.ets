import { UIContext } from '@kit.ArkUI';
import { Logger } from '../common/utils/Logger';

export enum AppToastType {
  Info = 'info',
  Success = 'success',
  Warning = 'warning',
  Error = 'error'
}

function prefixForType(type: AppToastType): string {
  if (type === AppToastType.Success) {
    return '完成：';
  }
  if (type === AppToastType.Warning) {
    return '注意：';
  }
  if (type === AppToastType.Error) {
    return '错误：';
  }
  return '';
}

export class AppToast {
  static show(uiContext: UIContext, message: string, type: AppToastType = AppToastType.Info,
    duration: number = 1800): void {
    try {
      uiContext.getPromptAction().showToast({
        message: prefixForType(type) + message,
        duration: duration
      });
    } catch (error) {
      Logger.warn('Toast failed: ' + String(error));
    }
  }

  static showError(uiContext: UIContext, message: string): void {
    AppToast.show(uiContext, message, AppToastType.Error, 2400);
  }
}
