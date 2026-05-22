import { common } from '@kit.AbilityKit';
import { PreferencesStore } from './PreferencesStore';
import { Logger } from '../utils/Logger';

export class JsonStore {
  static async getOptionalObject<T>(context: common.Context, key: string): Promise<T | null> {
    const rawValue: string = await PreferencesStore.getString(context, key, '');
    if (rawValue.length === 0) {
      return null;
    }

    try {
      return JSON.parse(rawValue) as T;
    } catch (error) {
      Logger.warn('JsonStore parse failed: ' + key + ', ' + String(error));
      return null;
    }
  }

  static async getObject<T>(context: common.Context, key: string, defaultValue: T): Promise<T> {
    const rawValue: string = await PreferencesStore.getString(context, key, '');
    if (rawValue.length === 0) {
      return defaultValue;
    }

    try {
      return JSON.parse(rawValue) as T;
    } catch (error) {
      Logger.warn('JsonStore parse failed: ' + key + ', ' + String(error));
      return defaultValue;
    }
  }

  static async setObject<T>(context: common.Context, key: string, value: T): Promise<void> {
    await PreferencesStore.set(context, key, JSON.stringify(value));
  }

  static async remove(context: common.Context, key: string): Promise<void> {
    await PreferencesStore.remove(context, key);
  }
}
