import { initSamlAuthorize, redirectUserWithSSOIdentity } from 'ee/saml_sso';
import UsernameValidator from '~/pages/sessions/new/username_validator';
import initConfirmDanger from '~/init_confirm_danger';
import { initLanguageSwitcher } from '~/language_switcher';
import { renderGFM } from '~/behaviors/markdown/render_gfm';

new UsernameValidator(); // eslint-disable-line no-new
initSamlAuthorize();
redirectUserWithSSOIdentity();
initConfirmDanger();
initLanguageSwitcher();
renderGFM(document.body);
