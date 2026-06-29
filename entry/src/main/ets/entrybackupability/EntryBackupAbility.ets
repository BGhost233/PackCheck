import { hilog } from '@kit.PerformanceAnalysisKit';
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';

const DOMAIN = 0x0001;
const TAG = 'PackCheck:Backup';

/**
 * PackCheck 备份恢复扩展能力。
 *
 * 数据持久化策略：全部数据存储在 Preferences（packcheck_store），
 * 位于 el2/base/preferences/ 路径下，属于框架默认备份范围。
 * 因此 onBackup/onRestore 不需要手动序列化——框架自动完成文件级备份恢复。
 *
 * 本实现仅用于：
 * - 备份时记录日志 + 返回成功状态
 * - 恢复时记录来源版本信息，辅助跨版本恢复的调试
 */

interface BackupResultInfo {
  type: string;
  errorCode: number;
  errorInfo: string;
}

export default class EntryBackupAbility extends BackupExtensionAbility {

  /**
   * 备份准备阶段回调。
   * Preferences 文件由框架自动打包，此处仅记录日志并返回成功状态。
   */
  async onBackupEx(backupInfo: string): Promise<string> {
    hilog.info(DOMAIN, TAG, 'onBackupEx start, backupInfo=%{public}s',
      backupInfo ? backupInfo : '(empty)');

    const result: BackupResultInfo = {
      type: 'BackupResult',
      errorCode: 0,
      errorInfo: 'PackCheck backup completed successfully'
    };

    hilog.info(DOMAIN, TAG, 'onBackupEx end');
    return JSON.stringify(result);
  }

  /**
   * 恢复完成阶段回调。
   * 框架已将 Preferences 文件恢复到原路径，PackStore 下次 init 时会直接读取。
   * 此处记录来源版本信息，便于排查跨版本兼容问题。
   */
  async onRestoreEx(bundleVersion: BundleVersion, restoreInfo: string): Promise<string> {
    hilog.info(DOMAIN, TAG,
      'onRestoreEx start, bundleVersion=%{public}s, restoreInfo=%{public}s',
      JSON.stringify(bundleVersion),
      restoreInfo ? restoreInfo : '(empty)');

    const result: BackupResultInfo = {
      type: 'RestoreResult',
      errorCode: 0,
      errorInfo: `PackCheck restore completed from version ${bundleVersion.name}(${bundleVersion.code})`
    };

    hilog.info(DOMAIN, TAG, 'onRestoreEx end');
    return JSON.stringify(result);
  }
}
