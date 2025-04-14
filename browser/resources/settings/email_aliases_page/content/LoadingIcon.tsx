import { color } from '@brave/leo/tokens/css/variables'
import * as React from 'react'
import Icon from '@brave/leo/react/icon'
import styled from 'styled-components'

const SpinningIcon = styled(Icon)`
  --leo-button-color: ${color.icon.default};
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
  animation: spin 1s linear infinite;
`

const LoadingIcon = () => <SpinningIcon name="loading-spinner" />

export default LoadingIcon
