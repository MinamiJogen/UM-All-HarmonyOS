import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../common/theme/AppTheme';
import { Haptics } from '../common/utils/Haptics';

@Component
export struct AppListItem {
  @Consume('appThemeMode') appThemeMode: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  title: string = '';
  subtitle: string = '';
  value: string = '';
  valueColor: string = '';
  clickable: boolean = false;
  showChevron: boolean = false;
  showDivider: boolean = true;
  disabled: boolean = false;
  danger: boolean = false;
  onTap: () => void = (): void => {};
  @BuilderParam trailingContent: () => void = this.EmptySlot;

  @Builder
  private EmptySlot(): void {
  }

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private resolvedTitleColor(): string {
    if (this.danger) {
      return this.theme().dangerColor;
    }
    return this.disabled ? this.theme().textTertiary : this.theme().textPrimary;
  }

  private resolvedValueColor(): string {
    if (this.valueColor.length > 0) {
      return this.valueColor;
    }
    return this.disabled ? this.theme().textTertiary : this.theme().textSecondary;
  }

  private handleClick(): void {
    if (!this.clickable || this.disabled) {
      return;
    }
    Haptics.trigger();
    this.onTap();
  }

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.resolvedTitleColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(12)
            .fontColor(this.theme().textTertiary)
            .lineHeight(17)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.value.length > 0) {
        Text(this.value)
          .fontSize(13)
          .fontColor(this.resolvedValueColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 12 })
          .constraintSize({ maxWidth: '42%' })
      }

      this.trailingContent();

      if (this.showChevron) {
        Text('>')
          .fontSize(18)
          .fontColor(this.theme().textTertiary)
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .height(this.subtitle.length > 0 ? 66 : 48)
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .border({ width: { bottom: this.showDivider ? 1 : 0 }, color: this.theme().borderColor })
    .opacity(this.disabled ? 0.56 : 1)
    .onClick(() => {
      this.handleClick();
    })
  }
}
