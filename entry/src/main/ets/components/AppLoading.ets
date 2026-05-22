import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../common/theme/AppTheme';

@Component
export struct AppLoading {
  @Consume('appThemeMode') appThemeMode: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  title: string = 'Loading';
  message: string = '';
  compact: boolean = false;

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  build() {
    Column() {
      LoadingProgress()
        .width(this.compact ? 24 : 36)
        .height(this.compact ? 24 : 36)
        .color(this.theme().themeColor)
      Text(this.title)
        .fontSize(this.compact ? 13 : 17)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().themeColor)
        .textAlign(TextAlign.Center)
        .margin({ top: this.compact ? 8 : 12 })
      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(12)
          .fontColor(this.theme().textTertiary)
          .lineHeight(18)
          .textAlign(TextAlign.Center)
          .margin({ top: 5 })
      }
    }
    .width('100%')
    .padding(this.compact ? 12 : 20)
    .borderRadius(8)
    .backgroundColor(this.theme().surfaceColor)
    .border({ width: this.compact ? 0 : 1, color: this.theme().themeColor })
  }
}
