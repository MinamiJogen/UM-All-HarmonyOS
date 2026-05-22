import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../common/theme/AppTheme';
import { Haptics } from '../common/utils/Haptics';

export interface AppSegmentOption {
  key: string;
  label: string;
}

@Component
export struct AppSegmentedControl {
  @Consume('appThemeMode') appThemeMode: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  options: AppSegmentOption[] = [];
  @Prop selectedIndex: number = 0;
  disabled: boolean = false;
  wrap: boolean = false;
  onChange: (index: number) => void = (_index: number): void => {};

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private select(index: number): void {
    if (this.disabled || index === this.selectedIndex) {
      return;
    }
    Haptics.trigger();
    this.onChange(index);
  }

  @Builder
  private SegmentButton(option: AppSegmentOption, index: number, weighted: boolean): void {
    Button(option.label)
      .height(32)
      .layoutWeight(weighted ? 1 : 0)
      .padding({ left: 12, right: 12 })
      .borderRadius(8)
      .fontSize(13)
      .fontWeight(this.selectedIndex === index ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.selectedIndex === index ? Color.White : this.theme().textSecondary)
      .backgroundColor(this.selectedIndex === index ? this.theme().themeColor : Color.Transparent)
      .stateEffect(true)
      .enabled(!this.disabled)
      .margin(weighted ? {} : { right: 6, bottom: 6 })
      .onClick(() => {
        this.select(index);
      })
  }

  build() {
    if (this.wrap) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.options, (option: AppSegmentOption, index: number) => {
          this.SegmentButton(option, index, false);
        }, (option: AppSegmentOption) => option.key)
      }
      .width('100%')
      .padding({ left: 4, right: 4, top: 4 })
      .borderRadius(8)
      .backgroundColor(this.theme().surfaceAltColor)
      .opacity(this.disabled ? 0.56 : 1)
    } else {
      Row({ space: 4 }) {
        ForEach(this.options, (option: AppSegmentOption, index: number) => {
          this.SegmentButton(option, index, true);
        }, (option: AppSegmentOption) => option.key)
      }
      .width('100%')
      .padding(4)
      .borderRadius(8)
      .backgroundColor(this.theme().surfaceAltColor)
      .opacity(this.disabled ? 0.56 : 1)
    }
  }
}
