import Vue from 'vue';
import { escape, minBy } from 'lodash';
import emojiRegexFactory from 'emoji-regex';
import emojiAliases from 'emojis/aliases.json';
import createApolloClient from '~/lib/graphql';
import { setAttributes } from '~/lib/utils/dom_utils';
import { getEmojiScoreWithIntent } from '~/emoji/utils';
import AccessorUtilities from '../lib/utils/accessor';
import axios from '../lib/utils/axios_utils';
import customEmojiQuery from './queries/custom_emoji.query.graphql';
import { CACHE_KEY, CACHE_VERSION_KEY, CATEGORY_NAMES, FREQUENTLY_USED_KEY } from './constants';

let emojiMap = null;
let validEmojiNames = null;

export const state = Vue.observable({
  loading: true,
});

export const FALLBACK_EMOJI_KEY = 'grey_question';

// Keep the version in sync with `lib/gitlab/emoji.rb`
export const EMOJI_VERSION = '3';

const isLocalStorageAvailable = AccessorUtilities.canUseLocalStorage();

async function loadEmoji() {
  if (
    isLocalStorageAvailable &&
    window.localStorage.getItem(CACHE_VERSION_KEY) === EMOJI_VERSION &&
    window.localStorage.getItem(CACHE_KEY)
  ) {
    return JSON.parse(window.localStorage.getItem(CACHE_KEY));
  }

  // We load the JSON file direct from the server
  // because it can't be loaded from a CDN due to
  // cross domain problems with JSON
  const { data } = await axios.get(
    `${gon.relative_url_root || ''}/-/emojis/${EMOJI_VERSION}/emojis.json`,
  );

  try {
    window.localStorage.setItem(CACHE_VERSION_KEY, EMOJI_VERSION);
    window.localStorage.setItem(CACHE_KEY, JSON.stringify(data));
  } catch {
    // Setting data in localstorage may fail when storage quota is exceeded.
    // We should continue even when this fails.
  }

  return data;
}

async function loadEmojiWithNames() {
  const emojiRegex = emojiRegexFactory();

  return (await loadEmoji()).reduce(
    (acc, emoji) => {
      // Filter out entries which aren't emojis
      if (emoji.e.match(emojiRegex)?.[0] === emoji.e) {
        acc.emojis[emoji.n] = { ...emoji, name: emoji.n };
        acc.names.push(emoji.n);
      }
      return acc;
    },
    { emojis: {}, names: [] },
  );
}

export async function loadCustomEmojiWithNames() {
  if (document.body?.dataset?.groupFullPath && window.gon?.features?.customEmoji) {
    const client = createApolloClient();
    const { data } = await client.query({
      query: customEmojiQuery,
      variables: {
        groupPath: document.body.dataset.groupFullPath,
      },
    });

    return data?.group?.customEmoji?.nodes?.reduce(
      (acc, e) => {
        // Map the custom emoji into the format of the normal emojis
        acc.emojis[e.name] = {
          c: 'custom',
          d: e.name,
          e: undefined,
          name: e.name,
          src: e.url,
          u: 'custom',
        };
        acc.names.push(e.name);

        return acc;
      },
      { emojis: {}, names: [] },
    );
  }

  return { emojis: {}, names: [] };
}

async function prepareEmojiMap() {
  return Promise.all([loadEmojiWithNames(), loadCustomEmojiWithNames()]).then((values) => {
    emojiMap = {
      ...values[0].emojis,
      ...values[1].emojis,
    };
    validEmojiNames = [...values[0].names, ...values[1].names];
    state.loading = false;
  });
}

export function initEmojiMap() {
  initEmojiMap.promise = initEmojiMap.promise || prepareEmojiMap();
  return initEmojiMap.promise;
}

export function normalizeEmojiName(name) {
  return Object.prototype.hasOwnProperty.call(emojiAliases, name) ? emojiAliases[name] : name;
}

export function isEmojiNameValid(name) {
  if (!emojiMap) {
    // eslint-disable-next-line @gitlab/require-i18n-strings
    throw new Error('The emoji map is uninitialized or initialization has not completed');
  }

  return name in emojiMap || name in emojiAliases;
}

export function getEmojiMap() {
  return emojiMap;
}

export function getAllEmoji() {
  return validEmojiNames.map((n) => emojiMap[n]);
}

export function findCustomEmoji(name) {
  return emojiMap[name];
}

function getAliasesMatchingQuery(query) {
  return Object.keys(emojiAliases)
    .filter((alias) => alias.includes(query))
    .reduce((map, alias) => {
      const emojiName = emojiAliases[alias];
      const score = alias.indexOf(query);

      const prev = map.get(emojiName);
      // overwrite if we beat the previous score or we're more alphabetical
      const shouldSet =
        !prev ||
        prev.score > score ||
        (prev.score === score && prev.alias.localeCompare(alias) > 0);

      if (shouldSet) {
        map.set(emojiName, { score, alias });
      }

      return map;
    }, new Map());
}

function getUnicodeMatch(emoji, query) {
  if (emoji.e === query) {
    return { score: 0, field: 'e', fieldValue: emoji.name, emoji };
  }

  return null;
}

function getDescriptionMatch(emoji, query) {
  if (emoji.d.includes(query)) {
    return { score: emoji.d.indexOf(query), field: 'd', fieldValue: emoji.d, emoji };
  }

  return null;
}

function getAliasMatch(emoji, matchingAliases) {
  if (matchingAliases.has(emoji.name)) {
    const { score, alias } = matchingAliases.get(emoji.name);

    return { score, field: 'alias', fieldValue: alias, emoji };
  }

  return null;
}

function getNameMatch(emoji, query) {
  if (emoji.name.includes(query)) {
    return {
      score: emoji.name.indexOf(query),
      field: 'name',
      fieldValue: emoji.name,
      emoji,
    };
  }

  return null;
}

// Sort emoji by emoji score falling back to a string comparison
export function sortEmoji(a, b) {
  return a.score - b.score || a.fieldValue.localeCompare(b.fieldValue);
}

export function searchEmoji(query) {
  const lowercaseQuery = query ? `${query}`.toLowerCase() : '';

  const matchingAliases = getAliasesMatchingQuery(lowercaseQuery);

  return Object.values(emojiMap)
    .map((emoji) => {
      const matches = [
        getUnicodeMatch(emoji, query),
        getDescriptionMatch(emoji, lowercaseQuery),
        getAliasMatch(emoji, matchingAliases),
        getNameMatch(emoji, lowercaseQuery),
      ]
        .filter(Boolean)
        .map((x) => ({ ...x, score: getEmojiScoreWithIntent(x.emoji.name, x.score) }));

      return minBy(matches, (x) => x.score);
    })
    .filter(Boolean)
    .sort(sortEmoji);
}

let emojiCategoryMap;
export function getEmojiCategoryMap() {
  if (!emojiCategoryMap && emojiMap) {
    emojiCategoryMap = CATEGORY_NAMES.reduce((acc, category) => {
      if (category === FREQUENTLY_USED_KEY) {
        return acc;
      }
      return { ...acc, [category]: [] };
    }, {});
    validEmojiNames.forEach((name) => {
      const emoji = emojiMap[name];
      if (emojiCategoryMap[emoji.c]) {
        emojiCategoryMap[emoji.c].push(name);
      }
    });
  }
  return emojiCategoryMap;
}

/**
 * Retrieves an emoji by name
 *
 * @param {String} query The emoji name
 * @param {Boolean} fallback If true, a fallback emoji will be returned if the
 * named emoji does not exist.
 * @returns {Object} The matching emoji.
 */
export function getEmojiInfo(query, fallback = true) {
  if (!emojiMap) {
    // eslint-disable-next-line @gitlab/require-i18n-strings
    throw new Error('The emoji map is uninitialized or initialization has not completed');
  }

  const lowercaseQuery = query ? `${query}`.toLowerCase() : '';
  const name = normalizeEmojiName(lowercaseQuery);

  if (name in emojiMap) {
    return emojiMap[name];
  }

  return fallback ? emojiMap[FALLBACK_EMOJI_KEY] : null;
}

export function emojiFallbackImageSrc(inputName) {
  const { name, src } = getEmojiInfo(inputName);
  return (
    src ||
    `${gon.asset_host || ''}${gon.relative_url_root || ''}/-/emojis/${EMOJI_VERSION}/${name}.png`
  );
}

export function emojiImageTag(name, src) {
  const img = document.createElement('img');

  img.className = 'emoji';
  setAttributes(img, {
    title: `:${name}:`,
    alt: `:${name}:`,
    src,
    align: 'absmiddle',
  });

  return img;
}

export function glEmojiTag(inputName, options) {
  const opts = { sprite: false, ...options };
  const name = normalizeEmojiName(inputName);
  const fallbackSpriteClass = `emoji-${name}`;

  const fallbackSpriteAttribute = opts.sprite
    ? `data-fallback-sprite-class="${escape(fallbackSpriteClass)}" `
    : '';

  const fallbackUrl = opts.url;
  const fallbackSrcAttribute = fallbackUrl
    ? `data-fallback-src="${fallbackUrl}" data-unicode-version="custom"`
    : '';

  return `<gl-emoji ${fallbackSrcAttribute}${fallbackSpriteAttribute}data-name="${escape(
    name,
  )}"></gl-emoji>`;
}
