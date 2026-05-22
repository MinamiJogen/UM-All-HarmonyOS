import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../common/theme/AppTheme';

@Component
export struct AppNetworkImage {
  @Consume('appThemeMode') appThemeMode: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  src: string = '';
  alt: string = '';
  imageHeight: number = 180;
  fitContain: boolean = false;
  radius: number = 8;
  @State loadedSrc: string = '';
  @State failedSrc: string = '';

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private showPlaceholder(): boolean {
    return this.src.length === 0 || this.loadedSrc !== this.src || this.failedSrc === this.src;
  }

  private shouldRenderImage(): boolean {
    return this.src.length > 0 && this.failedSrc !== this.src;
  }

  @Builder
  private Placeholder(): void {
    Column() {
      if (this.src.length > 0 && this.failedSrc !== this.src) {
        LoadingProgress()
          .width(24)
          .height(24)
          .color(this.theme().themeColor)
      } else {
        Text(this.alt.length > 0 ? this.alt : 'Image')
          .fontSize(13)
          .fontColor(this.theme().textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.theme().surfaceAltColor)
  }

  build() {
    Stack() {
      if (this.shouldRenderImage()) {
        Image(this.src)
          .width('100%')
          .height('100%')
          .objectFit(this.fitContain ? ImageFit.Contain : ImageFit.Cover)
          .opacity(this.loadedSrc === this.src ? 1 : 0)
          .onComplete(() => {
            this.loadedSrc = this.src;
            this.failedSrc = '';
          })
          .onError(() => {
            this.loadedSrc = '';
            this.failedSrc = this.src;
          })
      }
      if (this.showPlaceholder()) {
        this.Placeholder();
      }
    }
    .width('100%')
    .height(this.imageHeight)
    .borderRadius(this.radius)
    .clip(true)
    .backgroundColor(this.theme().surfaceAltColor)
  }
}
