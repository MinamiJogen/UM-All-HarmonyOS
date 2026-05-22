import { common } from '@kit.AbilityKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsNavigation,
  HdsNavigationMenuContentOptions,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode,
  HdsTabs,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit';
import { AppStartupState } from '../../app/AppState';
import {
  ARK_HARBOR_NEW_TOPIC,
  ARK_USER_AGREEMENT
} from '../../common/constants/ApiEndpoints';
import {
  ROOT_CONTENT_BOTTOM_PADDING,
  ROOT_CONTENT_TOP_PADDING,
  ROOT_TAB_BAR_BOTTOM_MARGIN,
  ROOT_TAB_BAR_HEIGHT
} from '../../common/constants/LayoutMetrics';
import {
  ROUTE_SETTING
} from '../../common/constants/RouteNames';
import {
  ROOT_TAB_INFO,
  ROOT_TAB_NEW_TOPIC,
  ROOT_TAB_SERVICE,
  ROOT_TAB_TIMETABLE,
  ROOT_TAB_WHAT2REG
} from '../../common/constants/TabIndexes';
import { I18nService } from '../../common/i18n/I18nService';
import { InfoRefreshRegistry } from '../../common/navigation/InfoRefreshRegistry';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../../common/theme/AppTheme';
import { OpenLink } from '../../common/utils/OpenLink';
import { AppToast } from '../../components/AppToast';
import { PlaceholderPage } from '../common/PlaceholderPage';
import { What2RegPage } from '../courses/What2RegPage';
import { ServicePage } from '../features/ServicePage';
import { CourseSimPage } from '../timetable/CourseSimPage';
import { InfoTopTabs } from './InfoTopTabs';

@Component
export struct RootTabs {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @Consume('appStartupState') startupState: AppStartupState;
  @Consume('appCurrentTabIndex') currentIndex: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @StorageLink('courseSimAddSheetVisible') timetableAddSheetVisible: boolean = false;
  @StorageLink('serviceFeedbackSheetVisible') serviceFeedbackSheetVisible: boolean = false;
  @StorageLink('what2RegUpdateSheetVisible') what2RegUpdateSheetVisible: boolean = false;
  @State private customMaterialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;
  private lastContentIndex: number = ROOT_TAB_INFO;

  aboutToAppear(): void {
    this.resolveBottomBarMaterialLevel();
  }

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private resolveBottomBarMaterialLevel(): void {
    const materialTypes = hdsMaterial.getSystemMaterialTypes();
    if (materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) < 0) {
      this.customMaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;
      return;
    }
    this.customMaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;
  }

  private text(key: string, fallback: string): string {
    return I18nService.t(this.language, key, fallback);
  }

  private openHarborNewTopic(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    OpenLink.open(context, ARK_HARBOR_NEW_TOPIC).then((success: boolean) => {
      if (!success) {
        AppToast.showError(this.getUIContext(), '无法打开新想法入口');
      }
    });
  }

  private openWhat2RegAgreement(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    OpenLink.open(context, ARK_USER_AGREEMENT).then((success: boolean) => {
      if (!success) {
        AppToast.showError(this.getUIContext(), this.text('setting.OPEN_LINK_FAILED', 'Unable to open link'));
      }
    });
  }

  private tabSymbol(index: number): Resource {
    switch (index) {
      case 0:
        return $r('sys.symbol.doc_plaintext');
      case 1:
        return $r('sys.symbol.magnifyingglass');
      case 2:
        return $r('sys.symbol.plus_circle_fill');
      case 3:
        return $r('sys.symbol.calendar');
      case 4:
        return $r('sys.symbol.square_grid_2x2');
      default:
        return $r('sys.symbol.service_card');
    }
  }

  @Builder
  StartupLoadingDialog() {
    if (this.startupState.running) {
      Stack({ alignContent: Alignment.Center }) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(this.theme().themeColor)
          Text(this.text('bootstrap.LOADING', 'ARK ALL is initializing'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme().textPrimary)
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 14 })
        }
        .width(184)
        .padding({ left: 20, right: 20, top: 24, bottom: 22 })
        .borderRadius(16)
        .backgroundColor(this.theme().surfaceColor)
        .shadow(ShadowStyle.OUTER_DEFAULT_MD)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme().isLight ? '#33000000' : '#66000000')
      .hitTestBehavior(HitTestMode.Block)
      .zIndex(1000)
      .transition(TransitionEffect.OPACITY)
    }
  }

  private BottomTabBar(title: string, symbol: Resource): BottomTabBarStyle {
    return new BottomTabBarStyle({
      normal: new SymbolGlyphModifier(symbol)
        .fontColor([this.theme().tabInactiveColor]),
      selected: new SymbolGlyphModifier(symbol)
        .fontColor([this.theme().themeColor])
    }, title)
      .labelStyle({
        maxLines: 1,
        selectedColor: this.theme().themeColor,
        unselectedColor: this.theme().tabInactiveColor
      });
  }

  private emptyTitleBarMenu(): HdsNavigationMenuContentOptions {
    return {
      value: [],
      maxCount: 0
    };
  }

  private titleBarSymbol(symbol: Resource): SymbolGlyphModifier {
    return new SymbolGlyphModifier(symbol)
      .fontColor([this.theme().themeColor]);
  }

  private toggleTimetableAddSheet(): void {
    this.timetableAddSheetVisible = !this.timetableAddSheetVisible;
  }

  private timetableTitleBarMenu(): HdsNavigationMenuContentOptions {
    return {
      value: [
        {
          content: {
            label: this.timetableAddSheetVisible ? this.text('common.CLOSE', 'Close') :
            this.text('common.ADD_COURSE', '搵課/加課'),
            icon: this.titleBarSymbol(this.timetableAddSheetVisible ? $r('sys.symbol.xmark_circle_fill') :
            $r('sys.symbol.plus_circle_fill')),
            action: (): void => {
              this.toggleTimetableAddSheet();
            }
          }
        }
      ],
      maxCount: 1
    };
  }

  private infoTitleBarMenu(): HdsNavigationMenuContentOptions {
    return {
      value: [
        {
          content: {
            label: this.text('common.REFRESH', '刷新'),
            icon: this.titleBarSymbol($r('sys.symbol.arrow_clockwise')),
            action: (): void => {
              InfoRefreshRegistry.refreshCurrent();
            }
          }
        }
      ],
      maxCount: 1
    };
  }

  private what2RegTitleBarMenu(): HdsNavigationMenuContentOptions {
    return {
      value: [
        {
          content: {
            label: this.text('common.UPDATE', '更新'),
            icon: this.titleBarSymbol($r('sys.symbol.arrow_clockwise')),
            action: (): void => {
              this.what2RegUpdateSheetVisible = true;
            }
          }
        },
        {
          content: {
            label: this.text('common.TERMS', '协议'),
            icon: this.titleBarSymbol($r('sys.symbol.doc_plaintext_and_checkmark')),
            action: (): void => {
              this.openWhat2RegAgreement();
            }
          }
        }
      ],
      maxCount: 1
    };
  }

  private serviceTitleBarMenu(): HdsNavigationMenuContentOptions {
    return {
      value: [
        {
          content: {
            label: this.text('common.SETTINGS', '设置'),
            icon: this.titleBarSymbol($r('sys.symbol.gearshape')),
            action: (): void => {
              this.pathStack.pushPathByName(ROUTE_SETTING, null);
            }
          }
        },
        {
          content: {
            label: this.text('setting.FEEDBACK', '反馈'),
            icon: this.titleBarSymbol($r('sys.symbol.message')),
            action: (): void => {
              this.serviceFeedbackSheetVisible = true;
            }
          }
        }
      ],
      maxCount: 1
    };
  }

  private currentTitleBarMenu(): HdsNavigationMenuContentOptions {
    if (this.currentIndex === ROOT_TAB_TIMETABLE) {
      return this.timetableTitleBarMenu();
    }
    if (this.currentIndex === ROOT_TAB_INFO) {
      return this.infoTitleBarMenu();
    }
    if (this.currentIndex === ROOT_TAB_WHAT2REG) {
      return this.what2RegTitleBarMenu();
    }
    if (this.currentIndex === ROOT_TAB_SERVICE) {
      return this.serviceTitleBarMenu();
    }
    return this.emptyTitleBarMenu();
  }

  private currentTitle(): string {
    switch (this.currentIndex) {
      case 0:
        return this.text('common.INFO', '资讯');
      case 1:
        return this.text('common.CATALOG', '揾课');
      case 2:
        return this.text('common.NEW_TOPIC', '新想法');
      case 3:
        return this.text('common.TIMETABLE', '课表');
      case 4:
        return this.text('common.SERVICE', '服务');
      default:
        return '';
    }
  }

  private currentTitleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      content: {
        title: {
          mainTitle: this.currentTitle()
        },
        menu: this.currentTitleBarMenu()
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: this.customMaterialLevel
        }
      },
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false
    };
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      HdsNavigation() {
        HdsTabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
          TabContent() {
            InfoTopTabs({
              topPadding: ROOT_CONTENT_TOP_PADDING,
              bottomPadding: ROOT_CONTENT_BOTTOM_PADDING
            })
          }
          .tabBar(this.BottomTabBar(this.text('common.INFO', '资讯'), this.tabSymbol(0)))

          TabContent() {
            What2RegPage()
          }
          .tabBar(this.BottomTabBar(this.text('common.CATALOG', '揾课'), this.tabSymbol(1)))

          TabContent() {
            PlaceholderPage({
              title: this.text('common.NEW_TOPIC', '新想法'),
              description: '这是 Harbor 发帖动作入口，点击底部入口会打开外部 Harbor 发帖页并保留当前页面。',
              topPadding: ROOT_CONTENT_TOP_PADDING,
              bottomPadding: ROOT_CONTENT_BOTTOM_PADDING
            })
          }
          .tabBar(this.BottomTabBar(this.text('common.NEW_TOPIC', '新想法'), this.tabSymbol(2)))

          TabContent() {
            CourseSimPage()
          }
          .tabBar(this.BottomTabBar(this.text('common.TIMETABLE', '课表'), this.tabSymbol(3)))

          TabContent() {
            ServicePage()
          }
          .tabBar(this.BottomTabBar(this.text('common.SERVICE', '服务'), this.tabSymbol(4)))
        }
        .layoutWeight(1)
        .width('100%')
        .vertical(false)
        .barMode(BarMode.Fixed)
        .barHeight(ROOT_TAB_BAR_HEIGHT)
        .scrollable(false)
        .barOverlap(true)
        .barFloatingStyle({
          adaptToHandedness: true,
          barBottomMargin: ROOT_TAB_BAR_BOTTOM_MARGIN,
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: this.customMaterialLevel
          }
        })
        .animationDuration(220)
        .barBackgroundColor('#00000000')
        .onChange((index: number) => {
          if (index === ROOT_TAB_NEW_TOPIC) {
            const returnIndex: number = this.currentIndex === ROOT_TAB_NEW_TOPIC ? this.lastContentIndex : this.currentIndex;
            this.openHarborNewTopic();
            this.currentIndex = returnIndex;
            return;
          }
          this.currentIndex = index;
          this.lastContentIndex = index;
        })
      }
      .layoutWeight(1)
      .width('100%')
      .height('100%')
      .mode(NavigationMode.Stack)
      .titleBar(this.currentTitleBarOptions())
      .systemBarStyle({ statusBarContentColor: this.theme().textPrimary }, {
        statusBarContentColor: this.theme().textPrimary
      })
      .hideBackButton(true)
      .titleMode(HdsNavigationTitleMode.MINI)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      this.StartupLoadingDialog()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bgColor)
  }
}
