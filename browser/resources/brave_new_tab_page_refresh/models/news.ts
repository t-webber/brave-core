/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

import { Optional } from '../lib/optional'

export interface NewsItem {
  title: string
  categoryName: string
  publisherId: string
  publisherName: string
  url: string
  imageUrl: string
  relativeTimeDescription: string
}

type ArticleFeedItem = NewsItem & { type: 'article' }

type HeroFeedItem = NewsItem & { type: 'hero' }

interface DiscoverFeedItem {
  type: 'discover'
  publisherIds: string[]
}

export interface ClusterFeedItem {
  type: 'cluster'
  clusterType: 'channel' | 'topic'
  clusterId: string
  items: NewsFeedItem[]
}

export type NewsFeedItem =
  ArticleFeedItem |
  HeroFeedItem |
  DiscoverFeedItem |
  ClusterFeedItem

interface AllFeedSpecifier {
  type: 'all'
}

interface FollowingFeedSpecifier {
  type: 'following'
}

interface PublisherFeedSpecifier {
  type: 'publisher'
  publisher: string
}

interface ChannelFeedSpecifier {
  type: 'channel'
  channel: string
}

export interface NewsPublisher {
  publisherId: string
  publisherName: string
  type: 'combined' | 'direct'
  userEnabledStatus: 'not-modified' | 'enabled' | 'disabled'
  categoryName: string
  siteUrl: string
  feedSourceUrl: string
  coverUrl: string
  backgroundColor: string
  locales: { name: string, rank: Optional<number> }[]
}

export type NewsFeedSpecifier =
  AllFeedSpecifier |
  FollowingFeedSpecifier |
  PublisherFeedSpecifier |
  ChannelFeedSpecifier

export interface NewsSignal {
  visitWeight: number
}

export type NewsFeedError = 'no-articles' | 'no-feeds' | 'connection-error'

export interface NewsChannel {
  channelName: string
  subscribedLocales: string[]
}

export interface NewsState {
  showNewsWidget: boolean
  newsEnabled: boolean
  currentNewsFeed: NewsFeedSpecifier
  newsFeedItems: NewsFeedItem[] | null
  newsPublishers: Record<string, NewsPublisher>
  newsUpdateAvailable: boolean
  newsSignals: Record<string, NewsSignal>
  newsChannels: Record<string, NewsChannel>
  newsFeedError: NewsFeedError | null
  newsLocale: string
}

export function defaultNewsState(): NewsState {
  return {
    showNewsWidget: false,
    newsEnabled: false,
    currentNewsFeed: { type: 'all' },
    newsFeedItems: null,
    newsPublishers: {},
    newsUpdateAvailable: false,
    newsSignals: {},
    newsChannels: {},
    newsFeedError: null,
    newsLocale: ''
  }
}

export interface FindFeedResult {
  feedUrl: string
  feedTitle: string
}

export interface NewsActions {
  setShowNewsWidget: (showNewsWidget: boolean) => void
  setNewsEnabled: (newsEnabled: boolean) => void
  setNewsPublisherEnabled: (publisherId: string, enabled: boolean) => void
  setNewsChannelEnabled: (channel: string, enabled: boolean) => void
  subscribeToDirectNewsFeed: (url: string) => void
  getSuggestedNewsPublishers: () => Promise<string[]>
  updateNewsFeed: () => void
  setCurrentNewsFeed: (specifier: NewsFeedSpecifier) => void
  onNewsVisible: () => void
  findNewsFeeds: (url: string) => Promise<FindFeedResult[]>
}

export function defaultNewsActions(): NewsActions {
  return {
    setShowNewsWidget(showNewsWidget) {},
    setNewsEnabled(newsEnabled) {},
    setNewsPublisherEnabled(publisherId, enabled) {},
    subscribeToDirectNewsFeed(url) {},
    updateNewsFeed() {},
    setCurrentNewsFeed(specifier) {},
    setNewsChannelEnabled(channel, enabled) {},
    async getSuggestedNewsPublishers() { return [] },
    onNewsVisible() {},
    async findNewsFeeds(url) { return [] }
  }
}

export function getNewsPublisherName(item: NewsItem) {
  if (item.publisherName) {
    return item.publisherName
  }
  try {
    return new URL(item.url).hostname
  } catch {
    return ''
  }
}

export function isNewsChannelEnabled(channel: NewsChannel) {
  return channel.subscribedLocales.length > 0
}

export function isNewsPublisherEnabled(publisher: NewsPublisher) {
  switch (publisher.userEnabledStatus) {
    case 'enabled': return true
    case 'disabled': return false
    case 'not-modified': return publisher.type === 'direct'
  }
}

export function newsFeedSpecifiersEqual(
  a: NewsFeedSpecifier,
  b: NewsFeedSpecifier
) {
  switch (a.type) {
    case 'all':
    case 'following':
      return a.type === b.type
    case 'channel':
      return b.type === 'channel' && a.channel === b.channel
    case 'publisher':
      return b.type === 'publisher' && a.publisher === b.publisher
  }
}
