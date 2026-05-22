import { HdsTabs } from '@kit.UIDesignKit';
import { I18nService } from '../../common/i18n/I18nService';
import { InfoRefreshRegistry } from '../../common/navigation/InfoRefreshRegistry';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../../common/theme/AppTheme';
import { HomePage } from '../info/home/HomePage';
import { ClubPage } from '../info/ClubPage';
import { NewsPage } from '../info/NewsPage';
import { UMEventPage } from '../info/UMEventPage';

@Component
export struct InfoTopTabs {
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State currentIndex: number = 0;
  topPadding: number = 0;
  bottomPadding: number = 0;

  aboutToAppear(): void {
    InfoRefreshRegistry.setCurrentTabIndex(this.currentIndex);
  }

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private text(key: string, fallback: string): string {
    return I18nService.t(this.language, key, fallback);
  }

  private topTabTitle(index: number): string {
    switch (index) {
      case 0:
        return this.text('common.TOPTAB_MAIN', '首页');
      case 1:
        return this.text('common.TOPTAB_CLUB', '组织');
      case 2:
        return this.text('common.TOPTAB_EVENT', '活动');
      case 3:
        return this.text('common.TOPTAB_NEWS', '新闻');
      default:
        return '';
    }
  }

  private topTabSymbol(index: number): Resource {
    switch (index) {
      case 0:
        return $r('sys.symbol.star_fill');
      case 1:
        return $r('sys.symbol.classify');
      case 2:
        return $r('sys.symbol.calendar');
      case 3:
        return $r('sys.symbol.doc_plaintext');
      default:
        return $r('sys.symbol.circle');
    }
  }

  @Builder
  TopSegmentItem(index: number): void {
    Row({ space: 4 }) {
      SymbolGlyph(this.topTabSymbol(index))
        .fontSize(13)
        .fontColor([index === this.currentIndex ? this.theme().surfaceColor : this.theme().textTertiary])
      Text(this.topTabTitle(index))
        .fontSize(12)
        .fontWeight(index === this.currentIndex ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(index === this.currentIndex ? this.theme().surfaceColor : this.theme().textPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(28)
    .padding({ left: 6, right: 6 })
    .borderRadius(14)
    .backgroundColor(index === this.currentIndex ? this.theme().textPrimary : this.theme().surfaceColor)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.currentIndex = index;
      InfoRefreshRegistry.setCurrentTabIndex(index);
    })
  }

  @Builder
  TopSegmentBar(): void {
    Column() {
      Blank()
        .height(this.topPadding)
      Row({ space: 6 }) {
        this.TopSegmentItem(0)
        this.TopSegmentItem(1)
        this.TopSegmentItem(2)
        this.TopSegmentItem(3)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 4, bottom: 8 })
    }
    .width('100%')
  }

  build() {
    Column() {
      HdsTabs({ barPosition: BarPosition.Start, index: this.currentIndex }) {
        TabContent() {
          HomePage({
            topContent: (): void => {
              this.TopSegmentBar();
            }
          })
        }
        .height('100%')

        TabContent() {
          ClubPage({
            topContent: (): void => {
              this.TopSegmentBar();
            }
          })
        }
        .height('100%')

        TabContent() {
          UMEventPage({
            topContent: (): void => {
              this.TopSegmentBar();
            }
          })
        }
        .height('100%')

        TabContent() {
          NewsPage({
            topContent: (): void => {
              this.TopSegmentBar();
            }
          })
        }
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .layoutWeight(1)
      .barHeight(0)
      .barBackgroundColor('#00000000')
      .animationDuration(220)
      .onChange((index: number) => {
        this.currentIndex = index;
        InfoRefreshRegistry.setCurrentTabIndex(index);
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bgColor)
  }
}
