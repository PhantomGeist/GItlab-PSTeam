import Vue from 'vue';
import VueApollo from 'vue-apollo';

import apolloProvider from 'ee/usage_quotas/shared/provider';

import ProductAnalyticsUsageQuotaApp from './components/product_analytics_usage_quota_app.vue';

Vue.use(VueApollo);

export default (containerId = 'js-product-analytics-usage-quota-app') => {
  const el = document.getElementById(containerId);

  if (!el) {
    return false;
  }

  const { namespacePath } = el.dataset;

  return new Vue({
    el,
    apolloProvider,
    name: 'ProductAnalyticsUsageQuotaRoot',
    provide: {
      namespacePath,
    },
    render(createElement) {
      return createElement(ProductAnalyticsUsageQuotaApp);
    },
  });
};
