export interface ClubActivity {
  _id?: string;
  activity_id?: string;
  club_num?: number;
  created_by?: number;
  club_name?: string;
  title?: string;
  content?: string;
  introduction?: string;
  cover_image_url?: string;
  relate_image_url?: string[];
  image_url_list?: string[];
  location?: string;
  link?: string;
  type?: string;
  timestamp?: string;
  startdatetime?: string;
  enddatetime?: string;
  time?: string;
  date?: string;
  start_time?: string;
  end_time?: string;
  tag?: string;
}

export interface UmEventCommon {
  dateFrom: string;
  dateTo?: string;
  timeFrom?: string;
  timeTo?: string;
  posterUrl?: string;
}

export interface UmEventDetail {
  locale: string;
  title?: string;
  content?: string;
  organiser?: string;
  coorganiser?: string;
  venue?: string;
  targetAudience?: string;
  speaker?: string;
  remark?: string;
  languages?: string[] | string;
  organizedBys?: string;
  coorganizers?: string;
  venues?: string;
  targetAudiences?: string;
  speakers?: string;
  contactName?: string;
  contactPhone?: string;
  contactFax?: string;
  contactEmail?: string;
}

export interface UmEventItem {
  _id: string;
  common: UmEventCommon;
  details: UmEventDetail[];
}
