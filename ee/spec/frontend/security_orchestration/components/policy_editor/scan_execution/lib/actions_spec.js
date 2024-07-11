import { buildScannerAction } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/actions';
import { REPORT_TYPE_DAST } from '~/vue_shared/security_reports/constants';

describe('buildScannerAction', () => {
  describe('DAST', () => {
    it('returns a DAST scanner action with empty profiles', () => {
      expect(buildScannerAction({ scanner: REPORT_TYPE_DAST })).toEqual({
        scan: REPORT_TYPE_DAST,
        site_profile: '',
        scanner_profile: '',
      });
    });

    it('returns a DAST scanner action with filled profiles', () => {
      const siteProfile = 'test_site_profile';
      const scannerProfile = 'test_scanner_profile';

      expect(
        buildScannerAction({ scanner: REPORT_TYPE_DAST, siteProfile, scannerProfile }),
      ).toEqual({
        scan: REPORT_TYPE_DAST,
        site_profile: siteProfile,
        scanner_profile: scannerProfile,
      });
    });
  });

  describe('non-DAST', () => {
    it('returns a non-DAST scanner action', () => {
      const scanner = 'sast';
      expect(buildScannerAction({ scanner })).toEqual({
        scan: scanner,
      });
    });
  });
});
