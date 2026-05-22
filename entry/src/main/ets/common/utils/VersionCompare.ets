function parseVersionPart(part: string): number {
  const digits: string = part.replace(/[^0-9]/g, '');
  if (digits.length === 0) {
    return 0;
  }
  const value: number = Number.parseInt(digits, 10);
  if (Number.isNaN(value)) {
    return 0;
  }
  return value;
}

function normalizeVersion(version: string): number[] {
  if (version.length === 0) {
    return [0];
  }
  return version.split(/[._+-]/).map((part: string): number => parseVersionPart(part));
}

export function compareVersion(current: string, target: string): number {
  const currentParts: number[] = normalizeVersion(current);
  const targetParts: number[] = normalizeVersion(target);
  const maxLength: number = Math.max(currentParts.length, targetParts.length);

  for (let index = 0; index < maxLength; index++) {
    const left: number = index < currentParts.length ? currentParts[index] : 0;
    const right: number = index < targetParts.length ? targetParts[index] : 0;
    if (left > right) {
      return 1;
    }
    if (left < right) {
      return -1;
    }
  }

  return 0;
}

export function isVersionNewer(latest: string, current: string): boolean {
  return compareVersion(latest, current) > 0;
}
