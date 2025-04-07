/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

import * as React from 'react'
import Button from '@brave/leo/react/button'
import Icon from '@brave/leo/react/icon'

import {
  NewsSignal,
  NewsFeedSpecifier,
  isNewsPublisherEnabled,
  isNewsChannelEnabled,
  newsFeedSpecifiersEqual } from '../../models/news'

import { useLocale } from '../context/locale_context'
import { useAppState, useAppActions } from '../context/app_model_context'
import classNames from '$web-common/classnames'

import { style } from './feed_nav.style'

interface Props {
  onAddChannelClick: () => void
  onAddPublisherClick: () => void
  onFeedSelect?: () => void
}

export function FeedNav(props: Props) {
  const { getString } = useLocale()
  const signals = useAppState((s) => s.newsSignals)
  const channels = useAppState((s) => s.newsChannels)
  const publishers = useAppState((s) => s.newsPublishers)

  const enabledChannels = React.useMemo(() => {
    return Object.values(channels)
      .filter(isNewsChannelEnabled)
      .sort((a, b) => compareVisitWeight(a.channelName, b.channelName, signals))
  }, [channels, signals])

  const enabledPublishers = React.useMemo(() => {
    return Object.values(publishers)
      .filter(isNewsPublisherEnabled)
      .sort((a, b) => compareVisitWeight(a.publisherId, b.publisherId, signals))
  }, [publishers, signals])

  return (
    <div data-css-scope={style.scope}>
      <FeedButton
        text={getString('newsFeedAllTitle')}
        specifier={{ type: 'all' }}
        onFeedSelect={props.onFeedSelect}
      />
      <FeedButton
        text={getString('newsFeedFollowingTitle')}
        specifier={{ type: 'following' }}
        onFeedSelect={props.onFeedSelect}
      />
      <FeedGroup
        text={getString('newsFeedChannelsTitle')}
        onAddClick={() => props.onAddChannelClick()}
        items={
          enabledChannels.map((channel) => (
            <FeedButton
              key={channel.channelName}
              text={channel.channelName}
              onFeedSelect={props.onFeedSelect}
              specifier={{ type: 'channel', channel: channel.channelName }}
            />
          ))
        }
      />
      <FeedGroup
        text={getString('newsFeedPublishersTitle')}
        onAddClick={() => props.onAddPublisherClick()}
        items={
          enabledPublishers.map((publisher) => (
            <FeedButton
              key={publisher.publisherId}
              text={publisher.publisherName}
              onFeedSelect={props.onFeedSelect}
              specifier={{
                type: 'publisher',
                publisher: publisher.publisherId
              }}
            />
          ))
        }
      />
    </div>
  )
}

interface FeedButtonProps {
  text: string
  specifier: NewsFeedSpecifier
  onFeedSelect?: () => void
}

function FeedButton(props: FeedButtonProps) {
  const actions = useAppActions()
  const currentFeed = useAppState((s) => s.currentNewsFeed)
  return (
    <button
      onClick={() => {
        actions.setCurrentNewsFeed(props.specifier)
        if (props.onFeedSelect) {
          props.onFeedSelect()
        }
      }}
      className={classNames({
        selected: newsFeedSpecifiersEqual(currentFeed, props.specifier)
      })}
    >
      {props.text}
    </button>
  )
}

const groupDisplayCount = 4

interface FeedGroupProps {
  text: string
  items: React.ReactNode[]
  onAddClick: () => void
}

function FeedGroup(props: FeedGroupProps) {
  const [showAll, setShowAll] = React.useState(false)
  let items = props.items
  if (!showAll) {
    items = items.slice(0, groupDisplayCount)
  }
  return (
    <details
      open
      className={classNames({
        'empty': props.items.length === 0,
        'show-all': showAll
      })}
    >
      <summary>
        <Icon name='arrow-small-right' />
        {props.text}
        <Button
          size='tiny'
          fab
          kind='outline'
          onClick={(event) => {
            event.preventDefault()
            props.onAddClick()
          }}
        >
          <Icon name='plus-add' />
        </Button>
      </summary>
      <div className='group-items'>
        {items}
        {
          props.items.length > groupDisplayCount &&
            <button
              className='show-all-button'
              onClick={() => setShowAll(!showAll)}
            >
              {showAll ? 'Show less' : 'Show more'}
            </button>
        }
      </div>
    </details>
  )
}

function compareVisitWeight(
  a: string,
  b: string,
  signals: Record<string, NewsSignal>
) {
  if (!signals[1] || !signals[b]) {
    return 0
  }
  return signals[a].visitWeight - signals[b].visitWeight
}
