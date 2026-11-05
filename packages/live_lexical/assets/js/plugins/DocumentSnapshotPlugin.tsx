import {useLexicalComposerContext} from '@lexical/react/LexicalComposerContext';
import {useLayoutEffect} from 'react';

import {useCollaborationConfig} from '../context/CollaborationContext';

export default function DocumentSnapshotPlugin({
  documentKey,
}: {
  documentKey: string;
}): null {
  const [editor] = useLexicalComposerContext();
  const {snapshotRegistry} = useCollaborationConfig();

  useLayoutEffect(
    () => snapshotRegistry.register(documentKey, editor),
    [documentKey, editor, snapshotRegistry],
  );

  return null;
}
