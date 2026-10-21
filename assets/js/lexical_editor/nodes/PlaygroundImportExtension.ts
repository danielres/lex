/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import {ClipboardDOMImportExtension} from '@lexical/clipboard';
import {CoreImportExtension} from '@lexical/html';
import {LinkExtension} from '@lexical/link';
import {defineExtension} from 'lexical';

/**
 * Plain-text-safe DOM-import baseline, added in `AppExtension` so it applies in
 * every editor mode:
 *
 *  - {@link CoreImportExtension} (paragraphs, text, line breaks, generic
 *    block/inline handling, plus the registration-gated core rules such as the
 *    `<hr>` rule)
 *  - {@link LinkExtension} (always in the playground; registers its own
 *    `<a>` import rule)
 *  - {@link ClipboardDOMImportExtension} so pastes flow through the pipeline
 *
 * Every other import rule rides its node extension — the rich-text framework
 * nodes (rich-text, list, table, code) each register their own rules, and the
 * playground block hosts (Card, PullQuote, Review) do the same in
 * `PlaygroundRichTextExtension`. So the importer set automatically matches the
 * node set per mode, and plain-text mode never pulls in `RichTextExtension`
 * (which *conflicts* with `PlainTextExtension`).
 */
export const PlaygroundImportExtension = defineExtension({
  dependencies: [
    CoreImportExtension,
    LinkExtension,
    ClipboardDOMImportExtension,
  ],
  name: '@lexical/playground/Import',
});
