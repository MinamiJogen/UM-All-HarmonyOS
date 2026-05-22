import { common } from '@kit.AbilityKit';
import { STORAGE_LANGUAGE } from '../constants/StorageKeys';
import { PreferencesStore } from '../storage/PreferencesStore';
import { enUsText } from './lang/en_US';
import { zhHkText } from './lang/zh_HK';
import { Logger } from '../utils/Logger';

export const LANGUAGE_TC: string = 'tc';
export const LANGUAGE_EN: string = 'en';

function normalizeStoredLanguage(rawValue: string): string {
  if (rawValue.length === 0) {
    return '';
  }
  if (rawValue === LANGUAGE_TC || rawValue === LANGUAGE_EN) {
    return rawValue;
  }
  try {
    const parsed: string = JSON.parse(rawValue) as string;
    if (parsed === LANGUAGE_TC || parsed === LANGUAGE_EN) {
      return parsed;
    }
  } catch (error) {
    Logger.debug('Stored language is not JSON: ' + String(error));
  }
  return '';
}

export class I18nService {
  static normalizeLanguage(language: string): string {
    if (language === LANGUAGE_EN) {
      return LANGUAGE_EN;
    }
    return LANGUAGE_TC;
  }

  static getDefaultLanguage(context: common.UIAbilityContext): string {
    const systemLanguage: string = context.config?.language ?? '';
    if (systemLanguage.toLowerCase().startsWith('zh')) {
      return LANGUAGE_TC;
    }
    return LANGUAGE_EN;
  }

  static async loadLanguage(context: common.UIAbilityContext): Promise<string> {
    const storedLanguage: string =
      normalizeStoredLanguage(await PreferencesStore.getString(context, STORAGE_LANGUAGE, ''));
    if (storedLanguage.length > 0) {
      return storedLanguage;
    }
    return I18nService.getDefaultLanguage(context);
  }

  static async setLanguage(context: common.UIAbilityContext, language: string): Promise<void> {
    const normalizedLanguage: string = I18nService.normalizeLanguage(language);
    await PreferencesStore.set(context, STORAGE_LANGUAGE, normalizedLanguage);
    try {
      context.getApplicationContext().setLanguage(normalizedLanguage === LANGUAGE_TC ? 'zh-Hant' : 'en');
    } catch (error) {
      Logger.warn('Apply language failed: ' + String(error));
    }
  }

  static t(language: string, key: string, fallback: string = ''): string {
    const normalizedLanguage: string = I18nService.normalizeLanguage(language);
    const value: string = normalizedLanguage === LANGUAGE_EN ? enUsText(key) : zhHkText(key);
    if (value.length > 0) {
      return value;
    }
    return fallback.length > 0 ? fallback : key;
  }
}
