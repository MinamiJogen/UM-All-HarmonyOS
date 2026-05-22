import {
  ARK_GET_CLUB_INFO_ALL,
  ARK_GET_CLUB_INFO_NUM,
  ARK_GET_EVENT_INFO_CLUB_NUM_PATH,
  ARK_GET_EVENT_INFO_EVENT_ID,
  addArkHost,
  buildArkApiUrl
} from '../common/constants/ApiEndpoints';
import { ApiClient } from '../common/net/ApiClient';
import { errorResult, ServiceResult } from '../common/net/HttpClient';
import {
  hasChinese,
  normalizeSimplifiedChinese
} from '../common/utils/ChineseText';
import {
  ArkContentResponse,
  ArkListResponse
} from '../models/ApiResponse';
import {
  ClubInfo,
  ClubSection
} from '../models/Club';
import { ClubActivity } from '../models/Event';

export const CLUB_TAG_ARK: string = 'ARK';
export const CLUB_TAG_SA: string = 'SA';
export const CLUB_TAG_CLUB: string = 'CLUB';
export const CLUB_TAG_SOCIETY: string = 'SOCIETY';
export const CLUB_TAG_COLLEGE: string = 'COLLEGE';
export const CLUB_TAG_OFFICIAL: string = 'OFFICIAL';
export const CLUB_TAG_MEDIA: string = 'MEDIA';
export const CLUB_TAG_BUSINESS: string = 'BUSINESS';

export const CLUB_TAG_ORDER: string[] = [
  CLUB_TAG_ARK,
  CLUB_TAG_SA,
  CLUB_TAG_CLUB,
  CLUB_TAG_SOCIETY,
  CLUB_TAG_COLLEGE,
  CLUB_TAG_OFFICIAL,
  CLUB_TAG_MEDIA,
  CLUB_TAG_BUSINESS
];

export interface ClubActivityPage {
  events: ClubActivity[];
  noMore: boolean;
  page: number;
}

interface ArkPagedListResponse<T> {
  code?: string;
  message: string;
  content: T[];
  num_pages?: number;
}

function okResult<T>(data: T): ServiceResult<T> {
  return {
    ok: true,
    data: data
  };
}

function safeText(value: string | undefined): string {
  return value ?? '';
}

function normalizeImageUrl(url: string | undefined): string {
  const normalized: string = addArkHost(safeText(url));
  if (normalized.startsWith('http:')) {
    return 'https:' + normalized.substring(5);
  }
  return normalized;
}

function normalizeClub(club: ClubInfo): ClubInfo {
  club.logo_url = normalizeImageUrl(club.logo_url);
  const photos: string[] = [];
  const sourcePhotos: string[] = club.club_photos_list ?? [];
  for (let i = 0; i < sourcePhotos.length; i++) {
    photos.push(normalizeImageUrl(sourcePhotos[i]));
  }
  club.club_photos_list = photos;
  return club;
}

function normalizeEvent(event: ClubActivity): ClubActivity {
  event.cover_image_url = normalizeImageUrl(event.cover_image_url);
  const related: string[] = [];
  const sourceRelated: string[] = event.relate_image_url ?? [];
  for (let i = 0; i < sourceRelated.length; i++) {
    related.push(normalizeImageUrl(sourceRelated[i]));
  }
  event.relate_image_url = related;
  return event;
}

function compareText(left: string, right: string): number {
  if (left < right) {
    return -1;
  }
  if (left > right) {
    return 1;
  }
  return 0;
}

function compareEventTime(left: ClubActivity, right: ClubActivity): number {
  const leftTime: number = ClubService.timestamp(left.startdatetime);
  const rightTime: number = ClubService.timestamp(right.startdatetime);
  if (leftTime > rightTime) {
    return -1;
  }
  if (leftTime < rightTime) {
    return 1;
  }
  return compareText(safeText(left.title), safeText(right.title));
}

function clubMatches(club: ClubInfo, rawKeyword: string): boolean {
  const keyword: string = rawKeyword.trim();
  if (keyword.length === 0) {
    return true;
  }
  const name: string = safeText(club.name);
  const tag: string = safeText(club.tag);
  const lower: string = keyword.toLowerCase();
  if (!hasChinese(keyword)) {
    return name.toLowerCase().includes(lower) || tag.toLowerCase().includes(lower) ||
    ClubService.tagLabel(tag).toLowerCase().includes(lower);
  }
  const normalized: string = normalizeSimplifiedChinese(keyword);
  return name.includes(keyword) || name.includes(normalized) || ClubService.tagLabel(tag).includes(keyword) ||
  ClubService.tagLabel(tag).includes(normalized);
}

export class ClubService {
  static normalizeImageUrl(url: string | undefined): string {
    return normalizeImageUrl(url);
  }

  static tagLabel(tag: string | undefined): string {
    if (tag === CLUB_TAG_SA) {
      return '學生會';
    }
    if (tag === CLUB_TAG_CLUB) {
      return '學會';
    }
    if (tag === CLUB_TAG_SOCIETY) {
      return '社團';
    }
    if (tag === CLUB_TAG_COLLEGE) {
      return '書院';
    }
    if (tag === CLUB_TAG_OFFICIAL) {
      return '澳大';
    }
    if (tag === CLUB_TAG_MEDIA) {
      return '媒體';
    }
    if (tag === CLUB_TAG_BUSINESS) {
      return '商業';
    }
    if (tag === CLUB_TAG_ARK) {
      return 'ARK';
    }
    return tag ?? '';
  }

  static async fetchClubs(): Promise<ServiceResult<ClubInfo[]>> {
    const result: ServiceResult<ArkListResponse<ClubInfo>> =
      await ApiClient.getArk<ArkListResponse<ClubInfo>>(ARK_GET_CLUB_INFO_ALL);
    if (!result.ok || !result.data) {
      return {
        ok: false,
        error: result.error,
        response: result.response
      };
    }
    if (result.data.message !== 'success') {
      return errorResult<ClubInfo[]>('CLUB_API_ERROR', result.data.message, result.response);
    }
    const clubs: ClubInfo[] = [];
    for (let i = 0; i < result.data.content.length; i++) {
      clubs.push(normalizeClub(result.data.content[i]));
    }
    return okResult<ClubInfo[]>(clubs);
  }

  static async fetchClub(clubNum: number): Promise<ServiceResult<ClubInfo>> {
    const result: ServiceResult<ArkContentResponse<ClubInfo>> =
      await ApiClient.getArk<ArkContentResponse<ClubInfo>>(ARK_GET_CLUB_INFO_NUM + encodeURIComponent(clubNum.toString()));
    if (!result.ok || !result.data) {
      return {
        ok: false,
        error: result.error,
        response: result.response
      };
    }
    if (result.data.message !== 'success') {
      return errorResult<ClubInfo>('CLUB_DETAIL_API_ERROR', result.data.message, result.response);
    }
    return okResult<ClubInfo>(normalizeClub(result.data.content));
  }

  static async fetchEvent(eventId: string): Promise<ServiceResult<ClubActivity>> {
    const result: ServiceResult<ArkContentResponse<ClubActivity>> =
      await ApiClient.getArk<ArkContentResponse<ClubActivity>>(ARK_GET_EVENT_INFO_EVENT_ID + encodeURIComponent(eventId));
    if (!result.ok || !result.data) {
      return {
        ok: false,
        error: result.error,
        response: result.response
      };
    }
    if (result.data.message !== 'success') {
      return errorResult<ClubActivity>('CLUB_EVENT_API_ERROR', result.data.message, result.response);
    }
    return okResult<ClubActivity>(normalizeEvent(result.data.content));
  }

  static async fetchClubEvents(clubNum: number, page: number = 1, pageSize: number = 10):
    Promise<ServiceResult<ClubActivityPage>> {
    const path: string = ARK_GET_EVENT_INFO_CLUB_NUM_PATH + '?club_num=' + encodeURIComponent(clubNum.toString()) +
      '&num_of_item=' + encodeURIComponent(pageSize.toString()) + '&page=' + encodeURIComponent(page.toString());
    const result: ServiceResult<ArkPagedListResponse<ClubActivity>> =
      await ApiClient.get<ArkPagedListResponse<ClubActivity>>(buildArkApiUrl(path));
    if (!result.ok || !result.data) {
      return {
        ok: false,
        error: result.error,
        response: result.response
      };
    }
    if (result.data.message !== 'success') {
      return errorResult<ClubActivityPage>('CLUB_EVENTS_API_ERROR', result.data.message, result.response);
    }
    const events: ClubActivity[] = [];
    for (let i = 0; i < result.data.content.length; i++) {
      events.push(normalizeEvent(result.data.content[i]));
    }
    events.sort(compareEventTime);
    return okResult<ClubActivityPage>({
      events: events,
      noMore: events.length < pageSize || (result.data.num_pages !== undefined && page >= result.data.num_pages),
      page: page
    });
  }

  static filterClubs(clubs: ClubInfo[], keyword: string): ClubInfo[] {
    const result: ClubInfo[] = [];
    for (let i = 0; i < clubs.length; i++) {
      if (clubMatches(clubs[i], keyword)) {
        result.push(clubs[i]);
      }
    }
    return result;
  }

  static buildSections(clubs: ClubInfo[]): ClubSection[] {
    const sections: ClubSection[] = [];
    for (let i = 0; i < CLUB_TAG_ORDER.length; i++) {
      const tag: string = CLUB_TAG_ORDER[i];
      const list: ClubInfo[] = [];
      for (let j = 0; j < clubs.length; j++) {
        if ((clubs[j].tag ?? '') === tag) {
          list.push(clubs[j]);
        }
      }
      if (list.length > 0) {
        sections.push({
          title: tag,
          clubs: list
        });
      }
    }
    return sections;
  }

  static timestamp(value: string | undefined): number {
    const parsed: Date = new Date(value ?? '');
    const time: number = parsed.getTime();
    return Number.isNaN(time) ? 0 : time;
  }

  static eventIsPast(event: ClubActivity): boolean {
    const endTime: number = ClubService.timestamp(event.enddatetime);
    return endTime > 0 && endTime < Date.now();
  }

  static eventIsAlmostEnd(event: ClubActivity): boolean {
    const endTime: number = ClubService.timestamp(event.enddatetime);
    if (endTime <= 0 || endTime < Date.now()) {
      return false;
    }
    return endTime - Date.now() <= 3 * 24 * 60 * 60 * 1000;
  }

  static pad2(value: number): string {
    return value < 10 ? '0' + value.toString() : value.toString();
  }

  static formatDateTime(value: string | undefined): string {
    const parsed: Date = new Date(value ?? '');
    if (Number.isNaN(parsed.getTime())) {
      return value ?? '';
    }
    return parsed.getFullYear().toString() + '/' + ClubService.pad2(parsed.getMonth() + 1) + '/' +
    ClubService.pad2(parsed.getDate()) + ' ' + ClubService.pad2(parsed.getHours()) + ':' +
    ClubService.pad2(parsed.getMinutes());
  }

  static formatEventRange(event: ClubActivity): string {
    const start: string = ClubService.formatDateTime(event.startdatetime);
    const end: string = ClubService.formatDateTime(event.enddatetime);
    if (start.length > 0 && end.length > 0) {
      return start + ' - ' + end;
    }
    return start.length > 0 ? start : end;
  }
}
