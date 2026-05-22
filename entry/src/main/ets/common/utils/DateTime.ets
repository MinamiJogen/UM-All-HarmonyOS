export const DAY_CODE_MON: string = 'MON';
export const DAY_CODE_TUE: string = 'TUE';
export const DAY_CODE_WED: string = 'WED';
export const DAY_CODE_THU: string = 'THU';
export const DAY_CODE_FRI: string = 'FRI';
export const DAY_CODE_SAT: string = 'SAT';
export const DAY_CODE_SUN: string = 'SUN';

export const WEEK_DAY_CODES: string[] = [
  DAY_CODE_MON,
  DAY_CODE_TUE,
  DAY_CODE_WED,
  DAY_CODE_THU,
  DAY_CODE_FRI,
  DAY_CODE_SAT,
  DAY_CODE_SUN
];

export function normalizeDayCode(day: string | undefined): string {
  const normalized: string = (day ?? '').trim().toUpperCase();
  if (normalized === DAY_CODE_MON || normalized === DAY_CODE_TUE || normalized === DAY_CODE_WED ||
    normalized === DAY_CODE_THU || normalized === DAY_CODE_FRI || normalized === DAY_CODE_SAT ||
    normalized === DAY_CODE_SUN) {
    return normalized;
  }
  return '';
}

export function dayCodeOrder(day: string | undefined): number {
  const normalized: string = normalizeDayCode(day);
  for (let i = 0; i < WEEK_DAY_CODES.length; i++) {
    if (WEEK_DAY_CODES[i] === normalized) {
      return i + 1;
    }
  }
  return 99;
}

export function parseClockTimeToMinutes(time: string | undefined): number {
  const normalized: string = (time ?? '').trim();
  if (normalized.length === 0) {
    return -1;
  }

  const parts: string[] = normalized.split(':');
  if (parts.length < 2) {
    return -1;
  }

  const hours: number = Number.parseInt(parts[0], 10);
  const minutes: number = Number.parseInt(parts[1], 10);
  if (Number.isNaN(hours) || Number.isNaN(minutes) || hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
    return -1;
  }
  return hours * 60 + minutes;
}

export function compareClockTime(left: string | undefined, right: string | undefined): number {
  const leftMinutes: number = parseClockTimeToMinutes(left);
  const rightMinutes: number = parseClockTimeToMinutes(right);
  if (leftMinutes < rightMinutes) {
    return -1;
  }
  if (leftMinutes > rightMinutes) {
    return 1;
  }
  return 0;
}

export function getDateDayCode(date: Date): string {
  const day: number = date.getDay();
  if (day === 1) {
    return DAY_CODE_MON;
  }
  if (day === 2) {
    return DAY_CODE_TUE;
  }
  if (day === 3) {
    return DAY_CODE_WED;
  }
  if (day === 4) {
    return DAY_CODE_THU;
  }
  if (day === 5) {
    return DAY_CODE_FRI;
  }
  if (day === 6) {
    return DAY_CODE_SAT;
  }
  return DAY_CODE_SUN;
}

export function getDateClockMinutes(date: Date): number {
  return date.getHours() * 60 + date.getMinutes();
}
