export interface ArkApiStatusResponse {
  message: string;
}

export interface ArkListResponse<T> {
  message: string;
  content: T[];
}

export interface ArkContentResponse<T> {
  message: string;
  content: T;
}

export interface UmOpenDataListResponse<T> {
  _embedded: T[];
}

export interface ServiceError {
  code: string;
  message: string;
}
