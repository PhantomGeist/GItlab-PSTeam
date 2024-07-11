import mountSubscriptionsApplication from 'ee/subscriptions/buy_minutes';
import { trackAddToCartUsageTab } from 'ee/google_tag_manager';

mountSubscriptionsApplication(document.getElementById('js-buy-minutes'));
trackAddToCartUsageTab();
