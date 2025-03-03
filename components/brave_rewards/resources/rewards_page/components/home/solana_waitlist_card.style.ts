/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

import { color, font } from '@brave/leo/tokens/css/variables'
import { scoped } from '../../lib/scoped_css'

export const style = scoped.css`
  h4 {
    --leo-icon-size: 24px;

    padding: 16px;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .header-text {
    flex: 1 1 auto;
  }

  section {
    padding: 16px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
    text-align: center;
  }

  section.pending {
    flex-direction: row;
    gap: 32px;
    font: ${font.large.regular};
  }

  img {
    height: 50px;
    width: auto;
  }

  .invite-text {
    font: ${font.heading.h4};
  }

  .invite-subtext {
    font: ${font.xSmall.regular};
    color: ${color.text.tertiary};
  }

  .more-menu {
    --leo-icon-size: 20px;

    font: ${font.default.regular};
    display: block;

    leo-menu-item {
      color: ${color.text.primary};
      display: flex;
      padding: 8px;
      gap: 16px;
      align-items: center;

      &.cancel {
        --leo-icon-color: ${color.systemfeedback.errorIcon};
        color: ${color.systemfeedback.errorText};
      }
    }
  }
`
