import type {Provider} from '@lexical/yjs';
import type {Doc} from 'yjs';

export type ProviderFactory = (
  id: string,
  yjsDocMap: Map<string, Doc>,
) => Provider;

export interface EditorCollaboration {
  confirmUpdatesApplied(): Promise<void>;
  destroy(): void;
  providerFactory: ProviderFactory;
}
