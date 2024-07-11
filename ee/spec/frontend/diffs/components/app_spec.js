import { shallowMount } from '@vue/test-utils';

import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import getMRCodequalityAndSecurityReports from '~/diffs/components/graphql/get_mr_codequality_and_security_reports.query.graphql';
import { TEST_HOST } from 'spec/test_constants';
import App from '~/diffs/components/app.vue';
import store from '~/mr_notes/stores';

const TEST_ENDPOINT = `${TEST_HOST}/diff/endpoint`;

jest.mock('~/mr_notes/stores', () => jest.requireActual('helpers/mocks/mr_notes/stores'));
Vue.use(VueApollo);
Vue.config.ignoredElements = ['copy-code'];

describe('diffs/components/app', () => {
  let mockDispatch;
  let fakeApollo;

  const codeQualityAndSastQueryHandlerSuccess = jest.fn().mockResolvedValue({});

  const createComponent = (props = {}, baseConfig = {}, flags = {}) => {
    store.reset();
    store.getters.isNotesFetched = false;
    store.getters.getNoteableData = {
      current_user: {
        can_create_note: true,
      },
    };
    store.getters['findingsDrawer/activeDrawer'] = {};
    store.getters['diffs/flatBlobsList'] = [];
    store.getters['diffs/isBatchLoading'] = false;
    store.getters['diffs/isBatchLoadingError'] = false;
    store.getters['diffs/whichCollapsedTypes'] = { any: false };

    store.state.diffs.isLoading = false;
    store.state.findingsDrawer = { activeDrawer: false };

    store.state.diffs.isTreeLoaded = true;

    store.dispatch('diffs/setBaseConfig', {
      endpoint: TEST_ENDPOINT,
      endpointMetadata: `${TEST_HOST}/diff/endpointMetadata`,
      endpointBatch: `${TEST_HOST}/diff/endpointBatch`,
      endpointDiffForPath: TEST_ENDPOINT,
      projectPath: 'namespace/project',
      dismissEndpoint: '',
      showSuggestPopover: true,
      mrReviews: {},
      ...baseConfig,
    });

    mockDispatch = jest.spyOn(store, 'dispatch');

    fakeApollo = createMockApollo([
      [getMRCodequalityAndSecurityReports, codeQualityAndSastQueryHandlerSuccess],
    ]);

    return shallowMount(App, {
      apolloProvider: fakeApollo,
      provide: {
        glFeatures: {
          ...flags,
        },
      },
      propsData: {
        endpointCoverage: `${TEST_HOST}/diff/endpointCoverage`,
        endpointCodequality: '',
        sastReportAvailable: false,
        currentUser: {},
        changesEmptyStateIllustration: '',
        ...props,
      },
      mocks: {
        $store: store,
      },
    });
  };

  describe('EE codequality diff', () => {
    describe('sastReportsInInlineDiff flag off', () => {
      it('fetches Code Quality data via REST and not via GraphQL when endpoint is provided', () => {
        createComponent({
          shouldShow: true,
          endpointCodequality: `${TEST_HOST}/diff/endpointCodequality`,
        });
        expect(codeQualityAndSastQueryHandlerSuccess).not.toHaveBeenCalled();
        expect(mockDispatch).toHaveBeenCalledWith('diffs/fetchCodequality');
      });

      it('does not fetch code quality data when endpoint is blank', () => {
        createComponent({ shouldShow: true, endpointCodequality: '' });

        expect(mockDispatch).not.toHaveBeenCalledWith('diffs/fetchCodequality');
        expect(codeQualityAndSastQueryHandlerSuccess).not.toHaveBeenCalled();
      });
    });

    describe('sastReportsInInlineDiff flag on', () => {
      it('fetches Code Quality data via GraphQL and not rest when endpoint is provided', () => {
        createComponent(
          { shouldShow: true, endpointCodequality: `${TEST_HOST}/diff/endpointCodequality` },
          {},
          { sastReportsInInlineDiff: true },
        );

        expect(codeQualityAndSastQueryHandlerSuccess).toHaveBeenCalledTimes(1);
        expect(mockDispatch).not.toHaveBeenCalledWith('diffs/fetchCodequality');
      });

      it('does not fetch code quality data when endpoint is blank', () => {
        createComponent(
          { shouldShow: false, endpointCodequality: '' },
          {},
          { sastReportsInInlineDiff: true },
        );
        expect(codeQualityAndSastQueryHandlerSuccess).not.toHaveBeenCalled();
        expect(mockDispatch).not.toHaveBeenCalledWith('diffs/fetchCodequality');
      });
    });
  });

  describe('EE SAST diff', () => {
    describe('sastReportsInInlineDiff flag off', () => {
      it('does not fetch SAST data when sastReportAvailable is true', () => {
        createComponent({ shouldShow: true, sastReportAvailable: true });
        expect(codeQualityAndSastQueryHandlerSuccess).not.toHaveBeenCalled();
      });

      it('does not fetch SAST data when sastReportAvailable is false', () => {
        createComponent({ shouldShow: false, sastReportAvailable: false });

        expect(codeQualityAndSastQueryHandlerSuccess).not.toHaveBeenCalled();
      });
    });

    describe('sastReportsInInlineDiff flag on', () => {
      it('fetches SAST data when sastReportAvailable is true', () => {
        createComponent(
          { shouldShow: true, sastReportAvailable: true },
          {},
          { sastReportsInInlineDiff: true },
        );

        expect(codeQualityAndSastQueryHandlerSuccess).toHaveBeenCalledTimes(1);
      });

      it('does not fetch SAST data when sastReportAvailable is false', () => {
        createComponent({ shouldShow: false }, {}, { sastReportsInInlineDiff: true });
        expect(codeQualityAndSastQueryHandlerSuccess).not.toHaveBeenCalled();
      });
    });
  });
});
