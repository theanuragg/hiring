import json
import logging
import os
from typing import Any

from iii import InitOptions, register_worker
from transformers import AutoModelForCausalLM, AutoTokenizer

os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("inference-worker")

MODEL_ID = os.getenv("MODEL_ID", "ggml-org/gemma-3-270m-GGUF")
MODEL_FILE = os.getenv("MODEL_FILE", "gemma-3-270m-Q8_0.gguf")
MODEL_NAME = os.getenv("MODEL_NAME", "quickstart-slm")

iii = register_worker(
    os.getenv("III_URL", "ws://127.0.0.1:49134"),
    InitOptions(worker_name="inference-worker"),
)

tokenizer = AutoTokenizer.from_pretrained(MODEL_ID, gguf_file=MODEL_FILE)
model = AutoModelForCausalLM.from_pretrained(MODEL_ID, gguf_file=MODEL_FILE)

tokenizer.chat_template = """{{ bos_token }}
{%- if messages[0]['role'] == 'system' -%}
    {%- if messages[0]['content'] is string -%}
        {%- set first_user_prefix = messages[0]['content'] + '\n\n' -%}
    {%- else -%}
        {%- set first_user_prefix = messages[0]['content'][0]['text'] + '\n\n' -%}
    {%- endif -%}
    {%- set loop_messages = messages[1:] -%}
{%- else -%}
    {%- set first_user_prefix = '' -%}
    {%- set loop_messages = messages -%}
{%- endif -%}
{%- for message in loop_messages -%}
    {%- if (message['role'] == 'user') != (loop.index0 % 2 == 0) -%}
        {{ raise_exception('Conversation roles must alternate user/assistant/user/assistant/...') }}
    {%- endif -%}
    {%- if message['role'] == 'assistant' -%}
        {%- set role = 'model' -%}
    {%- else -%}
        {%- set role = message['role'] -%}
    {%- endif -%}
    {{ '<start_of_turn>' + role + '\n' + (first_user_prefix if loop.first else '') }}
    {%- if message['content'] is string -%}
        {{ message['content'] | trim }}
    {%- elif message['content'] is iterable -%}
        {%- for item in message['content'] -%}
            {%- if item['type'] == 'image' -%}
                {{ '<start_of_image>' }}
            {%- elif item['type'] == 'text' -%}
                {{ item['text'] | trim }}
            {%- endif -%}
        {%- endfor -%}
    {%- else -%}
        {{ raise_exception('Invalid content type') }}
    {%- endif -%}
    {{ '<end_of_turn>\n' }}
{%- endfor -%}
{%- if add_generation_prompt -%}
    {{ '<start_of_turn>model\n' }}
{%- endif -%}"""


def run_inference_handler(payload: dict[str, Any]) -> dict[str, Any]:
    trace_id = payload.get("trace_id", "unknown")
    messages = payload.get("messages") or []
    max_tokens = int(payload.get("max_tokens", 64))
    temperature = float(payload.get("temperature", 0.7))

    if not isinstance(messages, list) or not messages:
        raise ValueError("messages must be a non-empty list")

    prompt = tokenizer.apply_chat_template(
        messages,
        tokenize=False,
        add_generation_prompt=True,
    )
    inputs = tokenizer(prompt, return_tensors="pt").to(model.device)

    generation_kwargs: dict[str, Any] = {
        "max_new_tokens": max_tokens,
        "do_sample": temperature > 0,
    }
    if temperature > 0:
        generation_kwargs["temperature"] = temperature

    output = model.generate(**inputs, **generation_kwargs)
    completion = tokenizer.decode(
        output[0][inputs["input_ids"].shape[-1] :],
        skip_special_tokens=True,
    )

    logger.info(
        json.dumps(
            {
                "event": "inference_completed",
                "trace_id": trace_id,
                "model": MODEL_NAME,
                "max_tokens": max_tokens,
            }
        )
    )

    return {
        "completion": completion,
        "model": MODEL_NAME,
    }


iii.register_function("inference::run_inference", run_inference_handler)
logger.info("Inference worker started - connected to iii engine")
