/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

import * as React from 'react'
import Icon from '@brave/leo/react/icon'

import { useLocale } from '../context/locale_context'
import { useAppState } from '../context/app_model_context'
import { PublisherSourceCard } from './source_card'

import { style } from './discover_card.style'

interface Props {
  publisherIds: string[]
}

export function DiscoverCard(props: Props) {
  const { getString } = useLocale()
  const publishers = useAppState((s) => s.newsPublishers)

  return (
    <div data-css-scope={style.scope}>
      <h3>
        <Icon name='star-outline' />
        {getString('newsDiscoverTitle')}
      </h3>
      <div className='publishers'>
        {
          props.publisherIds.map((id) => {
            const publisher = publishers[id]
            if (!publisher) {
              return null
            }
            return <PublisherSourceCard key={id} publisher={publisher} />
          })
        }
      </div>
    </div>
  )
}
