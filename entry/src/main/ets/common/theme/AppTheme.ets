import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { STORAGE_THEME_PREFERENCE } from '../constants/StorageKeys';
import { PreferencesStore } from '../storage/PreferencesStore';
import { Logger } from '../utils/Logger';

export const THEME_MODE_SYSTEM: number = 0;
export const THEME_MODE_LIGHT: number = 1;
export const THEME_MODE_DARK: number = 2;

export const ARKUI_COLOR_MODE_LIGHT: number = 0;
export const ARKUI_COLOR_MODE_DARK: number = 1;

export interface AppThemeColors {
  isLight: boolean;
  themeColor: string;
  themeColorLight: string;
  themeColorUltraLight: string;
  secondThemeColor: string;
  bgColor: string;
  surfaceColor: string;
  surfaceAltColor: string;
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  borderColor: string;
  successColor: string;
  warningColor: string;
  dangerColor: string;
  disabledColor: string;
  tabInactiveColor: string;
}

export const LIGHT_THEME: AppThemeColors = {
  isLight: true,
  themeColor: '#4796D6',
  themeColorLight: '#7CA8CC',
  themeColorUltraLight: '#C9E1F5',
  secondThemeColor: '#FF8627',
  bgColor: '#F5F5F7',
  surfaceColor: '#FFFFFF',
  surfaceAltColor: '#EEF2F6',
  textPrimary: '#111827',
  textSecondary: '#4B5563',
  textTertiary: '#6B7280',
  borderColor: '#E5E7EB',
  successColor: '#27AE60',
  warningColor: '#F39C12',
  dangerColor: '#F75353',
  disabledColor: '#CAD5DE',
  tabInactiveColor: '#4B5563'
};

export const DARK_THEME: AppThemeColors = {
  isLight: false,
  themeColor: '#4A9CDE',
  themeColorLight: '#2D5F87',
  themeColorUltraLight: '#23323D',
  secondThemeColor: '#FF8627',
  bgColor: '#121212',
  surfaceColor: '#272729',
  surfaceAltColor: '#1E1E20',
  textPrimary: '#FFFFFF',
  textSecondary: '#E5E5E7',
  textTertiary: '#B8B8BD',
  borderColor: '#383A3D',
  successColor: '#27AE60',
  warningColor: '#F39C12',
  dangerColor: '#F75353',
  disabledColor: '#3A3D40',
  tabInactiveColor: '#C8C8CC'
};

export class ThemeStore {
  static isValidThemeMode(mode: number): boolean {
    return mode === THEME_MODE_SYSTEM || mode === THEME_MODE_LIGHT || mode === THEME_MODE_DARK;
  }

  static getModeLabel(mode: number): string {
    if (mode === THEME_MODE_LIGHT) {
      return 'Light';
    }
    if (mode === THEME_MODE_DARK) {
      return 'Dark';
    }
    return 'System';
  }

  static systemIsLight(systemColorMode: number): boolean {
    return systemColorMode !== ARKUI_COLOR_MODE_DARK;
  }

  static resolveTheme(mode: number, systemColorMode: number): AppThemeColors {
    if (mode === THEME_MODE_LIGHT) {
      return LIGHT_THEME;
    }
    if (mode === THEME_MODE_DARK) {
      return DARK_THEME;
    }
    return ThemeStore.systemIsLight(systemColorMode) ? LIGHT_THEME : DARK_THEME;
  }

  static async loadThemeMode(context: common.Context): Promise<number> {
    const storedMode: number = await PreferencesStore.getNumber(context, STORAGE_THEME_PREFERENCE,
      THEME_MODE_SYSTEM);
    if (ThemeStore.isValidThemeMode(storedMode)) {
      return storedMode;
    }
    const storedText: string = await PreferencesStore.getString(context, STORAGE_THEME_PREFERENCE, '');
    const parsedMode: number = Number.parseInt(storedText, 10);
    if (ThemeStore.isValidThemeMode(parsedMode)) {
      return parsedMode;
    }
    return THEME_MODE_SYSTEM;
  }

  static async setThemeMode(context: common.UIAbilityContext, mode: number): Promise<void> {
    const nextMode: number = ThemeStore.isValidThemeMode(mode) ? mode : THEME_MODE_SYSTEM;
    await PreferencesStore.set(context, STORAGE_THEME_PREFERENCE, nextMode);
    ThemeStore.applyColorMode(context, nextMode);
  }

  static applyColorMode(context: common.UIAbilityContext, mode: number): void {
    try {
      if (mode === THEME_MODE_LIGHT) {
        context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else if (mode === THEME_MODE_DARK) {
        context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else {
        context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (error) {
      Logger.warn('Apply color mode failed: ' + String(error));
    }
  }
}
