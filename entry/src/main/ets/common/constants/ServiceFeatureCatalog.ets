import {
  ARK_HARBOR,
  ARK_WIKI,
  CANTEEN_QUEUE,
  UM_ADD_DROP,
  UM_ALUMNI,
  UM_BULLETIN,
  UM_CALENDAR,
  UM_CLASSROOM_MAP,
  UM_CMMS,
  UM_COMMENTS,
  UM_COMPUTER_ROOM,
  UM_DOCUMENTS,
  UM_EXCHANGE,
  UM_FIND_BOOKS,
  UM_IMPORTANT_DATE,
  UM_ISW,
  UM_ISW_NEW,
  UM_JOB_SYSTEM,
  UM_LIB_BOOK,
  UM_LIBRARY,
  UM_LOCKER,
  UM_LOST_FOUND,
  UM_MAP,
  UM_MOODLE,
  UM_NEW_INFOGRAPHIC,
  UM_NEW_REGISTRATION,
  UM_NEW_STUDENT_GUIDE,
  UM_MAINLAND_STUDENT_GUIDE,
  UM_PAPER_PLAN,
  UM_PARK_APPLY,
  UM_PASS,
  UM_PORTAL,
  UM_PRE_ENROLMENT,
  UM_PRE_ENROLMENT_EXCEL,
  UM_PRINT,
  UM_PRINT_BALANCE,
  UM_RC,
  UM_RC_MENU,
  UM_RBS,
  UM_SCAM_PREVENTION,
  UM_SCHOLARSHIP,
  UM_SPORT_BOOKING,
  UM_STUDENT_UNION_BULLETIN,
  UM_WHOLE_PERSON
} from './ApiEndpoints';
import {
  ROUTE_BUS,
  ROUTE_CAR_PARK,
  ROUTE_COURSE_SIM,
  ROUTE_UM_ORG
} from './RouteNames';

export const SERVICE_DYNAMIC_LINK_NONE: string = '';
export const SERVICE_DYNAMIC_LINK_UMEH: string = 'umeh';

export interface ServiceFeatureItem {
  key: string;
  iconText: string;
  titleTc: string;
  titleEn: string;
  descriptionTc: string;
  descriptionEn: string;
  url?: string;
  routeName?: string;
  dynamicLink?: string;
}

export interface ServiceFeatureSection {
  key: string;
  titleTc: string;
  titleEn: string;
  items: ServiceFeatureItem[];
}

export const SERVICE_FEATURE_SECTIONS: ServiceFeatureSection[] = [
  {
    key: 'campus',
    titleTc: '校園資訊',
    titleEn: 'Campus Services',
    items: [
      {
        key: 'bus',
        iconText: '巴',
        titleTc: '校園巴士',
        titleEn: 'Bus',
        descriptionTc: '查看校巴到站情況',
        descriptionEn: 'Check the bus arrival status',
        routeName: ROUTE_BUS
      },
      {
        key: 'calendar',
        iconText: '曆',
        titleTc: '校曆',
        titleEn: 'Calendar',
        descriptionTc: '查看澳大校曆發佈頁',
        descriptionEn: 'Check the UM calendar release page',
        url: UM_CALENDAR
      },
      {
        key: 'map',
        iconText: '圖',
        titleTc: '校園地圖',
        titleEn: 'Map',
        descriptionTc: '查看澳大校園地圖',
        descriptionEn: 'Check the UM campus map',
        url: UM_MAP
      },
      {
        key: 'classroom',
        iconText: '室',
        titleTc: '課室佔用',
        titleEn: 'Classroom',
        descriptionTc: '查看當前各課室佔用情況',
        descriptionEn: 'Check the current classroom occupancy',
        url: UM_CLASSROOM_MAP
      },
      {
        key: 'car_park',
        iconText: 'P',
        titleTc: '車位',
        titleEn: 'Park',
        descriptionTc: '查看當前澳大停車場剩餘車位',
        descriptionEn: 'Check the remaining parking spaces in UM',
        routeName: ROUTE_CAR_PARK
      },
      {
        key: 'computer_room',
        iconText: 'E6',
        titleTc: 'E6電腦',
        titleEn: 'Computer',
        descriptionTc: '查看E6電腦室使用情況',
        descriptionEn: 'Check the usage of E6 computer room',
        url: UM_COMPUTER_ROOM
      },
      {
        key: 'library',
        iconText: '書',
        titleTc: '圖書館',
        titleEn: 'Library',
        descriptionTc: '直接前往圖書館主頁，能查看圖書館人數和搜索資源等',
        descriptionEn: 'Go directly to the library homepage to check occupancy and search resources',
        url: UM_LIBRARY
      },
      {
        key: 'umpass',
        iconText: 'ID',
        titleTc: 'UM Pass',
        titleEn: 'UM Pass',
        descriptionTc: '進入UM PASS設置頁面',
        descriptionEn: 'Enter the UM PASS settings page',
        url: UM_PASS
      },
      {
        key: 'bulletin',
        iconText: '告',
        titleTc: '電子公告',
        titleEn: 'Bulletin',
        descriptionTc: '查看澳大電子公告，最新的更新（未放到新聞和活動）會在這裡公示',
        descriptionEn: 'Check the UM electronic bulletin for latest notices',
        url: UM_BULLETIN
      },
      {
        key: 'print_balance',
        iconText: '$',
        titleTc: '打印餘額',
        titleEn: 'Balance',
        descriptionTc: '查看在澳大打印服務的餘額',
        descriptionEn: 'Check the balance of printing services in UM',
        url: UM_PRINT_BALANCE
      },
      {
        key: 'lost_found',
        iconText: '失',
        titleTc: '失物認領',
        titleEn: 'Lost',
        descriptionTc: '查看澳大官方失物認領列表',
        descriptionEn: 'Check the official lost and found list of UM',
        url: UM_LOST_FOUND
      },
      {
        key: 'job',
        iconText: '職',
        titleTc: '職位空缺',
        titleEn: 'Vacancies',
        descriptionTc: '查看澳大和其他公司在澳大發佈的招聘',
        descriptionEn: 'Check recruitment posted by UM and other companies',
        url: UM_JOB_SYSTEM
      },
      {
        key: 'rc_menu',
        iconText: '餐',
        titleTc: '書院餐單',
        titleEn: 'Menu',
        descriptionTc: '查看澳大書院菜單',
        descriptionEn: 'Check the UM college menu',
        url: UM_RC_MENU
      },
      {
        key: 'canteen_queue',
        iconText: '排',
        titleTc: '飯堂排隊',
        titleEn: 'Canteen Queue',
        descriptionTc: '查看LCWC W22飯堂當前排隊人數',
        descriptionEn: 'Check the current queue count at LCWC W22 canteen',
        url: CANTEEN_QUEUE
      },
      {
        key: 'student_union',
        iconText: '會',
        titleTc: '學生會',
        titleEn: 'Student Union',
        descriptionTc: '查看澳大學生會通告頁',
        descriptionEn: 'Check the UM student union announcement page',
        url: UM_STUDENT_UNION_BULLETIN
      },
      {
        key: 'portal',
        iconText: '+',
        titleTc: '更多服務',
        titleEn: 'More',
        descriptionTc: '進入澳大MyUM網頁查看完整功能',
        descriptionEn: 'Enter the UM MyUM webpage to view the full functions',
        url: UM_PORTAL
      }
    ]
  },
  {
    key: 'reservation',
    titleTc: '預約服務',
    titleEn: 'Reservation Services',
    items: [
      {
        key: 'cmms',
        iconText: '修',
        titleTc: '維修預約',
        titleEn: 'Repair',
        descriptionTc: '進入CMMS報修系統，可以對書院等各種設施的問題下單申請維修',
        descriptionEn: 'Enter the CMMS repair system to request facility repairs',
        url: UM_CMMS
      },
      {
        key: 'sport',
        iconText: '體',
        titleTc: '體育預訂',
        titleEn: 'Sports',
        descriptionTc: '預約澳大體育場館的使用',
        descriptionEn: 'Reserve the use of UM sports venues',
        url: UM_SPORT_BOOKING
      },
      {
        key: 'rbs',
        iconText: '場',
        titleTc: '場地預約',
        titleEn: 'Booking',
        descriptionTc: '預約E6等建築的房間、場地',
        descriptionEn: 'Reserve rooms and venues in buildings such as E6',
        url: UM_RBS
      },
      {
        key: 'lib_book',
        iconText: '房',
        titleTc: 'Lib房間',
        titleEn: 'Lib Rooms',
        descriptionTc: '預約圖書館房間',
        descriptionEn: 'Reserve library rooms',
        url: UM_LIB_BOOK
      },
      {
        key: 'print',
        iconText: '印',
        titleTc: '打印',
        titleEn: 'Print',
        descriptionTc: '可以線上傳文件，到E6等地方使用有Web Print標識的打印機打印',
        descriptionEn: 'Upload files online and print with Web Print printers',
        url: UM_PRINT
      },
      {
        key: 'comments',
        iconText: '意',
        titleTc: 'UM提意見',
        titleEn: 'Feedback',
        descriptionTc: '為UM的各部門提意見，校方會對意見做出回應',
        descriptionEn: 'Provide feedback to UM departments and receive responses',
        url: UM_COMMENTS
      },
      {
        key: 'locker',
        iconText: '箱',
        titleTc: '儲物箱',
        titleEn: 'Box',
        descriptionTc: '租用教學樓見到的鐵櫃儲物箱',
        descriptionEn: 'Rent storage lockers in teaching buildings',
        url: UM_LOCKER
      },
      {
        key: 'park_apply',
        iconText: '票',
        titleTc: '泊車月票',
        titleEn: 'Park',
        descriptionTc: '申請澳大的停車月票',
        descriptionEn: 'Apply for UM parking monthly pass',
        url: UM_PARK_APPLY
      },
      {
        key: 'documents',
        iconText: '證',
        titleTc: '證明文件',
        titleEn: 'Certificate',
        descriptionTc: '申請澳大相關的證明文件、學生證補辦等',
        descriptionEn: 'Apply for UM certificates and student card replacement',
        url: UM_DOCUMENTS
      }
    ]
  },
  {
    key: 'academic',
    titleTc: '課業發展',
    titleEn: 'Coursework & Development',
    items: [
      {
        key: 'moodle',
        iconText: 'M',
        titleTc: 'Moodle',
        titleEn: 'Moodle',
        descriptionTc: 'UM Moodle，不想錯過DDL就要常看，可以把TimeLine板塊移動到最上方',
        descriptionEn: 'UM Moodle for courses, assignments and deadlines',
        url: UM_MOODLE
      },
      {
        key: 'wiki',
        iconText: 'W',
        titleTc: 'Wiki',
        titleEn: 'Wiki',
        descriptionTc: 'ARK Wiki，希望集成澳大的所有資訊、攻略、學習方法等',
        descriptionEn: 'ARK Wiki for UM information, guides and learning methods',
        url: ARK_WIKI
      },
      {
        key: 'course_sim',
        iconText: '表',
        titleTc: '課表模擬',
        titleEn: 'Timetable',
        descriptionTc: 'ARK課表模擬功能，選課時不用再對著Excel自己慢慢找啦！',
        descriptionEn: 'ARK timetable simulation for course planning',
        routeName: ROUTE_COURSE_SIM
      },
      {
        key: 'what2reg',
        iconText: '評',
        titleTc: '選咩課',
        titleEn: 'What2Reg',
        descriptionTc: '選咩課，UM Helper開發的課程評論網站',
        descriptionEn: 'What2Reg, a course review website developed by UM Helper',
        dynamicLink: SERVICE_DYNAMIC_LINK_UMEH
      },
      {
        key: 'isw',
        iconText: 'IS',
        titleTc: 'ISW',
        titleEn: 'ISW',
        descriptionTc: '舊版ISW，看分、課表、繳費、個人資料設定等重要網站',
        descriptionEn: 'Old ISW for grades, timetable, payments and profile settings',
        url: UM_ISW
      },
      {
        key: 'isw_new',
        iconText: '新',
        titleTc: 'New ISW',
        titleEn: 'New ISW',
        descriptionTc: '全新版本的ISW，估計未來會主推這個系統',
        descriptionEn: 'New version of ISW',
        url: UM_ISW_NEW
      },
      {
        key: 'pre_enrolment',
        iconText: '預',
        titleTc: '預選課',
        titleEn: 'PreEnroll',
        descriptionTc: '預選課網站入口，一般在學期結尾進行',
        descriptionEn: 'Pre-enrollment website entrance',
        url: UM_PRE_ENROLMENT
      },
      {
        key: 'pre_enrolment_excel',
        iconText: '表',
        titleTc: '預選表格',
        titleEn: 'PreEnroll Excel',
        descriptionTc: '進入澳大的預選表格、開課時間表的發佈頁',
        descriptionEn: 'UM pre-enrollment form and course schedule release page',
        url: UM_PRE_ENROLMENT_EXCEL
      },
      {
        key: 'add_drop',
        iconText: 'AD',
        titleTc: 'Add Drop',
        titleEn: 'Add Drop',
        descriptionTc: 'Add Drop課的入口，在學期開始前',
        descriptionEn: 'Add Drop course entrance before semester starts',
        url: UM_ADD_DROP
      },
      {
        key: 'important_date',
        iconText: '日',
        titleTc: '重要日期',
        titleEn: 'Important Dates',
        descriptionTc: '查看澳大本學年的重要日期，包括預選課、增補選、考試等重要時間點',
        descriptionEn: 'Check UM important academic dates',
        url: UM_IMPORTANT_DATE
      },
      {
        key: 'whole_person',
        iconText: '全',
        titleTc: '全人發展',
        titleEn: 'Whole Person',
        descriptionTc: '全人發展計劃的入口，拿到夠多的分數還有獎品',
        descriptionEn: 'Whole Person Development Program entrance',
        url: UM_WHOLE_PERSON
      },
      {
        key: 'exchange',
        iconText: '交',
        titleTc: '交流',
        titleEn: 'Exchange',
        descriptionTc: '申請澳大的出外交流項目',
        descriptionEn: 'Apply for UM outbound exchange programs',
        url: UM_EXCHANGE
      },
      {
        key: 'scholarship',
        iconText: '獎',
        titleTc: '獎學金',
        titleEn: 'Scholarship',
        descriptionTc: '查看澳大獎學金介紹頁',
        descriptionEn: 'Check the UM scholarship introduction page',
        url: UM_SCHOLARSHIP
      },
      {
        key: 'find_books',
        iconText: '搜',
        titleTc: '資源搜索',
        titleEn: 'Resource Finder',
        descriptionTc: '進入澳大圖書館的資源搜索頁，搜索澳大已購買的文獻資料、教科書等',
        descriptionEn: 'Search library resources, papers and textbooks',
        url: UM_FIND_BOOKS
      },
      {
        key: 'paper_plan',
        iconText: '論',
        titleTc: '論文計劃',
        titleEn: 'Essay Plan',
        descriptionTc: '你的論文計劃小幫手',
        descriptionEn: 'Your essay planning assistant',
        url: UM_PAPER_PLAN
      }
    ]
  },
  {
    key: 'freshman',
    titleTc: '新生推薦',
    titleEn: 'Recommended for Freshmen',
    items: [
      {
        key: 'harbor',
        iconText: '港',
        titleTc: '職涯港',
        titleEn: 'Harbor',
        descriptionTc: 'ARK職涯港論壇！求職、美食、校友應有盡有！',
        descriptionEn: 'ARK Harbor forum for careers, food, alumni and more',
        url: ARK_HARBOR
      },
      {
        key: 'survival',
        iconText: '生',
        titleTc: '生存指南',
        titleEn: 'Survival',
        descriptionTc: '澳大生存指南公眾號歷史推文',
        descriptionEn: 'Historical posts from the UM Survival Guide public account',
        url: UM_NEW_STUDENT_GUIDE
      },
      {
        key: 'mainland',
        iconText: '內',
        titleTc: '內地生',
        titleEn: 'Mainland',
        descriptionTc: '澳大生存指南公眾號給內地新生的一些指南建議',
        descriptionEn: 'Guide suggestions for mainland freshmen',
        url: UM_MAINLAND_STUDENT_GUIDE
      },
      {
        key: 'registration',
        iconText: '註',
        titleTc: '新生註冊',
        titleEn: 'Registration',
        descriptionTc: '新生註冊圖文包及相關資料',
        descriptionEn: 'New Student Registration Package and related materials',
        url: UM_NEW_REGISTRATION
      },
      {
        key: 'infographic',
        iconText: '包',
        titleTc: '圖文包',
        titleEn: 'Package',
        descriptionTc: '澳大官方出品的新生圖文包，包括EELC等課程要求',
        descriptionEn: 'UM official freshman package including EELC requirements',
        url: UM_NEW_INFOGRAPHIC
      },
      {
        key: 'scam',
        iconText: '防',
        titleTc: '防詐騙',
        titleEn: 'Scam',
        descriptionTc: '防詐騙圖文包，外地同學初次到達澳門要注意！',
        descriptionEn: 'Anti-fraud package for students arriving in Macau',
        url: UM_SCAM_PREVENTION
      },
      {
        key: 'rc',
        iconText: '院',
        titleTc: '書院',
        titleEn: 'RC',
        descriptionTc: '書院大全，快捷找到對應書院主頁',
        descriptionEn: 'A college list to quickly find college homepages',
        url: UM_RC
      },
      {
        key: 'alumni',
        iconText: '友',
        titleTc: '校友會',
        titleEn: 'Alumni',
        descriptionTc: 'UM校友會，也可以找到其他校友相關資訊的網站',
        descriptionEn: 'UM Alumni Association and related alumni information',
        url: UM_ALUMNI
      },
      {
        key: 'um_org',
        iconText: '部',
        titleTc: '澳大部門',
        titleEn: 'Organization',
        descriptionTc: 'UM部門，提供各種校內部門的資訊',
        descriptionEn: 'UM Departments with information on campus offices',
        routeName: ROUTE_UM_ORG
      }
    ]
  }
];
