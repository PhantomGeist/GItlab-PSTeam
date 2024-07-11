import '~/pages/admin/application_settings/general/index';
import initAddLicenseApp from 'ee/admin/application_settings/general/add_license';
import { initScimTokenApp } from 'ee/saml_sso';
import { initAdminDeletionProtectionSettings } from 'ee/admin/application_settings/deletion_protection';
import { initMaintenanceModeSettings } from 'ee/maintenance_mode_settings';
import { initServicePingSettingsClickTracking } from 'ee/registration_features_discovery_message';
import { initInputCopyToggleVisibility } from '~/vue_shared/components/form';

initAdminDeletionProtectionSettings();
initMaintenanceModeSettings();
initServicePingSettingsClickTracking();
initAddLicenseApp();
initScimTokenApp();
initInputCopyToggleVisibility();
