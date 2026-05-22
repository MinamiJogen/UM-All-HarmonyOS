import { http } from '@kit.NetworkKit';
import { ServiceError } from '../../models/ApiResponse';
import { Logger } from '../utils/Logger';

export class HttpHeaders {
  Authorization: string = '';
}

class HttpRequestHeader {
  Authorization: string = '';
}

export interface HttpRequestConfig {
  method?: http.RequestMethod;
  headers?: HttpHeaders;
  body?: string | Object | ArrayBuffer;
  timeoutMs?: number;
}

export interface HttpResponseMeta {
  url: string;
  statusCode: number;
  headers?: Object;
}

export interface ServiceResult<T> {
  ok: boolean;
  data?: T;
  error?: ServiceError;
  response?: HttpResponseMeta;
}

const DEFAULT_TIMEOUT_MS: number = 15000;

function okResult<T>(data: T, response: HttpResponseMeta): ServiceResult<T> {
  return {
    ok: true,
    data: data,
    response: response
  };
}

export function errorResult<T>(code: string, message: string, response?: HttpResponseMeta): ServiceResult<T> {
  return {
    ok: false,
    error: {
      code: code,
      message: message
    },
    response: response
  };
}

function resultToString(result: string | Object | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  return JSON.stringify(result);
}

function buildRequestHeader(headers?: HttpHeaders): Object | undefined {
  if (!headers || headers.Authorization.length === 0) {
    return undefined;
  }
  const requestHeader: HttpRequestHeader = new HttpRequestHeader();
  requestHeader.Authorization = headers.Authorization;
  return requestHeader;
}

export class HttpClient {
  static async requestText(url: string, config?: HttpRequestConfig): Promise<ServiceResult<string>> {
    const request: http.HttpRequest = http.createHttp();
    const timeoutMs: number = config?.timeoutMs ?? DEFAULT_TIMEOUT_MS;
    const method: http.RequestMethod = config?.method ?? http.RequestMethod.GET;
    const requestOptions: http.HttpRequestOptions = {
      method: method,
      header: buildRequestHeader(config?.headers),
      extraData: config?.body,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs
    };

    try {
      const response: http.HttpResponse = await request.request(url, requestOptions);
      const statusCode: number = Number(response.responseCode);
      const meta: HttpResponseMeta = {
        url: url,
        statusCode: statusCode,
        headers: response.header
      };
      const body: string = resultToString(response.result);

      if (statusCode < 200 || statusCode >= 300) {
        return errorResult<string>('HTTP_STATUS_ERROR', 'HTTP status ' + statusCode, meta);
      }

      return okResult<string>(body, meta);
    } catch (error) {
      Logger.error('HTTP request failed: ' + url + ', ' + String(error));
      return errorResult<string>('NETWORK_ERROR', String(error), {
        url: url,
        statusCode: 0
      });
    } finally {
      request.destroy();
    }
  }

  static async requestJson<T>(url: string, config?: HttpRequestConfig): Promise<ServiceResult<T>> {
    const textResult: ServiceResult<string> = await HttpClient.requestText(url, config);
    if (!textResult.ok || !textResult.data) {
      return {
        ok: false,
        error: textResult.error,
        response: textResult.response
      };
    }

    try {
      return okResult<T>(JSON.parse(textResult.data) as T, textResult.response as HttpResponseMeta);
    } catch (error) {
      Logger.error('JSON parse failed: ' + url + ', ' + String(error));
      return errorResult<T>('JSON_PARSE_ERROR', '响应数据解析失败', textResult.response);
    }
  }

  static async getJson<T>(url: string, headers?: HttpHeaders): Promise<ServiceResult<T>> {
    return await HttpClient.requestJson<T>(url, {
      method: http.RequestMethod.GET,
      headers: headers
    });
  }

  static async postJson<T>(url: string, body: Object, headers?: HttpHeaders): Promise<ServiceResult<T>> {
    return await HttpClient.requestJson<T>(url, {
      method: http.RequestMethod.POST,
      headers: headers,
      body: JSON.stringify(body)
    });
  }
}
