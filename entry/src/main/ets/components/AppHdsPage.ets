import { SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsNavigation,
  HdsNavigationMenuContentOptions,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../common/theme/AppTheme';
import { Haptics } from '../common/utils/Haptics';

@Component
export struct AppHdsPage {
  @Consume('appThemeMode') appThemeMode: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  title: string = '';
  backLabel: string = '返回';
  onBack: () => void = (): void => {};
  primaryActionLabel: string = '';
  primaryActionSymbol?: Resource;
  primaryActionEnabled: boolean = true;
  onPrimaryAction: () => void = (): void => {};
  @BuilderParam content: () => void = this.EmptySlot;
  @State private materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;

  aboutToAppear(): void {
    const materialTypes = hdsMaterial.getSystemMaterialTypes();
    if (materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) < 0) {
      this.materialLevel = hdsMaterial.MaterialLevel.SMOOTH;
    }
  }

  @Builder
  private EmptySlot(): void {
  }

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private handleBack(): void {
    Haptics.trigger();
    this.onBack();
  }

  private emptyMenu(): HdsNavigationMenuContentOptions {
    return {
      value: [],
      maxCount: 0
    };
  }

  private titleBarSymbol(symbol: Resource): SymbolGlyphModifier {
    return new SymbolGlyphModifier(symbol)
      .fontColor([this.theme().themeColor]);
  }

  private primaryMenu(): HdsNavigationMenuContentOptions {
    if (this.primaryActionLabel.length === 0 || this.primaryActionSymbol === undefined) {
      return this.emptyMenu();
    }
    return {
      value: [
        {
          content: {
            label: this.primaryActionLabel,
            icon: this.titleBarSymbol(this.primaryActionSymbol),
            isEnabled: this.primaryActionEnabled,
            action: (): void => {
              Haptics.trigger();
              this.onPrimaryAction();
            }
          }
        }
      ],
      maxCount: 1
    };
  }

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      content: {
        title: {
          mainTitle: this.title
        },
        backIcon: {
          label: this.backLabel,
          isEnabled: true,
          action: (): void => {
            this.handleBack();
          }
        },
        menu: this.primaryMenu()
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: this.materialLevel
        }
      },
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false
    };
  }

  build() {
    HdsNavigation() {
      Column() {
        this.content();
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .mode(NavigationMode.Stack)
    .titleBar(this.titleBarOptions())
    .systemBarStyle({ statusBarContentColor: this.theme().textPrimary }, {
      statusBarContentColor: this.theme().textPrimary
    })
    .hideBackButton(false)
    .titleMode(HdsNavigationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor(this.theme().bgColor)
  }
}
