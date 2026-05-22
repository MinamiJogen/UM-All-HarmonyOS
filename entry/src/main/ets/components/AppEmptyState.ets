import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../common/theme/AppTheme';
import { Haptics } from '../common/utils/Haptics';

@Component
export struct AppEmptyState {
  @Consume('appThemeMode') appThemeMode: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  title: string = '';
  description: string = '';
  actionText: string = '';
  onAction: () => void = (): void => {};

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private handleAction(): void {
    if (this.actionText.length === 0) {
      return;
    }
    Haptics.trigger();
    this.onAction();
  }

  build() {
    Column() {
      Text(this.title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
        .textAlign(TextAlign.Center)
        .margin({ bottom: 10 })
        .width('100%')
      if (this.description.length > 0) {
        Text(this.description)
          .fontSize(14)
          .fontColor(this.theme().textTertiary)
          .textAlign(TextAlign.Center)
          .lineHeight(21)
          .width('86%')
      }
      if (this.actionText.length > 0) {
        Button(this.actionText)
          .height(40)
          .borderRadius(8)
          .padding({ left: 18, right: 18 })
          .backgroundColor(this.theme().themeColor)
          .fontColor(Color.White)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 18 })
          .onClick(() => {
            this.handleAction();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }
}
