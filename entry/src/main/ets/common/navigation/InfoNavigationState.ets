import { UmEventItem } from '../../models/Event';
import { NewsItem } from '../../models/News';

export class InfoNavigationState {
  private static selectedNews: NewsItem | null = null;
  private static selectedUmEvent: UmEventItem | null = null;

  static setSelectedNews(item: NewsItem): void {
    InfoNavigationState.selectedNews = item;
  }

  static getSelectedNews(): NewsItem | null {
    return InfoNavigationState.selectedNews;
  }

  static setSelectedUmEvent(item: UmEventItem): void {
    InfoNavigationState.selectedUmEvent = item;
  }

  static getSelectedUmEvent(): UmEventItem | null {
    return InfoNavigationState.selectedUmEvent;
  }
}
