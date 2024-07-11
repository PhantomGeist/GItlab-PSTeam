import '~/pages/registrations/new';
import { trackNewRegistrations } from 'ee/google_tag_manager';
import initPasswordValidator from 'ee/password/password_validator';
import { setupArkoseLabsForSignup } from 'ee/arkose_labs';

trackNewRegistrations();

// Warning: initPasswordValidator has to run after initPasswordInput
// (which is executed when '~/pages/registrations/new' is imported)
initPasswordValidator();

if (gon.features.arkoseLabsSignupChallenge) {
  setupArkoseLabsForSignup();
}
