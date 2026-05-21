import { Logger, registerWorker } from 'iii-sdk';

declare const process: {
  env: Record<string, string | undefined>;
};

type ChatMessage = {
  role: string;
  content: string;
};

type InferencePayload = {
  messages: ChatMessage[];
  max_tokens?: number;
  temperature?: number;
  trace_id?: string;
};

const iii = registerWorker(process.env.III_URL ?? 'ws://127.0.0.1:49134');
const logger = new Logger();

iii.registerFunction('inference::get_response', async (payload: InferencePayload) => {
  logger.info('caller-worker forwarding request', payload as Record<string, unknown>);

  const result = await iii.trigger({
    function_id: 'inference::run_inference',
    payload,
  });

  if (typeof result === 'string') {
    return {
      completion: result,
      model: process.env.MODEL_NAME ?? 'quickstart-slm',
    };
  }

  return result;
});

logger.info('Caller worker started - connected to iii engine');
