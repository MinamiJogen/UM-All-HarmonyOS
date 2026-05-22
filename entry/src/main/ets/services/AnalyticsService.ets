import { Logger } from '../common/utils/Logger';

export class AnalyticsParams {
  warning: boolean = false;
  taskCount: number = 0;
  routeName: string = '';
  value: string = '';
}

export class AnalyticsService {
  static log(eventName: string, params?: AnalyticsParams): void {
    eventName;
    params;
  }

  static setUserId(userId: string): void {
    userId;
  }

  static setEnabled(enabled: boolean): void {
    Logger.info('Analytics no-op enabled=' + String(enabled));
  }
}
