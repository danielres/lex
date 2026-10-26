import {LexicalComposer} from '@lexical/react/LexicalComposer';
import {LexicalErrorBoundary} from '@lexical/react/LexicalErrorBoundary';
import {RichTextPlugin} from '@lexical/react/LexicalRichTextPlugin';
import type {SerializedEditorState} from 'lexical';
import type {JSX} from 'react';

import type {WikiPageReference} from './context/WikiPagesContext';
import {ReadOnlyEditorEnvironment} from './EditorEnvironment';
import EditorSurface from './EditorSurface';
import PlaygroundNodes from './nodes/PlaygroundNodes';
import PlaygroundEditorTheme from './themes/PlaygroundEditorTheme';
import ContentEditable from './ui/ContentEditable';

function PreviewEditor({lexicalState}: {lexicalState: SerializedEditorState}) {
  return (
    <LexicalComposer
      initialConfig={{
        editable: false,
        editorState: JSON.stringify(lexicalState),
        namespace: 'RevisionPreview',
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
      </EditorSurface>
    </LexicalComposer>
  );
}

export default function RevisionPreview({
  lexicalState,
  pages,
}: {
  lexicalState: SerializedEditorState;
  pages: WikiPageReference[];
}): JSX.Element {
  return (
    <ReadOnlyEditorEnvironment pages={pages}>
      <PreviewEditor lexicalState={lexicalState} />
    </ReadOnlyEditorEnvironment>
  );
}
