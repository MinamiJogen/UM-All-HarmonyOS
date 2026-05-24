import { common } from '@kit.AbilityKit';
import { AppBootstrap } from '../../app/AppBootstrap';
import { AppStartupState } from '../../app/AppState';
import {
  ARK_FAQ,
  ARK_GITHUB_ACTIVITY,
  ARK_GITHUB_DONATE,
  ARK_GITHUB_PAGE,
  ARK_GITHUB_UPDATE_PLAN,
  ARK_SITE_BASE,
  ARK_SUPPORT_MAIL,
  ARK_USER_AGREEMENT,
  ARK_WIKI_ABOUT_ARK
} from '../../common/constants/ApiEndpoints';
import { ROOT_CONTENT_TOP_PADDING } from '../../common/constants/LayoutMetrics';
import { CACHE_RESET_STORAGE_KEYS } from '../../common/constants/StorageKeys';
import { I18nService, LANGUAGE_EN, LANGUAGE_JA, LANGUAGE_PT, LANGUAGE_SC, LANGUAGE_TC } from '../../common/i18n/I18nService';
import { AppOpenLinkOptions, OpenLink } from '../../common/utils/OpenLink';
import {
  AppThemeColors,
  ARKUI_COLOR_MODE_LIGHT,
  THEME_MODE_DARK,
  THEME_MODE_LIGHT,
  THEME_MODE_SYSTEM,
  ThemeStore
} from '../../common/theme/AppTheme';
import { PreferencesStore } from '../../common/storage/PreferencesStore';
import { AppBottomSheet } from '../../components/AppBottomSheet';
import { AppCard } from '../../components/AppCard';
import { AppDialog } from '../../components/AppDialog';
import { AppHdsPage } from '../../components/AppHdsPage';
import { AppListItem } from '../../components/AppListItem';
import { AppLoading } from '../../components/AppLoading';
import { AppSegmentOption, AppSegmentedControl } from '../../components/AppSegmentedControl';
import { AppToast, AppToastType } from '../../components/AppToast';
import { AppInfoUpdateState, AppInfoService } from '../../services/AppInfoService';
import {
  UMEH_HOST_PREF_AUTO,
  UMEH_HOST_PREF_BACKUP,
  UMEH_HOST_PREF_PRIMARY,
  UmehHostService,
  UmehHostState
} from '../../services/UmehHostService';

@Component
export struct SettingPage {
  @Consume('appPathStack') pathStack: NavPathStack;
  @Consume('appThemeMode') themeMode: number;
  @Consume('appLanguage') language: string;
  @Consume('appStartupState') startupState: AppStartupState;
  @StorageProp('colorMode') systemColorMode: number = ARKUI_COLOR_MODE_LIGHT;
  @State busy: boolean = false;
  @State localMessage: string = '';
  @State showStartupSheet: boolean = false;
  @State showHostSheet: boolean = false;
  @State umehHostPref: string = UMEH_HOST_PREF_AUTO;
  @State currentUmehHost: string = UmehHostService.getCurrentHost();

  private theme(): AppThemeColors {
    return ThemeStore.resolveTheme(this.themeMode, this.systemColorMode);
  }

  private text(key: string, fallback: string): string {
    return I18nService.t(this.language, key, fallback);
  }

  private getContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private themeOptions(): AppSegmentOption[] {
    return [
      { key: 'system', label: this.text('setting.SYSTEM', 'System') },
      { key: 'light', label: this.text('setting.LIGHT', 'Light') },
      { key: 'dark', label: this.text('setting.DARK', 'Dark') }
    ];
  }

  private languageOptions(): AppSegmentOption[] {
    return [
      { key: LANGUAGE_SC, label: '简体中文' },
      { key: LANGUAGE_TC, label: '正體中文' },
      { key: LANGUAGE_EN, label: 'English' },
      { key: LANGUAGE_PT, label: 'Português' },
      { key: LANGUAGE_JA, label: '日本語' }
    ];
  }

  private hostOptions(): AppSegmentOption[] {
    return [
      { key: UMEH_HOST_PREF_AUTO, label: this.text('setting.AUTO', 'Auto') },
      { key: UMEH_HOST_PREF_PRIMARY, label: 'umeh' },
      { key: UMEH_HOST_PREF_BACKUP, label: 'cf' }
    ];
  }

  private languageIndex(): number {
    switch (I18nService.normalizeLanguage(this.language)) {
      case LANGUAGE_SC:
        return 0;
      case LANGUAGE_TC:
        return 1;
      case LANGUAGE_EN:
        return 2;
      case LANGUAGE_PT:
        return 3;
      case LANGUAGE_JA:
        return 4;
      default:
        return 0;
    }
  }

  private languageAt(index: number): string {
    if (index === 0) {
      return LANGUAGE_SC;
    }
    if (index === 1) {
      return LANGUAGE_TC;
    }
    if (index === 2) {
      return LANGUAGE_EN;
    }
    if (index === 3) {
      return LANGUAGE_PT;
    }
    return LANGUAGE_JA;
  }

  private languageLabel(language: string): string {
    switch (I18nService.normalizeLanguage(language)) {
      case LANGUAGE_SC:
        return '简体中文';
      case LANGUAGE_TC:
        return '正體中文';
      case LANGUAGE_PT:
        return 'Português';
      case LANGUAGE_JA:
        return '日本語';
      case LANGUAGE_EN:
      default:
        return 'English';
    }
  }

  private themeIndex(): number {
    if (this.themeMode === THEME_MODE_LIGHT) {
      return THEME_MODE_LIGHT;
    }
    if (this.themeMode === THEME_MODE_DARK) {
      return THEME_MODE_DARK;
    }
    return THEME_MODE_SYSTEM;
  }

  private hostIndex(): number {
    if (this.umehHostPref === UMEH_HOST_PREF_PRIMARY) {
      return 1;
    }
    if (this.umehHostPref === UMEH_HOST_PREF_BACKUP) {
      return 2;
    }
    return 0;
  }

  private hostPrefLabel(): string {
    if (this.umehHostPref === UMEH_HOST_PREF_PRIMARY) {
      return 'umeh';
    }
    if (this.umehHostPref === UMEH_HOST_PREF_BACKUP) {
      return 'cf';
    }
    return this.text('setting.AUTO', 'Auto');
  }

  private courseCacheValue(): string {
    if (!this.startupState.courseSummary) {
      return '-';
    }
    return String(this.startupState.courseSummary.coursePlanTimeCount) + ' ' +
    this.text('setting.TIMETABLE_ROWS', 'timetable rows');
  }

  private updateStatusTitle(): string {
    return this.startupState.appUpdateAvailable ?
    this.text('setting.UPDATE_AVAILABLE', 'Update available') :
    this.text('setting.UP_TO_DATE', 'Version is OK');
  }

  private updateStatusColor(): string {
    return this.startupState.appUpdateAvailable ? this.theme().warningColor : this.theme().textSecondary;
  }

  private startupStatusColor(): string {
    if (this.startupState.backgroundRunning) {
      return this.theme().themeColor;
    }
    return this.startupState.hasWarning ? this.theme().warningColor : this.theme().successColor;
  }

  private updateUrl(state: AppInfoUpdateState): string {
    const customUrl: string = state.appInfo?.update_url ?? '';
    return customUrl.length > 0 ? customUrl : ARK_SITE_BASE;
  }

  private applyHostState(state: UmehHostState): void {
    this.umehHostPref = state.preference;
    this.currentUmehHost = state.currentHost;
  }

  private updateStartupVersionState(state: AppInfoUpdateState): void {
    const nextStartupState: AppStartupState = {
      running: this.startupState.running,
      ready: this.startupState.ready,
      backgroundRunning: this.startupState.backgroundRunning,
      hasWarning: this.startupState.hasWarning,
      message: this.startupState.message,
      localVersion: state.localVersion,
      latestVersion: state.latestVersion,
      appUpdateAvailable: state.updateAvailable,
      courseSummary: this.startupState.courseSummary,
      courseUpdateSummary: this.startupState.courseUpdateSummary,
      appInfo: state.appInfo,
      tasks: this.startupState.tasks
    };
    this.startupState = nextStartupState;
  }

  private async loadSettingState(): Promise<void> {
    const hostState: UmehHostState = await UmehHostService.refreshHost(this.getContext());
    this.applyHostState(hostState);
  }

  private async setThemeMode(mode: number): Promise<void> {
    this.busy = true;
    await ThemeStore.setThemeMode(this.getContext(), mode);
    this.themeMode = mode;
    this.localMessage = this.text('setting.THEME', 'Theme') + ': ' + this.text(
      mode === THEME_MODE_LIGHT ? 'setting.LIGHT' : mode === THEME_MODE_DARK ? 'setting.DARK' : 'setting.SYSTEM',
      ThemeStore.getModeLabel(mode));
    this.busy = false;
  }

  private async setLanguage(language: string): Promise<void> {
    this.busy = true;
    await I18nService.setLanguage(this.getContext(), language);
    this.language = I18nService.normalizeLanguage(language);
    this.localMessage = this.text('setting.LANGUAGE', 'Language') + ': ' + this.languageLabel(this.language);
    this.busy = false;
  }

  private async rerunStartup(): Promise<void> {
    this.busy = true;
    this.localMessage = this.text('bootstrap.LOADING', 'Initializing');
    this.startupState = await AppBootstrap.initialize(this.getContext());
    this.localMessage = this.startupState.message;
    this.busy = false;
  }

  private async clearCache(): Promise<void> {
    const confirmed: boolean = await AppDialog.confirm(this.getUIContext(), {
      title: this.text('setting.CLEAR_CACHE', 'Clear cache'),
      message: this.text('setting.CLEAR_CACHE_MESSAGE',
        'Local business cache will be cleared and startup initialization will run again.'),
      confirmText: this.text('setting.CONFIRM', 'Confirm'),
      cancelText: this.text('setting.CANCEL', 'Cancel')
    });
    if (!confirmed) {
      return;
    }

    this.busy = true;
    this.localMessage = this.text('setting.CLEARING_CACHE', 'Clearing cache');
    try {
      await PreferencesStore.removeKeys(this.getContext(), CACHE_RESET_STORAGE_KEYS);
      this.applyHostState(await UmehHostService.refreshHost(this.getContext()));
      this.startupState = await AppBootstrap.initialize(this.getContext());
      this.localMessage = this.startupState.message;
      AppToast.show(this.getUIContext(), this.text('setting.CACHE_CLEARED', 'Cache cleared'),
        AppToastType.Success);
    } catch (error) {
      this.localMessage = this.text('setting.CLEAR_CACHE_FAILED', 'Clear cache failed') + ': ' + String(error);
      AppToast.showError(this.getUIContext(), this.localMessage);
    }
    this.busy = false;
  }

  private async checkUpdate(): Promise<void> {
    this.busy = true;
    this.localMessage = this.text('setting.CHECKING_UPDATE', 'Checking update');
    const result = await AppInfoService.checkUpdateState(this.getContext());
    this.busy = false;

    if (result.data) {
      this.updateStartupVersionState(result.data);
    }

    if (!result.ok || !result.data) {
      this.localMessage = this.text('setting.CHECK_UPDATE_ERROR', 'Unable to check update');
      await AppDialog.alert(this.getUIContext(), {
        title: this.text('setting.CHECK_UPDATE', 'Check update'),
        message: this.localMessage,
        confirmText: this.text('common.BACK', 'Back')
      });
      return;
    }

    if (!result.data.updateAvailable) {
      this.localMessage = this.text('setting.LATEST_VERSION', 'Already on the latest version');
      await AppDialog.alert(this.getUIContext(), {
        title: this.text('setting.CHECK_UPDATE', 'Check update'),
        message: this.localMessage,
        confirmText: this.text('common.BACK', 'Back')
      });
      return;
    }

    const versionInfo: string = result.data.appInfo?.version_info ??
    this.text('setting.UPDATE_MESSAGE', 'A new version is available.');
    const openUpdate: boolean = await AppDialog.confirm(this.getUIContext(), {
      title: 'ARK ' + result.data.latestVersion + ' ' + this.text('setting.CAN_UPDATE', 'is available'),
      message: versionInfo,
      confirmText: this.text('setting.UPDATE_NOW', 'Update'),
      cancelText: this.text('setting.CANCEL', 'Cancel')
    });
    if (openUpdate) {
      await this.openExternal(this.updateUrl(result.data));
    }
  }

  private async setHostPreference(preference: string): Promise<void> {
    this.busy = true;
    this.localMessage = this.text('setting.WHAT2REG_HOST', 'What2Reg Host') + ': ' + this.hostPrefLabel();
    try {
      const hostState: UmehHostState = await UmehHostService.setHostPreference(this.getContext(), preference);
      this.applyHostState(hostState);
      this.localMessage = this.text('setting.WHAT2REG_HOST', 'What2Reg Host') + ': ' + this.hostPrefLabel();
      AppToast.show(this.getUIContext(), this.localMessage, AppToastType.Success);
    } catch (error) {
      this.localMessage = this.text('setting.HOST_UPDATE_FAILED', 'Host preference update failed') + ': ' +
      String(error);
      AppToast.showError(this.getUIContext(), this.localMessage);
    }
    this.busy = false;
  }

  private async openExternal(url: string, options?: AppOpenLinkOptions): Promise<void> {
    const success: boolean = await OpenLink.open(this.getContext(), url, options);
    if (!success) {
      AppToast.showError(this.getUIContext(), this.text('setting.OPEN_LINK_FAILED', 'Unable to open link'));
    }
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.theme().textTertiary)
      .margin({ top: 18, bottom: 8 })
      .width('100%')
      .textAlign(TextAlign.Start)
  }

  @Builder
  AppearanceSection() {
    this.SectionTitle(this.text('setting.APPEARANCE', 'Appearance'))
    AppCard({
      content: (): void => {
        this.AppearanceCardContent();
      }
    })
  }

  @Builder
  AppearanceCardContent() {
    Column() {
      Text(this.text('setting.THEME', 'Theme'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme().textPrimary)
        .width('100%')
        .margin({ bottom: 10 })
      AppSegmentedControl({
        options: this.themeOptions(),
        selectedIndex: this.themeIndex(),
        disabled: this.busy,
        onChange: (index: number): void => {
          this.setThemeMode(index);
        }
      })
      Text(this.text('setting.LANGUAGE', 'Language'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme().textPrimary)
        .width('100%')
        .margin({ top: 16, bottom: 10 })
      AppSegmentedControl({
        options: this.languageOptions(),
        selectedIndex: this.languageIndex(),
        wrap: true,
        disabled: this.busy,
        onChange: (index: number): void => {
          this.setLanguage(this.languageAt(index));
        }
      })
    }
    .width('100%')
  }

  @Builder
  ApplicationSection() {
    this.SectionTitle(this.text('setting.APPLICATION', 'Application'))
    AppCard({
      cardPadding: 0,
      content: (): void => {
        this.ApplicationCardContent();
      }
    })

    Button(this.busy ? this.text('bootstrap.LOADING', 'Initializing') :
    this.text('setting.CHECK_AGAIN', 'Run startup again'))
      .height(40)
      .borderRadius(8)
      .fontSize(14)
      .fontColor(Color.White)
      .backgroundColor(this.theme().themeColor)
      .enabled(!this.busy)
      .margin({ top: 12 })
      .width('100%')
      .onClick(() => {
        this.rerunStartup();
      })
  }

  @Builder
  ApplicationCardContent() {
    Column() {
      AppListItem({
        title: this.text('setting.STARTUP_STATUS', 'Startup status'),
        value: this.startupState.message,
        valueColor: this.startupStatusColor(),
        clickable: true,
        showChevron: true,
        disabled: this.busy,
        onTap: (): void => {
          this.showStartupSheet = true;
        }
      })
      AppListItem({
        title: this.text('setting.COURSE_CACHE', 'Course cache'),
        value: this.courseCacheValue()
      })
      AppListItem({
        title: this.text('setting.CLEAR_CACHE', 'Clear cache'),
        value: this.text('setting.RESET', 'Reset'),
        valueColor: this.theme().dangerColor,
        clickable: true,
        showChevron: true,
        disabled: this.busy,
        danger: true,
        onTap: (): void => {
          this.clearCache();
        }
      })
      AppListItem({
        title: this.text('setting.CHECK_UPDATE', 'Check update'),
        subtitle: this.updateStatusTitle(),
        value: this.startupState.localVersion.length > 0 ? 'v' + this.startupState.localVersion : '-',
        valueColor: this.updateStatusColor(),
        clickable: true,
        showChevron: true,
        disabled: this.busy,
        onTap: (): void => {
          this.checkUpdate();
        }
      })
      AppListItem({
        title: this.text('setting.WHAT2REG_HOST', 'What2Reg Host'),
        subtitle: this.currentUmehHost,
        value: this.hostPrefLabel(),
        clickable: true,
        showChevron: true,
        disabled: this.busy,
        showDivider: false,
        onTap: (): void => {
          this.showHostSheet = true;
        }
      })
    }
    .width('100%')
  }

  @Builder
  AboutSection() {
    this.SectionTitle(this.text('setting.ABOUT', 'About'))
    AppCard({
      cardPadding: 0,
      content: (): void => {
        this.AboutCardContent();
      }
    })
  }

  @Builder
  AboutCardContent() {
    Column() {
      AppListItem({
        title: this.text('setting.VERSION', 'Version'),
        value: this.startupState.localVersion.length > 0 ? 'v' + this.startupState.localVersion : '-'
      })
      AppListItem({
        title: this.text('setting.OPEN_SOURCE', 'Open Source'),
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.openExternal(ARK_GITHUB_PAGE);
        }
      })
      AppListItem({
        title: this.text('setting.COMMON_ISSUES', 'Common Issues'),
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.openExternal(ARK_FAQ);
        }
      })
      AppListItem({
        title: this.text('setting.PRIVACY_POLICY', 'Privacy Policy'),
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.openExternal(ARK_USER_AGREEMENT);
        }
      })
      AppListItem({
        title: this.text('setting.DONATE', 'Donate'),
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.openExternal(ARK_GITHUB_DONATE);
        }
      })
      AppListItem({
        title: this.text('setting.FEEDBACK', 'Feedback'),
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.openExternal(ARK_GITHUB_UPDATE_PLAN);
        }
      })
      AppListItem({
        title: this.text('setting.ACTIVITY', 'Activity'),
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.openExternal(ARK_GITHUB_ACTIVITY);
        }
      })
      AppListItem({
        title: this.text('setting.ABOUT_ARK', 'About ARK ALL'),
        clickable: true,
        showChevron: true,
        showDivider: false,
        onTap: (): void => {
          this.openExternal(ARK_WIKI_ABOUT_ARK);
        }
      })
    }
    .width('100%')
  }

  @Builder
  ContactSection() {
    this.SectionTitle(this.text('setting.CONTACT', 'Contact'))
    AppCard({
      cardPadding: 0,
      content: (): void => {
        this.ContactCardContent();
      }
    })
  }

  @Builder
  ContactCardContent() {
    Column() {
      AppListItem({
        title: this.text('setting.OFFICIAL_WEBSITE', 'Official Website'),
        subtitle: ARK_SITE_BASE,
        clickable: true,
        showChevron: true,
        onTap: (): void => {
          this.openExternal(ARK_SITE_BASE);
        }
      })
      AppListItem({
        title: this.text('setting.EMAIL', 'Email'),
        subtitle: ARK_SUPPORT_MAIL,
        clickable: true,
        showChevron: true,
        showDivider: false,
        onTap: (): void => {
          this.openExternal('mailto:' + ARK_SUPPORT_MAIL);
        }
      })
    }
    .width('100%')
  }

  @Builder
  RuntimeMessage() {
    if (this.busy) {
      AppLoading({
        title: this.text('bootstrap.LOADING', 'Initializing'),
        message: this.localMessage,
        compact: true
      })
      .margin({ top: 14 })
    } else if (this.localMessage.length > 0) {
      Text(this.localMessage)
        .fontSize(13)
        .fontColor(this.theme().textTertiary)
        .lineHeight(19)
        .margin({ top: 14 })
        .width('100%')
        .textAlign(TextAlign.Center)
    }
  }

  @Builder
  StartupSheetContent() {
    AppCard({
      cardPadding: 0,
      content: (): void => {
        this.StartupSummaryCardContent();
      }
    })
  }

  @Builder
  StartupSummaryCardContent() {
    Column() {
      AppListItem({
        title: this.text('setting.STARTUP_STATUS', 'Startup status'),
        value: this.startupState.message,
        valueColor: this.startupStatusColor()
      })
      AppListItem({
        title: this.text('setting.APP_VERSION', 'App version'),
        value: this.startupState.localVersion.length > 0 ? 'v' + this.startupState.localVersion : '-'
      })
      AppListItem({
        title: this.text('setting.LATEST_VERSION', 'Latest version'),
        value: this.startupState.latestVersion.length > 0 ? 'v' + this.startupState.latestVersion : '-',
        valueColor: this.updateStatusColor()
      })
      AppListItem({
        title: this.text('setting.COURSE_CACHE', 'Course cache'),
        value: this.courseCacheValue(),
        showDivider: false
      })
    }
    .width('100%')
  }

  @Builder
  HostSheetContent() {
    AppCard({
      content: (): void => {
        this.HostPreferenceCardContent();
      }
    })
    AppCard({
      cardPadding: 0,
      content: (): void => {
        this.HostLinkCardContent();
      }
    })
    .margin({ top: 12 })
  }

  @Builder
  HostPreferenceCardContent() {
    Column() {
      Text(this.text('setting.WHAT2REG_HOST', 'What2Reg Host'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme().textPrimary)
        .width('100%')
        .margin({ bottom: 10 })
      AppSegmentedControl({
        options: this.hostOptions(),
        selectedIndex: this.hostIndex(),
        disabled: this.busy,
        onChange: (index: number): void => {
          if (index === 1) {
            this.setHostPreference(UMEH_HOST_PREF_PRIMARY);
          } else if (index === 2) {
            this.setHostPreference(UMEH_HOST_PREF_BACKUP);
          } else {
            this.setHostPreference(UMEH_HOST_PREF_AUTO);
          }
        }
      })
    }
    .width('100%')
  }

  @Builder
  HostLinkCardContent() {
    Column() {
      AppListItem({
        title: this.text('setting.CURRENT_HOST', 'Current host'),
        subtitle: this.currentUmehHost
      })
      AppListItem({
        title: this.text('setting.OPEN_CURRENT_HOST', 'Open current host'),
        clickable: true,
        showChevron: true,
        showDivider: false,
        onTap: (): void => {
          this.openExternal(this.currentUmehHost);
        }
      })
    }
    .width('100%')
  }

  @Builder
  PageContent(): void {
    Scroll() {
      Column() {
        Blank()
          .height(ROOT_CONTENT_TOP_PADDING)
        this.AppearanceSection()
        this.ApplicationSection()
        this.AboutSection()
        this.ContactSection()
        this.RuntimeMessage()
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .layoutWeight(1)
  }

  build() {
    Stack() {
      AppHdsPage({
        title: this.text('common.SETTINGS', 'Settings'),
        backLabel: this.text('common.BACK', 'Back'),
        onBack: (): void => {
          this.pathStack.pop();
        },
        content: (): void => {
          this.PageContent()
        }
      })
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme().bgColor)

      AppBottomSheet({
        visible: $showStartupSheet,
        title: this.text('setting.STARTUP_STATUS', 'Startup status'),
        closeText: this.text('common.BACK', 'Back'),
        content: (): void => {
          this.StartupSheetContent();
        }
      })

      AppBottomSheet({
        visible: $showHostSheet,
        title: this.text('setting.WHAT2REG_HOST', 'What2Reg Host'),
        closeText: this.text('common.BACK', 'Back'),
        content: (): void => {
          this.HostSheetContent();
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bgColor)
    .onAppear(() => {
      this.loadSettingState();
    })
  }
}
