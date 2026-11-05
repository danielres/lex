import {LexicalComposer} from '@lexical/react/LexicalComposer';
import {useLexicalComposerContext} from '@lexical/react/LexicalComposerContext';
import {LexicalErrorBoundary} from '@lexical/react/LexicalErrorBoundary';
import {RichTextPlugin} from '@lexical/react/LexicalRichTextPlugin';
import type {SerializedEditorState} from 'lexical';
import {type JSX, useCallback, useEffect, useState} from 'react';

import differ from '../../vendor/htmldiffer';

import type {Collaborator} from './context/CollaborationContext';
import type {EditorIntegration} from './context/EditorIntegrationContext';
import {ReadOnlyEditorEnvironment} from './EditorEnvironment';
import EditorSurface from './EditorSurface';
import PlaygroundNodes from './nodes/PlaygroundNodes';
import PlaygroundEditorTheme from './themes/PlaygroundEditorTheme';
import ContentEditable from './ui/ContentEditable';

const EXCALIDRAW_SELECTOR = '[data-lexical-excalidraw-id]';
const EXCALIDRAW_PLACEHOLDER = 'data-revision-excalidraw';

function protectExcalidraw(
  html: string,
  elements: Map<string, Element>,
): string {
  const template = document.createElement('template');
  const occurrences = new Map<string, number>();
  template.innerHTML = html;

  template.content.querySelectorAll(EXCALIDRAW_SELECTOR).forEach(element => {
    const revisionId = element.getAttribute('data-lexical-excalidraw-id');

    if (revisionId === null) {
      throw new Error('Excalidraw revision id is missing');
    }

    const occurrence = occurrences.get(revisionId) ?? 0;
    const id = `${revisionId}-${occurrence}`;
    occurrences.set(revisionId, occurrence + 1);
    elements.set(id, element.cloneNode(true) as Element);

    const placeholder = document.createElement('img');
    placeholder.setAttribute(EXCALIDRAW_PLACEHOLDER, id);
    element.replaceWith(placeholder);
  });

  return template.innerHTML;
}

function restoreExcalidraw(html: string, elements: Map<string, Element>): string {
  const template = document.createElement('template');
  template.innerHTML = html;

  template.content
    .querySelectorAll(`[${EXCALIDRAW_PLACEHOLDER}]`)
    .forEach(placeholder => {
      const id = placeholder.getAttribute(EXCALIDRAW_PLACEHOLDER);
      const element = id === null ? undefined : elements.get(id);

      if (element !== undefined) {
        placeholder.replaceWith(element.cloneNode(true));
      }
    });

  return template.innerHTML;
}

function renderDiff(previousHtml: string, currentHtml: string): string {
  const elements = new Map<string, Element>();
  const protectedPreviousHtml = protectExcalidraw(previousHtml, elements);
  const protectedCurrentHtml = protectExcalidraw(currentHtml, elements);
  const html = differ(protectedPreviousHtml, protectedCurrentHtml);

  return restoreExcalidraw(html, elements);
}

function CaptureHtmlPlugin({onHtml}: {onHtml: (html: string) => void}) {
  const [editor] = useLexicalComposerContext();

  useEffect(() => {
    let observer: MutationObserver | undefined;

    const unregisterRootListener = editor.registerRootListener(root => {
      observer?.disconnect();

      if (root === null) {
        return;
      }

      const captureHtml = () => onHtml(root.innerHTML);
      observer = new MutationObserver(captureHtml);
      observer.observe(root, {
        attributes: true,
        characterData: true,
        childList: true,
        subtree: true,
      });
      captureHtml();
    });

    return () => {
      observer?.disconnect();
      unregisterRootListener();
    };
  }, [editor, onHtml]);

  return null;
}

function PreviewEditor({
  integration,
  lexicalState,
  namespace,
  onHtml,
}: {
  integration: EditorIntegration;
  lexicalState: SerializedEditorState | null;
  namespace: string;
  onHtml: (html: string) => void;
}) {
  return (
    <LexicalComposer
      initialConfig={{
        editable: false,
        editorState:
          lexicalState === null ? undefined : JSON.stringify(lexicalState),
        namespace,
        nodes: [...PlaygroundNodes, ...integration.nodes],
        onError: error => {
          throw error;
        },
        theme: PlaygroundEditorTheme,
      }}
    >
      <EditorSurface className="lexical-revision-preview" editable={false}>
        <RichTextPlugin
          contentEditable={<ContentEditable placeholder="" />}
          ErrorBoundary={LexicalErrorBoundary}
        />
        <CaptureHtmlPlugin onHtml={onHtml} />
      </EditorSurface>
    </LexicalComposer>
  );
}

export default function RevisionPreview({
  collaborator,
  integration,
  lexicalState,
  previousLexicalState,
}: {
  collaborator: Collaborator;
  integration: EditorIntegration;
  lexicalState: SerializedEditorState;
  previousLexicalState: SerializedEditorState | null;
}): JSX.Element {
  const [currentHtml, setCurrentHtml] = useState<string | null>(null);
  const [previousHtml, setPreviousHtml] = useState<string | null>(null);
  const captureCurrentHtml = useCallback((html: string) => {
    setCurrentHtml(html);
  }, []);
  const capturePreviousHtml = useCallback((html: string) => {
    setPreviousHtml(html);
  }, []);
  const diffHtml =
    currentHtml === null || previousHtml === null
      ? ''
      : renderDiff(previousHtml, currentHtml);

  return (
    <ReadOnlyEditorEnvironment collaborator={collaborator}>
      <div aria-hidden="true" className="hidden">
        <PreviewEditor
          integration={integration}
          lexicalState={previousLexicalState}
          namespace="PreviousRevisionPreview"
          onHtml={capturePreviousHtml}
        />
        <PreviewEditor
          integration={integration}
          lexicalState={lexicalState}
          namespace="CurrentRevisionPreview"
          onHtml={captureCurrentHtml}
        />
      </div>

      <EditorSurface className="lexical-revision-preview" editable={false}>
        <div
          className="ContentEditable__root lexical-revision-diff"
          dangerouslySetInnerHTML={{__html: diffHtml}}
        />
      </EditorSurface>
    </ReadOnlyEditorEnvironment>
  );
}
