import { common } from '@kit.AbilityKit';
import { AppBootstrap } from '../app/AppBootstrap';
import { AppStartupState, createInitialStartupState } from '../app/AppState';
import { I18nService, LANGUAGE_TC } from '../common/i18n/I18nService';
import {
  ARKUI_COLOR_MODE_LIGHT,
  THEME_MODE_SYSTEM,
  ThemeStore
} from '../common/theme/AppTheme';
import { RootTabs } from '../pages/root/RootTabs';
import {
  ROOT_TAB_INFO,
  ROOT_TAB_TIMETABLE
} from '../common/constants/TabIndexes';
import {
  LAUNCH_TARGET_TIMETABLE
} from '../common/constants/LaunchTargets';
import {
  ROUTE_ALL_EVENTS,
  ROUTE_BUS,
  ROUTE_CAR_PARK,
  ROUTE_CLUB_DETAIL,
  ROUTE_COURSE_SIM,
  ROUTE_EVENT_DETAIL,
  ROUTE_LOCAL_COURSE,
  ROUTE_NEWS_DETAIL,
  ROUTE_SETTING,
  ROUTE_UM_EVENT_DETAIL,
  ROUTE_UM_ORG,
  ROUTE_WEBVIEWER
} from '../common/constants/RouteNames';
import { BusPage } from './features/BusPage';
import { CarParkPage } from './features/CarParkPage';
import { SettingPage } from './features/SettingPage';
import { UMOrgPage } from './features/UMOrgPage';
import { LocalCoursePage } from './courses/LocalCoursePage';
import { CourseSimPage } from './timetable/CourseSimPage';
import { NewsDetailPage } from './info/news/NewsDetailPage';
import { UMEventDetailPage } from './info/news/UMEventDetailPage';
import { ClubDetailPage } from './info/club/ClubDetailPage';
import { ClubEventDetailPage } from './info/club/ClubEventDetailPage';
import { AllClubEventsPage } from './info/club/AllClubEventsPage';
import { WebViewerPage } from './web/WebViewerPage';

Environment.envProp<number>('colorMode', ARKUI_COLOR_MODE_LIGHT);

@Entry
@Component
struct Index {
  @Provide('appPathStack') pathStack: NavPathStack = new NavPathStack();
  @Provide('appThemeMode') appThemeMode: number = THEME_MODE_SYSTEM;
  @Provide('appLanguage') appLanguage: string = LANGUAGE_TC;
  @Provide('appStartupState') appStartupState: AppStartupState = createInitialStartupState();
  @Provide('appCurrentTabIndex') currentTabIndex: number = ROOT_TAB_INFO;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @StorageLink('appLaunchTarget') launchTarget: string = '';
  @StorageLink('appLaunchSequence') @Watch('onLaunchSequenceChanged') launchSequence: number = 0;
  private bootstrapStarted: boolean = false;
  private backgroundBootstrapStarted: boolean = false;
  private handledLaunchSequence: number = -1;

  aboutToAppear(): void {
    this.consumeLaunchTarget();
    if (this.bootstrapStarted) {
      return;
    }
    this.bootstrapStarted = true;
    const preparedState: AppStartupState | undefined = AppBootstrap.getStartupState();
    if (preparedState) {
      this.appStartupState = preparedState;
    }
    this.initializeApp();
  }

  onPageShow(): void {
    this.consumeLaunchTarget();
  }

  private async initializeApp(): Promise<void> {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    let startupState: AppStartupState | undefined = AppBootstrap.getStartupState();
    if (!startupState) {
      this.appStartupState = createInitialStartupState();
    }
    this.appThemeMode = await ThemeStore.loadThemeMode(context);
    ThemeStore.applyColorMode(context, this.appThemeMode);
    this.appLanguage = await I18nService.loadLanguage(context);
    startupState = AppBootstrap.getStartupState();
    if (!startupState || startupState.running || !startupState.ready) {
      this.appStartupState = createInitialStartupState();
      startupState = await AppBootstrap.initializeEssential(context);
      this.appStartupState = startupState;
    }
    this.startBackgroundInitialization(context, startupState);
  }

  private startBackgroundInitialization(context: common.UIAbilityContext, baseState: AppStartupState): void {
    if (this.backgroundBootstrapStarted) {
      return;
    }
    this.backgroundBootstrapStarted = true;
    const backgroundState: AppStartupState = AppBootstrap.markBackgroundInitializationRunning(baseState);
    this.appStartupState = backgroundState;
    AppBootstrap.initializeBackground(context, backgroundState).then((state: AppStartupState) => {
      this.appStartupState = state;
    });
  }

  private popRouteIfNeeded(): boolean {
    if (this.pathStack.size() > 0) {
      this.pathStack.pop();
      return true;
    }
    return false;
  }

  private onLaunchSequenceChanged(): void {
    this.consumeLaunchTarget();
  }

  private consumeLaunchTarget(): void {
    if (this.launchSequence === this.handledLaunchSequence) {
      return;
    }
    this.handledLaunchSequence = this.launchSequence;
    if (this.launchTarget !== LAUNCH_TARGET_TIMETABLE) {
      return;
    }

    this.pathStack.clear(false);
    this.currentTabIndex = ROOT_TAB_TIMETABLE;
    this.launchTarget = '';
  }

  onBackPress(): boolean {
    return this.popRouteIfNeeded();
  }

  @Builder
  RouteContent(routeName: string) {
    if (routeName === ROUTE_BUS) {
      BusPage()
    } else if (routeName === ROUTE_CAR_PARK) {
      CarParkPage()
    } else if (routeName === ROUTE_UM_ORG) {
      UMOrgPage()
    } else if (routeName === ROUTE_COURSE_SIM) {
      CourseSimPage({ showBack: true })
    } else if (routeName === ROUTE_SETTING) {
      SettingPage()
    } else if (routeName === ROUTE_CLUB_DETAIL) {
      ClubDetailPage()
    } else if (routeName === ROUTE_EVENT_DETAIL) {
      ClubEventDetailPage()
    } else if (routeName === ROUTE_NEWS_DETAIL) {
      NewsDetailPage()
    } else if (routeName === ROUTE_UM_EVENT_DETAIL) {
      UMEventDetailPage()
    } else if (routeName === ROUTE_ALL_EVENTS) {
      AllClubEventsPage()
    } else if (routeName === ROUTE_LOCAL_COURSE) {
      LocalCoursePage()
    } else if (routeName === ROUTE_WEBVIEWER) {
      WebViewerPage()
    }
  }

  @Builder
  routeMap(routeName: string) {
    NavDestination() {
      this.RouteContent(routeName)
    }
    .hideTitleBar(true)
    .mode(NavDestinationMode.STANDARD)
    .systemTransition(NavigationSystemTransitionType.SLIDE_RIGHT)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .onBackPressed(() => {
      return this.popRouteIfNeeded();
    })
  }

  build() {
    Navigation(this.pathStack) {
      RootTabs()
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.routeMap)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor(ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode).bgColor)
  }
}
