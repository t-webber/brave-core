/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

import * as React from 'react'
import Button from '@brave/leo/react/button'

import { NewsItem, NewsFeedItem, getNewsPublisherName } from '../../models/news'
import { useLocale } from '../context/locale_context'
import { useAppActions, useAppState } from '../context/app_model_context'
import { SafeImage } from '../common/safe_image'
import { Link } from '../common/link'
import { CategoryIcon } from '../news/category_icon'
import { CategoryName } from '../news/category_name'

import { style } from './news_widget.style'

export function NewsWidget() {
  const { getString } = useLocale()
  const actions = useAppActions()

  const newsEnabled = useAppState((s) => s.newsEnabled)
  const feedItems = useAppState((s) => s.newsFeedItems)

  React.useEffect(() => {
    if (feedItems) {
      cacheNewsItem(getPeekItem(feedItems))
    }
  }, [feedItems])

  const peekItem = React.useMemo(() => {
    if (feedItems) {
      return getPeekItem(feedItems)
    }
    return loadCachedNewsItem()
  }, [feedItems])

  React.useEffect(() => {
    setTimeout(() => actions.onNewsVisible(), 250)
  }, [])

  function renderSkeleton() {
    return (
      <div className='peek loading'>
        <div className='img skeleton' />
        <div>
          <div className='meta skeleton' />
          <div className='item-title skeleton' />
        </div>
      </div>
    )
  }

  function renderPeekItem() {
    if (!peekItem) {
      return renderSkeleton()
    }

    return (
      <Link url={peekItem.url} className='peek'>
        <SafeImage src={peekItem.imageUrl} />
        <div>
          <div className='meta'>
            <span>{getNewsPublisherName(peekItem)}</span>
            <span>•</span>
            <CategoryIcon category={peekItem.categoryName} />
            <span><CategoryName category={peekItem.categoryName} /></span>
          </div>
          <div className='item-title'>
            {formatTitle(peekItem.title)}
          </div>
        </div>
      </Link>
    )
  }

  function renderOptIn() {
    return (
      <div className='opt-in'>
        <div className='graphic' />
        <div className='text'>
          {getString('newsEnableText')}
        </div>
        <div className='actions'>
          <Button
            size='small'
            onClick={() => { actions.setNewsEnabled(true) }}
          >
            {getString('newsEnableButtonLabel')}
          </Button>
        </div>
      </div>
    )
  }

  return (
    <div data-css-scope={style.scope}>
      <div className='title'>
        {getString('newsWidgetTitle')}
      </div>
      {newsEnabled ? renderPeekItem() : renderOptIn()}
    </div>
  )
}

function getPeekItem(feedItems: NewsFeedItem[]): NewsItem | null {
  if (!feedItems) {
    return null
  }
  const item = feedItems.find((item) => {
    return item.type === 'article' || item.type === 'hero'
  })
  return item ?? null
}

function formatTitle(title: string) {
  const maxLength = 99
  if (title.length < maxLength + 1) {
    return title
  }
  return <>{title.slice(0, maxLength)}&hellip;</>
}

const cacheKey = 'ntp-news-widget-item'

function cacheNewsItem(newsItem: NewsItem | null) {
  localStorage.setItem(cacheKey, JSON.stringify({
    cachedAt: Date.now(),
    data: newsItem
  }))
}

function loadCachedNewsItem(): NewsItem | null {
  let entry: any = null
  try { entry = JSON.parse(localStorage.getItem(cacheKey) || '') } catch {}
  if (!entry) {
    return null
  }

  const cachedAt = Number(entry.cachedAt) || 0
  if (cachedAt < Date.now() - (1000 * 60 * 60)) {
    return null
  }

  const { data } = entry
  if (!data) {
    return null
  }

  const item: NewsItem = {
    title: String(data.title || ''),
    categoryName: String(data.categoryName || ''),
    publisherId: String(data.publisherId || ''),
    publisherName: String(data.publisherName || ''),
    url: String(data.url || ''),
    imageUrl: String(data.imageUrl || ''),
    relativeTimeDescription: ''
  }

  if (item.title && item.url && item.categoryName && item.publisherName &&
      item.imageUrl) {
    return item
  }

  return null
}
