/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

import * as React from 'react'
import Icon from '@brave/leo/react/icon'

import {
  NewsPublisher,
  NewsChannel,
  isNewsPublisherEnabled,
  isNewsChannelEnabled } from '../../models/news'

import { useAppActions } from '../context/app_model_context'
import { SafeImage } from '../common/safe_image'
import { inlineCSSVars } from '../../lib/inline_css_vars'
import { getKeyedColor } from '../../lib/keyed_colors'
import { CategoryIcon } from './category_icon'
import { CategoryName } from './category_name'
import classNames from '$web-common/classnames'

import { style } from './source_card.style'

interface Props {
  background?: string
  enabled: boolean
  image: React.ReactNode
  name: React.ReactNode
  onToggle: () => void
}

export function SourceCard(props: Props) {
  const background = props.background || ''

  function renderImage() {
    if (!props.image) {
      return null
    }
    if (typeof props.image === 'string') {
      return <SafeImage src={props.image} />
    }
    return props.image
  }

  return (
    <div
      data-css-scope={style.scope}
      style={inlineCSSVars({ '--cover-background': background })}
    >
      <div className={classNames({'cover': true, 'enabled': props.enabled })}>
        {renderImage()}
        <button onClick={props.onToggle}>
          <Icon name={props.enabled ? 'minus' : 'plus-add'} />
        </button>
      </div>
      {props.name}
    </div>
  )
}

export function PublisherSourceCard(props: { publisher: NewsPublisher }) {
  const actions = useAppActions()
  const { publisher } = props
  const enabled = isNewsPublisherEnabled(publisher)
  const background =
    publisher.backgroundColor ||
    getKeyedColor(publisher.feedSourceUrl || publisher.publisherId)

  return (
    <SourceCard
      background={background}
      image={publisher.coverUrl}
      name={publisher.publisherName}
      enabled={enabled}
      onToggle={() => {
        actions.setNewsPublisherEnabled(publisher.publisherId, !enabled)
      }}
    />
  )
}

export function DirectFeedSourceCard(props: { title: string, url: string}) {
  const actions = useAppActions()
  return (
    <SourceCard
      background={getKeyedColor(props.url)}
      name={props.title}
      image={null}
      enabled={false}
      onToggle={() => actions.subscribeToDirectNewsFeed(props.url)}
    />
  )
}

export function ChannelSourceCard(props: { channel: NewsChannel }) {
  const actions = useAppActions()
  const { channel } = props
  const enabled = isNewsChannelEnabled(channel)
  return (
    <SourceCard
      key={channel.channelName}
      image={<CategoryIcon category={channel.channelName} />}
      name={<CategoryName category={channel.channelName} />}
      enabled={enabled}
      onToggle={() => {
        actions.setNewsChannelEnabled(channel.channelName, !enabled)
      }}
    />
  )
}
