import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../common/theme/AppTheme';
import { Haptics } from '../common/utils/Haptics';

@Component
export struct AppCard {
  @Consume('appThemeMode') appThemeMode: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  clickable: boolean = false;
  disabled: boolean = false;
  cardPadding: number = 14;
  surfaceColor: string = '';
  borderVisible: boolean = false;
  onTap: () => void = (): void => {};
  @BuilderParam content: () => void = this.EmptySlot;

  @Builder
  private EmptySlot(): void {
  }

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private resolvedBackground(): string {
    return this.surfaceColor.length > 0 ? this.surfaceColor : this.theme().surfaceColor;
  }

  private handleClick(): void {
    if (!this.clickable || this.disabled) {
      return;
    }
    Haptics.trigger();
    this.onTap();
  }

  build() {
    Column() {
      this.content();
    }
    .width('100%')
    .padding(this.cardPadding)
    .borderRadius(8)
    .backgroundColor(this.resolvedBackground())
    .border({ width: this.borderVisible ? 1 : 0, color: this.theme().borderColor })
    .opacity(this.disabled ? 0.56 : 1)
    .onClick(() => {
      this.handleClick();
    })
  }
}
