export const RAWFILE_COURSE_VERSION: string = 'UMCourses/courseVersion.json';
export const RAWFILE_OFFER_COURSES: string = 'UMCourses/offerCourses.json';
export const RAWFILE_COURSE_PLAN: string = 'UMCourses/coursePlan.json';
export const RAWFILE_COURSE_PLAN_TIME: string = 'UMCourses/coursePlanTime.json';

export const RAWFILE_APP_LOGO: string = 'img/logo.png';
export const RAWFILE_APP_LOGO_ROUND: string = 'img/logo_round.png';
export const RAWFILE_APP_LAUNCHER_FOREGROUND: string = 'img/ic_launcher_foreground.png';
export const RAWFILE_TRANSPARENT_IMAGE: string = 'img/transparent.png';

export const RAWFILE_BUS_ICON: string = 'img/Bus/bus.png';
export const RAWFILE_BUS_ROUTE: string = 'img/Bus/bus_route.png';

export const RAWFILE_DONATE_BOC: string = 'img/donate/boc.jpg';
export const RAWFILE_DONATE_MPAY: string = 'img/donate/mpay.jpg';
export const RAWFILE_DONATE_ALIPAY: string = 'img/donate/alipay.jpg';
export const RAWFILE_DONATE_WECHAT: string = 'img/donate/wechat.jpg';

export const RAWFILE_APPSTORE_ICON: string = 'UMARK_Assets/AppIcons/appstore.png';
export const RAWFILE_PLAYSTORE_ICON: string = 'UMARK_Assets/AppIcons/playstore.png';

export const RAWFILE_UM_CALENDAR: string = 'UMCalendar/UMCalendar.js';
export const RAWFILE_UM_CALENDAR_CONST: string = 'UMCalendar/CalendarConst.js';
export const RAWFILE_ICON_SVG_SOURCE: string = 'icon/iconSvg.js';

export interface NamedRawResource {
  name: string;
  path: string;
}

export const RAWFILE_BUS_STOP_IMAGES: NamedRawResource[] = [
  { name: 'E11', path: 'img/Bus/stopImg/E11.jpg' },
  { name: 'E21', path: 'img/Bus/stopImg/E21.jpg' },
  { name: 'E32', path: 'img/Bus/stopImg/E32.jpg' },
  { name: 'E4', path: 'img/Bus/stopImg/E4.jpg' },
  { name: 'N2', path: 'img/Bus/stopImg/N2.jpg' },
  { name: 'N6', path: 'img/Bus/stopImg/N6.jpg' },
  { name: 'PGH', path: 'img/Bus/stopImg/PGH.jpg' },
  { name: 'S4', path: 'img/Bus/stopImg/S4.jpg' }
];

export const RAWFILE_DONATE_IMAGES: NamedRawResource[] = [
  { name: 'boc', path: RAWFILE_DONATE_BOC },
  { name: 'mpay', path: RAWFILE_DONATE_MPAY },
  { name: 'alipay', path: RAWFILE_DONATE_ALIPAY },
  { name: 'wechat', path: RAWFILE_DONATE_WECHAT }
];

export const MEDIA_APP_LOGO: string = 'app.media.app_logo';
export const MEDIA_APP_LOGO_ROUND: string = 'app.media.app_logo_round';
export const MEDIA_BUS_ICON: string = 'app.media.bus_icon';
