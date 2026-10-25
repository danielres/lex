import {
  $getRoot,
  type LexicalEditor,
  type SerializedEditorState,
} from 'lexical';

export interface DocumentSnapshot {
  documentKey: string;
  lexicalState: SerializedEditorState;
  searchText: string;
}

export class DocumentSnapshotRegistry {
  private editors = new Map<string, LexicalEditor>();
  private editable: boolean;

  constructor(editable: boolean) {
    this.editable = editable;
  }

  register(documentKey: string, editor: LexicalEditor): () => void {
    editor.setEditable(this.editable);
    this.editors.set(documentKey, editor);

    return () => {
      if (this.editors.get(documentKey) === editor) {
        this.editors.delete(documentKey);
      }
    };
  }

  setEditable(editable: boolean): void {
    this.editable = editable;
    this.editors.forEach(editor => editor.setEditable(editable));
  }

  snapshots(): DocumentSnapshot[] {
    return Array.from(this.editors.entries())
      .sort(([firstKey], [secondKey]) => firstKey.localeCompare(secondKey))
      .map(([documentKey, editor]) => {
        const editorState = editor.getEditorState();
        const searchText = editorState.read(() => $getRoot().getTextContent());

        return {
          documentKey,
          lexicalState: editorState.toJSON(),
          searchText,
        };
      });
  }
}
