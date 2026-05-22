export const INFO_TOP_TAB_HOME: number = 0;
export const INFO_TOP_TAB_CLUB: number = 1;
export const INFO_TOP_TAB_EVENT: number = 2;
export const INFO_TOP_TAB_NEWS: number = 3;

export type InfoRefreshHandler = () => void;

export class InfoRefreshRegistry {
  private static currentTabIndex: number = INFO_TOP_TAB_HOME;
  private static handlers: Map<number, InfoRefreshHandler> = new Map<number, InfoRefreshHandler>();

  static setCurrentTabIndex(index: number): void {
    InfoRefreshRegistry.currentTabIndex = index;
  }

  static register(index: number, handler: InfoRefreshHandler): void {
    InfoRefreshRegistry.handlers.set(index, handler);
  }

  static unregister(index: number, handler: InfoRefreshHandler): void {
    const currentHandler: InfoRefreshHandler | undefined = InfoRefreshRegistry.handlers.get(index);
    if (currentHandler === handler) {
      InfoRefreshRegistry.handlers.delete(index);
    }
  }

  static refreshCurrent(): boolean {
    const handler: InfoRefreshHandler | undefined =
      InfoRefreshRegistry.handlers.get(InfoRefreshRegistry.currentTabIndex);
    if (!handler) {
      return false;
    }
    handler();
    return true;
  }
}
