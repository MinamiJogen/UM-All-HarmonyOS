import { ServiceError } from '../../models/ApiResponse';

const MISSING_TOKEN_MESSAGE: string = '缺少 UM Open Data Token/配置';

export class UmOpenDataConfig {
  private static token: string = 'Bearer c9b17308-8579-3672-8a0d-beb483b794bf';

  static setToken(token: string): void {
    UmOpenDataConfig.token = token.trim();
  }

  static getToken(): string {
    return UmOpenDataConfig.token;
  }

  static hasToken(): boolean {
    return UmOpenDataConfig.token.length > 0;
  }

  static missingTokenError(): ServiceError {
    return {
      code: 'UM_OPEN_DATA_TOKEN_MISSING',
      message: MISSING_TOKEN_MESSAGE
    };
  }
}
