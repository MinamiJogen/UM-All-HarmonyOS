import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../common/theme/AppTheme';
import { Haptics } from '../common/utils/Haptics';

@Component
export struct AppBottomSheet {
  @Consume('appThemeMode') appThemeMode: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @Link visible: boolean;
  title: string = '';
  closeText: string = 'Close';
  maxHeightPercent: number = 70;
  onClose: () => void = (): void => {};
  @BuilderParam content: () => void = this.EmptySlot;

  @Builder
  private EmptySlot(): void {
  }

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private close(): void {
    Haptics.trigger();
    this.visible = false;
    this.onClose();
  }

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.close();
        })

        Column() {
          Row() {
            Text(this.title)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().textPrimary)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Button(this.closeText)
              .height(34)
              .borderRadius(8)
              .fontSize(13)
              .fontColor(this.theme().themeColor)
              .backgroundColor(this.theme().surfaceAltColor)
              .onClick(() => {
                this.close();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 8 })

          Scroll() {
            Column() {
              this.content();
            }
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 22 })
          }
          .constraintSize({ maxHeight: String(this.maxHeightPercent) + '%' })
        }
        .width('100%')
        .backgroundColor(this.theme().bgColor)
        .borderRadius({ topLeft: 8, topRight: 8 })
        .clip(true)
      }
      .width('100%')
      .height('100%')
      .zIndex(100)
      .transition(TransitionEffect.OPACITY)
    }
  }
}
