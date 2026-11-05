import {Socket} from 'phoenix';
import {PhoenixChannelProvider} from 'y-phoenix-channel';
import {Doc} from 'yjs';

import type {
  EditorCollaboration,
  ProviderFactory,
} from '../lexical_editor/collaboration';

const CONFIRM_UPDATES_APPLIED_TIMEOUT_MS = 5000;

function confirmProviderUpdatesApplied(
  provider: PhoenixChannelProvider,
): Promise<void> {
  return new Promise((resolve, reject) => {
    const startedAt = Date.now();

    const requestConfirmation = () => {
      const channel = provider.channel;

      if (channel?.state === 'joined') {
        channel
          .push('confirm_updates_applied', {})
          .receive('ok', () => resolve())
          .receive('error', reason => reject(reason))
          .receive('timeout', () =>
            reject(new Error('Yjs update confirmation timed out')),
          );
        return;
      }

      if (Date.now() - startedAt >= CONFIRM_UPDATES_APPLIED_TIMEOUT_MS) {
        reject(new Error('Yjs provider did not connect'));
        return;
      }

      requestAnimationFrame(requestConfirmation);
    };

    requestConfirmation();
  });
}

export function createPhoenixCollaboration(
  documentId: string,
  spaceId: string,
  csrfToken: string,
): EditorCollaboration {
  const socket = new Socket('/socket', {
    params: {_csrf_token: csrfToken, space_id: spaceId},
  });
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
    const destroy = provider.destroy.bind(provider);
    provider.destroy = () => {
      providers.delete(provider);
      destroy();
    };

    // Both libraries use the same Yjs awareness runtime contract. Lexical's
    // type narrows the otherwise open awareness state to its cursor fields.
    return provider as unknown as ReturnType<ProviderFactory>;
  };

  return {
    confirmUpdatesApplied() {
      return Promise.all(
        Array.from(providers, confirmProviderUpdatesApplied),
      ).then(() => undefined);
    },
    destroy() {
      providers.forEach(provider => provider.destroy());
      providers.clear();
      socket.disconnect();
    },
    providerFactory,
  };
}
