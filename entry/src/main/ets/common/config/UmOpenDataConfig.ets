import { common } from '@kit.AbilityKit';
import { ServiceError } from '../../models/ApiResponse';
import { RAWFILE_APP_ENV } from '../constants/ResourcePaths';
import { ServiceResult } from '../net/HttpClient';
import { RawFileReader } from '../resources/RawFileReader';
import { Logger } from '../utils/Logger';

const MISSING_TOKEN_MESSAGE: string = '缺少 UM Open Data Token/配置';
const ENV_UM_OPEN_DATA_TOKEN: string = 'UM_OPEN_DATA_TOKEN';
const ENV_EXPO_PUBLIC_UM_API_TOKEN: string = 'EXPO_PUBLIC_UM_API_TOKEN';

function stripWrappingQuotes(value: string): string {
  if (value.length < 2) {
    return value;
  }

  const first: string = value.charAt(0);
  const last: string = value.charAt(value.length - 1);
  if ((first === '"' && last === '"') || (first === "'" && last === "'")) {
    return value.substring(1, value.length - 1);
  }

  return value;
}

function readEnvValue(content: string, key: string): string {
  const lines: string[] = content.split('\n');
  for (let index = 0; index < lines.length; index++) {
    let line: string = lines[index].trim();
    if (line.length === 0 || line.startsWith('#')) {
      continue;
    }
    if (line.startsWith('export ')) {
      line = line.substring('export '.length).trim();
    }

    const equalIndex: number = line.indexOf('=');
    if (equalIndex <= 0) {
      continue;
    }

    const envKey: string = line.substring(0, equalIndex).trim();
    if (envKey !== key) {
      continue;
    }

    return stripWrappingQuotes(line.substring(equalIndex + 1).trim());
  }

  return '';
}

function readUmOpenDataToken(content: string): string {
  const harmonyToken: string = readEnvValue(content, ENV_UM_OPEN_DATA_TOKEN);
  if (harmonyToken.length > 0) {
    return harmonyToken;
  }

  return readEnvValue(content, ENV_EXPO_PUBLIC_UM_API_TOKEN);
}

export class UmOpenDataConfig {
  private static token: string = '';

  static async loadFromEnv(context: common.Context): Promise<boolean> {
    const envResult: ServiceResult<string> = await RawFileReader.readText(context, RAWFILE_APP_ENV);
    if (!envResult.ok || !envResult.data) {
      UmOpenDataConfig.token = '';
      Logger.warn('UM Open Data env file missing or unreadable: ' + RAWFILE_APP_ENV);
      return false;
    }

    UmOpenDataConfig.setToken(readUmOpenDataToken(envResult.data));
    if (!UmOpenDataConfig.hasToken()) {
      Logger.warn('UM Open Data token is empty in ' + RAWFILE_APP_ENV);
      return false;
    }

    return true;
  }

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
