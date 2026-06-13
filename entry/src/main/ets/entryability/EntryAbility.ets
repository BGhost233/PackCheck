import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BLACK, PAGE_BG } from '../constants/Colors';

const DOMAIN = 0x0001;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (error) {
      hilog.warn(DOMAIN, 'PackCheck', 'Failed to set color mode. Cause: %{public}s', JSON.stringify(error));
    }
    hilog.info(DOMAIN, 'PackCheck', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'PackCheck', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'PackCheck', '%{public}s', 'Ability onWindowStageCreate');

    // 真沉浸式：开启全屏布局，系统栏透明、内容穿透显示。
    // 全屏后系统不再自动避让，状态栏/导航条高度由 Index 取 AvoidArea 下发各折叠头补 padding。
    // ⚠️ 不再设 statusBarColor / navigationBarColor（设了会渲染不透明色块，造成「两层割裂」）。
    try {
      const mainWindow = windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(true);
      mainWindow.setWindowBackgroundColor(PAGE_BG);
      mainWindow.setWindowSystemBarProperties({
        statusBarContentColor: BLACK,
        navigationBarContentColor: BLACK
      });
    } catch (error) {
      hilog.warn(DOMAIN, 'PackCheck', 'Failed to set window properties. Cause: %{public}s', JSON.stringify(error));
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'PackCheck', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'PackCheck', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'PackCheck', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'PackCheck', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'PackCheck', '%{public}s', 'Ability onBackground');
  }
}
