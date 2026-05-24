import { Want } from '@kit.AbilityKit';
import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';
import { Logger } from '../common/utils/Logger';
import { NextClassCardData, NextClassCardService } from '../services/NextClassCardService';

function emptyBindingRecord(): Record<string, string> {
  const data: NextClassCardData = NextClassCardService.emptyData();
  return {
    'hasCourse': data.hasCourse,
    'title': data.title,
    'courseCode': data.courseCode,
    'timeText': data.timeText,
    'locationText': data.locationText
  };
}

export default class NextClassFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = this.getFormId(want);
    this.registerAndUpdateForm(formId);
    return formBindingData.createFormBindingData(emptyBindingRecord());
  }

  onUpdateForm(formId: string): void {
    this.registerAndUpdateForm(formId);
  }

  onRemoveForm(formId: string): void {
    this.unregisterForm(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  private getFormId(want: Want): string {
    if (want.parameters === undefined) {
      return '';
    }
    const value: Object | undefined = want.parameters[formInfo.FormParam.IDENTITY_KEY];
    if (value === undefined || value === null) {
      return '';
    }
    return value.toString();
  }

  private async registerAndUpdateForm(formId: string): Promise<void> {
    try {
      await NextClassCardService.registerForm(this.context, formId);
      await NextClassCardService.updateForm(this.context, formId);
    } catch (error) {
      Logger.warn('Next class form add failed: ' + formId + ', ' + String(error));
    }
  }

  private async updateForm(formId: string): Promise<void> {
    try {
      await NextClassCardService.updateForm(this.context, formId);
    } catch (error) {
      Logger.warn('Next class form update failed: ' + formId + ', ' + String(error));
    }
  }

  private async unregisterForm(formId: string): Promise<void> {
    try {
      await NextClassCardService.unregisterForm(this.context, formId);
    } catch (error) {
      Logger.warn('Next class form remove failed: ' + formId + ', ' + String(error));
    }
  }
}
