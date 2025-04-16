/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

import { color, font } from '@brave/leo/tokens/css/variables'
import { scoped } from '../../lib/scoped_css'

const twoColumnBreak = '1024px'
const oneColumnBreak = '800px'
const controlBarHeight = '54px'

export const style = scoped.css`
  & {
    container-type: inline-size;
    position: relative;
    padding: 16px 16px 48px;
    color: ${color.text.primary};
    min-height: 100vh;
    display: flex;
    flex-direction: column;
  }

  .news-feed {
    flex: 1 1 auto;
    display: flex;
    justify-content: center;
    gap: 32px;
  }

  .update-available {
    --leo-button-color: rgba(255, 255, 255, 0.1);

    position: fixed;
    z-index: 2;
    inset-block-start: 32px;
    inset-inline-start: 0;
    inset-inline-end: 0;
    text-align: center;

    leo-button {
      border-radius: 20px;
      overflow: hidden;
      backdrop-filter: brightness(0.8) blur(32px);
    }

    @container (max-width: ${twoColumnBreak}) {
      inset-block-start: calc(32px + ${controlBarHeight});
    }
  }

  .loading {
    --leo-progressring-color: rgba(255, 255, 255, 0.25);
    --leo-progressring-size: 32px;

    display: flex;
    justify-content: center;
    position: sticky;
    inset-block-start: 16px;

    > * {
      margin: 16px 0;
    }

    @container (max-width: ${twoColumnBreak}) {
      inset-block-start: calc(16px + ${controlBarHeight});
    }
  }

  .sidebar {
    flex: 0 1 270px;

    @container (max-width: ${oneColumnBreak}) {
      display: none;
    }
  }

  .side-nav {
    padding: 16px 8px;
    position: sticky;
    inset-block-start: 16px;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 16px;

    @container (max-width: ${twoColumnBreak}) {
      inset-block-start: calc(16px + ${controlBarHeight});
    }
  }

  .feed-items {
    flex: 0 1 540px;
    align-self: stretch;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .feed-card {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 16px;
    padding: 12px 16px 16px;
  }

  .caught-up {
    --leo-icon-size: 24px;

    display: flex;
    align-items: center;
    gap: 16px;
    color: rgba(255, 255, 255, 0.5);
    font: ${font.small.regular};
    padding: 16px 0;

    hr {
      flex: 1 1 auto;
      border-color: rgba(255, 255, 255, 0.1);
    }

    p {
      display: flex;
      align-items: center;
      gap: 6px;
    }
  }

  .controls-container {
    flex: 0 1 270px;

    @container (max-width: ${twoColumnBreak}) {
      position: fixed;
    }
  }

  .controls {
    --leo-button-color: rgba(255, 255, 255, 0.5);
    --leo-button-radius: 4px;
    --leo-button-padding: 4px;

    anchor-name: --ntp-news-controls;

    position: fixed;
    inset-block-end: 48px;
    inset-inline-end: 48px;
    border-radius: 8px;
    padding: 8px;
    background: rgba(255, 255, 255, 0.05);
    backdrop-filter: blur(64px);
    display: flex;
    align-items: center;
    gap: 8px;

    > * {
      flex: 0 0 auto;
    }

    .popover-nav-control {
      flex: 1 1 auto;
      display: none;

      @container (max-width: ${twoColumnBreak}) {
        display: block;

        leo-button {
          display: none;
        }
      }

      @container (max-width: ${oneColumnBreak}) {
        leo-button {
          display: block;
        }
      }
    }

    @container (max-width: ${twoColumnBreak}) {
      inset-block-start: 0;
      inset-block-end: auto;
      inset-inline-start: 0;
      inset-inline-end: 0;
      border-radius: 0;
      padding: 12px 16px;
    }

    @container (max-width: ${oneColumnBreak}) {
      .popover-nav-control {
        display: block;
      }
    }
  }

  .popover-nav {
    position: fixed;
    position-anchor: --ntp-news-controls;
    inset-block-start: anchor(bottom);
    inset-block-end: 0;
    inset-inline-start: 0;
    backdrop-filter: blur(64px);
    padding: 16px;
    height: auto;
    width: 270px;

    transform: translateX(-270px);
    transition: all 200ms allow-discrete;

    &:popover-open {
      transform: translateX(0);

      @starting-style {
        transform: translateX(-270px);
      }
    }
  }
`
