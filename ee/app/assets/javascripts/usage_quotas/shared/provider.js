import VueApollo from 'vue-apollo';
import createClient from '~/lib/graphql';
import { createCustomersDotClient } from 'ee/lib/customers_dot_graphql';

const gitlabClient = createClient();
const customersDotClient = createCustomersDotClient();

export default new VueApollo({
  defaultClient: gitlabClient,
  clients: {
    gitlabClient,
    customersDotClient,
  },
});
