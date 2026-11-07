/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import {
  EditorModeAnnounceExtension,
  FocusManagerExtension,
  FocusTrapExtension,
  HistoryAnnounceExtension,
  RovingTabIndexExtension,
} from '@lexical/a11y';
import {$isCodeNode} from '@lexical/code';
import {
  $defaultShouldInsertAfter,
  AutoFocusExtension,
  ClearEditorExtension,
  ClickAfterLastBlockExtension,
  DecoratorTextExtension,
  HorizontalRuleExtension,
  SelectBlockExtension,
  SelectionAlwaysOnDisplayExtension,
  TabIndentationExtension,
} from '@lexical/extension';
import {HashtagExtension} from '@lexical/hashtag';
import {$createLinkNode, LinkExtension} from '@lexical/link';
import {
  $createListItemNode,
  $createListNode,
  CheckListExtension,
  ListExtension,
} from '@lexical/list';
import {PlainTextExtension} from '@lexical/plain-text';
import {useLexicalComposerContext} from '@lexical/react/LexicalComposerContext';
import {useLexicalEditable} from '@lexical/react/useLexicalEditable';
import {LexicalExtensionComposer} from '@lexical/react/LexicalExtensionComposer';
import {CollaborationPlugin} from '@lexical/react/LexicalCollaborationPlugin';
import {
  $createHeadingNode,
  $createQuoteNode,
  RichTextExtension,
} from '@lexical/rich-text';
import {TableExtension} from '@lexical/table';
import {
  $createParagraphNode,
  $createTextNode,
  $getRoot,
  configExtension,
  defineExtension,
  type SerializedEditorState,
} from 'lexical';
import {type JSX, useEffect, useMemo, useRef} from 'react';
import type {Collaborator, ProviderFactory} from './collaboration';
import {useCollaborationConfig} from './context/CollaborationContext';
import {EditorIntegrationProvider} from './context/EditorIntegrationContext';
import type {DocumentSnapshotRegistry} from './documentSnapshots';
import type {EditorIntegration} from './integration';
import {useSettings} from './context/SettingsContext';
import {ToolbarContext} from './context/ToolbarContext';
import Editor from './Editor';
import {CollaborativeEditorEnvironment} from './EditorEnvironment';
import EditorSurface from './EditorSurface';
import {registerSettingsSynchronization} from './hooks/useSynchronizeSettings';
import {KeywordsExtension} from './nodes/KeywordNode';
import {PlaygroundImportExtension} from './nodes/PlaygroundImportExtension';
import PlaygroundNodes from './nodes/PlaygroundNodes';
import {PlaygroundDOMRenderExtension} from './PlaygroundDOMRenderExtension';
import {AutocompleteExtension} from './plugins/AutocompleteExtension';
import {PlaygroundAutoLinkExtension} from './plugins/AutoLinkExtension';
import {CardExtension} from './plugins/CardExtension';
import DocumentSnapshotPlugin from './plugins/DocumentSnapshotPlugin';
import {CodeHighlightExtension} from './plugins/CodeHighlightExtension';
import {CollapsibleExtension} from './plugins/CollapsibleExtension';
import {DateTimeExtension} from './plugins/DateTimeExtension';
import {DragDropPasteExtension} from './plugins/DragDropPasteExtension';
import {EmojisExtension} from './plugins/EmojisExtension';
import {EquationsExtension} from './plugins/EquationsExtension';
import {ExcalidrawExtension} from './plugins/ExcalidrawExtension';
import {FigmaExtension} from './plugins/FigmaExtension';
import {ReactFindReplaceExtension} from './plugins/FindReplaceExtension';
import {ImagesExtension} from './plugins/ImagesExtension';
import {LayoutExtension} from './plugins/LayoutExtension/LayoutExtension';
import {PlaygroundMarkdownShortcutsExtension} from './plugins/MarkdownShortcutsExtension';
import {MaxLengthExtension} from './plugins/MaxLengthPlugin';
import {MentionsExtension} from './plugins/MentionsExtension';
import {PollExtension} from './plugins/PollExtension';
import {PullQuoteExtension} from './plugins/PullQuoteExtension';
import {ReactReviewExtension} from './plugins/ReviewExtension';
import {ShortcutsExtension} from './plugins/ShortcutsExtension';
import {SpecialTextExtension} from './plugins/SpecialTextExtension';
import {TabFocusExtension} from './plugins/TabFocusExtension';
import {TerseExportExtension} from './plugins/TerseExportExtension';
import {TwitterExtension} from './plugins/TwitterExtension';
import TypingPerfPlugin from './plugins/TypingPerfPlugin';
import {VisibleNonPrintingExtension} from './plugins/VisibleNonPrintingExtension';
import {YouTubeExtension} from './plugins/YouTubeExtension';
import Settings from './Settings';
import PlaygroundEditorTheme from './themes/PlaygroundEditorTheme';
import ShadowDomWrapper from './ui/ShadowDomWrapper';
import {validateUrl} from './url';

console.warn(
  'If you are profiling the playground app, please ensure you turn off the debug view. You can disable it by pressing on the settings control in the bottom-left of your screen and toggling the debug view setting.',
);

function $prepopulatedRichText() {
  const root = $getRoot();
  if (root.getFirstChild() === null) {
    const heading = $createHeadingNode('h1');
    heading.append($createTextNode('Welcome to the playground'));
    root.append(heading);
    const quote = $createQuoteNode();
    quote.append(
      $createTextNode(
        `In case you were wondering what the black box at the bottom is – it's the debug view, showing the current state of the editor. ` +
          `You can disable it by pressing on the settings control in the bottom-left of your screen and toggling the debug view setting.`,
      ),
    );
    root.append(quote);
    const paragraph = $createParagraphNode();
    paragraph.append(
      $createTextNode('The playground is a demo environment built with '),
      $createTextNode('@lexical/react').toggleFormat('code'),
      $createTextNode('.'),
      $createTextNode(' Try typing in '),
      $createTextNode('some text').toggleFormat('bold'),
      $createTextNode(' with '),
      $createTextNode('different').toggleFormat('italic'),
      $createTextNode(' formats.'),
    );
    root.append(paragraph);
    const paragraph2 = $createParagraphNode();
    paragraph2.append(
      $createTextNode(
        'Make sure to check out the various plugins in the toolbar. You can also use #hashtags or @-mentions too!',
      ),
    );
    root.append(paragraph2);
    const paragraph3 = $createParagraphNode();
    paragraph3.append(
      $createTextNode(`If you'd like to find out more about Lexical, you can:`),
    );
    root.append(paragraph3);
    const list = $createListNode('bullet');
    list.append(
      $createListItemNode().append(
        $createTextNode(`Visit the `),
        $createLinkNode('https://lexical.dev/').append(
          $createTextNode('Lexical website'),
        ),
        $createTextNode(` for documentation and more information.`),
      ),
      $createListItemNode().append(
        $createTextNode(`Check out the code on our `),
        $createLinkNode('https://github.com/facebook/lexical').append(
          $createTextNode('GitHub repository'),
        ),
        $createTextNode(`.`),
      ),
      $createListItemNode().append(
        $createTextNode(`Playground code can be found `),
        $createLinkNode(
          'https://github.com/facebook/lexical/tree/main/packages/lexical-playground',
        ).append($createTextNode('here')),
        $createTextNode(`.`),
      ),
      $createListItemNode().append(
        $createTextNode(`Join our `),
        $createLinkNode('https://discord.com/invite/KmG4wQnnD9').append(
          $createTextNode('Discord Server'),
        ),
        $createTextNode(` and chat with the team.`),
      ),
    );
    root.append(list);
    const paragraph4 = $createParagraphNode();
    paragraph4.append(
      $createTextNode(
        `Lastly, we're constantly adding cool new features to this playground. So make sure you check back here when you next get a chance :).`,
      ),
    );
    root.append(paragraph4);
  }
}

// These are only enabled for rich-text mode
const PlaygroundRichTextExtension = defineExtension({
  dependencies: [
    configExtension(RichTextExtension, {
      escapeFormatTriggers: {
        code: {arrow: true, click: true, enter: true, onlyAtBoundary: true},
      },
    }),
    // Each node extension below registers its own DOM-import rules — the
    // framework nodes (rich-text, list, table, code) and the playground block
    // hosts (Card, PullQuote, Review) alike — so the rich-text importer set
    // tracks this node set automatically (kept out of the always-on
    // PlaygroundImportExtension so plain-text mode doesn't pull in
    // RichTextExtension, which conflicts with PlainTextExtension).
    configExtension(TableExtension, {
      hasStickyScrollbar: true,
    }),
    ImagesExtension,
    HorizontalRuleExtension,
    TwitterExtension,
    YouTubeExtension,
    FigmaExtension,
    TabFocusExtension,
    CollapsibleExtension,
    CodeHighlightExtension,
    configExtension(ListExtension, {
      shouldPreserveNumbering: false,
    }),
    CheckListExtension,
    PlaygroundMarkdownShortcutsExtension,
    PollExtension,
    EquationsExtension,
    LayoutExtension,
    ExcalidrawExtension,
    CardExtension,
    ReactReviewExtension,
    ReactFindReplaceExtension,
    PullQuoteExtension,
    ShortcutsExtension,
    configExtension(TabIndentationExtension, {maxIndent: 7}),
  ],
  name: '@lexical/playground/RichText',
});

const AppExtension = defineExtension({
  dependencies: [
    AutoFocusExtension,
    ClearEditorExtension,
    DecoratorTextExtension,
    HistoryAnnounceExtension,
    EditorModeAnnounceExtension,
    KeywordsExtension,
    HashtagExtension,
    DateTimeExtension,
    MaxLengthExtension,
    SpecialTextExtension,
    DragDropPasteExtension,
    EmojisExtension,
    MentionsExtension,
    configExtension(LinkExtension, {validateUrl}),
    PlaygroundAutoLinkExtension,
    SelectionAlwaysOnDisplayExtension,
    configExtension(SelectBlockExtension, {
      cascadeSelection: true,
    }),
    TerseExportExtension,
    configExtension(ClickAfterLastBlockExtension, {
      $shouldInsertAfter: node =>
        $defaultShouldInsertAfter(node) || $isCodeNode(node),
    }),
    configExtension(AutocompleteExtension, {disabled: true}),
    configExtension(VisibleNonPrintingExtension, {
      disabled: true,
    }),
    // DOMImportExtension pipeline — `PlaygroundImportExtension` bundles
    // the shared `CoreImportExtension` baseline, the playground-specific
    // inline-style overlay and the `ClipboardDOMImportExtension` paste
    // handler. Per-node import rules ride along with each node extension.
    PlaygroundImportExtension,
    // Replaces the legacy `buildHTMLConfig().export` overrides.
    PlaygroundDOMRenderExtension,
    FocusTrapExtension,
    RovingTabIndexExtension,
    FocusManagerExtension,
  ],
  name: '@lexical/playground',
  namespace: 'Playground',
  nodes: PlaygroundNodes,
  theme: PlaygroundEditorTheme,
});

/** Shared construction-time configuration for interactive editors and read-only previews. */
interface EditorExtensionConfig {
  autoFocus: boolean;
  editable: boolean;
  initialEditorState?: SerializedEditorState | null;
  isRichText: boolean;
  namespace?: string;
}

export function createEditorExtension(
  config: EditorExtensionConfig,
  integration: EditorIntegration,
) {
  const {
    autoFocus,
    editable,
    initialEditorState = null,
    isRichText,
    namespace,
  } = config;

  return defineExtension({
    $initialEditorState:
      initialEditorState === null ? null : JSON.stringify(initialEditorState),
    dependencies: [
      AppExtension,
      configExtension(AutoFocusExtension, {disabled: !autoFocus}),
      integration.extension,
      isRichText ? PlaygroundRichTextExtension : PlainTextExtension,
    ],
    editable,
    name: '@lexical/playground/editor',
    namespace,
    // Apply INITIAL_SETTINGS to the extension config signals synchronously as
    // the editor is built, before the React useSynchronizeSettings effect
    // takes over live updates.
    register: registerSettingsSynchronization,
  });
}

function EditableController({editable}: {editable: boolean}): null {
  const [editor] = useLexicalComposerContext();

  useEffect(() => {
    editor.setEditable(editable);
  }, [editable, editor]);

  return null;
}

function EditorShell({isShadowDOM}: {isShadowDOM: boolean}): JSX.Element {
  const isEditable = useLexicalEditable();
  const editor = (
    <EditorSurface editable={isEditable}>
      <Editor />
    </EditorSurface>
  );

  return isShadowDOM ? <ShadowDomWrapper>{editor}</ShadowDomWrapper> : editor;
}

function App({
  editable,
  integration,
}: {
  editable: boolean;
  integration: EditorIntegration;
}): JSX.Element {
  const initialEditable = useRef(editable).current;
  const {
    settings: {emptyEditor, isRichText, isShadowDOM, measureTypingPerf},
  } = useSettings();

  // Only the editor-recreating settings belong in this memo's deps. Table
  // behavior toggles (and other live-reconfigurable settings) are applied
  // reactively in Editor.tsx via useSyncExtensionSignal, so they must NOT
  // appear here or they would rebuild the whole editor on every change.
  const app = useMemo(
    () =>
      createEditorExtension(
        {
          autoFocus: true,
          editable: initialEditable,
          isRichText,
        },
        integration,
      ),
    [emptyEditor, initialEditable, integration, isRichText],
  );
  const {cursorColor, displayName, providerFactory} = useCollaborationConfig();

  return (
    <EditorIntegrationProvider value={integration}>
      <LexicalExtensionComposer extension={app} contentEditable={null}>
        <CollaborationPlugin
          cursorColor={cursorColor}
          id="main"
          initialEditorState={emptyEditor ? undefined : $prepopulatedRichText}
          providerFactory={providerFactory}
          shouldBootstrap={true}
          username={displayName}
        />
        <DocumentSnapshotPlugin documentKey="main" />
        <EditableController editable={editable} />
        <ToolbarContext>
          <EditorShell isShadowDOM={isShadowDOM} />
          <Settings />
          {measureTypingPerf ? <TypingPerfPlugin /> : null}
        </ToolbarContext>
      </LexicalExtensionComposer>
    </EditorIntegrationProvider>
  );
}

export default function PlaygroundApp({
  collaborator,
  editable,
  integration,
  providerFactory,
  snapshotRegistry,
}: {
  collaborator: Collaborator;
  editable: boolean;
  integration: EditorIntegration;
  providerFactory: ProviderFactory;
  snapshotRegistry: DocumentSnapshotRegistry;
}): JSX.Element {
  return (
    <CollaborativeEditorEnvironment
      collaborator={collaborator}
      providerFactory={providerFactory}
      snapshotRegistry={snapshotRegistry}
    >
      <App editable={editable} integration={integration} />
    </CollaborativeEditorEnvironment>
  );
}
