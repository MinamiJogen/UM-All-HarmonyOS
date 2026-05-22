import { http } from '@kit.NetworkKit';
import {
  buildArkApiUrl,
  buildCourseApiUrl
} from '../constants/ApiEndpoints';
import { UmOpenDataConfig } from '../config/UmOpenDataConfig';
import { errorResult, HttpClient, HttpHeaders, ServiceResult } from './HttpClient';

export class ApiClient {
  static async get<T>(url: string, headers?: HttpHeaders): Promise<ServiceResult<T>> {
    return await HttpClient.getJson<T>(url, headers);
  }

  static async post<T>(url: string, body: Object, headers?: HttpHeaders): Promise<ServiceResult<T>> {
    return await HttpClient.postJson<T>(url, body, headers);
  }

  static async getArk<T>(path: string): Promise<ServiceResult<T>> {
    return await ApiClient.get<T>(buildArkApiUrl(path));
  }

  static async postArk<T>(path: string, body: Object): Promise<ServiceResult<T>> {
    return await ApiClient.post<T>(buildArkApiUrl(path), body);
  }

  static async getCourse<T>(path: string): Promise<ServiceResult<T>> {
    return await ApiClient.get<T>(buildCourseApiUrl(path));
  }

  static async getUmOpenData<T>(url: string): Promise<ServiceResult<T>> {
    if (!UmOpenDataConfig.hasToken()) {
      return {
        ok: false,
        error: UmOpenDataConfig.missingTokenError()
      };
    }

    const headers: HttpHeaders = new HttpHeaders();
    headers.Authorization = UmOpenDataConfig.getToken();
    return await ApiClient.get<T>(url, headers);
  }

  static async requestJson<T>(url: string, method: http.RequestMethod, body?: Object,
    headers?: HttpHeaders): Promise<ServiceResult<T>> {
    return await HttpClient.requestJson<T>(url, {
      method: method,
      body: body,
      headers: headers
    });
  }
}
