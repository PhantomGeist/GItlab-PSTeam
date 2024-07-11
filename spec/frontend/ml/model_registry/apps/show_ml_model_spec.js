import { GlBadge, GlTab } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { ShowMlModel } from '~/ml/model_registry/apps';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';
import { NO_VERSIONS_LABEL } from '~/ml/model_registry/translations';
import { MODEL, makeModel } from '../mock_data';

let wrapper;
const createWrapper = (model = MODEL) => {
  wrapper = shallowMount(ShowMlModel, { propsData: { model } });
};

const findDetailTab = () => wrapper.findAllComponents(GlTab).at(0);
const findVersionsTab = () => wrapper.findAllComponents(GlTab).at(1);
const findVersionsCountBadge = () => findVersionsTab().findComponent(GlBadge);
const findCandidateTab = () => wrapper.findAllComponents(GlTab).at(2);
const findCandidatesCountBadge = () => findCandidateTab().findComponent(GlBadge);
const findTitleArea = () => wrapper.findComponent(TitleArea);
const findVersionCountMetadataItem = () => findTitleArea().findComponent(MetadataItem);

describe('ShowMlModel', () => {
  describe('Title', () => {
    beforeEach(() => createWrapper());

    it('title is set to model name', () => {
      expect(findTitleArea().props('title')).toBe(MODEL.name);
    });

    it('subheader is set to description', () => {
      expect(findTitleArea().text()).toContain(MODEL.description);
    });

    it('sets version metadata item to version count', () => {
      expect(findVersionCountMetadataItem().props('text')).toBe(`${MODEL.versionCount} versions`);
    });
  });

  describe('Details', () => {
    beforeEach(() => createWrapper());

    it('has a details tab', () => {
      expect(findDetailTab().attributes('title')).toBe('Details');
    });

    describe('when it has latest version', () => {
      it('displays the version', () => {
        expect(findDetailTab().text()).toContain(MODEL.latestVersion.version);
      });
    });

    describe('when it does not have latest version', () => {
      beforeEach(() => {
        createWrapper(makeModel({ latestVersion: null }));
      });

      it('shows no version message', () => {
        expect(findDetailTab().text()).toContain(NO_VERSIONS_LABEL);
      });
    });
  });

  describe('Versions tab', () => {
    beforeEach(() => createWrapper());

    it('shows the number of versions in the tab', () => {
      expect(findVersionsCountBadge().text()).toBe(MODEL.versionCount.toString());
    });
  });

  describe('Candidates tab', () => {
    beforeEach(() => createWrapper());

    it('shows the number of candidates in the tab', () => {
      expect(findCandidatesCountBadge().text()).toBe(MODEL.candidateCount.toString());
    });
  });
});
