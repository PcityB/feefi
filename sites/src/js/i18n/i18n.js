import { addLocaleData } from 'react-intl';
import enLocaleData from 'react-intl/locale-data/en';
import jaLocaleData from 'react-intl/locale-data/ja';
import zhLocaleData from 'react-intl/locale-data/zh';

import enMessages from './messages/en.yml';
import jaMessages from './messages/ja.yml';
import zhMessages from './messages/zh.yml';

addLocaleData([...enLocaleData, ...jaLocaleData, ...zhLocaleData]);

const messages = {
  en: enMessages,
  ja: jaMessages,
  zh: zhMessages
};

export const getMessages = (locale) => {
  return messages[locale.split('-')[0]] || messages.en;
};

export const getIntlConfig = (locale) => {
  return {
    locale: locale,
    messages: getMessages(locale),
    timeZone: 'UTC', // You might want to make this configurable
    formats: {
      date: {
        short: {
          day: 'numeric',
          month: 'short',
          year: 'numeric'
        }
      },
      time: {
        short: {
          hour: 'numeric',
          minute: 'numeric'
        }
      },
      number: {
        currency: {
          style: 'currency',
          currency: 'USD', // This should be configurable based on user preferences
          minimumFractionDigits: 2,
          maximumFractionDigits: 2
        },
        percent: {
          style: 'percent',
          minimumFractionDigits: 2,
          maximumFractionDigits: 2
        }
      }
    }
  };
};
