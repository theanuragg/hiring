import json
import logging
import os
import time
import uuid
from typing import Any

from fastapi import FastAPI, HTTPException
from iii import InitOptions, register_worker
from pydantic import BaseModel, Field

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("api-gateway")

MODEL_NAME = os.getenv("MODEL_NAME", "quickstart-slm")
CALLER_FUNCTION_ID = os.getenv("CALLER_FUNCTION_ID", "inference::get_response")

iii = register_worker(
    os.getenv("III_URL", "ws://127.0.0.1:49134"),
    InitOptions(worker_name=os.getenv("III_WORKER_NAME", "api-gateway")),
)

app = FastAPI(title="Alchemyst Quickstart API", version="1.0.0")


class InferRequest(BaseModel):
    prompt: str = Field(min_length=1, max_length=4000)
    max_tokens: int = Field(default=64, ge=1, le=512)
    temperature: float = Field(default=0.7, ge=0.0, le=2.0)
    system_prompt: str = Field(
        default="You are a concise and helpful assistant.",
        max_length=1000,
    )


class InferResponse(BaseModel):
    completion: str
    model: str
    latency_ms: int
    trace_id: str


def log_event(level: int, event: str, **fields: Any) -> None:
    logger.log(level, json.dumps({"event": event, **fields}))


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok", "service": "api-gateway"}


@app.post("/infer", response_model=InferResponse)
def infer(request: InferRequest) -> InferResponse:
    trace_id = str(uuid.uuid4())
    started_at = time.perf_counter()
    payload = {
        "messages": [
            {"role": "system", "content": request.system_prompt},
            {"role": "user", "content": request.prompt},
        ],
        "max_tokens": request.max_tokens,
        "temperature": request.temperature,
        "trace_id": trace_id,
    }

    log_event(logging.INFO, "infer_request_received", trace_id=trace_id)

    try:
        result = iii.trigger(
            {
                "function_id": CALLER_FUNCTION_ID,
                "payload": payload,
            }
        )
    except Exception as exc:
        log_event(
            logging.ERROR,
            "infer_request_failed",
            trace_id=trace_id,
            error=str(exc),
        )
        raise HTTPException(
            status_code=502,
            detail={
                "message": "caller worker invocation failed",
                "trace_id": trace_id,
            },
        ) from exc

    if isinstance(result, str):
        completion = result
        model = MODEL_NAME
    elif isinstance(result, dict):
        completion = result.get("completion")
        model = result.get("model", MODEL_NAME)
    else:
        completion = None
        model = MODEL_NAME

    if not completion:
        raise HTTPException(
            status_code=502,
            detail={
                "message": "worker returned an empty response",
                "trace_id": trace_id,
            },
        )

    latency_ms = int((time.perf_counter() - started_at) * 1000)
    log_event(
        logging.INFO,
        "infer_request_completed",
        trace_id=trace_id,
        latency_ms=latency_ms,
        model=model,
    )

    return InferResponse(
        completion=completion,
        model=model,
        latency_ms=latency_ms,
        trace_id=trace_id,
    )
