/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

import * as React from 'react'
import Button from '@brave/leo/react/button'
import Icon from '@brave/leo/react/icon'
import ProgressRing from '@brave/leo/react/progressRing'

import { Modal } from '../modal'

import { AppModelContext } from '../../lib/app_model_context'
import { style } from './solana_waitlist_modal.style'

import waitlistImage from '../../assets/solana_waitlist.svg'

type JoinStatus = 'pending' | 'success' | 'error'

interface Props {
  onClose: () => void
}

export function SolanaWaitlistModal(props: Props) {
  const model = React.useContext(AppModelContext)
  const [joinStatus, setJoinStatus] = React.useState<JoinStatus | null>(null)

  function onJoinClick() {
    if (joinStatus) {
      return
    }
    setJoinStatus('pending')
    model.joinSelfCustodyWaitlist().then((success) => {
      setJoinStatus(success ? 'success' : 'error')
    })
  }

  if (joinStatus === 'pending') {
    return (
      <Modal>
        <div className='pending' {...style}>
          <ProgressRing />
          <h3>Joining</h3>
          <p>Please wait...</p>
        </div>
      </Modal>
    )
  }

  if (joinStatus === 'success') {
    return (
      <Modal onEscape={props.onClose}>
        <Modal.Header onClose={props.onClose} />
        <div className='success' {...style}>
          <Icon name='check-circle-filled' />
          <h3>Successfully joined</h3>
          <p>You will get notified when you will be able to receive earnings via Solana wallet.</p>
        </div>
      </Modal>
    )
  }

  if (joinStatus === 'error') {
    return (
      <Modal onEscape={props.onClose}>
        <Modal.Header onClose={props.onClose} />
        <div className='error' {...style}>
          <Icon name='warning-circle-filled' />
          <h3>Cannot join right now</h3>
          <p>You cannot join the waitlist right now. You’ll have to wait 72 hours before rejoining the waitlist.</p>
          <div className='actions'>
            <Button onClick={props.onClose}>
              Close
            </Button>
          </div>
        </div>
      </Modal>
    )
  }

  return (
    <Modal onEscape={props.onClose}>
      <Modal.Header onClose={props.onClose} />
      <div {...style}>
        <img src={waitlistImage} />
        <h3>Join the Waitlist</h3>
        <p>Be the first to receive your rewards directly to your Solana wallet. Secure your spot now!</p>
      </div>
      <Modal.Actions
        actions={[
          {
            text: 'Cancel',
            onClick: props.onClose
          },
          {
            text: 'Join the waitlist',
            onClick: onJoinClick,
            isPrimary: true
          }
        ]}
      />
    </Modal>
  )
}
