import {
  UM_BUS_LOOP_EN,
  UM_BUS_LOOP_ZH
} from '../common/constants/ApiEndpoints';
import { HttpClient, ServiceResult } from '../common/net/HttpClient';
import {
  BusLoopState,
  BusPositionInfo,
  BusStopInfo
} from '../models/Bus';

export const BUS_REFRESH_INTERVAL_MS: number = 7000;

export const BUS_STOP_INFOS: BusStopInfo[] = [
  { code: 'PGH', nameTc: '研究生宿舍(起)', nameEn: 'Postgraduate House', positionIndex: 0 },
  { code: 'E4', nameTc: '劉少榮樓', nameEn: 'Anthony Lau Building', positionIndex: 2 },
  { code: 'N2', nameTc: '大學會堂', nameEn: 'University Hall', positionIndex: 4 },
  { code: 'N6', nameTc: '行政樓', nameEn: 'Administration Building', positionIndex: 6 },
  { code: 'E11', nameTc: '科技學院', nameEn: 'Faculty of Science and Technology', positionIndex: 8 },
  { code: 'E21', nameTc: '人文社科樓', nameEn: 'FAH/FSS Building', positionIndex: 10 },
  { code: 'E32', nameTc: '法學院', nameEn: 'Faculty of Law', positionIndex: 12 },
  { code: 'S4', nameTc: '研究生宿舍南四座(終)', nameEn: 'Postgraduate House S4', positionIndex: 14 }
];

const BUS_POSITION_LABELS_TC: string[] = [
  'PGH 研究生宿舍',
  'PGH 往 E4 途中',
  'E4 劉少榮樓',
  'E4 往 N2 途中',
  'N2 大學會堂',
  'N2 往 N6 途中',
  'N6 行政樓',
  'N6 往 E11 途中',
  'E11 科技學院',
  'E11 往 E21 途中',
  'E21 人文社科樓',
  'E21 往 E32 途中',
  'E32 法學院',
  'E32 往 S4 途中',
  'S4 研究生宿舍南四座',
  'S4 往 PGH 途中'
];

const BUS_POSITION_LABELS_EN: string[] = [
  'PGH Postgraduate House',
  'PGH to E4',
  'E4 Anthony Lau Building',
  'E4 to N2',
  'N2 University Hall',
  'N2 to N6',
  'N6 Administration Building',
  'N6 to E11',
  'E11 Faculty of Science and Technology',
  'E11 to E21',
  'E21 FAH/FSS Building',
  'E21 to E32',
  'E32 Faculty of Law',
  'E32 to S4',
  'S4 Postgraduate House',
  'S4 to PGH'
];

function createEmptyState(sourceUrl: string = ''): BusLoopState {
  return {
    infoLines: [],
    positions: [],
    lastUpdatedAt: 0,
    sourceUrl: sourceUrl
  };
}

function decodeHtmlEntities(input: string): string {
  return input
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', '\'');
}

function cleanHtmlText(input: string): string {
  return decodeHtmlEntities(input)
    .replace(/<[^>]+>/g, '')
    .replace(/[\t\n\r]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function extractTagText(html: string, tagName: string): string[] {
  const result: string[] = [];
  const regex: RegExp = new RegExp('<' + tagName + '[^>]*>([\\s\\S]*?)<\\/' + tagName + '>', 'gi');
  let match: RegExpExecArray | null = regex.exec(html);
  while (match !== null) {
    result.push(cleanHtmlText(match[1]));
    match = regex.exec(html);
  }
  return result;
}

function extractLeftClassText(html: string): string[] {
  const result: string[] = [];
  const regex: RegExp = /<div[^>]*class=["'][^"']*\bleft\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/gi;
  let match: RegExpExecArray | null = regex.exec(html);
  while (match !== null) {
    result.push(cleanHtmlText(match[1]));
    match = regex.exec(html);
  }
  return result;
}

export class BusService {
  static emptyState(): BusLoopState {
    return createEmptyState();
  }

  static urlForLanguage(english: boolean): string {
    return english ? UM_BUS_LOOP_EN : UM_BUS_LOOP_ZH;
  }

  static positionLabel(index: number, english: boolean): string {
    const source: string[] = english ? BUS_POSITION_LABELS_EN : BUS_POSITION_LABELS_TC;
    if (index >= 0 && index < source.length) {
      return source[index];
    }
    return english ? 'Unknown position' : '未知位置';
  }

  static parse(html: string, sourceUrl: string, english: boolean): BusLoopState {
    const spans: string[] = extractTagText(html, 'span');
    const infoLines: string[] = [];
    const infoIndex: number = spans.length >= 12 ? 3 : 2;
    for (let i = 0; i <= infoIndex && i < spans.length; i++) {
      if (spans[i].length > 0) {
        infoLines.push(spans[i]);
      }
    }
    if (infoLines.length > 0) {
      infoLines.shift();
    }

    const leftTexts: string[] = extractLeftClassText(html);
    const positions: BusPositionInfo[] = [];
    for (let i = 0; i < leftTexts.length; i++) {
      const busId: string = leftTexts[i];
      if (busId.length > 0) {
        positions.push({
          busId: busId,
          index: i,
          stopName: BusService.positionLabel(i, english),
          status: i % 2 === 0 ? 'stop' : 'between'
        });
      }
    }

    return {
      infoLines: infoLines,
      positions: positions,
      lastUpdatedAt: Date.now(),
      sourceUrl: sourceUrl
    };
  }

  static async fetchLoop(english: boolean): Promise<ServiceResult<BusLoopState>> {
    const url: string = BusService.urlForLanguage(english);
    const response: ServiceResult<string> = await HttpClient.requestText(url, {
      timeoutMs: 10000
    });

    if (!response.ok || !response.data) {
      return {
        ok: false,
        error: response.error,
        response: response.response
      };
    }

    return {
      ok: true,
      data: BusService.parse(response.data, url, english),
      response: response.response
    };
  }
}
