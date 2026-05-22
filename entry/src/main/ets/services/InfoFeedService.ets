import {
  UM_OPEN_DATA_EVENT,
  UM_OPEN_DATA_NEWS
} from '../common/constants/ApiEndpoints';
import { STORAGE_WEEK_TIMETABLE } from '../common/constants/StorageKeys';
import {
  DAY_CODE_FRI,
  DAY_CODE_MON,
  DAY_CODE_SAT,
  DAY_CODE_SUN,
  DAY_CODE_THU,
  DAY_CODE_TUE,
  DAY_CODE_WED,
  getDateClockMinutes,
  getDateDayCode,
  parseClockTimeToMinutes
} from '../common/utils/DateTime';
import { ApiClient } from '../common/net/ApiClient';
import { errorResult, ServiceResult } from '../common/net/HttpClient';
import { JsonStore } from '../common/storage/JsonStore';
import { common } from '@kit.AbilityKit';
import { UmOpenDataListResponse } from '../models/ApiResponse';
import {
  UmEventDetail,
  UmEventItem
} from '../models/Event';
import {
  NewsDetail,
  NewsItem,
  OPEN_DATA_LOCALE_EN_US,
  OPEN_DATA_LOCALE_PT_PT,
  OPEN_DATA_LOCALE_ZH_TW
} from '../models/News';
import {
  TimetableHomeCacheItem,
  WeekTimetableHomeCache
} from '../models/Course';

export interface NewsFeedState {
  topNews?: NewsItem;
  newsList: NewsItem[];
}

export interface OpenDataLocaleOption {
  key: string;
  label: string;
  locale: string;
}

export interface HtmlLink {
  label: string;
  url: string;
}

export interface SimplifiedHtmlContent {
  text: string;
  links: HtmlLink[];
}

function okResult<T>(data: T): ServiceResult<T> {
  return {
    ok: true,
    data: data
  };
}

function safeString(value: string | undefined): string {
  return value ?? '';
}

function compareNumber(left: number, right: number): number {
  if (left < right) {
    return -1;
  }
  if (left > right) {
    return 1;
  }
  return 0;
}

function normalizeHttps(url: string): string {
  if (url.startsWith('http:')) {
    return 'https:' + url.substring(5);
  }
  return url;
}

function decodeHtmlEntities(text: string): string {
  return text
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function stripHtmlToText(html: string): string {
  return decodeHtmlEntities(html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n')
    .replace(/<\/div>/gi, '\n')
    .replace(/<\/li>/gi, '\n')
    .replace(/<li[^>]*>/gi, '\n- ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n\s+/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim());
}

function pushUniqueLink(links: HtmlLink[], link: HtmlLink): void {
  if (link.url.length === 0) {
    return;
  }
  for (let i = 0; i < links.length; i++) {
    if (links[i].url === link.url) {
      return;
    }
  }
  links.push(link);
}

function extractLinks(html: string): HtmlLink[] {
  const links: HtmlLink[] = [];
  const anchorRegex: RegExp = /<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
  let match: RegExpExecArray | null = anchorRegex.exec(html);
  while (match !== null) {
    const url: string = normalizeHttps(decodeHtmlEntities(match[1].trim()));
    const label: string = stripHtmlToText(match[2]).trim();
    pushUniqueLink(links, {
      label: label.length > 0 ? label : url,
      url: url
    });
    match = anchorRegex.exec(html);
  }

  const plainUrlRegex: RegExp = /(https?:\/\/[^\s<>"']+)/g;
  match = plainUrlRegex.exec(html);
  while (match !== null) {
    const url: string = normalizeHttps(match[1].replace(/[),.;]+$/g, ''));
    pushUniqueLink(links, {
      label: url,
      url: url
    });
    match = plainUrlRegex.exec(html);
  }
  return links;
}

function dateTimestamp(dateText: string | undefined): number {
  const parsed: Date = new Date(dateText ?? '');
  const timestamp: number = parsed.getTime();
  return Number.isNaN(timestamp) ? 0 : timestamp;
}

function pad2(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

function formatDateParts(dateText: string | undefined, dateOnly: boolean): string {
  const parsed: Date = new Date(dateText ?? '');
  if (Number.isNaN(parsed.getTime())) {
    return dateText ?? '';
  }
  const datePart: string = parsed.getFullYear().toString() + '-' + pad2(parsed.getMonth() + 1) + '-' +
  pad2(parsed.getDate());
  if (dateOnly) {
    return datePart;
  }
  return datePart + ' ' + pad2(parsed.getHours()) + ':' + pad2(parsed.getMinutes());
}

function formatClock(dateText: string | undefined): string {
  const parsed: Date = new Date(dateText ?? '');
  if (!Number.isNaN(parsed.getTime())) {
    return pad2(parsed.getHours()) + ':' + pad2(parsed.getMinutes());
  }
  const raw: string = dateText ?? '';
  if (raw.length >= 5) {
    return raw.substring(0, 5);
  }
  return raw;
}

function cloneNewsList(source: NewsItem[]): NewsItem[] {
  const result: NewsItem[] = [];
  for (let i = 0; i < source.length; i++) {
    result.push(source[i]);
  }
  return result;
}

function normalizeNewsImages(item: NewsItem): NewsItem {
  const imageUrls: string[] = [];
  const sourceImages: string[] = item.common.imageUrls ?? [];
  for (let i = 0; i < sourceImages.length; i++) {
    imageUrls.push(normalizeHttps(sourceImages[i]));
  }
  item.common.imageUrls = imageUrls;
  return item;
}

function normalizeEventPoster(item: UmEventItem): UmEventItem {
  if (item.common.posterUrl) {
    item.common.posterUrl = normalizeHttps(item.common.posterUrl);
  }
  return item;
}

function buildEmptyWeekCache(): WeekTimetableHomeCache {
  return {
    MON: [],
    TUE: [],
    WED: [],
    THU: [],
    FRI: [],
    SAT: [],
    SUN: []
  };
}

function normalizeWeekCache(text: string): string {
  return text
    .replace(/"Course Code"\s*:/g, '"courseCode":')
    .replace(/"Section"\s*:/g, '"section":')
    .replace(/"Time From"\s*:/g, '"timeFrom":');
}

function dayCache(cache: WeekTimetableHomeCache, day: string): TimetableHomeCacheItem[] {
  if (day === DAY_CODE_MON) {
    return cache.MON;
  }
  if (day === DAY_CODE_TUE) {
    return cache.TUE;
  }
  if (day === DAY_CODE_WED) {
    return cache.WED;
  }
  if (day === DAY_CODE_THU) {
    return cache.THU;
  }
  if (day === DAY_CODE_FRI) {
    return cache.FRI;
  }
  if (day === DAY_CODE_SAT) {
    return cache.SAT;
  }
  return cache.SUN;
}

function sortHomeItems(items: TimetableHomeCacheItem[]): TimetableHomeCacheItem[] {
  const result: TimetableHomeCacheItem[] = [];
  for (let i = 0; i < items.length; i++) {
    result.push(items[i]);
  }
  result.sort((left: TimetableHomeCacheItem, right: TimetableHomeCacheItem): number =>
  compareNumber(parseClockTimeToMinutes(left.timeFrom), parseClockTimeToMinutes(right.timeFrom)));
  return result;
}

function chooseTopNews(source: NewsItem[]): NewsItem | undefined {
  for (let i = 0; i < source.length; i++) {
    if ((source[i].common.imageUrls ?? []).length > 0 && source[i].details.length > 0) {
      return source[i];
    }
  }
  return source.length > 0 ? source[0] : undefined;
}

function newsId(item: NewsItem | undefined): string {
  return item?._id ?? '';
}

function sortEvents(source: UmEventItem[]): UmEventItem[] {
  const now: number = Date.now();
  const upcoming: UmEventItem[] = [];
  const past: UmEventItem[] = [];
  for (let i = 0; i < source.length; i++) {
    const event: UmEventItem = normalizeEventPoster(source[i]);
    const begin: number = dateTimestamp(event.common.dateFrom);
    if (begin === 0 || begin >= now - 24 * 60 * 60 * 1000) {
      upcoming.push(event);
    } else {
      past.push(event);
    }
  }
  upcoming.sort((left: UmEventItem, right: UmEventItem): number =>
  compareNumber(Math.abs(dateTimestamp(left.common.dateFrom) - now), Math.abs(dateTimestamp(right.common.dateFrom) - now)));
  past.sort((left: UmEventItem, right: UmEventItem): number =>
  compareNumber(Math.abs(dateTimestamp(left.common.dateFrom) - now), Math.abs(dateTimestamp(right.common.dateFrom) - now)));
  return upcoming.concat(past);
}

function detailTitle(detail: NewsDetail | UmEventDetail): string {
  return safeString(detail.title);
}

function detailContent(detail: NewsDetail | UmEventDetail): string {
  return safeString(detail.content);
}

export class InfoFeedService {
  static normalizeImageUrl(url: string | undefined): string {
    return normalizeHttps(url ?? '');
  }

  static async fetchNews(): Promise<ServiceResult<NewsFeedState>> {
    const response: ServiceResult<UmOpenDataListResponse<NewsItem>> =
      await ApiClient.getUmOpenData<UmOpenDataListResponse<NewsItem>>(UM_OPEN_DATA_NEWS);
    if (!response.ok || !response.data) {
      return {
        ok: false,
        error: response.error,
        response: response.response
      };
    }
    if (!response.data._embedded) {
      return errorResult<NewsFeedState>('NEWS_API_ERROR', '新闻数据格式无效', response.response);
    }

    const allNews: NewsItem[] = [];
    for (let i = 0; i < response.data._embedded.length; i++) {
      const item: NewsItem = normalizeNewsImages(response.data._embedded[i]);
      if (item.details.length > 0) {
        allNews.push(item);
      }
    }
    const topNews: NewsItem | undefined = chooseTopNews(allNews);
    const list: NewsItem[] = [];
    for (let i = 0; i < allNews.length; i++) {
      if (newsId(allNews[i]) !== newsId(topNews)) {
        list.push(allNews[i]);
      }
    }
    return okResult<NewsFeedState>({
      topNews: topNews,
      newsList: list
    });
  }

  static async fetchUmEvents(limit: number = 0): Promise<ServiceResult<UmEventItem[]>> {
    const response: ServiceResult<UmOpenDataListResponse<UmEventItem>> =
      await ApiClient.getUmOpenData<UmOpenDataListResponse<UmEventItem>>(UM_OPEN_DATA_EVENT);
    if (!response.ok || !response.data) {
      return {
        ok: false,
        error: response.error,
        response: response.response
      };
    }
    if (!response.data._embedded) {
      return errorResult<UmEventItem[]>('UM_EVENT_API_ERROR', '活动数据格式无效', response.response);
    }
    const sorted: UmEventItem[] = sortEvents(response.data._embedded);
    if (limit <= 0 || sorted.length <= limit) {
      return okResult<UmEventItem[]>(sorted);
    }
    const limited: UmEventItem[] = [];
    for (let i = 0; i < limit; i++) {
      limited.push(sorted[i]);
    }
    return okResult<UmEventItem[]>(limited);
  }

  static async readUpcomingCourse(context: common.Context): Promise<TimetableHomeCacheItem | null> {
    const rawCache: WeekTimetableHomeCache | null =
      await JsonStore.getOptionalObject<WeekTimetableHomeCache>(context, STORAGE_WEEK_TIMETABLE);
    if (rawCache === null) {
      return null;
    }

    let cache: WeekTimetableHomeCache = buildEmptyWeekCache();
    try {
      cache = JSON.parse(normalizeWeekCache(JSON.stringify(rawCache))) as WeekTimetableHomeCache;
    } catch (error) {
      return null;
    }

    const todayItems: TimetableHomeCacheItem[] = sortHomeItems(dayCache(cache, getDateDayCode(new Date())));
    const currentMinutes: number = getDateClockMinutes(new Date());
    for (let i = 0; i < todayItems.length; i++) {
      if (parseClockTimeToMinutes(todayItems[i].timeFrom) > currentMinutes) {
        return todayItems[i];
      }
    }
    return null;
  }

  static getLocaleOptions(details: Array<NewsDetail | UmEventDetail>): OpenDataLocaleOption[] {
    const result: OpenDataLocaleOption[] = [];
    for (let i = 0; i < details.length; i++) {
      const title: string = detailTitle(details[i]);
      if (title.length === 0) {
        continue;
      }
      if (details[i].locale === OPEN_DATA_LOCALE_ZH_TW) {
        result.push({ key: 'zh', label: '中', locale: OPEN_DATA_LOCALE_ZH_TW });
      } else if (details[i].locale === OPEN_DATA_LOCALE_EN_US) {
        result.push({ key: 'en', label: 'EN', locale: OPEN_DATA_LOCALE_EN_US });
      } else if (details[i].locale === OPEN_DATA_LOCALE_PT_PT) {
        result.push({ key: 'pt', label: 'PT', locale: OPEN_DATA_LOCALE_PT_PT });
      }
    }
    if (result.length === 0) {
      result.push({ key: 'raw', label: 'Text', locale: details.length > 0 ? details[0].locale : '' });
    }
    return result;
  }

  static findDetail<T extends NewsDetail | UmEventDetail>(details: T[], locale: string): T | undefined {
    for (let i = 0; i < details.length; i++) {
      if (details[i].locale === locale) {
        return details[i];
      }
    }
    return details.length > 0 ? details[0] : undefined;
  }

  static titleFor(details: Array<NewsDetail | UmEventDetail>, preferredLocale: string): string {
    const detail: NewsDetail | UmEventDetail | undefined = InfoFeedService.findDetail(details, preferredLocale);
    return detail ? detailTitle(detail) : '';
  }

  static contentFor(details: Array<NewsDetail | UmEventDetail>, preferredLocale: string): string {
    const detail: NewsDetail | UmEventDetail | undefined = InfoFeedService.findDetail(details, preferredLocale);
    return detail ? detailContent(detail) : '';
  }

  static simplifyHtml(html: string | undefined): SimplifiedHtmlContent {
    const source: string = html ?? '';
    return {
      text: stripHtmlToText(source),
      links: extractLinks(source)
    };
  }

  static imageUrlsForNews(item: NewsItem): string[] {
    const result: string[] = [];
    const source: string[] = item.common.imageUrls ?? [];
    for (let i = 0; i < source.length; i++) {
      result.push(normalizeHttps(source[i]));
    }
    return result;
  }

  static publishDateForNews(item: NewsItem): string {
    return item.lastModified ?? item.common.publishDate;
  }

  static eventDateTimestamp(item: UmEventItem): number {
    return dateTimestamp(item.common.dateFrom);
  }

  static formatDate(dateText: string | undefined): string {
    return formatDateParts(dateText, true);
  }

  static formatDateTime(dateText: string | undefined): string {
    return formatDateParts(dateText, false);
  }

  static formatMonthDay(dateText: string | undefined): string {
    const formatted: string = formatDateParts(dateText, true);
    if (formatted.length >= 10) {
      return formatted.substring(5, 10);
    }
    return formatted;
  }

  static formatClock(dateText: string | undefined): string {
    return formatClock(dateText);
  }

  static formatEventTimeRange(item: UmEventItem): string {
    const startDate: string = InfoFeedService.formatDate(item.common.dateFrom);
    const endDate: string = InfoFeedService.formatDate(item.common.dateTo);
    const dateText: string = endDate.length > 0 && endDate !== startDate ? startDate + ' - ' + endDate : startDate;
    const timeFrom: string = InfoFeedService.formatClock(item.common.timeFrom);
    const timeTo: string = InfoFeedService.formatClock(item.common.timeTo);
    if (timeFrom.length > 0 && timeTo.length > 0) {
      return dateText + ' ' + timeFrom + ' - ' + timeTo;
    }
    return dateText;
  }

  static cloneNewsList(source: NewsItem[]): NewsItem[] {
    return cloneNewsList(source);
  }
}
