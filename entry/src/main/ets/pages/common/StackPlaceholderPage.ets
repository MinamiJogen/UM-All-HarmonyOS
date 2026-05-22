import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../../common/theme/AppTheme';
import { AppEmptyState } from '../../components/AppEmptyState';
import { AppHdsPage } from '../../components/AppHdsPage';

@Component
export struct StackPlaceholderPage {
  title: string = '';
  description: string = '';
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  @Builder
  PageContent(): void {
    Column() {
      AppEmptyState({
        title: this.title,
        description: this.description
      })
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    AppHdsPage({
      title: this.title,
      onBack: (): void => {
        this.pathStack.pop();
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
