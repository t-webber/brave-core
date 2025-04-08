// Copyright (c) 2025 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

import styled from 'styled-components'
import Icon from '@brave/leo/react/icon'
import { color } from '@brave/leo/tokens/css/variables'

const BraveIconCircle = styled(Icon)`
  align-items: center;
  border-radius: 50%;
  border: ${color.divider.subtle} 1px solid;
  display: flex;
  min-height: 4.5em;
  justify-content: center;
  margin-inline-end: 1.5em;
  min-width: 4.5em;
  flex-grow: 0;
  --leo-icon-size: 3.6em;
`

export default BraveIconCircle