import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { resourceManager } from '@kit.LocalizationKit';
import { errorResult, ServiceResult } from '../net/HttpClient';
import { Logger } from '../utils/Logger';

function okResult<T>(data: T): ServiceResult<T> {
  return {
    ok: true,
    data: data
  };
}

export class RawFileReader {
  static async readBytes(context: common.Context, path: string): Promise<ServiceResult<Uint8Array>> {
    try {
      const manager: resourceManager.ResourceManager = context.resourceManager;
      const content: Uint8Array = await manager.getRawFileContent(path);
      return okResult<Uint8Array>(content);
    } catch (error) {
      Logger.error('Rawfile read failed: ' + path + ', ' + String(error));
      return errorResult<Uint8Array>('RAWFILE_READ_ERROR', '无法读取内置资源：' + path);
    }
  }

  static decodeUtf8(content: Uint8Array): string {
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8', {
      fatal: false,
      ignoreBOM: true
    });
    return decoder.decodeWithStream(content);
  }

  static async readText(context: common.Context, path: string): Promise<ServiceResult<string>> {
    const bytesResult: ServiceResult<Uint8Array> = await RawFileReader.readBytes(context, path);
    if (!bytesResult.ok || !bytesResult.data) {
      return {
        ok: false,
        error: bytesResult.error
      };
    }

    try {
      return okResult<string>(RawFileReader.decodeUtf8(bytesResult.data));
    } catch (error) {
      Logger.error('Rawfile decode failed: ' + path + ', ' + String(error));
      return errorResult<string>('RAWFILE_DECODE_ERROR', '内置资源编码解析失败：' + path);
    }
  }

  static async readJson<T>(context: common.Context, path: string): Promise<ServiceResult<T>> {
    const textResult: ServiceResult<string> = await RawFileReader.readText(context, path);
    if (!textResult.ok || !textResult.data) {
      return {
        ok: false,
        error: textResult.error
      };
    }

    try {
      return okResult<T>(JSON.parse(textResult.data) as T);
    } catch (error) {
      Logger.error('Rawfile JSON parse failed: ' + path + ', ' + String(error));
      return errorResult<T>('RAWFILE_JSON_PARSE_ERROR', '内置 JSON 解析失败：' + path);
    }
  }
}
