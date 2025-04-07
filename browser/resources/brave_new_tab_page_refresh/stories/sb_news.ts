/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

import { Store } from '../lib/store'

import {
  NewsState,
  NewsActions,
  defaultNewsActions } from '../models/news'

import { optional } from '../lib/optional'

export function initializeNews(store: Store<NewsState>): NewsActions {
  store.update({
    showNewsWidget: true,
    newsEnabled: true,
    newsUpdateAvailable: true,
    newsFeedError: null,
    newsLocale: 'en-US',
    newsFeedItems: [
      {
        type: 'hero',
        title: 'Why I chose Brave as my Chrome browser replacement Why I chose Brave as my Chrome browser replacement Why I chose Brave as my Chrome browser replacement Why I chose Brave as my Chrome browser replacement Why I chose Brave as my Chrome browser replacement',
        categoryName: 'Technology',
        publisherId: 'p1',
        publisherName: 'Tech Beat',
        imageUrl: '',
        url: 'https://brave.com',
        relativeTimeDescription: '2 hours ago'
      }, {
        type: 'cluster',
        clusterType: 'channel',
        clusterId: 'Cluster Name',
        items: [
          {
            type: 'article',
            title: 'Why I chose Brave as my Chrome browser replacement',
            categoryName: 'Technology',
            publisherId: 'p1',
            publisherName: 'Tech Beat',
            imageUrl: '',
            url: 'https://brave.com',
            relativeTimeDescription: '2 hours ago'
          },
          {
            type: 'hero',
            title: 'Why I chose Brave as my Chrome browser replacement',
            categoryName: 'Technology',
            publisherId: 'p1',
            publisherName: 'Tech Beat',
            imageUrl: '',
            url: 'https://brave.com',
            relativeTimeDescription: '2 hours ago'
          }
        ]
      }, {
        type: 'discover',
        publisherIds: [
          'p1',
          'p2'
        ]
      }
    ],
    newsPublishers: {
      'p1': {
        publisherId: 'p1',
        publisherName: 'Publisher One',
        type: 'combined',
        userEnabledStatus: 'enabled',
        categoryName: '',
        siteUrl: '',
        feedSourceUrl: '',
        coverUrl: '',
        backgroundColor: '',
        locales: [{
          name: 'en-US',
          rank: optional(1)
        }]
      },
      'p2': {
        publisherId: 'p2',
        publisherName: 'Publisher Two',
        type: 'direct',
        userEnabledStatus: 'not-modified',
        categoryName: '',
        siteUrl: '',
        feedSourceUrl: '',
        coverUrl: '',
        backgroundColor: '',
        locales: [{
          name: 'en-US',
          rank: optional(2)
        }]
      },
      'p3': {
        publisherId: 'p3',
        publisherName: 'Publisher Three',
        type: 'combined',
        userEnabledStatus: 'not-modified',
        categoryName: '',
        siteUrl: '',
        feedSourceUrl: '',
        coverUrl: '',
        backgroundColor: '',
        locales: [{
          name: 'en-US',
          rank: optional(2)
        }]
      },
      'p4': {
        publisherId: 'p4',
        publisherName: 'Publisher Four',
        type: 'combined',
        userEnabledStatus: 'not-modified',
        categoryName: '',
        siteUrl: '',
        feedSourceUrl: '',
        coverUrl: '',
        backgroundColor: '',
        locales: [{
          name: 'en-US',
          rank: optional(2)
        }]
      }
    },
    newsChannels: {
      'Top Stories': {
        channelName: 'Top Stories',
        subscribedLocales: []
      }
    }
  })

  return {
    ...defaultNewsActions(),

    setShowNewsWidget(showNewsWidget) {
      store.update({ showNewsWidget })
    },

    setNewsEnabled(newsEnabled) {
      store.update({ newsEnabled })
    },

    setNewsPublisherEnabled(publisherId, enabled) {
      const publishers = store.getState().newsPublishers
      const publisher = publishers[publisherId]
      if (publisher) {
        publisher.userEnabledStatus = enabled ? 'enabled' : 'disabled'
      }
      store.update({
        newsPublishers: {...publishers}
      })
    },

    async findNewsFeeds(url) {
      await new Promise((resolve) => setTimeout(resolve, 2000))
      return [
        { feedTitle: 'Direct feed', feedUrl: 'https://brave.com' }
      ]
    },

    async getSuggestedNewsPublishers() {
      return ['p1', 'p2']
    },

    updateNewsFeed() {
      const { newsFeedItems } = store.getState()
      store.update({
        newsFeedItems: null
      })
      new Promise((resolve) => setTimeout(resolve, 2000)).then(() => {
        store.update({ newsFeedItems })
      })
    },

    onNewsVisible() {
      console.log('News visible')
    }
  }
}
