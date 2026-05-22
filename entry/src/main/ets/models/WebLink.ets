export interface WebLinkParams {
  url: string;
  title?: string;
  textColor?: string;
  backgroundColor?: string;
  prefersDarkStatusBar?: boolean;
}

export interface FeatureEntry {
  title: string;
  keyName: string;
  keywords: string;
  description?: string;
  routeName?: string;
  link?: WebLinkParams;
  requiresLogin?: boolean;
}

export interface FeatureGroup {
  title: string;
  entries: FeatureEntry[];
}
