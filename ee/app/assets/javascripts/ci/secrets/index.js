import Vue from 'vue';
import VueRouter from 'vue-router';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import GroupSecretsApp from './group_secrets_app.vue';
import ProjectSecretsApp from './project_secrets_app.vue';

Vue.use(VueRouter);
Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

const initSecretsApp = (el, app, props) => {
  return new Vue({
    el,
    name: 'SecretsRoot',
    apolloProvider,
    render(createElement) {
      return createElement(app, { props });
    },
  });
};

export const initGroupSecretsApp = () => {
  const el = document.querySelector('#js-group-secrets-manager');

  if (!el) {
    return false;
  }

  const { groupPath, groupId } = el.dataset;

  return initSecretsApp(el, GroupSecretsApp, { groupPath, groupId });
};

export const initProjectSecretsApp = () => {
  const el = document.querySelector('#js-project-secrets-manager');

  if (!el) {
    return false;
  }

  const { projectPath, projectId } = el.dataset;

  return initSecretsApp(el, ProjectSecretsApp, { projectPath, projectId });
};
