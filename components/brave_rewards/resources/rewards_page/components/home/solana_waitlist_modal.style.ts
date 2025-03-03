/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

import { color, font } from '@brave/leo/tokens/css/variables'
import { scoped } from '../../lib/scoped_css'

export const style = scoped.css`
  & {
    --leo-progressring-size: 48px;

    display: flex;
    flex-direction: column;
    gap: 16px;
    align-items: center;
    font: ${font.default.regular};

    @container style(--is-wide-view) {
      width: 350px;
    }
  }

  &.pending {
    padding: 48px 0 24px;
  }

  &.success {
    --leo-icon-size: 48px;
    --leo-icon-color: ${color.systemfeedback.successIcon};

    margin-top: -16px;
  }

  &.error {
    --leo-icon-size: 48px;
    --leo-icon-color: ${color.systemfeedback.warningIcon};

    margin-top: -16px;
  }

  img {
    height: 50px;
    width: auto;
    margin-bottom: 16px;
  }

  p {
    margin-bottom: 8px;
    text-align: center;
  }

  .actions {
    width: 100%;
    display: flex;
    flex-direction: column;
    gap: 8px;
    align-items: stretch;
  }
`
