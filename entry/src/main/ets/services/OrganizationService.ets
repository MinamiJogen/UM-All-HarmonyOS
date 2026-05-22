import { UM_OPEN_DATA_ORG } from '../common/constants/ApiEndpoints';
import { ApiClient } from '../common/net/ApiClient';
import { errorResult, ServiceResult } from '../common/net/HttpClient';
import { UmOpenDataListResponse } from '../models/ApiResponse';
import {
  UmOrgSubUnit,
  UmOrgUnit
} from '../models/Organization';

function normalizeSimplifiedChinese(input: string): string {
  return input
    .replaceAll('学', '學')
    .replaceAll('办', '辦')
    .replaceAll('处', '處')
    .replaceAll('门', '門')
    .replaceAll('车', '車')
    .replaceAll('电', '電')
    .replaceAll('脑', '腦')
    .replaceAll('资', '資')
    .replaceAll('务', '務')
    .replaceAll('书', '書')
    .replaceAll('图', '圖')
    .replaceAll('馆', '館')
    .replaceAll('会', '會')
    .replaceAll('议', '議')
    .replaceAll('体', '體')
    .replaceAll('医', '醫')
    .replaceAll('药', '藥')
    .replaceAll('发', '發')
    .replaceAll('财', '財')
    .replaceAll('经', '經')
    .replaceAll('济', '濟')
    .replaceAll('国', '國')
    .replaceAll('际', '際')
    .replaceAll('联', '聯')
    .replaceAll('络', '絡')
    .replaceAll('总', '總')
    .replaceAll('员', '員')
    .replaceAll('职', '職')
    .replaceAll('课', '課')
    .replaceAll('注', '註')
    .replaceAll('册', '冊')
    .replaceAll('后', '後')
    .replaceAll('统', '統')
    .replaceAll('实', '實')
    .replaceAll('验', '驗')
    .replaceAll('组', '組')
    .replaceAll('织', '織');
}

function containsText(source: string | undefined, keyword: string, traditionalKeyword: string): boolean {
  if (!source) {
    return false;
  }
  const normalizedSource: string = source.toLowerCase();
  return normalizedSource.includes(keyword) || normalizedSource.includes(traditionalKeyword);
}

export class OrganizationService {
  static async fetchAll(): Promise<ServiceResult<UmOrgUnit[]>> {
    const response: ServiceResult<UmOpenDataListResponse<UmOrgUnit>> =
      await ApiClient.getUmOpenData<UmOpenDataListResponse<UmOrgUnit>>(UM_OPEN_DATA_ORG);

    if (!response.ok || !response.data) {
      return {
        ok: false,
        error: response.error,
        response: response.response
      };
    }

    if (!response.data._embedded) {
      return errorResult<UmOrgUnit[]>('UM_ORG_API_ERROR', '部门数据格式无效', response.response);
    }

    return {
      ok: true,
      data: response.data._embedded,
      response: response.response
    };
  }

  static buildSearchUrl(query: string): string {
    return 'https://www.google.com/search?q=' +
    encodeURIComponent('site:umall.one OR site:um.edu.mo ' + query);
  }

  static titleCase(input: string): string {
    const parts: string[] = input.toLowerCase().split(' ');
    const formatted: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      const part: string = parts[i];
      if (part.length === 0) {
        continue;
      }
      formatted.push(part.substring(0, 1).toUpperCase() + part.substring(1));
    }
    return formatted.join(' ');
  }

  static unitMatches(unit: UmOrgUnit, searchText: string): boolean {
    const keyword: string = searchText.trim().toLowerCase();
    if (keyword.length === 0) {
      return true;
    }
    const traditionalKeyword: string = normalizeSimplifiedChinese(keyword);
    if (containsText(unit.chinUnitName, keyword, traditionalKeyword) ||
      containsText(unit.unitName, keyword, traditionalKeyword) ||
      containsText(unit.unitCode, keyword, traditionalKeyword)) {
      return true;
    }

    const subUnits: UmOrgSubUnit[] = unit.subUnit ?? [];
    for (let i = 0; i < subUnits.length; i++) {
      const subUnit: UmOrgSubUnit = subUnits[i];
      if (containsText(subUnit.chinSubUnitName, keyword, traditionalKeyword) ||
        containsText(subUnit.subUnitName, keyword, traditionalKeyword) ||
        containsText(subUnit.subUnitCode, keyword, traditionalKeyword)) {
        return true;
      }
    }
    return false;
  }

  static filterUnits(units: UmOrgUnit[], searchText: string): UmOrgUnit[] {
    const filtered: UmOrgUnit[] = [];
    for (let i = 0; i < units.length; i++) {
      const unit: UmOrgUnit = units[i];
      if (OrganizationService.unitMatches(unit, searchText)) {
        filtered.push(unit);
      }
    }
    return filtered;
  }
}
