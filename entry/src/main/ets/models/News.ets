export const OPEN_DATA_LOCALE_ZH_TW: string = 'zh_TW';
export const OPEN_DATA_LOCALE_EN_US: string = 'en_US';
export const OPEN_DATA_LOCALE_PT_PT: string = 'pt_PT';

export interface NewsCommon {
  publishDate: string;
  imageUrls?: string[];
}

export interface NewsDetail {
  locale: string;
  title: string;
  content?: string;
}

export interface NewsItem {
  _id: string;
  common: NewsCommon;
  details: NewsDetail[];
  lastModified?: string;
}
