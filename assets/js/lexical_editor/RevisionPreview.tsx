import {LexicalComposer} from '@lexical/react/LexicalComposer';
import {useLexicalComposerContext} from '@lexical/react/LexicalComposerContext';
import {LexicalErrorBoundary} from '@lexical/react/LexicalErrorBoundary';
import {RichTextPlugin} from '@lexical/react/LexicalRichTextPlugin';
import type {SerializedEditorState} from 'lexical';
import {type JSX, useCallback, useEffect, useState} from 'react';

import differ from '../../vendor/htmldiffer';

import type {WikiPageReference} from './context/WikiPagesContext';
import {ReadOnlyEditorEnvironment} from './EditorEnvironment';
import EditorSurface from './EditorSurface';
import PlaygroundNodes from './nodes/PlaygroundNodes';
import PlaygroundEditorTheme from './themes/PlaygroundEditorTheme';
import ContentEditable from './ui/ContentEditable';

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
  lexicalState,
  namespace,
  onHtml,
}: {
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
        nodes: PlaygroundNodes,
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
  lexicalState,
  pages,
  previousLexicalState,
}: {
  lexicalState: SerializedEditorState;
  pages: WikiPageReference[];
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
      : differ(previousHtml, currentHtml);

  return (
    <ReadOnlyEditorEnvironment pages={pages}>
      <div aria-hidden="true" className="hidden">
        <PreviewEditor
          lexicalState={previousLexicalState}
          namespace="PreviousRevisionPreview"
          onHtml={capturePreviousHtml}
        />
        <PreviewEditor
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
