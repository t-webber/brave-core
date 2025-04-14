// Copyright (c) 2025 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

import Button from "@brave/leo/react/button"
import Icon from "@brave/leo/react/icon"
import { getLocale } from '$web-common/locale'
import formatMessage from '$web-common/formatMessage'
import * as React from 'react'
import { ViewState, ViewMode, MappingService } from "./types"
import Col from "./styles/Col"
import Row from "./styles/Row"
import Input from "@brave/leo/react/input"
import styled from "styled-components"
import onEnterKey from "./onEnterKey"
import { color, font, spacing } from "@brave/leo/tokens/css/variables"
import { MAX_ALIASES } from "./constant"

const ModalSectionCol = styled(Col)`
  margin: ${spacing["2Xl"]} 0;
  & h3 {
    margin: ${spacing.s} ${spacing.m};
  }
  & leo-input {
    margin: ${spacing.s} 0;
  }
`

const ButtonRow = styled(Row)<{ bubble?: boolean }>`
  justify-content: ${props => props.bubble ? 'space-between' : 'end'};
  margin: ${spacing["2Xl"]} 0;
  & leo-button {
    flex-grow: 0;
  }
  & span {
    display: flex;
    flex-direction: row;
    column-gap: ${spacing.m};
  }
`

const GeneratedEmailContainer = styled(Row)`
  font: ${font.large.regular};
  background-color: ${color.neutralVariant[10]};
  border-radius: ${spacing.m};
  padding: 0 0 0 ${spacing.m};
  margin: ${spacing.s} 0;
  justify-content: space-between;
  height: ${spacing["5Xl"]};
  & leo-button {
    flex-grow: 0;
  }
`

const ButtonWrapper = styled.div`
  display: flex;
  justify-content: center;
  align-items: center;
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
  & .waiting {
    animation: spin 1s linear infinite;
  }
  width: ${spacing["4Xl"]};
  height: 100%;
`

const RefreshButton = ({ onClick, waiting }: { onClick: () => Promise<void>, waiting: boolean }) => {
  return <ButtonWrapper title={getLocale('emailAliasesRefreshButtonTitle')}>
    {waiting
      ? <Icon className='waiting' name="loading-spinner" />
      : <Button title={getLocale('emailAliasesGeneratingNewAlias')}
        onClick={onClick}
        kind="plain" >
        <Icon name="refresh" />
      </Button>}
  </ButtonWrapper>
}

export const EmailAliasModal = (
  { onReturnToMain, viewState, email, mode, mappingService, bubble }:
    {
      onReturnToMain: () => void,
      viewState?: ViewState,
      bubble?: boolean,
      mode: ViewMode,
      email: string,
      mappingService: MappingService
    }
) => {
  const [limitReached, setLimitReached] = React.useState<boolean>(false)
  const [mainEmail, setMainEmail] = React.useState<string>(email)
  const [proposedAlias, setProposedAlias] = React.useState<string>(viewState?.alias?.email ?? '')
  const [proposedNote, setProposedNote] = React.useState<string>(viewState?.alias?.note ?? '')
  const [awaitingProposedAlias, setAwaitingProposedAlias] = React.useState<boolean>(true)
  const createOrSave = async () => {
    if (proposedAlias) {
      if (mode === 'Create') {
        await mappingService.createAlias(proposedAlias, proposedNote)
        await mappingService.fillField(proposedAlias)
      } else {
        await mappingService.updateAlias(proposedAlias, proposedNote, true)
      }
      onReturnToMain()
    }
  }
  const regenerateAlias = async () => {
    setAwaitingProposedAlias(true)
    const newEmailAlias = await mappingService.generateAlias()
    if (viewState?.mode === 'Create' || viewState?.mode === 'Edit') {
      setProposedAlias(newEmailAlias)
      setAwaitingProposedAlias(false)
    }
  }
  React.useEffect(() => {
    if (mode === 'Create') {
      regenerateAlias()
    }
    mappingService.getAccountEmail().then(email => setMainEmail(email ?? ''))
    if (bubble) {
      mappingService.getAliases().then(aliases => {
        setLimitReached(aliases.length >= MAX_ALIASES)
      })
    }
  }, [mode])
  return (
    <div>
      <h2>{mode === 'Create' ? getLocale('emailAliasesCreateAliasTitle') : getLocale('emailAliasesEditAliasTitle')}</h2>
      {bubble && <div>{getLocale('emailAliasesBubbleDescription')}</div>}
      {(bubble && limitReached) ?
        <h3>{getLocale('emailAliasesBubbleLimitReached')}</h3> :
        <span>
          <ModalSectionCol>
            <h3>{getLocale('emailAliasesAliasLabel')}</h3>
            <GeneratedEmailContainer>
              <div>{proposedAlias}</div>
              {mode === 'Create' && <RefreshButton onClick={regenerateAlias} waiting={awaitingProposedAlias} />}
            </GeneratedEmailContainer>
            <div>{formatMessage(getLocale('emailAliasesEmailsWillBeForwardedTo'), { placeholders: { $1: mainEmail } })}</div>
          </ModalSectionCol>
          <ModalSectionCol>
            <h3>{getLocale('emailAliasesNoteLabel')}</h3>
            <Input
              type='text'
              placeholder={getLocale('emailAliasesEditNotePlaceholder')}
              maxlength={255}
              value={proposedNote}
              onChange={(detail) => setProposedNote(detail.value)}
              onKeyDown={onEnterKey(createOrSave)}>
            </Input>
            {mode === 'Edit' && viewState?.alias?.domains &&
             <div>
               {formatMessage(getLocale('emailAliasesUsedBy'),
                              { placeholders: { $1: viewState?.alias?.domains?.join(', ') } })}
              </div>}
          </ModalSectionCol>
        </span>
      }
      <ButtonRow bubble={bubble}>
        <span>
          {bubble && <Button onClick={mappingService.showSettingsPage} kind='plain'>
            {getLocale('emailAliasesManageButton')}
          </Button>}
        </span>
        <span>
          <Button onClick={onReturnToMain} kind='plain'>
            {getLocale('emailAliasesCancelButton')}
          </Button>
          <Button
            kind='filled'
            isDisabled={mode === 'Create' && (limitReached || awaitingProposedAlias)}
            onClick={createOrSave}>
            {mode === 'Create' ? getLocale('emailAliasesCreateAliasButton') : getLocale('emailAliasesSaveAliasButton')}
          </Button>
        </span>
      </ButtonRow>
    </div>
  )
}