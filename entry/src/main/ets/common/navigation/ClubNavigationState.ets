import { ClubInfo } from '../../models/Club';
import { ClubActivity } from '../../models/Event';

export class ClubNavigationState {
  private static selectedClub: ClubInfo | null = null;
  private static selectedEvent: ClubActivity | null = null;

  static setSelectedClub(club: ClubInfo): void {
    ClubNavigationState.selectedClub = club;
  }

  static getSelectedClub(): ClubInfo | null {
    return ClubNavigationState.selectedClub;
  }

  static setSelectedEvent(event: ClubActivity): void {
    ClubNavigationState.selectedEvent = event;
  }

  static getSelectedEvent(): ClubActivity | null {
    return ClubNavigationState.selectedEvent;
  }
}
