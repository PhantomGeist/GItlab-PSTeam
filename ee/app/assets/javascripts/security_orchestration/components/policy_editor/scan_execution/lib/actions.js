import { REPORT_TYPE_DAST } from '~/vue_shared/security_reports/constants';

export function buildScannerAction({ scanner, siteProfile = '', scannerProfile = '' }) {
  const action = { scan: scanner };

  if (scanner === REPORT_TYPE_DAST) {
    action.site_profile = siteProfile;
    action.scanner_profile = scannerProfile;
  }

  return action;
}
