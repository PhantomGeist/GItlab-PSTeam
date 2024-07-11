import { dateToYearMonthDate, newDateAsLocaleTime } from '~/lib/utils/datetime_utility';

const formatMonthData = (cur) => {
  const date = newDateAsLocaleTime(cur.monthIso8601);
  const formattedDate = dateToYearMonthDate(date);

  return {
    date,
    ...formattedDate,
    ...cur,
  };
};

export const getUsageDataByYearAsArray = (ciMinutesUsage) => {
  return ciMinutesUsage.reduce((acc, cur) => {
    const formattedData = formatMonthData(cur);

    if (acc[formattedData.year] != null) {
      acc[formattedData.year].push(formattedData);
    } else {
      acc[formattedData.year] = [formattedData];
    }
    return acc;
  }, {});
};

export const getUsageDataByYearByMonthAsObject = (ciMinutesUsage) => {
  return ciMinutesUsage.reduce((acc, cur) => {
    const formattedData = formatMonthData(cur);

    if (!acc[formattedData.year]) {
      acc[formattedData.year] = {};
    }

    acc[formattedData.year][formattedData.date.getMonth()] = formattedData;
    return acc;
  }, {});
};

/**
 * Formats date to `yyyy-mm-dd`
 * @param { number } year full year
 * @param { number } monthIndex month index, between 0 and 11
 * @param { number } day day of the month
 * @returns { string } formatted date string
 *
 * NOTE: it might be worth moving this utility to date time utils
 * in ~/lib/utils/datetime_utility.js
 */
export const formatIso8601Date = (year, monthIndex, day) => {
  return [year, monthIndex + 1, day]
    .map(String)
    .map((s) => s.padStart(2, '0'))
    .join('-');
};
