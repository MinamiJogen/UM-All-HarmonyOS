import { bundleManager } from '@kit.AbilityKit';
import { ARK_GET_APP_INFO } from '../common/constants/ApiEndpoints';
import { errorResult, ServiceResult } from '../common/net/HttpClient';
import { ApiClient } from '../common/net/ApiClient';
import { JsonStore } from '../common/storage/JsonStore';
import { STORAGE_APP_INFO } from '../common/constants/StorageKeys';
import { isVersionNewer } from '../common/utils/VersionCompare';
import { ArkContentResponse } from '../models/ApiResponse';
import { AppInfo, AppVersionState } from '../models/AppInfo';
import { common } from '@kit.AbilityKit';
import { Logger } from '../common/utils/Logger';

export interface AppInfoUpdateState {
  localVersion: string;
  latestVersion: string;
  updateAvailable: boolean;
  appInfo?: AppInfo;
}

function okResult<T>(data: T): ServiceResult<T> {
  return {
    ok: true,
    data: data
  };
}

export class AppInfoService {
  static async getLocalVersion(): Promise<string> {
    try {
      const bundleInfo: bundleManager.BundleInfo =
        await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      return bundleInfo.versionName;
    } catch (error) {
      Logger.warn('Get local version failed: ' + String(error));
      return '1.0.0';
    }
  }

  static async getCachedAppInfo(context: common.Context): Promise<AppInfo | null> {
    return await JsonStore.getOptionalObject<AppInfo>(context, STORAGE_APP_INFO);
  }

  static async fetchAppInfoFromServer(context: common.Context): Promise<ServiceResult<AppInfo>> {
    const response: ServiceResult<ArkContentResponse<AppInfo>> =
      await ApiClient.getArk<ArkContentResponse<AppInfo>>(ARK_GET_APP_INFO);
    if (!response.ok || !response.data) {
      return {
        ok: false,
        error: response.error,
        response: response.response
      };
    }
    if (response.data.message !== 'success' || !response.data.content) {
      return errorResult<AppInfo>('APP_INFO_API_ERROR', 'AppInfo API returned invalid content',
        response.response);
    }
    await JsonStore.setObject<AppInfo>(context, STORAGE_APP_INFO, response.data.content);
    return okResult<AppInfo>(response.data.content);
  }

  static async checkUpdateState(context: common.Context): Promise<ServiceResult<AppInfoUpdateState>> {
    const localVersion: string = await AppInfoService.getLocalVersion();
    const appInfoResult: ServiceResult<AppInfo> = await AppInfoService.fetchAppInfoFromServer(context);
    if (!appInfoResult.ok || !appInfoResult.data) {
      const cachedInfo: AppInfo | null = await AppInfoService.getCachedAppInfo(context);
      const latestVersion: string = cachedInfo?.app_version ?? '';
      const fallbackState: AppInfoUpdateState = {
        localVersion: localVersion,
        latestVersion: latestVersion,
        updateAvailable: latestVersion.length > 0 && isVersionNewer(latestVersion, localVersion),
        appInfo: cachedInfo ?? undefined
      };
      return {
        ok: false,
        data: fallbackState,
        error: appInfoResult.error,
        response: appInfoResult.response
      };
    }

    const latestVersion: string = appInfoResult.data.app_version ?? '';
    const versionState: AppVersionState = {
      local: localVersion,
      latest: latestVersion
    };
    const updateState: AppInfoUpdateState = {
      localVersion: versionState.local,
      latestVersion: versionState.latest,
      updateAvailable: versionState.latest.length > 0 && isVersionNewer(versionState.latest, versionState.local),
      appInfo: appInfoResult.data
    };
    return okResult<AppInfoUpdateState>(updateState);
  }
}
