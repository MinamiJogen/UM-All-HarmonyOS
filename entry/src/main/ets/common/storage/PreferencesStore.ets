import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { APP_PREFERENCES_NAME } from '../constants/StorageKeys';
import { Logger } from '../utils/Logger';

export class PreferencesStore {
  private static store?: preferences.Preferences;

  private static async getStore(context: common.Context): Promise<preferences.Preferences> {
    if (!PreferencesStore.store) {
      PreferencesStore.store = await preferences.getPreferences(context, APP_PREFERENCES_NAME);
    }
    return PreferencesStore.store;
  }

  static async has(context: common.Context, key: string): Promise<boolean> {
    const store: preferences.Preferences = await PreferencesStore.getStore(context);
    return await store.has(key);
  }

  static async getString(context: common.Context, key: string, defaultValue: string = ''): Promise<string> {
    const store: preferences.Preferences = await PreferencesStore.getStore(context);
    const value: preferences.ValueType = await store.get(key, defaultValue);
    if (typeof value === 'string') {
      return value;
    }
    return defaultValue;
  }

  static async getNumber(context: common.Context, key: string, defaultValue: number = 0): Promise<number> {
    const store: preferences.Preferences = await PreferencesStore.getStore(context);
    const value: preferences.ValueType = await store.get(key, defaultValue);
    if (typeof value === 'number') {
      return value;
    }
    return defaultValue;
  }

  static async getBoolean(context: common.Context, key: string, defaultValue: boolean = false): Promise<boolean> {
    const store: preferences.Preferences = await PreferencesStore.getStore(context);
    const value: preferences.ValueType = await store.get(key, defaultValue);
    if (typeof value === 'boolean') {
      return value;
    }
    return defaultValue;
  }

  static async set(context: common.Context, key: string, value: preferences.ValueType): Promise<void> {
    const store: preferences.Preferences = await PreferencesStore.getStore(context);
    await store.put(key, value);
    await store.flush();
  }

  static async remove(context: common.Context, key: string): Promise<void> {
    const store: preferences.Preferences = await PreferencesStore.getStore(context);
    await store.delete(key);
    await store.flush();
  }

  static async removeKeys(context: common.Context, keys: string[]): Promise<void> {
    const store: preferences.Preferences = await PreferencesStore.getStore(context);
    for (let index = 0; index < keys.length; index++) {
      try {
        await store.delete(keys[index]);
      } catch (error) {
        Logger.warn('Preferences delete skipped: ' + keys[index] + ', ' + String(error));
      }
    }
    await store.flush();
  }

  static async clear(context: common.Context): Promise<void> {
    const store: preferences.Preferences = await PreferencesStore.getStore(context);
    await store.clear();
    await store.flush();
  }
}
