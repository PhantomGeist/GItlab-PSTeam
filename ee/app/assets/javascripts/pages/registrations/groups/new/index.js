/* eslint-disable no-new */

import mountComponents from 'ee/registrations/groups/new';
import Group from '~/group';
import { trackCombinedGroupProjectForm, trackProjectImport } from 'ee/google_tag_manager';

new Group();
mountComponents();
trackCombinedGroupProjectForm();
trackProjectImport();
