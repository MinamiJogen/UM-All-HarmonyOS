import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0x0A11;
const LOG_TAG: string = 'UMARKALL';

export class Logger {
  static debug(message: string): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, '%{public}s', message);
  }

  static info(message: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, '%{public}s', message);
  }

  static warn(message: string): void {
    hilog.warn(LOG_DOMAIN, LOG_TAG, '%{public}s', message);
  }

  static error(message: string): void {
    hilog.error(LOG_DOMAIN, LOG_TAG, '%{public}s', message);
  }
}
