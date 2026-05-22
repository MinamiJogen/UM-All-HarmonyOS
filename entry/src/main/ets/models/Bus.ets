export interface BusArrivalInfo {
  stopName: string;
  message: string;
  routeName?: string;
  updateTime?: string;
}

export interface BusPositionInfo {
  busId: string;
  index: number;
  stopName: string;
  status?: string;
}

export interface BusLoopState {
  infoLines: string[];
  positions: BusPositionInfo[];
  lastUpdatedAt: number;
  sourceUrl: string;
}

export interface BusStopInfo {
  code: string;
  nameTc: string;
  nameEn: string;
  positionIndex: number;
}
