import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../../common/theme/AppTheme';
import { AppEmptyState } from '../../components/AppEmptyState';

@Component
export struct PlaceholderPage {
  title: string = '';
  description: string = '';
  primaryActionText: string = '';
  primaryRouteName: string = '';
  topPadding: number = 0;
  bottomPadding: number = 0;
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  build() {
    Scroll() {
      Column() {
        Blank()
          .height(this.topPadding)
        AppEmptyState({
          title: this.title,
          description: this.description,
          actionText: this.primaryActionText,
          onAction: (): void => {
            if (this.primaryRouteName.length > 0) {
              this.pathStack.pushPathByName(this.primaryRouteName, null);
            }
          }
        })
        Blank()
          .height(this.bottomPadding)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(this.theme().bgColor)
  }
}
