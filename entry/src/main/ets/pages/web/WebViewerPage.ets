import { common } from '@kit.AbilityKit';
import webview from '@ohos.web.webview';
import { WebNavigationState } from '../../common/navigation/WebNavigationState';
import { I18nService } from '../../common/i18n/I18nService';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../../common/theme/AppTheme';
import { OpenLink } from '../../common/utils/OpenLink';
import { AppHdsPage } from '../../components/AppHdsPage';
import { AppToast } from '../../components/AppToast';
import { WebLinkParams } from '../../models/WebLink';

interface WebPageUrlEvent {
  url: string;
}

interface WebProgressEvent {
  newProgress: number;
}

interface WebTitleEvent {
  title: string;
}

@Component
export struct WebViewerPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  private controller: webview.WebviewController = new webview.WebviewController();
  @State url: string = '';
  @State pageTitle: string = '';
  @State progress: number = 0;
  @State loading: boolean = false;
  @State canGoBack: boolean = false;
  @State canGoForward: boolean = false;
  private initialized: boolean = false;

  aboutToAppear(): void {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    const link: WebLinkParams = WebNavigationState.getLink();
    this.url = link.url;
    this.pageTitle = link.title ?? this.localized('網頁', 'Web');
    try {
      webview.WebviewController.initializeWebEngine();
    } catch (error) {
      error;
    }
  }

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private localized(tcText: string, enText: string, ptText: string = '', jaText: string = ''): string {
    return I18nService.localizeText(this.language, tcText, enText, ptText, jaText);
  }

  private getContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private syncHistoryState(): void {
    try {
      this.canGoBack = this.controller.accessBackward();
      this.canGoForward = this.controller.accessForward();
    } catch (error) {
      this.canGoBack = false;
      this.canGoForward = false;
    }
  }

  private goBack(): void {
    this.syncHistoryState();
    if (this.canGoBack) {
      try {
        this.controller.backward();
      } catch (error) {
        this.pathStack.pop();
      }
      return;
    }
    this.pathStack.pop();
  }

  private goForward(): void {
    this.syncHistoryState();
    if (!this.canGoForward) {
      return;
    }
    try {
      this.controller.forward();
    } catch (error) {
      error;
    }
  }

  private refresh(): void {
    try {
      this.controller.refresh();
    } catch (error) {
      if (this.url.length > 0) {
        this.controller.loadUrl(this.url);
      }
    }
  }

  private async openExternal(): Promise<void> {
    const target: string = this.url;
    const success: boolean = await OpenLink.open(this.getContext(), target);
    if (!success) {
      AppToast.showError(this.getUIContext(), this.localized('無法打開鏈接', 'Unable to open link'));
    }
  }

  @Builder
  ProgressBar(): void {
    if (this.loading && this.progress < 100) {
      Stack({ alignContent: Alignment.Start }) {
        Column() {
        }
          .height(2)
          .width('100%')
          .backgroundColor(this.theme().surfaceAltColor)
        Column() {
        }
          .height(2)
          .width(this.progress.toString() + '%')
          .backgroundColor(this.theme().themeColor)
      }
      .width('100%')
      .height(2)
    } else {
      Column() {
      }
        .width('100%')
        .height(2)
        .backgroundColor(this.theme().bgColor)
    }
  }

  @Builder
  WebToolbar(): void {
    Row() {
      Button(this.localized('後退', 'Back'))
        .height(38)
        .layoutWeight(1)
        .borderRadius(8)
        .fontSize(13)
        .fontColor(this.canGoBack ? this.theme().themeColor : this.theme().textTertiary)
        .backgroundColor(this.theme().surfaceAltColor)
        .onClick(() => {
          this.goBack();
        })
      Button(this.localized('前進', 'Forward'))
        .height(38)
        .layoutWeight(1)
        .borderRadius(8)
        .fontSize(13)
        .fontColor(this.canGoForward ? this.theme().themeColor : this.theme().textTertiary)
        .backgroundColor(this.theme().surfaceAltColor)
        .onClick(() => {
          this.goForward();
        })
      Button(this.localized('刷新', 'Refresh'))
        .height(38)
        .layoutWeight(1)
        .borderRadius(8)
        .fontSize(13)
        .fontColor(this.theme().themeColor)
        .backgroundColor(this.theme().surfaceAltColor)
        .onClick(() => {
          this.refresh();
        })
      Button(this.localized('外部', 'Open'))
        .height(38)
        .layoutWeight(1)
        .borderRadius(8)
        .fontSize(13)
        .fontColor(this.theme().themeColor)
        .backgroundColor(this.theme().surfaceAltColor)
        .onClick(() => {
          this.openExternal();
        })
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 8, bottom: 10 })
    .backgroundColor(this.theme().bgColor)
  }

  @Builder
  PageContent(): void {
    this.ProgressBar()
    Web({ src: this.url, controller: this.controller })
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .onlineImageAccess(true)
      .imageAccess(true)
      .fileAccess(true)
      .mixedMode(MixedMode.All)
      .cacheMode(CacheMode.None)
      .darkMode(this.theme().isLight ? WebDarkMode.Off : WebDarkMode.On)
      .onPageBegin((event?: WebPageUrlEvent) => {
        this.loading = true;
        this.progress = 0;
        if (event) {
          this.url = event.url;
        }
        this.syncHistoryState();
      })
      .onProgressChange((event?: WebProgressEvent) => {
        if (event) {
          this.progress = event.newProgress;
        }
      })
      .onTitleReceive((event?: WebTitleEvent) => {
        if (event && event.title.length > 0) {
          this.pageTitle = event.title;
        }
      })
      .onPageEnd((event?: WebPageUrlEvent) => {
        this.loading = false;
        this.progress = 100;
        if (event) {
          this.url = event.url;
        }
        this.syncHistoryState();
      })
      .layoutWeight(1)
    this.WebToolbar()
  }

  build() {
    AppHdsPage({
      title: this.pageTitle,
      backLabel: this.localized('返回', 'Back'),
      primaryActionLabel: this.localized('外部', 'Open'),
      primaryActionSymbol: $r('sys.symbol.paperplan_right_2'),
      onBack: (): void => {
        this.goBack();
      },
      onPrimaryAction: (): void => {
        this.openExternal();
      },
      content: (): void => {
        this.PageContent()
      }
    })
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bgColor)
  }
}
