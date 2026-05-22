import { common } from '@kit.AbilityKit';
import {
  ARK_HARBOR_FEEDBACK,
  ARK_SUPPORT_MAIL
} from '../../common/constants/ApiEndpoints';
import {
  ROUTE_COURSE_SIM
} from '../../common/constants/RouteNames';
import {
  ROOT_CONTENT_BOTTOM_PADDING,
  ROOT_CONTENT_TOP_PADDING
} from '../../common/constants/LayoutMetrics';
import {
  SERVICE_DYNAMIC_LINK_UMEH,
  SERVICE_FEATURE_SECTIONS,
  ServiceFeatureItem,
  ServiceFeatureSection
} from '../../common/constants/ServiceFeatureCatalog';
import { ROOT_TAB_TIMETABLE } from '../../common/constants/TabIndexes';
import { I18nService, LANGUAGE_EN } from '../../common/i18n/I18nService';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  ThemeStore
} from '../../common/theme/AppTheme';
import { OpenLink } from '../../common/utils/OpenLink';
import { AppBottomSheet } from '../../components/AppBottomSheet';
import { AppCard } from '../../components/AppCard';
import { AppListItem } from '../../components/AppListItem';
import { AppToast } from '../../components/AppToast';
import { AnalyticsParams, AnalyticsService } from '../../services/AnalyticsService';
import { UmehHostService, UmehHostState } from '../../services/UmehHostService';

@Component
export struct ServicePage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') appThemeMode: number;
  @Consume('appLanguage') language: string;
  @Consume('appCurrentTabIndex') currentTabIndex: number;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @StorageLink('serviceFeedbackSheetVisible') showFeedbackSheet: boolean = false;
  @State busyKey: string = '';
  @State currentUmehHost: string = UmehHostService.getCurrentHost();

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.appThemeMode, this.systemColorMode);
  }

  private isEnglish(): boolean {
    return I18nService.normalizeLanguage(this.language) === LANGUAGE_EN;
  }

  private localized(tcText: string, enText: string): string {
    return this.isEnglish() ? enText : tcText;
  }

  private getContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private itemTitle(item: ServiceFeatureItem): string {
    return this.localized(item.titleTc, item.titleEn);
  }

  private logFeatureUse(item: ServiceFeatureItem): void {
    const params: AnalyticsParams = new AnalyticsParams();
    params.value = item.key;
    AnalyticsService.log('funcUse', params);
  }

  private featureSymbol(item: ServiceFeatureItem): Resource {
    switch (item.key) {
      case 'bus':
        return $r('sys.symbol.bus_fill');
      case 'calendar':
      case 'important_date':
        return $r('sys.symbol.calendar');
      case 'map':
        return $r('sys.symbol.map');
      case 'classroom':
        return $r('sys.symbol.school');
      case 'car_park':
        return $r('sys.symbol.car_parking_spot');
      case 'computer_room':
        return $r('sys.symbol.computer');
      case 'library':
        return $r('sys.symbol.bookshelf');
      case 'umpass':
        return $r('sys.symbol.passport');
      case 'bulletin':
        return $r('sys.symbol.bell');
      case 'print_balance':
      case 'print':
        return $r('sys.symbol.printer');
      case 'lost_found':
      case 'find_books':
        return $r('sys.symbol.magnifyingglass');
      case 'job':
        return $r('sys.symbol.briefcase');
      case 'rc_menu':
        return $r('sys.symbol.rice_badge_clock');
      case 'canteen_queue':
        return $r('sys.symbol.list_bullet');
      case 'student_union':
      case 'alumni':
        return $r('sys.symbol.person_3');
      case 'portal':
        return $r('sys.symbol.plus_circle');
      case 'cmms':
      case 'comments':
        return $r('sys.symbol.service');
      case 'sport':
        return $r('sys.symbol.dumbbell');
      case 'rbs':
      case 'um_org':
        return $r('sys.symbol.building');
      case 'lib_book':
      case 'survival':
        return $r('sys.symbol.book_pages');
      case 'locker':
        return $r('sys.symbol.lock');
      case 'park_apply':
        return $r('sys.symbol.doc_text_badge_park');
      case 'documents':
      case 'infographic':
        return $r('sys.symbol.doc_plaintext');
      case 'moodle':
      case 'wiki':
        return $r('sys.symbol.character_book');
      case 'course_sim':
        return $r('sys.symbol.calendar_badge_clock');
      case 'what2reg':
      case 'harbor':
        return $r('sys.symbol.ellipsis_message');
      case 'isw':
      case 'isw_new':
        return $r('sys.symbol.phone_doc');
      case 'pre_enrolment':
        return $r('sys.symbol.calendar_and_pencil');
      case 'pre_enrolment_excel':
        return $r('sys.symbol.doc_text');
      case 'add_drop':
        return $r('sys.symbol.plus_square');
      case 'whole_person':
        return $r('sys.symbol.person_badge_star');
      case 'exchange':
        return $r('sys.symbol.arrow_clockwise');
      case 'scholarship':
        return $r('sys.symbol.star');
      case 'paper_plan':
        return $r('sys.symbol.paperplan_right_2');
      case 'mainland':
      case 'rc':
        return $r('sys.symbol.house');
      case 'registration':
        return $r('sys.symbol.doc_plaintext_and_checkmark');
      case 'scam':
        return $r('sys.symbol.lock_shield');
      default:
        return $r('sys.symbol.service_card');
    }
  }

  private async openExternal(url: string): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), url);
    if (!success) {
      AppToast.showError(this.getUIContext(), this.localized('無法打開鏈接', 'Unable to open link'));
    }
  }

  private async openWhat2Reg(item: ServiceFeatureItem): Promise<void> {
    this.busyKey = item.key;
    try {
      const state: UmehHostState = await UmehHostService.refreshHost(this.getContext());
      this.currentUmehHost = state.currentHost;
      await this.openExternal(state.currentHost);
    } catch (error) {
      AppToast.showError(this.getUIContext(), this.localized('選咩課站點暫時不可用', 'What2Reg host is unavailable'));
    }
    this.busyKey = '';
  }

  private handleFeatureTap(item: ServiceFeatureItem): void {
    this.logFeatureUse(item);
    const routeName: string = item.routeName ?? '';
    if (routeName.length > 0) {
      if (routeName === ROUTE_COURSE_SIM) {
        this.currentTabIndex = ROOT_TAB_TIMETABLE;
        return;
      }
      this.pathStack.pushPathByName(routeName, null);
      return;
    }

    const dynamicLink: string = item.dynamicLink ?? '';
    if (dynamicLink === SERVICE_DYNAMIC_LINK_UMEH) {
      this.openWhat2Reg(item);
      return;
    }

    const url: string = item.url ?? '';
    if (url.length > 0) {
      this.openExternal(url);
      return;
    }

    AppToast.showError(this.getUIContext(), this.localized('入口尚未配置', 'Entry is not configured'));
  }

  private async refreshWhat2RegHost(): Promise<void> {
    const state: UmehHostState = await UmehHostService.refreshHost(this.getContext());
    this.currentUmehHost = state.currentHost;
  }

  @Builder
  FeatureIcon(item: ServiceFeatureItem) {
    Stack() {
      if (this.busyKey === item.key) {
        LoadingProgress()
          .width(22)
          .height(22)
          .color(this.theme().themeColor)
      } else {
        SymbolGlyph(this.featureSymbol(item))
          .fontSize(28)
          .fontColor([this.theme().themeColor])
      }
    }
    .width(48)
    .height(48)
    .borderRadius(14)
    .backgroundColor(this.theme().themeColorUltraLight)
  }

  @Builder
  FeatureTile(item: ServiceFeatureItem) {
    Column() {
      this.FeatureIcon(item)

      Text(this.itemTitle(item))
        .fontSize(this.isEnglish() ? 10 : 11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme().textSecondary)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .lineHeight(15)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .height(32)
        .margin({ top: 8 })
    }
    .width('20%')
    .height(90)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 4, right: 4 })
    .onClick(() => {
      this.handleFeatureTap(item);
    })
  }

  @Builder
  ServiceSection(section: ServiceFeatureSection) {
    AppCard({
      cardPadding: 0,
      content: (): void => {
        this.ServiceSectionCardContent(section);
      }
    })
      .margin({ top: 12 })
  }

  @Builder
  ServiceSectionCardContent(section: ServiceFeatureSection) {
    Column() {
      Row() {
        Text(this.localized(section.titleTc, section.titleEn))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme().textPrimary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(48)
      .padding({ left: 14, right: 14 })
      .border({ width: { bottom: 1 }, color: this.theme().bgColor })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(section.items, (item: ServiceFeatureItem) => {
          this.FeatureTile(item);
        }, (item: ServiceFeatureItem) => item.key)
      }
      .width('100%')
      .padding({ left: 4, right: 4, top: 12, bottom: 10 })
    }
    .width('100%')
  }

  @Builder
  FeedbackSheetContent() {
    AppCard({
      cardPadding: 0,
      content: (): void => {
        this.FeedbackCardContent();
      }
    })
  }

  @Builder
  FeedbackCardContent() {
    Column() {
      AppListItem({
        title: 'Harbor',
        subtitle: ARK_HARBOR_FEEDBACK,
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.showFeedbackSheet = false;
          this.openExternal(ARK_HARBOR_FEEDBACK);
        }
      })
      AppListItem({
        title: 'Email',
        subtitle: ARK_SUPPORT_MAIL,
        clickable: true,
        showChevron: true,
        showDivider: false,
        onTap: (): void => {
          this.showFeedbackSheet = false;
          this.openExternal('mailto:' + ARK_SUPPORT_MAIL);
        }
      })
    }
    .width('100%')
  }

  build() {
    Stack() {
      Column() {
        Scroll() {
          Column() {
            Blank()
              .height(ROOT_CONTENT_TOP_PADDING)
            ForEach(SERVICE_FEATURE_SECTIONS, (section: ServiceFeatureSection) => {
              this.ServiceSection(section);
            }, (section: ServiceFeatureSection) => section.key)
            Blank()
              .height(ROOT_CONTENT_BOTTOM_PADDING)
          }
          .width('100%')
          .padding({ left: 10, right: 10 })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme().bgColor)

      AppBottomSheet({
        visible: $showFeedbackSheet,
        title: this.localized('反饋', 'Feedback'),
        closeText: this.localized('返回', 'Back'),
        content: (): void => {
          this.FeedbackSheetContent();
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bgColor)
    .onAppear(() => {
      this.refreshWhat2RegHost();
    })
  }
}
