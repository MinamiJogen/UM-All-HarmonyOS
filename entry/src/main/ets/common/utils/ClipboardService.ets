import { pasteboard } from '@kit.BasicServicesKit';
import { Logger } from './Logger';

export class ClipboardService {
  static async copyText(text: string): Promise<boolean> {
    try {
      const data: pasteboard.PasteData = pasteboard.createPlainTextData(text);
      await pasteboard.getSystemPasteboard().setData(data);
      return true;
    } catch (error) {
      Logger.error('Clipboard copy failed: ' + String(error));
      return false;
    }
  }
}
