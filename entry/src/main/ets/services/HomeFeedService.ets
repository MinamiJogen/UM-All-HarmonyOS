import {
  ARK_HARBOR_LATEST,
  ARK_HARBOR_TOPIC,
  ARK_HARBOR_AVATAR
} from '../common/constants/ApiEndpoints';
import { ApiClient } from '../common/net/ApiClient';
import { errorResult, ServiceResult } from '../common/net/HttpClient';
import { ClubActivity } from '../models/Event';
import {
  ClubActivityPage,
  ClubService
} from './ClubService';
import { InfoFeedService } from './InfoFeedService';

export const HOME_FEED_KIND_EVENT: string = 'event';
export const HOME_FEED_KIND_HARBOR: string = 'harbor';

export interface HarborTopic {
  id?: number | string;
  title?: string;
  unicode_title?: string;
  excerpt?: string;
  last_poster_username?: string;
  like_count?: number;
  highest_post_number?: number;
  views?: number;
  pinned?: boolean;
}

interface HarborTopicList {
  topics?: HarborTopic[];
}

interface HarborLatestResponse {
  topic_list?: HarborTopicList;
}

export interface HomeFeedItem {
  key: string;
  kind: string;
  event?: ClubActivity;
  harbor?: HarborTopic;
}

export interface HomeFeedPage {
  page: number;
  noMore: boolean;
  items: HomeFeedItem[];
}

function okResult<T>(data: T): ServiceResult<T> {
  return {
    ok: true,
    data: data
  };
}

function safeText(value: string | number | undefined | null): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'number') {
    return value.toString();
  }
  return value;
}

function feedEventId(event: ClubActivity, index: number): string {
  const id: string = event._id ?? event.activity_id ?? '';
  return id.length > 0 ? id : 'event-' + index.toString();
}

function feedTopicId(topic: HarborTopic, index: number): string {
  const id: string = safeText(topic.id);
  return id.length > 0 ? id : 'harbor-' + index.toString();
}

function itemKeyExists(items: HomeFeedItem[], key: string): boolean {
  for (let i = 0; i < items.length; i++) {
    if (items[i].key === key) {
      return true;
    }
  }
  return false;
}

function shuffleNumbers(values: number[]): number[] {
  const result: number[] = [];
  for (let i = 0; i < values.length; i++) {
    result.push(values[i]);
  }
  for (let i = result.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const temp: number = result[i];
    result[i] = result[j];
    result[j] = temp;
  }
  return result;
}

function shuffleEvents(values: ClubActivity[]): ClubActivity[] {
  const result: ClubActivity[] = [];
  for (let i = 0; i < values.length; i++) {
    result.push(values[i]);
  }
  for (let i = result.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const temp: ClubActivity = result[i];
    result[i] = result[j];
    result[j] = temp;
  }
  return result;
}

function shuffleTopics(values: HarborTopic[]): HarborTopic[] {
  const result: HarborTopic[] = [];
  for (let i = 0; i < values.length; i++) {
    result.push(values[i]);
  }
  for (let i = result.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const temp: HarborTopic = result[i];
    result[i] = result[j];
    result[j] = temp;
  }
  return result;
}

function uniqueEvents(events: ClubActivity[]): ClubActivity[] {
  const result: ClubActivity[] = [];
  for (let i = 0; i < events.length; i++) {
    const id: string = feedEventId(events[i], i);
    let exists: boolean = false;
    for (let j = 0; j < result.length; j++) {
      if (feedEventId(result[j], j) === id) {
        exists = true;
        break;
      }
    }
    if (!exists) {
      result.push(events[i]);
    }
  }
  return result;
}

export class HomeFeedService {
  static async fetchFirstPage(pageSize: number): Promise<ServiceResult<HomeFeedPage>> {
    const eventResult: ServiceResult<ClubActivityPage> = await ClubService.fetchEvents(1, pageSize);
    if (!eventResult.ok || !eventResult.data) {
      return {
        ok: false,
        error: eventResult.error,
        response: eventResult.response
      };
    }
    const harborTopics: HarborTopic[] = await HomeFeedService.fetchHarborTopics();
    return okResult<HomeFeedPage>({
      page: 1,
      noMore: eventResult.data.noMore,
      items: HomeFeedService.mixInitialItems(eventResult.data.events, harborTopics)
    });
  }

  static async fetchNextPage(page: number, pageSize: number): Promise<ServiceResult<HomeFeedPage>> {
    if (page <= 1) {
      return errorResult<HomeFeedPage>('HOME_FEED_PAGE_ERROR', 'Invalid feed page');
    }
    const eventResult: ServiceResult<ClubActivityPage> = await ClubService.fetchEvents(page, pageSize);
    if (!eventResult.ok || !eventResult.data) {
      return {
        ok: false,
        error: eventResult.error,
        response: eventResult.response
      };
    }
    return okResult<HomeFeedPage>({
      page: page,
      noMore: eventResult.data.noMore,
      items: HomeFeedService.eventItems(eventResult.data.events)
    });
  }

  static harborTitle(topic: HarborTopic): string {
    const unicodeTitle: string = topic.unicode_title ?? '';
    return unicodeTitle.length > 0 ? unicodeTitle : (topic.title ?? '');
  }

  static harborExcerpt(topic: HarborTopic): string {
    const simplified: string = InfoFeedService.simplifyHtml(topic.excerpt ?? '').text;
    return simplified.replace(/:[a-zA-Z0-9_+-]+:/g, '').trim();
  }

  static harborAuthor(topic: HarborTopic): string {
    return topic.last_poster_username ?? '';
  }

  static harborAvatar(topic: HarborTopic): string {
    const username: string = HomeFeedService.harborAuthor(topic);
    return username.length > 0 ? ARK_HARBOR_AVATAR(username) : '';
  }

  static harborTopicUrl(topic: HarborTopic): string {
    const id: string = safeText(topic.id);
    return id.length > 0 ? ARK_HARBOR_TOPIC + id : '';
  }

  static eventItems(events: ClubActivity[]): HomeFeedItem[] {
    const result: HomeFeedItem[] = [];
    for (let i = 0; i < events.length; i++) {
      const key: string = HOME_FEED_KIND_EVENT + '-' + feedEventId(events[i], i);
      if (!itemKeyExists(result, key)) {
        result.push({
          key: key,
          kind: HOME_FEED_KIND_EVENT,
          event: events[i]
        });
      }
    }
    return result;
  }

  private static async fetchHarborTopics(): Promise<HarborTopic[]> {
    const result: ServiceResult<HarborLatestResponse> = await ApiClient.get<HarborLatestResponse>(ARK_HARBOR_LATEST);
    if (!result.ok || !result.data || !result.data.topic_list || !result.data.topic_list.topics) {
      return [];
    }
    const candidates: HarborTopic[] = [];
    const source: HarborTopic[] = result.data.topic_list.topics;
    for (let i = 0; i < source.length; i++) {
      if (source[i].pinned !== true && safeText(source[i].id).length > 0 &&
        HomeFeedService.harborTitle(source[i]).length > 0) {
        candidates.push(source[i]);
      }
    }
    const shuffled: HarborTopic[] = shuffleTopics(candidates);
    const picked: HarborTopic[] = [];
    const limit: number = Math.min(12, shuffled.length);
    for (let i = 0; i < limit; i++) {
      picked.push(shuffled[i]);
    }
    return picked;
  }

  private static prioritizeInitialEvents(events: ClubActivity[]): ClubActivity[] {
    const activePinned: ClubActivity[] = [];
    const active: ClubActivity[] = [];
    for (let i = 0; i < events.length; i++) {
      if (!ClubService.eventIsPast(events[i])) {
        if (i === 0) {
          activePinned.push(events[i]);
        } else {
          active.push(events[i]);
        }
      }
    }
    return uniqueEvents(activePinned.concat(shuffleEvents(active)).concat(events));
  }

  private static harborItems(topics: HarborTopic[]): HomeFeedItem[] {
    const result: HomeFeedItem[] = [];
    for (let i = 0; i < topics.length; i++) {
      const key: string = HOME_FEED_KIND_HARBOR + '-' + feedTopicId(topics[i], i);
      if (!itemKeyExists(result, key)) {
        result.push({
          key: key,
          kind: HOME_FEED_KIND_HARBOR,
          harbor: topics[i]
        });
      }
    }
    return result;
  }

  private static mixInitialItems(events: ClubActivity[], harborTopics: HarborTopic[]): HomeFeedItem[] {
    const result: HomeFeedItem[] = HomeFeedService.eventItems(HomeFeedService.prioritizeInitialEvents(events));
    const harborItems: HomeFeedItem[] = HomeFeedService.harborItems(harborTopics);
    if (harborItems.length === 0) {
      return result;
    }

    const insertOnTop: boolean = Math.random() < 0.4;
    if (insertOnTop && harborItems.length > 0) {
      const topIndex: number = Math.floor(Math.random() * harborItems.length);
      result.unshift(harborItems[topIndex]);
      harborItems.splice(topIndex, 1);
    }

    const positions: number[] = [];
    for (let i = 0; i <= result.length; i++) {
      positions.push(i);
    }
    const shuffledPositions: number[] = shuffleNumbers(positions);
    let used: number = 0;
    for (let i = 0; i < harborItems.length && i < shuffledPositions.length; i++) {
      const target: number = Math.min(Math.max(shuffledPositions[i] + used, 0), result.length);
      result.splice(target, 0, harborItems[i]);
      used++;
    }
    for (let i = used; i < harborItems.length; i++) {
      result.push(harborItems[i]);
    }
    return result;
  }
}
