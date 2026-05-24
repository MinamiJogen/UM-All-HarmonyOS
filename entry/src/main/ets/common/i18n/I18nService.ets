import { common } from '@kit.AbilityKit';
import { STORAGE_LANGUAGE } from '../constants/StorageKeys';
import { PreferencesStore } from '../storage/PreferencesStore';
import { enUsText } from './lang/en_US';
import { jaJpText } from './lang/ja_JP';
import { ptPtText } from './lang/pt_PT';
import { zhCnText } from './lang/zh_CN';
import { zhHkText } from './lang/zh_HK';
import { Logger } from '../utils/Logger';

export const LANGUAGE_SC: string = 'sc';
export const LANGUAGE_TC: string = 'tc';
export const LANGUAGE_EN: string = 'en';
export const LANGUAGE_PT: string = 'pt';
export const LANGUAGE_JA: string = 'ja';

function isSupportedLanguage(language: string): boolean {
  return language === LANGUAGE_SC || language === LANGUAGE_TC || language === LANGUAGE_EN ||
  language === LANGUAGE_PT || language === LANGUAGE_JA;
}

function normalizeStoredLanguage(rawValue: string): string {
  if (rawValue.length === 0) {
    return '';
  }
  if (isSupportedLanguage(rawValue)) {
    return rawValue;
  }
  try {
    const parsed: string = JSON.parse(rawValue) as string;
    if (isSupportedLanguage(parsed)) {
      return parsed;
    }
  } catch (error) {
    Logger.debug('Stored language is not JSON: ' + String(error));
  }
  return '';
}

function getSystemLanguage(context: common.UIAbilityContext): string {
  return (context.config?.language ?? '').toLowerCase().replaceAll('_', '-');
}

function getSystemTag(language: string): string {
  switch (language) {
    case LANGUAGE_SC:
      return 'zh-Hans';
    case LANGUAGE_TC:
      return 'zh-Hant';
    case LANGUAGE_PT:
      return 'pt-PT';
    case LANGUAGE_JA:
      return 'ja-JP';
    case LANGUAGE_EN:
    default:
      return 'en';
  }
}

function toSimplifiedChinese(text: string): string {
  return text
    .replaceAll('資訊', '资讯')
    .replaceAll('資源', '资源')
    .replaceAll('課程', '课程')
    .replaceAll('課表', '课表')
    .replaceAll('課節', '课节')
    .replaceAll('課', '课')
    .replaceAll('節', '节')
    .replaceAll('學年', '学年')
    .replaceAll('學生', '学生')
    .replaceAll('學習', '学习')
    .replaceAll('學', '学')
    .replaceAll('圖書館', '图书馆')
    .replaceAll('圖文', '图文')
    .replaceAll('圖', '图')
    .replaceAll('書院', '书院')
    .replaceAll('書', '书')
    .replaceAll('校園', '校园')
    .replaceAll('澳門', '澳门')
    .replaceAll('榮譽', '荣誉')
    .replaceAll('榮', '荣')
    .replaceAll('劉', '刘')
    .replaceAll('樓', '楼')
    .replaceAll('搵', '找')
    .replaceAll('選', '选')
    .replaceAll('預約', '预约')
    .replaceAll('預', '预')
    .replaceAll('載入', '载入')
    .replaceAll('讀取', '读取')
    .replaceAll('數據', '数据')
    .replaceAll('數', '数')
    .replaceAll('資料', '资料')
    .replaceAll('資', '资')
    .replaceAll('緩存', '缓存')
    .replaceAll('快取', '缓存')
    .replaceAll('狀態', '状态')
    .replaceAll('當前', '当前')
    .replaceAll('目前', '当前')
    .replaceAll('點擊', '点击')
    .replaceAll('按鈕', '按钮')
    .replaceAll('反饋', '反馈')
    .replaceAll('鏈接', '链接')
    .replaceAll('打開', '打开')
    .replaceAll('開啟', '打开')
    .replaceAll('開設', '开设')
    .replaceAll('開', '开')
    .replaceAll('關閉', '关闭')
    .replaceAll('關鍵字', '关键字')
    .replaceAll('關於', '关于')
    .replaceAll('後退', '后退')
    .replaceAll('後', '后')
    .replaceAll('前進', '前进')
    .replaceAll('無', '无')
    .replaceAll('暫', '暂')
    .replaceAll('將', '将')
    .replaceAll('進行', '进行')
    .replaceAll('進入', '进入')
    .replaceAll('進', '进')
    .replaceAll('已過', '已过')
    .replaceAll('來', '来')
    .replaceAll('舉報', '举报')
    .replaceAll('舉辦', '举办')
    .replaceAll('發送', '发送')
    .replaceAll('發佈', '发布')
    .replaceAll('發展', '发展')
    .replaceAll('發帖', '发帖')
    .replaceAll('發現', '发现')
    .replaceAll('發', '发')
    .replaceAll('聯絡', '联系')
    .replaceAll('聯繫', '联系')
    .replaceAll('聯', '联')
    .replaceAll('組織', '组织')
    .replaceAll('組', '组')
    .replaceAll('活動', '活动')
    .replaceAll('新聞', '新闻')
    .replaceAll('首頁', '首页')
    .replaceAll('服務', '服务')
    .replaceAll('設置', '设置')
    .replaceAll('設定', '设置')
    .replaceAll('應用', '应用')
    .replaceAll('應有盡有', '应有尽有')
    .replaceAll('應', '应')
    .replaceAll('語言', '语言')
    .replaceAll('語', '语')
    .replaceAll('請', '请')
    .replaceAll('錯誤', '错误')
    .replaceAll('錯', '错')
    .replaceAll('誤', '误')
    .replaceAll('頁面', '页面')
    .replaceAll('網頁', '网页')
    .replaceAll('網', '网')
    .replaceAll('頁', '页')
    .replaceAll('項目', '项目')
    .replaceAll('項', '项')
    .replaceAll('記錄', '记录')
    .replaceAll('記', '记')
    .replaceAll('錄', '录')
    .replaceAll('顯示', '显示')
    .replaceAll('顯', '显')
    .replaceAll('搜尋', '搜索')
    .replaceAll('篩選', '筛选')
    .replaceAll('篩', '筛')
    .replaceAll('過濾', '过滤')
    .replaceAll('濾', '滤')
    .replaceAll('獲取', '获取')
    .replaceAll('獲', '获')
    .replaceAll('遠端', '远端')
    .replaceAll('遠', '远')
    .replaceAll('離線', '离线')
    .replaceAll('離', '离')
    .replaceAll('連線', '连线')
    .replaceAll('連結', '链接')
    .replaceAll('連', '连')
    .replaceAll('顏色', '颜色')
    .replaceAll('顏', '颜')
    .replaceAll('報名', '报名')
    .replaceAll('報', '报')
    .replaceAll('詳細', '详细')
    .replaceAll('詳', '详')
    .replaceAll('變更', '变更')
    .replaceAll('變', '变')
    .replaceAll('儲存', '保存')
    .replaceAll('廣場', '广场')
    .replaceAll('廣', '广')
    .replaceAll('頻道', '频道')
    .replaceAll('頻', '频')
    .replaceAll('會員', '会员')
    .replaceAll('員', '员')
    .replaceAll('講師', '讲师')
    .replaceAll('講', '讲')
    .replaceAll('師', '师')
    .replaceAll('歷史', '历史')
    .replaceAll('校曆', '校历')
    .replaceAll('曆', '历')
    .replaceAll('歷', '历')
    .replaceAll('導航', '导航')
    .replaceAll('懸浮', '悬浮')
    .replaceAll('懸', '悬')
    .replaceAll('綜合', '综合')
    .replaceAll('綜', '综')
    .replaceAll('總', '总')
    .replaceAll('區', '区')
    .replaceAll('園', '园')
    .replaceAll('業', '业')
    .replaceAll('務', '务')
    .replaceAll('萬', '万')
    .replaceAll('雙', '双')
    .replaceAll('單', '单')
    .replaceAll('風險', '风险')
    .replaceAll('險', '险')
    .replaceAll('間', '间')
    .replaceAll('續', '续')
    .replaceAll('齊', '齐')
    .replaceAll('術', '术')
    .replaceAll('並', '并')
    .replaceAll('時', '时')
    .replaceAll('點', '点')
    .replaceAll('標籤', '标签')
    .replaceAll('籤', '签')
    .replaceAll('辦', '办')
    .replaceAll('邊', '边')
    .replaceAll('這裡', '这里')
    .replaceAll('這', '这')
    .replaceAll('裡', '里')
    .replaceAll('裏', '里')
    .replaceAll('從', '从')
    .replaceAll('雲', '云')
    .replaceAll('歡迎', '欢迎')
    .replaceAll('參加', '参加')
    .replaceAll('參', '参')
    .replaceAll('備註', '备注')
    .replaceAll('準備', '准备')
    .replaceAll('準', '准')
    .replaceAll('備', '备')
    .replaceAll('註', '注')
    .replaceAll('查詢', '查询')
    .replaceAll('詢', '询')
    .replaceAll('輸入', '输入')
    .replaceAll('輸', '输')
    .replaceAll('複製', '复制')
    .replaceAll('複', '复')
    .replaceAll('製', '制')
    .replaceAll('貼', '贴')
    .replaceAll('欄', '栏')
    .replaceAll('協議', '协议')
    .replaceAll('協', '协')
    .replaceAll('郵箱', '邮箱')
    .replaceAll('郵件', '邮件')
    .replaceAll('郵', '邮')
    .replaceAll('分類', '分类')
    .replaceAll('級', '级')
    .replaceAll('別', '别')
    .replaceAll('難', '难')
    .replaceAll('異常', '异常')
    .replaceAll('異', '异')
    .replaceAll('彈出', '弹出')
    .replaceAll('彈', '弹')
    .replaceAll('鎖定', '锁定')
    .replaceAll('鎖', '锁')
    .replaceAll('驗證', '验证')
    .replaceAll('驗', '验')
    .replaceAll('證', '证')
    .replaceAll('確定', '确定')
    .replaceAll('確', '确')
    .replaceAll('權限', '权限')
    .replaceAll('權', '权')
    .replaceAll('庫', '库')
    .replaceAll('隊列', '队列')
    .replaceAll('隊', '队')
    .replaceAll('創建', '创建')
    .replaceAll('創', '创')
    .replaceAll('刪除', '删除')
    .replaceAll('刪', '删')
    .replaceAll('碼', '码')
    .replaceAll('編號', '编号')
    .replaceAll('編', '编')
    .replaceAll('塊', '块')
    .replaceAll('餵', '喂')
    .replaceAll('導師', '导师')
    .replaceAll('咩', '什么')
    .replaceAll('睇', '看')
    .replaceAll('畀', '给')
    .replaceAll('啲', '些')
    .replaceAll('哋', '们')
    .replaceAll('唔', '不')
    .replaceAll('淺色', '浅色')
    .replaceAll('啟動', '启动')
    .replaceAll('啟', '启')
    .replaceAll('檢查', '检查')
    .replaceAll('隱私', '隐私')
    .replaceAll('動態', '动态')
    .replaceAll('電子', '电子')
    .replaceAll('電腦', '电脑')
    .replaceAll('電機', '电机')
    .replaceAll('電', '电')
    .replaceAll('公告', '公告')
    .replaceAll('內測', '内测')
    .replaceAll('適配', '适配')
    .replaceAll('後續', '后续')
    .replaceAll('補齊', '补齐')
    .replaceAll('分鐘', '分钟')
    .replaceAll('時間', '时间')
    .replaceAll('地點', '地点')
    .replaceAll('老師', '老师')
    .replaceAll('電話', '电话')
    .replaceAll('學院', '学院')
    .replaceAll('學系', '学系')
    .replaceAll('類型', '类型')
    .replaceAll('類', '类')
    .replaceAll('通識', '通识')
    .replaceAll('識', '识')
    .replaceAll('必修 / 選修', '必修 / 选修')
    .replaceAll('簡介', '简介')
    .replaceAll('簡', '简')
    .replaceAll('照片', '照片')
    .replaceAll('繁體', '繁体')
    .replaceAll('正體', '正体')
    .replaceAll('號', '号')
    .replaceAll('與', '与')
    .replaceAll('為', '为')
    .replaceAll('個', '个')
    .replaceAll('沒有', '没有')
    .replaceAll('沒', '没')
    .replaceAll('餘額', '余额')
    .replaceAll('餘', '余')
    .replaceAll('認領', '认领')
    .replaceAll('認', '认')
    .replaceAll('領', '领')
    .replaceAll('職位', '职位')
    .replaceAll('職涯', '职涯')
    .replaceAll('職', '职')
    .replaceAll('空缺', '空缺')
    .replaceAll('維修', '维修')
    .replaceAll('維', '维')
    .replaceAll('體育', '体育')
    .replaceAll('體', '体')
    .replaceAll('場館', '场馆')
    .replaceAll('館', '馆')
    .replaceAll('場地', '场地')
    .replaceAll('場', '场')
    .replaceAll('房間', '房间')
    .replaceAll('線上', '线上')
    .replaceAll('傳文件', '传文件')
    .replaceAll('傳播', '传播')
    .replaceAll('傳', '传')
    .replaceAll('標識', '标识')
    .replaceAll('標題', '标题')
    .replaceAll('標', '标')
    .replaceAll('鐵櫃', '铁柜')
    .replaceAll('櫃', '柜')
    .replaceAll('儲物', '储物')
    .replaceAll('儲', '储')
    .replaceAll('證明', '证明')
    .replaceAll('證', '证')
    .replaceAll('補辦', '补办')
    .replaceAll('補', '补')
    .replaceAll('獎學金', '奖学金')
    .replaceAll('獎品', '奖品')
    .replaceAll('獎', '奖')
    .replaceAll('導入', '导入')
    .replaceAll('導', '导')
    .replaceAll('模擬', '模拟')
    .replaceAll('擬', '拟')
    .replaceAll('論文', '论文')
    .replaceAll('論', '论')
    .replaceAll('計劃', '计划')
    .replaceAll('計', '计')
    .replaceAll('評', '评')
    .replaceAll('劃', '划')
    .replaceAll('推薦', '推荐')
    .replaceAll('眾號', '众号')
    .replaceAll('註冊', '注册')
    .replaceAll('註', '注')
    .replaceAll('注冊', '注册')
    .replaceAll('冊', '册')
    .replaceAll('詐騙', '诈骗')
    .replaceAll('詐', '诈')
    .replaceAll('騙', '骗')
    .replaceAll('達', '达')
    .replaceAll('對應', '对应')
    .replaceAll('對', '对')
    .replaceAll('部門', '部门')
    .replaceAll('門', '门')
    .replaceAll('車位', '车位')
    .replaceAll('車輛', '车辆')
    .replaceAll('車', '车')
    .replaceAll('佔用', '占用')
    .replaceAll('佔', '占')
    .replaceAll('餸', '餸')
    .replaceAll('薈萃坊', '荟萃坊')
    .replaceAll('舊版', '旧版')
    .replaceAll('舊', '旧')
    .replaceAll('繳費', '缴费')
    .replaceAll('繳', '缴')
    .replaceAll('個人', '个人')
    .replaceAll('個', '个')
    .replaceAll('估計', '估计')
    .replaceAll('失敗', '失败')
    .replaceAll('敗', '败')
    .replaceAll('重試', '重试')
    .replaceAll('試', '试')
    .replaceAll('結束', '结束')
    .replaceAll('結', '结')
    .replaceAll('衝突', '冲突')
    .replaceAll('衝', '冲')
    .replaceAll('系統', '系统')
    .replaceAll('統', '统')
    .replaceAll('寫', '写')
    .replaceAll('該', '该')
    .replaceAll('說明', '说明')
    .replaceAll('說', '说')
    .replaceAll('還', '还')
    .replaceAll('相關', '相关')
    .replaceAll('尋', '寻')
    .replaceAll('內容', '内容')
    .replaceAll('見', '见')
    .replaceAll('換', '换')
    .replaceAll('況', '况')
    .replaceAll('藥', '药')
    .replaceAll('醫', '医')
    .replaceAll('經濟', '经济')
    .replaceAll('經', '经')
    .replaceAll('濟', '济')
    .replaceAll('國', '国')
    .replaceAll('際', '际')
    .replaceAll('實', '实')
    .replaceAll('華', '华')
    .replaceAll('環', '环')
    .replaceAll('鍵', '键')
    .replaceAll('名稱', '名称')
    .replaceAll('稱', '称')
    .replaceAll('話', '话')
    .replaceAll('極', '极')
    .replaceAll('訪', '访')
    .replaceAll('執行', '执行')
    .replaceAll('執', '执')
    .replaceAll('問題', '问题')
    .replaceAll('問', '问')
    .replaceAll('處', '处')
    .replaceAll('社團', '社团')
    .replaceAll('團', '团')
    .replaceAll('遊', '游')
    .replaceAll('氣', '气')
    .replaceAll('價', '价')
    .replaceAll('鈕', '钮')
    .replaceAll('嗎', '吗')
    .replaceAll('瀏覽', '浏览')
    .replaceAll('瀏', '浏')
    .replaceAll('覽', '览')
    .replaceAll('賬號', '账号')
    .replaceAll('賬', '账')
    .replaceAll('輕型', '轻型')
    .replaceAll('輕', '轻')
    .replaceAll('輛', '辆')
    .replaceAll('緊張', '紧张')
    .replaceAll('緊', '紧')
    .replaceAll('張', '张')
    .replaceAll('折疊', '折叠')
    .replaceAll('疊', '叠')
    .replaceAll('繼續', '继续')
    .replaceAll('繼', '继')
    .replaceAll('內', '内')
    .replaceAll('動', '动')
    .replaceAll('設計', '设计')
    .replaceAll('設', '设')
    .replaceAll('藝術', '艺术')
    .replaceAll('藝', '艺')
    .replaceAll('議', '议')
    .replaceAll('財', '财')
    .replaceAll('絡', '络')
    .replaceAll('機', '机')
    .replaceAll('終', '终')
    .replaceAll('題', '题')
    .replaceAll('約', '约')
    .replaceAll('織', '织')
    .replaceAll('腦', '脑')
    .replaceAll('孫', '孙')
    .replaceAll('賢', '贤')
    .replaceAll('飯堂', '饭堂')
    .replaceAll('飯', '饭')
    .replaceAll('各種', '各种')
    .replaceAll('種', '种')
    .replaceAll('訂', '订')
    .replaceAll('建築', '建筑')
    .replaceAll('築', '筑')
    .replaceAll('過', '过')
    .replaceAll('夠', '够')
    .replaceAll('介紹', '介绍')
    .replaceAll('紹', '绍')
    .replaceAll('購買', '购买')
    .replaceAll('購', '购')
    .replaceAll('買', '买')
    .replaceAll('文獻', '文献')
    .replaceAll('獻', '献')
    .replaceAll('幫手', '帮手')
    .replaceAll('幫', '帮')
    .replaceAll('論壇', '论坛')
    .replaceAll('壇', '坛')
    .replaceAll('公眾號', '公众号')
    .replaceAll('公眾', '公众')
    .replaceAll('眾', '众')
    .replaceAll('給', '给')
    .replaceAll('進駐', '进驻')
    .replaceAll('駐', '驻')
    .replaceAll('會', '会')
    .replaceAll('體', '体')
    .replaceAll('線', '线')
    .replaceAll('臺', '台');
}

function portugueseInlineText(enText: string): string {
  switch (enText) {
    case 'Back':
      return 'Voltar';
    case 'Close':
      return 'Fechar';
    case 'Retry':
      return 'Tentar novamente';
    case 'Refresh':
      return 'Atualizar';
    case 'Search':
      return 'Pesquisar';
    case 'Loading':
      return 'A carregar';
    case 'Open':
      return 'Abrir';
    case 'Links':
      return 'Ligações';
    case 'Unable to open link':
      return 'Não foi possível abrir a ligação';
    case 'Not available yet':
      return 'Ainda não disponível';
    case 'HarmonyOS Beta Version':
      return 'Versão beta para HarmonyOS';
    case 'Send Feedback':
      return 'Enviar feedback';
    case 'Current version: ':
      return 'Versão atual: ';
    case 'HarmonyOS beta for HarmonyOS 6.1.0 and later.\nBeta features may be incomplete or buggy. Tap to report via GitHub Issues.':
      return 'Versão beta para HarmonyOS 6.1.0 e posterior.\nAlgumas funcionalidades podem estar incompletas ou conter erros. Toque para reportar no GitHub Issues.';
    case 'Search: everything about UM...':
      return 'Pesquisar: tudo sobre a UM...';
    case 'Search UM pages or services':
      return 'Pesquisar páginas ou serviços da UM';
    case 'Search UM websites':
      return 'Pesquisar sites da UM';
    case 'Calendar Upcoming:':
      return 'Próximos no calendário:';
    case 'Next class':
      return 'Próxima aula';
    case 'No upcoming class':
      return 'Sem aulas próximas';
    case 'Open timetable':
      return 'Abrir horário';
    case 'Bulletin':
      return 'Avisos';
    case 'Check the UM electronic bulletin for latest notices':
      return 'Consultar os avisos eletrónicos da UM e as comunicações mais recentes';
    case 'Harbor new-topic entry. Tapping this bottom tab opens the external Harbor post page and keeps the current page.':
      return 'Entrada para publicar no Harbor. Ao tocar neste separador, a página externa de publicação do Harbor é aberta e a página atual é mantida.';
    case 'Unable to open the new-topic entry':
      return 'Não foi possível abrir a entrada de publicação';
    case 'Bus':
      return 'Autocarro';
    case 'New':
      return 'Novo';
    case 'Donate':
      return 'Donativo';
    case 'Login':
      return 'Iniciar sessão';
    case 'Home refreshed':
      return 'Página inicial atualizada';
    case 'Failed to load calendar':
      return 'Falha ao carregar calendário';
    case 'Failed to load feed':
      return 'Falha ao carregar feed';
    case 'Failed to load more feed':
      return 'Falha ao carregar mais conteúdos';
    case 'Loading home':
      return 'A carregar página inicial';
    case 'No more content':
      return 'Sem mais conteúdos';
    case 'Load more':
      return 'Carregar mais';
    case 'Untitled event':
      return 'Evento sem título';
    case 'Past':
      return 'Passado';
    case 'Ending':
      return 'A terminar';
    case 'Active':
      return 'Ativo';
    case 'Web':
      return 'Web';
    case 'Campus Bus':
      return 'Autocarro do campus';
    case 'Loading bus data':
      return 'A carregar dados do autocarro';
    case 'Unable to load bus data':
      return 'Não foi possível carregar dados do autocarro';
    case 'Bus data refreshed':
      return 'Dados do autocarro atualizados';
    case 'No bus is currently shown':
      return 'Não há autocarros apresentados no momento';
    case 'Last refresh: ':
      return 'Última atualização: ';
    case 'Map':
      return 'Mapa';
    case 'Stops':
      return 'Paragens';
    case 'Current buses':
      return 'Autocarros atuais';
    case 'No bus info':
      return 'Sem informação de autocarros';
    case 'Car Park':
      return 'Parque de estacionamento';
    case 'Car park data refreshed':
      return 'Dados do estacionamento atualizados';
    case 'Failed to load car park data':
      return 'Falha ao carregar dados do estacionamento';
    case 'Parking target':
      return 'Destinatário';
    case 'Vehicle type':
      return 'Tipo de veículo';
    case 'Available spaces: ':
      return 'Lugares disponíveis: ';
    case 'Tight':
      return 'Limitado';
    case 'Search results':
      return 'Resultados';
    case 'No search results':
      return 'Sem resultados';
    case 'No results found':
      return 'Sem resultados';
    case 'Clear search':
      return 'Limpar pesquisa';
    case 'Enter a keyword':
      return 'Introduza uma palavra-chave';
    case 'Enter a keyword first':
      return 'Introduza primeiro uma palavra-chave';
    case 'Actions':
      return 'Ações';
    case 'Details':
      return 'Detalhes';
    case 'Date':
      return 'Data';
    case 'Time':
      return 'Hora';
    case 'Venue':
      return 'Local';
    case 'Location: ':
      return 'Localização: ';
    case 'Contact':
      return 'Contacto';
    case 'Email':
      return 'Email';
    case 'Phone':
      return 'Telefone';
    case 'Fax':
      return 'Fax';
    case 'Language':
      return 'Idioma';
    case 'Audience':
      return 'Público';
    case 'Organiser':
      return 'Organizador';
    case 'Co-organiser':
      return 'Coorganizador';
    case 'Remark':
      return 'Observação';
    case 'News Detail':
      return 'Detalhes da notícia';
    case 'No news data':
      return 'Sem dados da notícia';
    case 'No content available':
      return 'Sem conteúdo disponível';
    case 'Event Detail':
      return 'Detalhes do evento';
    case 'Event Details':
      return 'Detalhes do evento';
    case 'UM Event Detail':
      return 'Detalhes do evento da UM';
    case 'No event data':
      return 'Sem dados do evento';
    case 'No event content available':
      return 'Sem conteúdo do evento disponível';
    case 'Course data refreshed':
      return 'Dados das disciplinas atualizados';
    case 'Failed to load course data':
      return 'Falha ao carregar dados das disciplinas';
    case 'Course mode':
      return 'Modo da disciplina';
    case 'Faculty':
      return 'Faculdade';
    case 'Department':
      return 'Departamento';
    case 'Course actions':
      return 'Ações da disciplina';
    case 'Timetable':
      return 'Horário';
    case 'Courses':
      return 'Disciplinas';
    case 'Meetings':
      return 'Aulas';
    case 'Status':
      return 'Estado';
    case 'Conflict':
      return 'Conflito';
    case 'Free':
      return 'Livre';
    case 'Add':
      return 'Adicionar';
    case 'Clear':
      return 'Limpar';
    case 'Cancel':
      return 'Cancelar';
    case 'OK':
      return 'OK';
    case 'Method 1':
      return 'Método 1';
    case 'Method 2':
      return 'Método 2';
    case 'How to start your timetable':
      return 'Como começar o horário';
    case 'Use Add to search courses, then add one section or every section of the course.':
      return 'Use Adicionar para pesquisar disciplinas e adicione uma secção ou todas as secções da disciplina.';
    case 'Search and add manually':
      return 'Pesquisar e adicionar manualmente';
    case 'Copy the Timetable text from old ISW, paste it below, and import it.':
      return 'Copie o texto do horário no ISW antigo, cole-o abaixo e importe.';
    case 'Open old ISW':
      return 'Abrir ISW antigo';
    case 'Selected sections with no valid time: ':
      return 'Secções selecionadas sem horário válido: ';
    case 'Use the official timetable as the source of truth.':
      return 'Use o horário oficial como referência.';
    case 'Import from ISW text':
      return 'Importar texto do ISW';
    case 'Break ':
      return 'Intervalo ';
    case 'Evening':
      return 'Noite';
    case 'Afternoon':
      return 'Tarde';
    case 'Choose a section':
      return 'Escolher uma secção';
    case 'Add all sections':
      return 'Adicionar todas as secções';
    case 'Chinese searches immediately. English or course code needs at least 3 characters.':
      return 'A pesquisa em chinês é imediata. Inglês ou código da disciplina requer pelo menos 3 caracteres.';
    case 'PreEnroll courses':
      return 'Disciplinas de pré-inscrição';
    case 'Add/Drop courses':
      return 'Disciplinas Add/Drop';
    case 'Data version: ':
      return 'Versão dos dados: ';
    case 'Use the official timetable Excel as the source of truth. Reviews are for reference.':
      return 'Use o Excel oficial do horário como referência. As avaliações são apenas indicativas.';
    case 'Use the actions below to check whether the latest data has been uploaded. If the official date changed but the app did not, restart the app or contact the maintainer.':
      return 'Use as ações abaixo para verificar se os dados mais recentes foram enviados. Se a data oficial mudou mas a app não, reinicie a app ou contacte o responsável.';
    case 'Tap a stop to view its photo. Tap a bus icon to refresh.':
      return 'Toque numa paragem para ver a foto. Toque no ícone do autocarro para atualizar.';
    case 'No bus service is currently shown, or the official page returned no plate number.':
      return 'Não há serviço de autocarro apresentado no momento, ou a página oficial não devolveu matrícula.';
    case 'Unable to open campus map':
      return 'Não foi possível abrir o mapa do campus';
    case 'No record matches the current filters':
      return 'Nenhum registo corresponde aos filtros atuais';
    case 'Reading UM Open Data':
      return 'A ler UM Open Data';
    case 'Unable to load car parks':
      return 'Não foi possível carregar os parques de estacionamento';
    case 'Loading car park data':
      return 'A carregar dados do estacionamento';
    case 'Update: ':
      return 'Atualização: ';
    case 'News image':
      return 'Imagem da notícia';
    case 'Event poster':
      return 'Cartaz do evento';
    case 'Missing club data':
      return 'Dados do clube em falta';
    case 'Club Detail':
      return 'Detalhes do clube';
    case 'All Events':
      return 'Todos os eventos';
    case 'Events':
      return 'Eventos';
    case 'Events refreshed':
      return 'Eventos atualizados';
    case 'Failed to load events':
      return 'Falha ao carregar eventos';
    case 'Loading events':
      return 'A carregar eventos';
    case 'Events unavailable':
      return 'Eventos indisponíveis';
    case 'No events':
      return 'Sem eventos';
    case 'This club has no events for now.':
      return 'Este clube não tem eventos por agora.';
    case 'No more events':
      return 'Sem mais eventos';
    case 'Failed to load event':
      return 'Falha ao carregar evento';
    case 'Event refreshed':
      return 'Evento atualizado';
    case 'Event unavailable':
      return 'Evento indisponível';
    case 'Report event':
      return 'Reportar evento';
    case 'Please describe the event title and reason in the email.':
      return 'Descreva no email o título do evento e o motivo.';
    case 'Organizer':
      return 'Organizador';
    case 'Related Photos':
      return 'Fotografias relacionadas';
    case 'This club has not left contact information yet':
      return 'Este clube ainda não deixou contactos';
    default:
      return '';
  }
}

function japaneseInlineText(enText: string): string {
  switch (enText) {
    case 'Back':
      return '戻る';
    case 'Close':
      return '閉じる';
    case 'Retry':
      return '再試行';
    case 'Refresh':
      return '更新';
    case 'Search':
      return '検索';
    case 'Loading':
      return '読み込み中';
    case 'Open':
      return '開く';
    case 'Links':
      return 'リンク';
    case 'Unable to open link':
      return 'リンクを開けません';
    case 'Not available yet':
      return 'まだ利用できません';
    case 'HarmonyOS Beta Version':
      return 'HarmonyOS ベータ版';
    case 'Send Feedback':
      return 'フィードバック';
    case 'Current version: ':
      return '現在のバージョン: ';
    case 'HarmonyOS beta for HarmonyOS 6.1.0 and later.\nBeta features may be incomplete or buggy. Tap to report via GitHub Issues.':
      return 'HarmonyOS 6.1.0 以降向けのベータ版です。\n一部機能は未完成または不具合がある場合があります。タップして GitHub Issues で報告できます。';
    case 'Search: everything about UM...':
      return '検索: UM に関するすべて...';
    case 'Search UM pages or services':
      return 'UM のページやサービスを検索';
    case 'Search UM websites':
      return 'UM のウェブサイトを検索';
    case 'Calendar Upcoming:':
      return '今後のカレンダー:';
    case 'Next class':
      return '次の授業';
    case 'No upcoming class':
      return '今後の授業はありません';
    case 'Open timetable':
      return '時間割を開く';
    case 'Bulletin':
      return '掲示';
    case 'Check the UM electronic bulletin for latest notices':
      return 'UM 電子掲示で最新のお知らせを確認';
    case 'Harbor new-topic entry. Tapping this bottom tab opens the external Harbor post page and keeps the current page.':
      return 'Harbor 投稿入口です。この下部タブをタップすると外部の Harbor 投稿ページを開き、現在のページは保持されます。';
    case 'Unable to open the new-topic entry':
      return '投稿入口を開けません';
    case 'Bus':
      return 'バス';
    case 'New':
      return '新規';
    case 'Donate':
      return '寄付';
    case 'Login':
      return 'ログイン';
    case 'Home refreshed':
      return 'ホームを更新しました';
    case 'Failed to load calendar':
      return 'カレンダーの読み込みに失敗しました';
    case 'Failed to load feed':
      return 'フィードの読み込みに失敗しました';
    case 'Failed to load more feed':
      return '追加フィードの読み込みに失敗しました';
    case 'Loading home':
      return 'ホームを読み込み中';
    case 'No more content':
      return 'これ以上の内容はありません';
    case 'Load more':
      return 'さらに読み込む';
    case 'Untitled event':
      return '無題のイベント';
    case 'Past':
      return '終了';
    case 'Ending':
      return 'まもなく終了';
    case 'Active':
      return '開催中';
    case 'Web':
      return 'Web';
    case 'Campus Bus':
      return 'キャンパスバス';
    case 'Loading bus data':
      return 'バスデータを読み込み中';
    case 'Unable to load bus data':
      return 'バスデータを読み込めません';
    case 'Bus data refreshed':
      return 'バスデータを更新しました';
    case 'No bus is currently shown':
      return '現在表示できるバスはありません';
    case 'Last refresh: ':
      return '最終更新: ';
    case 'Map':
      return '地図';
    case 'Stops':
      return '停留所';
    case 'Current buses':
      return '現在のバス';
    case 'No bus info':
      return 'バス情報はありません';
    case 'Car Park':
      return '駐車場';
    case 'Car park data refreshed':
      return '駐車場データを更新しました';
    case 'Failed to load car park data':
      return '駐車場データの読み込みに失敗しました';
    case 'Parking target':
      return '利用対象';
    case 'Vehicle type':
      return '車両タイプ';
    case 'Available spaces: ':
      return '空き台数: ';
    case 'Tight':
      return '混雑';
    case 'Search results':
      return '検索結果';
    case 'No search results':
      return '検索結果はありません';
    case 'No results found':
      return '結果が見つかりません';
    case 'Clear search':
      return '検索をクリア';
    case 'Enter a keyword':
      return 'キーワードを入力';
    case 'Enter a keyword first':
      return '先にキーワードを入力してください';
    case 'Actions':
      return '操作';
    case 'Details':
      return '詳細';
    case 'Date':
      return '日付';
    case 'Time':
      return '時間';
    case 'Venue':
      return '場所';
    case 'Location: ':
      return '場所: ';
    case 'Contact':
      return '連絡先';
    case 'Email':
      return 'Email';
    case 'Phone':
      return '電話';
    case 'Fax':
      return 'Fax';
    case 'Language':
      return '言語';
    case 'Audience':
      return '対象';
    case 'Organiser':
      return '主催';
    case 'Co-organiser':
      return '共催';
    case 'Remark':
      return '備考';
    case 'News Detail':
      return 'ニュース詳細';
    case 'No news data':
      return 'ニュースデータがありません';
    case 'No content available':
      return '本文はありません';
    case 'Event Detail':
      return 'イベント詳細';
    case 'Event Details':
      return 'イベント詳細';
    case 'UM Event Detail':
      return 'UM イベント詳細';
    case 'No event data':
      return 'イベントデータがありません';
    case 'No event content available':
      return 'イベント本文はありません';
    case 'Course data refreshed':
      return '科目データを更新しました';
    case 'Failed to load course data':
      return '科目データの読み込みに失敗しました';
    case 'Course mode':
      return '科目モード';
    case 'Faculty':
      return '学部';
    case 'Department':
      return '学科';
    case 'Course actions':
      return '科目操作';
    case 'Timetable':
      return '時間割';
    case 'Courses':
      return '科目';
    case 'Meetings':
      return '授業';
    case 'Status':
      return '状態';
    case 'Conflict':
      return '重複';
    case 'Free':
      return '空き';
    case 'Add':
      return '追加';
    case 'Clear':
      return 'クリア';
    case 'Cancel':
      return 'キャンセル';
    case 'OK':
      return 'OK';
    case 'Method 1':
      return '方法 1';
    case 'Method 2':
      return '方法 2';
    case 'How to start your timetable':
      return '時間割の始め方';
    case 'Use Add to search courses, then add one section or every section of the course.':
      return '追加から科目を検索し、1 つのセクションまたは全セクションを追加します。';
    case 'Search and add manually':
      return '手動で検索して追加';
    case 'Copy the Timetable text from old ISW, paste it below, and import it.':
      return '旧 ISW の Timetable テキストをコピーし、下に貼り付けてインポートします。';
    case 'Open old ISW':
      return '旧 ISW を開く';
    case 'Selected sections with no valid time: ':
      return '有効な時間がない選択済みセクション: ';
    case 'Use the official timetable as the source of truth.':
      return '公式時間割を正として確認してください。';
    case 'Import from ISW text':
      return 'ISW テキストからインポート';
    case 'Break ':
      return '休憩 ';
    case 'Evening':
      return '夜';
    case 'Afternoon':
      return '午後';
    case 'Choose a section':
      return 'セクションを選択';
    case 'Add all sections':
      return '全セクションを追加';
    case 'Chinese searches immediately. English or course code needs at least 3 characters.':
      return '中国語は即時検索されます。英語または科目コードは 3 文字以上必要です。';
    case 'PreEnroll courses':
      return '事前登録科目';
    case 'Add/Drop courses':
      return 'Add/Drop 科目';
    case 'Data version: ':
      return 'データ版: ';
    case 'Use the official timetable Excel as the source of truth. Reviews are for reference.':
      return '公式時間割 Excel を正として確認してください。レビューは参考情報です。';
    case 'Use the actions below to check whether the latest data has been uploaded. If the official date changed but the app did not, restart the app or contact the maintainer.':
      return '下の操作で最新データがアップロード済みか確認できます。公式日付が変わってもアプリが更新されない場合は、アプリを再起動するか管理者に連絡してください。';
    case 'Tap a stop to view its photo. Tap a bus icon to refresh.':
      return '停留所をタップすると写真を表示します。バスアイコンをタップすると更新します。';
    case 'No bus service is currently shown, or the official page returned no plate number.':
      return '現在表示できるバスサービスがないか、公式ページが車両番号を返していません。';
    case 'Unable to open campus map':
      return 'キャンパスマップを開けません';
    case 'No record matches the current filters':
      return '現在のフィルターに一致する記録はありません';
    case 'Reading UM Open Data':
      return 'UM Open Data を読み込み中';
    case 'Unable to load car parks':
      return '駐車場を読み込めません';
    case 'Loading car park data':
      return '駐車場データを読み込み中';
    case 'Update: ':
      return '更新: ';
    case 'News image':
      return 'ニュース画像';
    case 'Event poster':
      return 'イベントポスター';
    case 'Missing club data':
      return 'クラブデータがありません';
    case 'Club Detail':
      return 'クラブ詳細';
    case 'All Events':
      return 'すべてのイベント';
    case 'Events':
      return 'イベント';
    case 'Events refreshed':
      return 'イベントを更新しました';
    case 'Failed to load events':
      return 'イベントの読み込みに失敗しました';
    case 'Loading events':
      return 'イベントを読み込み中';
    case 'Events unavailable':
      return 'イベントを利用できません';
    case 'No events':
      return 'イベントはありません';
    case 'This club has no events for now.':
      return 'このクラブには現在イベントがありません。';
    case 'No more events':
      return 'これ以上のイベントはありません';
    case 'Failed to load event':
      return 'イベントの読み込みに失敗しました';
    case 'Event refreshed':
      return 'イベントを更新しました';
    case 'Event unavailable':
      return 'イベントを利用できません';
    case 'Report event':
      return 'イベントを報告';
    case 'Please describe the event title and reason in the email.':
      return 'メールにイベント名と理由を書いてください。';
    case 'Organizer':
      return '主催者';
    case 'Related Photos':
      return '関連写真';
    case 'This club has not left contact information yet':
      return 'このクラブはまだ連絡先を登録していません';
    case 'What2Reg host is unavailable':
      return 'What2Reg サイトを利用できません';
    case 'Entry is not configured':
      return '入口が未設定です';
    case 'Campus Services':
      return 'キャンパス';
    case 'Reservation Services':
      return '予約サービス';
    case 'Coursework & Development':
      return '学修・発展';
    case 'Recommended for Freshmen':
      return '新入生向け';
    case 'Calendar':
      return '校暦';
    case 'Classroom':
      return '教室';
    case 'Park':
      return '駐車';
    case 'Computer':
      return 'PC 室';
    case 'Library':
      return '図書館';
    case 'UM Pass':
      return 'UM Pass';
    case 'Balance':
      return '印刷残高';
    case 'Lost':
      return '遺失物';
    case 'Vacancies':
      return '求人';
    case 'Menu':
      return '食堂メニュー';
    case 'Canteen Queue':
      return '食堂待ち列';
    case 'Student Union':
      return '学生会';
    case 'More':
      return 'その他';
    case 'Repair':
      return '修理';
    case 'Sports':
      return 'スポーツ';
    case 'Booking':
      return '施設予約';
    case 'Lib Rooms':
      return '図書館室';
    case 'Print':
      return '印刷';
    case 'Feedback':
      return '意見';
    case 'Box':
      return 'ロッカー';
    case 'Certificate':
      return '証明書';
    case 'Moodle':
      return 'Moodle';
    case 'Wiki':
      return 'Wiki';
    case 'What2Reg':
      return 'What2Reg';
    case 'ISW':
      return 'ISW';
    case 'New ISW':
      return '新 ISW';
    case 'PreEnroll':
      return '事前登録';
    case 'PreEnroll Excel':
      return '登録表';
    case 'Add Drop':
      return 'Add Drop';
    case 'Important Dates':
      return '重要日程';
    case 'Whole Person':
      return '全人発展';
    case 'Exchange':
      return '交換留学';
    case 'Scholarship':
      return '奨学金';
    case 'Resource Finder':
      return '資料検索';
    case 'Essay Plan':
      return '論文計画';
    case 'Harbor':
      return 'Harbor';
    case 'Survival':
      return '生活ガイド';
    case 'Mainland':
      return '中国本土生';
    case 'Registration':
      return '新入生登録';
    case 'Package':
      return '案内パック';
    case 'Scam':
      return '詐欺対策';
    case 'RC':
      return 'カレッジ';
    case 'Alumni':
      return '同窓会';
    case 'Organization':
      return '部門';
    case 'Check the bus arrival status':
      return 'キャンパスバスの到着状況を確認';
    case 'Check the UM calendar release page':
      return 'UM 校暦の公開ページを確認';
    case 'Check the UM campus map':
      return 'UM キャンパスマップを確認';
    case 'Check the current classroom occupancy':
      return '現在の教室利用状況を確認';
    case 'Check the remaining parking spaces in UM':
      return 'UM 駐車場の残り台数を確認';
    case 'Check the usage of E6 computer room':
      return 'E6 PC 室の利用状況を確認';
    case 'Go directly to the library homepage to check occupancy and search resources':
      return '図書館ホームページで混雑状況や資料検索を確認';
    case 'Enter the UM PASS settings page':
      return 'UM PASS 設定ページを開く';
    case 'Check the balance of printing services in UM':
      return 'UM 印刷サービスの残高を確認';
    case 'Check the official lost and found list of UM':
      return 'UM 公式の遺失物一覧を確認';
    case 'Check recruitment posted by UM and other companies':
      return 'UM や関連企業の求人情報を確認';
    case 'Check the UM college menu':
      return 'UM カレッジのメニューを確認';
    case 'Check the current queue count at LCWC W22 canteen':
      return 'LCWC W22 食堂の現在の待ち人数を確認';
    case 'Check the UM student union announcement page':
      return 'UM 学生会のお知らせページを確認';
    case 'Enter the UM MyUM webpage to view the full functions':
      return 'MyUM ページで全機能を確認';
    case 'Enter the CMMS repair system to request facility repairs':
      return 'CMMS 修理システムで施設修理を申請';
    case 'Reserve the use of UM sports venues':
      return 'UM スポーツ施設を予約';
    case 'Reserve rooms and venues in buildings such as E6':
      return 'E6 などの建物の部屋・会場を予約';
    case 'Reserve library rooms':
      return '図書館の部屋を予約';
    case 'Upload files online and print with Web Print printers':
      return 'オンラインでファイルをアップロードし、Web Print 対応プリンターで印刷';
    case 'Provide feedback to UM departments and receive responses':
      return 'UM 各部門へ意見を送り、回答を受け取る';
    case 'Rent storage lockers in teaching buildings':
      return '教学棟のロッカーを借りる';
    case 'Apply for UM parking monthly pass':
      return 'UM 駐車場の月極パスを申請';
    case 'Apply for UM certificates and student card replacement':
      return 'UM 関連証明書や学生証再発行を申請';
    case 'UM Moodle for courses, assignments and deadlines':
      return '授業、課題、締切を確認する UM Moodle';
    case 'ARK Wiki for UM information, guides and learning methods':
      return 'UM 情報、攻略、学習方法をまとめた ARK Wiki';
    case 'ARK timetable simulation for course planning':
      return '履修計画用の ARK 時間割シミュレーション';
    case 'What2Reg, a course review website developed by UM Helper':
      return 'UM Helper が開発した授業レビューサイト What2Reg';
    case 'Old ISW for grades, timetable, payments and profile settings':
      return '成績、時間割、支払い、個人情報設定に使う旧 ISW';
    case 'New version of ISW':
      return '新しい ISW';
    case 'Pre-enrollment website entrance':
      return '事前登録サイトの入口';
    case 'UM pre-enrollment form and course schedule release page':
      return 'UM 事前登録表と開講時間表の公開ページ';
    case 'Add Drop course entrance before semester starts':
      return '学期開始前の Add/Drop 科目入口';
    case 'Check UM important academic dates':
      return '事前登録、Add/Drop、試験などの重要日程を確認';
    case 'Whole Person Development Program entrance':
      return '全人発展プログラムの入口';
    case 'Apply for UM outbound exchange programs':
      return 'UM の海外交換プログラムを申請';
    case 'Check the UM scholarship introduction page':
      return 'UM 奨学金の紹介ページを確認';
    case 'Search library resources, papers and textbooks':
      return '図書館資料、論文、教科書を検索';
    case 'Your essay planning assistant':
      return '論文計画を支援するツール';
    case 'ARK Harbor forum for careers, food, alumni and more':
      return '就職、食事、同窓生情報などを扱う ARK Harbor フォーラム';
    case 'Historical posts from the UM Survival Guide public account':
      return 'UM 生活ガイド公式アカウントの過去投稿';
    case 'Guide suggestions for mainland freshmen':
      return '中国本土からの新入生向けガイド';
    case 'New Student Registration Package and related materials':
      return '新入生登録案内パックと関連資料';
    case 'UM official freshman package including EELC requirements':
      return 'EELC 要件などを含む UM 公式の新入生案内パック';
    case 'Anti-fraud package for students arriving in Macau':
      return 'マカオ到着直後の学生向け詐欺対策案内';
    case 'A college list to quickly find college homepages':
      return '各カレッジのホームページを素早く探す一覧';
    case 'UM Alumni Association and related alumni information':
      return 'UM 同窓会と関連情報';
    case 'UM Departments with information on campus offices':
      return 'キャンパス内各部門の情報';
    default:
      return '';
  }
}

export class I18nService {
  static normalizeLanguage(language: string): string {
    if (isSupportedLanguage(language)) {
      return language;
    }
    return LANGUAGE_SC;
  }

  static isSimplifiedChinese(language: string): boolean {
    return I18nService.normalizeLanguage(language) === LANGUAGE_SC;
  }

  static isEnglishLike(language: string): boolean {
    const normalizedLanguage: string = I18nService.normalizeLanguage(language);
    return normalizedLanguage === LANGUAGE_EN || normalizedLanguage === LANGUAGE_PT ||
    normalizedLanguage === LANGUAGE_JA;
  }

  static toSimplifiedText(text: string): string {
    return toSimplifiedChinese(text);
  }

  static localizeDataText(language: string, tcText: string, enText: string = ''): string {
    const normalizedLanguage: string = I18nService.normalizeLanguage(language);
    if (normalizedLanguage === LANGUAGE_TC) {
      return tcText;
    }
    if (normalizedLanguage === LANGUAGE_SC) {
      return toSimplifiedChinese(tcText);
    }
    if (enText.length > 0 && enText !== tcText) {
      return enText;
    }
    return toSimplifiedChinese(tcText);
  }

  static getDefaultLanguage(context: common.UIAbilityContext): string {
    const systemLanguage: string = getSystemLanguage(context);
    if (systemLanguage.startsWith('zh')) {
      if (systemLanguage.includes('hant') || systemLanguage.includes('-hk') || systemLanguage.includes('-mo') ||
        systemLanguage.includes('-tw')) {
        return LANGUAGE_TC;
      }
      return LANGUAGE_SC;
    }
    if (systemLanguage.startsWith('pt')) {
      return LANGUAGE_PT;
    }
    if (systemLanguage.startsWith('ja')) {
      return LANGUAGE_JA;
    }
    if (systemLanguage.startsWith('en')) {
      return LANGUAGE_EN;
    }
    return LANGUAGE_SC;
  }

  static async loadLanguage(context: common.UIAbilityContext): Promise<string> {
    const storedLanguage: string =
      normalizeStoredLanguage(await PreferencesStore.getString(context, STORAGE_LANGUAGE, ''));
    if (storedLanguage.length > 0) {
      return storedLanguage;
    }
    return I18nService.getDefaultLanguage(context);
  }

  static async setLanguage(context: common.UIAbilityContext, language: string): Promise<void> {
    const normalizedLanguage: string = I18nService.normalizeLanguage(language);
    await PreferencesStore.set(context, STORAGE_LANGUAGE, normalizedLanguage);
    try {
      context.getApplicationContext().setLanguage(getSystemTag(normalizedLanguage));
    } catch (error) {
      Logger.warn('Apply language failed: ' + String(error));
    }
  }

  static t(language: string, key: string, fallback: string = ''): string {
    const normalizedLanguage: string = I18nService.normalizeLanguage(language);
    let value: string = '';
    switch (normalizedLanguage) {
      case LANGUAGE_SC:
        value = zhCnText(key);
        break;
      case LANGUAGE_EN:
        value = enUsText(key);
        break;
      case LANGUAGE_PT:
        value = ptPtText(key);
        break;
      case LANGUAGE_JA:
        value = jaJpText(key);
        break;
      case LANGUAGE_TC:
      default:
        value = zhHkText(key);
        break;
    }
    if (value.length > 0) {
      return value;
    }
    return fallback.length > 0 ? fallback : key;
  }

  static localizeText(language: string, tcText: string, enText: string, ptText: string = '',
    jaText: string = ''): string {
    const normalizedLanguage: string = I18nService.normalizeLanguage(language);
    if (normalizedLanguage === LANGUAGE_TC) {
      return tcText;
    }
    if (normalizedLanguage === LANGUAGE_SC) {
      return toSimplifiedChinese(tcText);
    }
    if (normalizedLanguage === LANGUAGE_PT) {
      const translated: string = ptText.length > 0 ? ptText : portugueseInlineText(enText);
      return translated.length > 0 ? translated : enText;
    }
    if (normalizedLanguage === LANGUAGE_JA) {
      const translated: string = jaText.length > 0 ? jaText : japaneseInlineText(enText);
      return translated.length > 0 ? translated : enText;
    }
    return enText;
  }
}
