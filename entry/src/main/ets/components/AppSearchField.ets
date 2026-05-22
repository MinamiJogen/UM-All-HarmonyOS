import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../common/theme/AppTheme';

@Component
export struct AppSearchField {
  @Consume('appThemeMode') appThemeMode: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  placeholder: string = '';
  @Prop value: string = '';
  accentColor: string = '';
  isEnabled: boolean = true;
  onChange: (value: string) => void = (_value: string): void => {};
  onSubmit: (value: string) => void = (_value: string): void => {};

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private resolvedAccentColor(): string {
    return this.accentColor.length > 0 ? this.accentColor : this.theme().themeColor;
  }

  build() {
    TextInput({
      placeholder: this.placeholder,
      text: this.value
    })
      .height(40)
      .fontSize(14)
      .fontColor(this.theme().textPrimary)
      .placeholderColor(this.theme().textTertiary)
      .backgroundColor(this.theme().surfaceColor)
      .borderRadius(8)
      .border({ width: 1, color: this.resolvedAccentColor() })
      .padding({ left: 12, right: 12 })
      .enterKeyType(EnterKeyType.Search)
      .enabled(this.isEnabled)
      .onChange((value: string) => {
        this.onChange(value);
      })
      .onSubmit((_enterKey: EnterKeyType) => {
        this.onSubmit(this.value);
      })
  }
}
