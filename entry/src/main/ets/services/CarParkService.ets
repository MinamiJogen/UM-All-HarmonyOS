import { UM_OPEN_DATA_CAR_PARK } from '../common/constants/ApiEndpoints';
import { ApiClient } from '../common/net/ApiClient';
import { errorResult, ServiceResult } from '../common/net/HttpClient';
import { UmOpenDataListResponse } from '../models/ApiResponse';
import {
  CarParkAvailabilityItem,
  CarParkPlaceInfo
} from '../models/Parking';

const MACAU_UTC_OFFSET_MS: number = 8 * 60 * 60 * 1000;
const CAR_PARK_QUERY_WINDOW_MS: number = 30 * 60 * 1000;
const CAR_PARK_LIMIT: number = 5;

const CAR_PARK_PLACES: CarParkPlaceInfo[] = [
  {
    code: 'P6',
    descriptionZh: 'S1-S2 研究生宿舍 及 S8 薈萃坊',
    descriptionEn: 'S1-S2 Postgraduate House and S8 UM Guest House'
  },
  {
    code: 'P5',
    descriptionZh: 'E2 澳門大學伍宜孫圖書館 及 E3-E7 中央教學樓',
    descriptionEn: 'E2 University Library and E3-E7 Central Teaching Building'
  },
  {
    code: 'P3',
    descriptionZh: 'N1 聚賢樓 及 N2 大學會堂',
    descriptionEn: 'N1 Administration Building and N2 University Hall'
  },
  {
    code: 'P2',
    descriptionZh: 'N6 行政樓',
    descriptionEn: 'N6 Administration Building'
  },
  {
    code: 'P1',
    descriptionZh: 'N8 澳大綜合體育館',
    descriptionEn: 'N8 UM Sports Complex'
  }
];

function pad2(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

function formatMacauOpenDataTime(timestamp: number): string {
  const macauDate: Date = new Date(timestamp + MACAU_UTC_OFFSET_MS);
  return macauDate.getUTCFullYear().toString() + '-' +
  pad2(macauDate.getUTCMonth() + 1) + '-' +
  pad2(macauDate.getUTCDate()) + 'T' +
  pad2(macauDate.getUTCHours()) + ':' +
  pad2(macauDate.getUTCMinutes()) + ':' +
  pad2(macauDate.getUTCSeconds());
}

export class CarParkService {
  static buildDateFrom(now: number = Date.now()): string {
    return formatMacauOpenDataTime(now - CAR_PARK_QUERY_WINDOW_MS);
  }

  static getPlaceDescription(code: string, english: boolean): string {
    for (let i = 0; i < CAR_PARK_PLACES.length; i++) {
      const place: CarParkPlaceInfo = CAR_PARK_PLACES[i];
      if (place.code === code) {
        return english ? (place.descriptionEn ?? place.descriptionZh) : place.descriptionZh;
      }
    }
    return english ? 'Campus car park' : '校園停車場';
  }

  static formatRecordDate(recordDate: string): string {
    if (recordDate.length === 0) {
      return '-';
    }
    if (!recordDate.endsWith('Z') && !recordDate.includes('+')) {
      return recordDate.substring(0, Math.min(19, recordDate.length)).replace('T', ', ');
    }
    const parsed: Date = new Date(recordDate);
    if (Number.isNaN(parsed.getTime())) {
      return recordDate.replace('T', ', ');
    }
    return formatMacauOpenDataTime(parsed.getTime()).replace('T', ', ');
  }

  static async fetchLatest(): Promise<ServiceResult<CarParkAvailabilityItem[]>> {
    const dateFrom: string = CarParkService.buildDateFrom();
    const url: string = UM_OPEN_DATA_CAR_PARK + '?date_from=' + encodeURIComponent(dateFrom);
    const response: ServiceResult<UmOpenDataListResponse<CarParkAvailabilityItem>> =
      await ApiClient.getUmOpenData<UmOpenDataListResponse<CarParkAvailabilityItem>>(url);

    if (!response.ok || !response.data) {
      return {
        ok: false,
        error: response.error,
        response: response.response
      };
    }

    if (!response.data._embedded) {
      return errorResult<CarParkAvailabilityItem[]>('CAR_PARK_API_ERROR', '停车场数据格式无效',
        response.response);
    }

    const limited: CarParkAvailabilityItem[] = [];
    const source: CarParkAvailabilityItem[] = response.data._embedded;
    const count: number = Math.min(CAR_PARK_LIMIT, source.length);
    for (let i = 0; i < count; i++) {
      limited.push(source[i]);
    }

    return {
      ok: true,
      data: limited,
      response: response.response
    };
  }
}
