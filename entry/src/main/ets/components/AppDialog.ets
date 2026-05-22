import { promptAction, UIContext } from '@kit.ArkUI';
import { Logger } from '../common/utils/Logger';

export interface AppDialogOptions {
  title: string;
  message: string;
  confirmText?: string;
  cancelText?: string;
}

export class AppDialog {
  static async alert(uiContext: UIContext, options: AppDialogOptions): Promise<void> {
    try {
      await uiContext.getPromptAction().showDialog({
        title: options.title,
        message: options.message,
        buttons: [
          {
            text: options.confirmText ?? '确定',
            color: '#4796D6',
            primary: true
          }
        ]
      });
    } catch (error) {
      Logger.warn('Dialog alert failed: ' + String(error));
    }
  }

  static async confirm(uiContext: UIContext, options: AppDialogOptions): Promise<boolean> {
    try {
      const response: promptAction.ShowDialogSuccessResponse = await uiContext.getPromptAction().showDialog({
        title: options.title,
        message: options.message,
        buttons: [
          {
            text: options.confirmText ?? '确定',
            color: '#4796D6',
            primary: true
          },
          {
            text: options.cancelText ?? '取消',
            color: '#6B7280'
          }
        ]
      });
      return response.index === 0;
    } catch (error) {
      Logger.warn('Dialog confirm failed: ' + String(error));
      return false;
    }
  }
}
