#!/usr/bin/vpython3
#
# Copyright (c) 2022 The Brave Authors. All rights reserved.
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at https://mozilla.org/MPL/2.0/.

import argparse
import os.path
import sys
import glob

from xml.etree import ElementTree as ET
import defusedxml.ElementTree as DET

from lib.l10n.grd_utils import (braveify_grd_in_place, braveify_grd_tree,
                                find_all_comments, find_all_tags,
                                get_grd_leading_comments,
                                GOOGLE_CHROME_STRINGS_MIGRATION_MAP,
                                get_override_file_path, textify,
                                write_xml_file_from_tree)

BRAVE_SOURCE_ROOT = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
SRC_SOURCE_ROOT = os.path.abspath(os.path.dirname(BRAVE_SOURCE_ROOT))

sys.path.insert(1, os.path.join(SRC_SOURCE_ROOT, 'tools/grit'))

from grit.extern import tclib  # pylint: disable=import-error,wrong-import-position


def write_xtb_content(xtb_tree, source_string_path):
    transformed_content = (b'<?xml version="1.0" ?>\n' +
        b'<!DOCTYPE translationbundle>\n' +
        ET.tostring(xtb_tree.getroot(), encoding='utf-8',
            xml_declaration=False).strip().replace(b'" />', b'"/>'))
    print(f'writing file {source_string_path}')
    transformed_content = transformed_content.replace(b'  <translation',
                                                      b'<translation')
    with open(source_string_path, mode='wb') as f:
        f.write(transformed_content)
    print('-----------')


def write_new_translations_to_xtb(xtb_path, messages):
    brave_xtb_xml_tree = DET.parse(xtb_path)
    bundle_element = brave_xtb_xml_tree.getroot()
    for message in messages:
        element = brave_xtb_xml_tree.find(f'.//translation[@id="{message[0]}"]')
        if element is None:
            print(f'Did not find id={message[0]} in {xtb_path}')
            element = ET.SubElement(bundle_element, 'translation')
            element.set('id', message[0])
        element.text = message[1]
    write_xtb_content(brave_xtb_xml_tree, xtb_path)


def migrate_google_chrome_xtb_translations_for_messages(message_ids):
    google_chrome_xtb_files = glob.glob(
        os.path.join(SRC_SOURCE_ROOT,
                     'chrome/app/resources/google_chrome_strings_*.xtb'))
    for google_xtb_path in google_chrome_xtb_files:
        google_xtb_xml_tree = DET.parse(google_xtb_path)
        #print(google_xtb_path, google_elem.text)
        lang = os.path.basename(google_xtb_path).replace(
            'google_chrome_strings_', '').replace('.xtb', '')
        if not lang:
            print(
                'Skipping file {} because unable to determine language'.format(
                    google_xtb_path))
            continue
        brave_xtb_path = os.path.join(
            BRAVE_SOURCE_ROOT,
            'app/resources/brave_strings_{}.xtb'.format(lang))
        if not os.path.exists(brave_xtb_path):
            print('Unable to find brave translation file {}'.format(
                brave_xtb_path))
            return False
        messages = [(message_id,
                     google_xtb_xml_tree.find('.//translation[@id="' +
                                               message_id + '"]').text)
                    for message_id in message_ids]

        write_new_translations_to_xtb(brave_xtb_path, messages)

    return True


def migrate_google_chrome_strings(brave_strings_xml_tree,
                                  google_chrome_strings_map):
    print('Migrating Chrome strings...')
    google_chrome_string_path = os.path.join(
        SRC_SOURCE_ROOT, 'chrome/app/google_chrome_strings.grd')
    google_chrome_xml_tree = DET.parse(google_chrome_string_path)

    message_ids = []
    for item in google_chrome_strings_map.keys():
        google_message_elem = google_chrome_xml_tree.find(
            './/message[@name="{}"]'.format(item))
        message_text = google_message_elem.text.lstrip().rstrip()
        message_ids.append(tclib.GenerateMessageId(message_text))
        messages_element = brave_strings_xml_tree.find('.//messages')
        new_element = ET.SubElement(messages_element, 'message')
        new_element.set('name', google_chrome_strings_map[item])
        new_element.text = google_message_elem.text
        new_element.set('desc', google_message_elem.get('desc'))
    return migrate_google_chrome_xtb_translations_for_messages(message_ids)


def parse_args():
    parser = argparse.ArgumentParser(description='Push strings to Transifex')
    parser.add_argument('--source_string_path', nargs=1)
    return parser.parse_args()


def generate_overrides_and_replace_strings(source_string_path,
                                           leading_comments):
    # pylint: disable=too-many-locals
    # Read the clean GRD and apply only branding replacements (e.g. Chrome ->
    # Brave).
    original_parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    original_xml_tree_with_branding_fixes = DET.parse(
        source_string_path, original_parser)
    braveify_grd_tree(original_xml_tree_with_branding_fixes, True)
    # Apply all replacements the the clean GRD.
    braveify_grd_in_place(source_string_path)
    # This tree has all replacements whereas the
    # original_xml_tree_with_branding_fixes only has branding replacements. We
    # don't need to write branding-only replacements to the _override file
    # because we don't need to translate them - we apply branding replacements
    # to the XTB files when we do pull_l10n.
    modified_parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    modified_xml_tree = DET.parse(source_string_path, modified_parser)

    original_messages = original_xml_tree_with_branding_fixes.findall(
        './/message')
    modified_messages = find_all_tags(modified_xml_tree.getroot(), 'message')
    assert len(original_messages) == len(modified_messages)
    # pylint: disable=consider-using-enumerate
    for i in range(0, len(original_messages)):
        if textify(original_messages[i]) == textify(modified_messages[i][0]):
            modified_messages[i][1].remove(modified_messages[i][0])

    # Remove unneeded things from the override grds
    comments = find_all_comments(modified_xml_tree.getroot())
    for (comment, parent) in comments:
        parent.remove(comment)
    outputs = find_all_tags(modified_xml_tree.getroot(), 'outputs')
    for (output, parent) in outputs:
        parent.remove(output)

    parts = find_all_tags(modified_xml_tree.getroot(), 'part')
    for (part, parent) in parts:
        override_file = get_override_file_path(part.attrib['file'])
        # Check for the special case of brave_stings.grd:
        if (os.path.basename(source_string_path) == 'brave_strings.grd'
                and override_file == 'settings_chromium_strings_override.grdp'):
            override_file = 'settings_brave_strings_override.grdp'

        if os.path.exists(os.path.join(os.path.dirname(source_string_path),
                                       override_file)):
            part.attrib['file'] = override_file
        else:
            # No grdp override here, carry on
            parent.remove(part)
    files = modified_xml_tree.findall('.//file')
    for f in files:
        f.attrib['path'] = get_override_file_path(f.attrib['path'])

    # Write out an override file that is a duplicate of the original file but
    # with strings that are shared with Chrome stripped out.
    override_string_path = get_override_file_path(source_string_path)
    modified_messages = modified_xml_tree.findall('.//message')
    modified_parts = modified_xml_tree.findall('.//part')
    if len(modified_messages) > 0 or len(modified_parts) > 0:
        # Fix output filenames to generate "brave" files instead of "chromium".
        if os.path.basename(source_string_path) == 'brave_strings.grd':
            for file in files:
                if file.attrib['path'].endswith('.xtb'):
                    file.attrib['path'] = \
                        file.attrib['path'].replace('chromium_strings',
                                                    'brave_strings')
        print(f'Writing override {override_string_path}')
        write_xml_file_from_tree(override_string_path, modified_xml_tree,
                                 leading_comments)


def main():
    # pylint: disable=too-many-statements
    args = parse_args()
    # This file path is a string path inside brave/ but just recently copied
    # in from chromium files which need replacements.
    source_string_path = os.path.join(BRAVE_SOURCE_ROOT,
                                      args.source_string_path[0])
    filename = os.path.basename(source_string_path)
    extension = os.path.splitext(source_string_path)[1]
    if extension not in ('.grd', '.grdp'):
        print(f'returning early: unexpected file extension {extension}')
        return 1

    print(f'Rebasing source string file: {source_string_path}')
    print(f'filename: {filename}')

    # Retrieve original pre-root comments as python's xml library doesn't
    # parse them.
    comments = get_grd_leading_comments(source_string_path)

    generate_overrides_and_replace_strings(source_string_path, comments)

    # If you modify the translateable attribute then also update
    # is_translateable_string function in brave/script/lib/transifex_common.py.
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    xml_tree = DET.parse(source_string_path, parser)
    (basename, _) = filename.split('.')
    if basename == 'brave_strings':
        if not migrate_google_chrome_strings(
                xml_tree, GOOGLE_CHROME_STRINGS_MIGRATION_MAP):
            return 1
        elem1 = xml_tree.find('.//message[@name="IDS_SXS_SHORTCUT_NAME"]')
        elem1.text = 'Brave Nightly'
        elem1.attrib.pop('desc')
        elem1.attrib.pop('translateable')
        elem1 = xml_tree.find('.//message[@name="IDS_SHORTCUT_NAME_BETA"]')
        elem1.text = 'Brave Beta'
        elem1.attrib.pop('desc')
        elem1.attrib.pop('translateable')
        elem1 = xml_tree.find('.//message[@name="IDS_SHORTCUT_NAME_DEV"]')
        elem1.text = 'Brave Dev'
        elem1.attrib.pop('desc')
        elem1.attrib.pop('translateable')
        elem1 = xml_tree.find(
            './/message[@name="IDS_APP_SHORTCUTS_SUBDIR_NAME_BETA"]')
        elem1.text = 'Brave Apps'
        elem1.attrib.pop('desc')
        elem1.attrib.pop('translateable')
        elem1 = xml_tree.find(
            './/message[@name="IDS_APP_SHORTCUTS_SUBDIR_NAME_DEV"]')
        elem1.text = 'Brave Apps'
        elem1.attrib.pop('desc')
        elem1.attrib.pop('translateable')
        elem1 = xml_tree.find(
            './/message[@name="IDS_INBOUND_MDNS_RULE_NAME_BETA"]')
        elem1.text = 'Brave Beta (mDNS-In)'
        elem1.attrib.pop('desc')
        elem1.attrib.pop('translateable')
        elem1 = xml_tree.find(
            './/message[@name="IDS_INBOUND_MDNS_RULE_NAME_CANARY"]')
        elem1.text = 'Brave Nightly (mDNS-In)'
        elem1.attrib.pop('desc')
        elem1.attrib.pop('translateable')
        elem1 = xml_tree.find(
            './/message[@name="IDS_INBOUND_MDNS_RULE_NAME_DEV"]')
        elem1.text = 'Brave Dev (mDNS-In)'
        elem1.attrib.pop('desc')
        elem1.attrib.pop('translateable')
        elem1 = xml_tree.find(
            './/message[@name="IDS_INBOUND_MDNS_RULE_DESCRIPTION"]')
        elem1.attrib.pop('desc')
        elem1 = xml_tree.find(
            './/message[@name="IDS_INBOUND_MDNS_RULE_DESCRIPTION_BETA"]')
        elem1.text = 'Inbound rule for Brave Beta to allow mDNS traffic.'
        elem1.attrib.pop('desc')
        elem1.attrib.pop('translateable')
        elem1 = xml_tree.find(
            './/message[@name="IDS_INBOUND_MDNS_RULE_DESCRIPTION_CANARY"]')
        elem1.text = 'Inbound rule for Brave Nightly to allow mDNS traffic.'
        elem1.attrib.pop('desc')
        elem1.attrib.pop('translateable')
        elem1 = xml_tree.find(
            './/message[@name="IDS_INBOUND_MDNS_RULE_DESCRIPTION_DEV"]')
        elem1.text = 'Inbound rule for Brave Dev to allow mDNS traffic.'
        elem1.attrib.pop('desc')
        elem1.attrib.pop('translateable')
        elem1 = xml_tree.find(
            './/part[@file="settings_chromium_strings.grdp"]')
        elem1.set('file', 'settings_brave_strings.grdp')
        elem1 = xml_tree.find(
            './/message[@name="IDS_INSTALL_OS_NOT_SUPPORTED"]')
        elem1.text = elem1.text.replace('Windows 7', 'Windows 10')

    # Fix output filenames to generate "brave" files instead of "chromium".
    if basename in ('brave_strings', 'components_brave_strings'):
        outputs = xml_tree.findall('.//output')
        for output in outputs:
            if output.attrib['filename'].endswith('.pak') or \
                output.attrib['filename'].endswith('.xml'):
                    output.attrib['filename'] = \
                        output.attrib['filename'].replace(
                            'chromium_strings', 'brave_strings')
    if basename in ('brave_strings'):
        files = xml_tree.findall('.//file')
        for file in files:
            if file.attrib['path'].endswith('.xtb'):
                file.attrib['path'] = file.attrib['path'].replace(
                    'chromium_strings', 'brave_strings')

    print(f'writing file {source_string_path}')
    write_xml_file_from_tree(source_string_path, xml_tree, comments)
    print('-----------')
    return 0


if __name__ == '__main__':
    sys.exit(main())
