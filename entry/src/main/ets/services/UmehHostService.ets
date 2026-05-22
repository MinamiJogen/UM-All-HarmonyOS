import { common } from '@kit.AbilityKit';
import {
  WHAT2REG_BACKUP_HOST,
  WHAT2REG_PRIMARY_HOST
} from '../common/constants/ApiEndpoints';
import { STORAGE_UMEH_HOST_PREF } from '../common/constants/StorageKeys';
import { HttpClient, ServiceResult } from '../common/net/HttpClient';
import { PreferencesStore } from '../common/storage/PreferencesStore';

export const UMEH_HOST_PREF_AUTO: string = 'auto';
export const UMEH_HOST_PREF_PRIMARY: string = 'primary';
export const UMEH_HOST_PREF_BACKUP: string = 'backup';

const PROBE_TIMEOUT_MS: number = 2500;
const PROBE_CACHE_TTL_MS: number = 5 * 60 * 1000;

export interface UmehHostState {
  preference: string;
  currentHost: string;
  primaryReachable: boolean;
  probedAt: number;
}

function normalizePreference(preference: string): string {
  if (preference === UMEH_HOST_PREF_PRIMARY || preference === UMEH_HOST_PREF_BACKUP) {
    return preference;
  }
  return UMEH_HOST_PREF_AUTO;
}

export class UmehHostService {
  private static currentHost: string = WHAT2REG_PRIMARY_HOST;
  private static probeCacheResult: boolean | null = null;
  private static probeCacheTimestamp: number = 0;

  static getCurrentHost(): string {
    return UmehHostService.currentHost;
  }

  static async getHostPreference(context: common.Context): Promise<string> {
    const storedPreference: string = await PreferencesStore.getString(context, STORAGE_UMEH_HOST_PREF, '');
    return normalizePreference(storedPreference);
  }

  static async setHostPreference(context: common.Context, preference: string): Promise<UmehHostState> {
    const normalizedPreference: string = normalizePreference(preference);
    await PreferencesStore.set(context, STORAGE_UMEH_HOST_PREF, normalizedPreference);
    return await UmehHostService.refreshHost(context);
  }

  static async refreshHost(context: common.Context): Promise<UmehHostState> {
    const preference: string = await UmehHostService.getHostPreference(context);
    let primaryReachable: boolean = true;
    let probedAt: number = UmehHostService.probeCacheTimestamp;

    if (preference === UMEH_HOST_PREF_PRIMARY) {
      UmehHostService.currentHost = WHAT2REG_PRIMARY_HOST;
      primaryReachable = true;
      probedAt = Date.now();
    } else if (preference === UMEH_HOST_PREF_BACKUP) {
      UmehHostService.currentHost = WHAT2REG_BACKUP_HOST;
      primaryReachable = false;
      probedAt = Date.now();
    } else {
      primaryReachable = await UmehHostService.probePrimaryHost();
      probedAt = UmehHostService.probeCacheTimestamp;
      UmehHostService.currentHost = primaryReachable ? WHAT2REG_PRIMARY_HOST : WHAT2REG_BACKUP_HOST;
    }

    return {
      preference: preference,
      currentHost: UmehHostService.currentHost,
      primaryReachable: primaryReachable,
      probedAt: probedAt
    };
  }

  static buildCourseUrl(courseCode: string): string {
    return UmehHostService.currentHost + '/course/' + encodeURIComponent(courseCode);
  }

  static buildSearchUrl(keyword: string): string {
    return UmehHostService.currentHost + '/search/course/' + encodeURIComponent(keyword);
  }

  private static async probePrimaryHost(): Promise<boolean> {
    const now: number = Date.now();
    if (UmehHostService.probeCacheResult !== null &&
      now - UmehHostService.probeCacheTimestamp < PROBE_CACHE_TTL_MS) {
      return UmehHostService.probeCacheResult;
    }

    const result: ServiceResult<string> = await HttpClient.requestText(WHAT2REG_PRIMARY_HOST, {
      timeoutMs: PROBE_TIMEOUT_MS
    });
    const reachable: boolean = result.ok;
    UmehHostService.probeCacheResult = reachable;
    UmehHostService.probeCacheTimestamp = Date.now();
    return reachable;
  }
}
