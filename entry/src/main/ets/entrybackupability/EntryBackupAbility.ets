import { hilog } from '@kit.PerformanceAnalysisKit';
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';

const DOMAIN = 0x0001;

export default class EntryBackupAbility extends BackupExtensionAbility {
  onBackup() {
    hilog.info(DOMAIN, 'PackCheck', 'onBackup ok');
  }

  onRestore(bundleVersion: BundleVersion) {
    hilog.info(DOMAIN, 'PackCheck', 'onRestore ok %{public}s', JSON.stringify(bundleVersion));
  }
}