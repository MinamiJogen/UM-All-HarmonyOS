import { ARK_WIKI } from '../constants/ApiEndpoints';
import { WebLinkParams } from '../../models/WebLink';

export class WebNavigationState {
  private static currentLink: WebLinkParams = {
    url: ARK_WIKI,
    title: 'ARK Wiki'
  };

  static setLink(link: WebLinkParams): void {
    WebNavigationState.currentLink = link;
  }

  static getLink(): WebLinkParams {
    return WebNavigationState.currentLink;
  }
}
