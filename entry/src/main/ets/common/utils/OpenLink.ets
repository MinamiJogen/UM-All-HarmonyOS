import { common } from '@kit.AbilityKit';
import { Logger } from './Logger';

export enum OpenLinkMode {
  Default = 'default',
  FullScreen = 'fullScreen'
}

export interface AppOpenLinkOptions {
  mode?: OpenLinkMode;
}

export class OpenLink {
  static async open(context: common.UIAbilityContext, url: string, options?: AppOpenLinkOptions): Promise<boolean> {
    options;
    if (url.trim().length === 0) {
      Logger.warn('OpenLink skipped empty url');
      return false;
    }

    try {
      await context.openLink(url);
      return true;
    } catch (error) {
      Logger.error('OpenLink failed: ' + url + ', ' + String(error));
      return false;
    }
  }
}
