import {LexicalExtensionComposer} from '@lexical/react/LexicalExtensionComposer';
import type {SerializedEditorState} from 'lexical';
import {type JSX, useMemo} from 'react';

import {createEditorExtension} from './App';
import {EditorIntegrationProvider} from './context/EditorIntegrationContext';
import {ReadOnlyEditorEnvironment} from './EditorEnvironment';
import EditorSurface from './EditorSurface';
import type {Collaborator} from './collaboration';
import type {EditorIntegration} from './integration';
import ContentEditable from './ui/ContentEditable';

export default function ReadOnlyContent({
  collaborator,
  integration,
  lexicalState,
  namespace,
}: {
  collaborator: Collaborator;
  integration: EditorIntegration;
  lexicalState: SerializedEditorState | null;
  namespace: string;
}): JSX.Element {
  const extension = useMemo(
    () =>
      createEditorExtension(
        {
          autoFocus: false,
          editable: false,
          initialEditorState: lexicalState,
          isRichText: true,
          namespace,
        },
        integration,
      ),
    [integration, lexicalState, namespace],
  );

  return (
    <ReadOnlyEditorEnvironment collaborator={collaborator}>
      <EditorIntegrationProvider value={integration}>
        <LexicalExtensionComposer extension={extension} contentEditable={null}>
          <EditorSurface className="lexical-embedded-page" editable={false}>
            <ContentEditable placeholder="(Empty page)" />
          </EditorSurface>
        </LexicalExtensionComposer>
      </EditorIntegrationProvider>
    </ReadOnlyEditorEnvironment>
  );
}
