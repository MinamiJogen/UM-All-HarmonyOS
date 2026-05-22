export interface ClubContact {
  type: string;
  num: string;
  url?: string;
}

export interface ClubInfo {
  _id?: string;
  club_num: number;
  name: string;
  eng_name?: string;
  logo_url?: string;
  tag?: string;
  intro?: string;
  description?: string;
  email?: string;
  instagram?: string;
  facebook?: string;
  wechat?: string;
  club_photos_list?: string[];
  contact?: ClubContact[];
  login_time?: number;
}

export interface ClubSection {
  title: string;
  clubs: ClubInfo[];
}
