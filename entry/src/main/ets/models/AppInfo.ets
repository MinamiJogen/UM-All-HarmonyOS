export interface AppInfo {
  app_version?: string;
  API_version?: string;
  version_info?: string;
  update_url?: string;
  force_update?: boolean;
}

export interface AppVersionState {
  latest: string;
  local: string;
}

export interface UserInfo {
  token?: string;
  userName?: string;
  userId?: string;
  studentId?: string;
  clubNum?: string;
}
