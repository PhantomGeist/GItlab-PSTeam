const LATEST_VERSION = {
  version: '1.2.3',
};

export const makeModel = ({ latestVersion } = { latestVersion: LATEST_VERSION }) => ({
  id: 1234,
  name: 'blah',
  path: 'path/to/blah',
  description: 'Description of the model',
  latestVersion,
  versionCount: 2,
  candidateCount: 1,
});

export const MODEL = makeModel();

export const MODEL_VERSION = { version: '1.2.3', model: MODEL };

export const mockModels = [
  {
    name: 'model_1',
    version: '1.0',
    versionPath: 'path/to/version',
    path: 'path/to/model_1',
    versionCount: 3,
  },
  {
    name: 'model_2',
    version: '1.1',
    path: 'path/to/model_2',
    versionCount: 1,
  },
];

export const modelWithoutVersion = {
  name: 'model_without_version',
  path: 'path/to/model_without_version',
  versionCount: 0,
};

export const startCursor = 'eyJpZCI6IjE2In0';

export const defaultPageInfo = Object.freeze({
  startCursor,
  endCursor: 'eyJpZCI6IjIifQ',
  hasNextPage: true,
  hasPreviousPage: true,
});
