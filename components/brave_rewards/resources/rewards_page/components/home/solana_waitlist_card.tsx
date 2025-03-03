/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

import * as React from 'react'
import Button from '@brave/leo/react/button'
import ButtonMenu from '@brave/leo/react/buttonMenu'
import Icon from '@brave/leo/react/icon'

import { useAppState } from '../../lib/app_model_context'
import { SolanaWaitlistModal } from './solana_waitlist_modal'

import { style } from './solana_waitlist_card.style'

import waitlistImage from '../../assets/solana_waitlist.svg'
import waitlistPendingImage from '../../assets/solana_waitlist_pending.svg'

export function SolanaWaitlistCard() {
  const [waitlistPending] = useAppState((state) => [
    state.selfCustodyWaitlistPending
  ])

  const [showModal, setShowModal] = React.useState(false)

  function renderHeader() {
    function onCancel() {}
    return (
      <h4>
        <Icon name='solana-on' />
        <span className='header-text'>Get your payouts on Solana</span>
        {
          waitlistPending &&
            <ButtonMenu className='more-menu'>
              <button slot='anchor-content'>
                <Icon name='more-vertical' />
              </button>
              <leo-menu-item class='cancel' onClick={onCancel}>
                <Icon name='close' />
                <span>Cancel request</span>
              </leo-menu-item>
            </ButtonMenu>
        }
      </h4>
    )
  }

  if (waitlistPending) {
    return (
      <div className='content-card' {...style}>
        {renderHeader()}
        <section className='pending'>
          <img src={waitlistPendingImage} />
          You are currently on the waiting list.
        </section>
      </div>
    )
  }

  return (
    <div className='content-card' {...style}>
      {renderHeader()}
      <section>
        <img src={waitlistImage} />
        <div className='invite-text'>
          Want to receive your BAT earnings using your Solana address?
        </div>
        <Button onClick={() => setShowModal(true)}>
          Join the waitlist
        </Button>
        <div className='invite-subtext'>
          Joining the waitlist does not guarantee that you will receive an invitation. Other restrictions may apply.
        </div>
      </section>
      {
        showModal && <SolanaWaitlistModal onClose={() => setShowModal(false)} />
      }
    </div>
  )
}
