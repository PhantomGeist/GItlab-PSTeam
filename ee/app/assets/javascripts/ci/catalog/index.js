import Vue from 'vue';
import VueApollo from 'vue-apollo';

import { __, s__ } from '~/locale';
import createDefaultClient from '~/lib/graphql';
import { createRouter } from '~/ci/catalog/router';
import { cacheConfig, resolvers } from '~/ci/catalog/graphql/settings';
import CiNamespaceCatalogApp from './ci_namespace_catalog_app.vue';
import CiResourcesPage from './components/pages/ci_resources_page.vue';

export const initNamespaceCatalog = (selector = '#js-ci-namespace-catalog') => {
  const el = document.querySelector(selector);

  if (!el) {
    return null;
  }

  const { dataset } = el;
  const { ciCatalogPath, projectFullPath } = dataset;

  Vue.use(VueApollo);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(resolvers, cacheConfig),
  });

  return new Vue({
    el,
    name: 'CiCatalogRoot',
    apolloProvider,
    router: createRouter(ciCatalogPath, CiResourcesPage),
    provide: {
      ciCatalogPath,
      projectFullPath,
      pageTitle: __('CI/CD Catalog'),
      pageDescription: s__(
        'CiCatalog|Repositories of pipeline components available in this namespace.',
      ),
    },
    render(h) {
      return h(CiNamespaceCatalogApp);
    },
  });
};
