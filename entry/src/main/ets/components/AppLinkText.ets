import { common } from '@kit.AbilityKit';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../common/theme/AppTheme';
import { Haptics } from '../common/utils/Haptics';
import { OpenLink } from '../common/utils/OpenLink';
import { AppToast } from './AppToast';

@Component
export struct AppLinkText {
  @Consume('appThemeMode') appThemeMode: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  label: string = '';
  url: string = '';
  disabled: boolean = false;
  errorMessage: string = '无法打开链接';

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private open(): void {
    if (this.disabled || this.url.length === 0) {
      return;
    }
    Haptics.trigger();
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    OpenLink.open(context, this.url).then((success: boolean) => {
      if (!success) {
        AppToast.showError(this.getUIContext(), this.errorMessage);
      }
    });
  }

  build() {
    Text(this.label.length > 0 ? this.label : this.url)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.disabled ? this.theme().textTertiary : this.theme().themeColor)
      .maxLines(2)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .opacity(this.disabled ? 0.56 : 1)
      .onClick(() => {
        this.open();
      })
  }
}
