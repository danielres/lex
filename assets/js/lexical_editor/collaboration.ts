import type {Provider} from '@lexical/yjs';

import {Socket} from 'phoenix';
import {PhoenixChannelProvider} from 'y-phoenix-channel';
import {Doc} from 'yjs';

export type ProviderFactory = (
  id: string,
  yjsDocMap: Map<string, Doc>,
) => Provider;

export interface PhoenixCollaboration {
  destroy(): void;
  providerFactory: ProviderFactory;
}

export function createPhoenixCollaboration(
  documentId: string,
): PhoenixCollaboration {
  const socket = new Socket('/socket');
  const providers = new Set<PhoenixChannelProvider>();
  socket.connect();

  const providerFactory: ProviderFactory = (id, yjsDocMap) => {
    let doc = yjsDocMap.get(id);

    if (doc === undefined) {
      doc = new Doc();
      yjsDocMap.set(id, doc);
    } else {
      doc.load();
    }

    const provider = new PhoenixChannelProvider(
      socket,
      `y_doc:${documentId}/${id}`,
      doc,
      {connect: false, disableBc: true},
    );
    providers.add(provider);

    // Both libraries use the same Yjs awareness runtime contract. Lexical's
    // type narrows the otherwise open awareness state to its cursor fields.
    return provider as unknown as Provider;
  };

  return {
    destroy() {
      providers.forEach(provider => provider.destroy());
      providers.clear();
      socket.disconnect();
    },
    providerFactory,
  };
}
