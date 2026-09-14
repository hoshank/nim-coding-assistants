#!/usr/bin/env python3
"""
NVIDIA NIM Bridge Proxy for Claude Code
Translates Anthropic /v1/messages protocol requests to NVIDIA NIM OpenAI-compatible API.
Supports streaming SSE, non-streaming responses, tool calling, and parameter sanitization.
Works on macOS, Linux, and Windows.
"""

import os
import sys
import json
import argparse
import asyncio
import shutil
from pathlib import Path
import uuid
from typing import Optional, Dict, Any, List

from fastapi import FastAPI, Request, Response
from fastapi.responses import StreamingResponse, JSONResponse
import litellm
from litellm.llms.anthropic.experimental_pass_through.messages.handler import (
    LiteLLMMessagesToCompletionTransformationHandler,
)

# Suppress verbose debug output & drop unsupported parameters
litellm.drop_params = True
litellm.suppress_debug_info = True
litellm.use_chat_completions_url_for_anthropic_messages = True

ANTHROPIC_ADAPTER = LiteLLMMessagesToCompletionTransformationHandler.anthropic_messages_handler.__globals__.get("ANTHROPIC_ADAPTER")

app = FastAPI(title="Claude Code NVIDIA NIM Bridge")

def get_env() -> Dict[str, str]:
    """Load settings from environment variables or local .env file."""
    env: Dict[str, str] = {}
    
    # Priority locations for .env
    potential_paths = [
        Path.cwd() / ".env",
        Path(__file__).parent / ".env",
        Path.home() / ".claude" / "nim" / ".env",
        Path.home() / ".nim-coding-assistants" / ".env",
    ]
    
    for p in potential_paths:
        if p.exists():
            try:
                with open(p, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            k, v = line.split("=", 1)
                            env[k.strip()] = v.strip().strip('"').strip("'")
                break
            except Exception:
                pass
                
    return env

@app.get("/")
@app.get("/health")
@app.get("/health/liveliness")
@app.get("/health/readiness")
async def health():
    return {
        "status": "ok",
        "service": "claude-nim-bridge",
        "platform": sys.platform
    }

@app.get("/v1/models")
async def list_models():
    env = get_env()
    model = os.environ.get("NIM_MODEL") or env.get("NIM_MODEL") or "nvidia/nemotron-3-ultra-550b-a55b"
    models_file = Path(__file__).parent / "config" / "models.json"
    available = []
    if models_file.exists():
        try:
            with open(models_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                for m in data.get("models", []):
                    available.append({"id": m["id"], "object": "model"})
                    available.append({"id": f"{m['id']}[1m]", "object": "model"})
        except Exception:
            pass
    if not available:
        available = [
            {"id": "nvidia/nemotron-3-ultra-550b-a55b", "object": "model"},
            {"id": "nvidia/nemotron-3-super-120b-a12b", "object": "model"},
            {"id": "deepseek-ai/deepseek-v4-pro", "object": "model"},
            {"id": "deepseek-ai/deepseek-v4-flash-0731", "object": "model"},
            {"id": "minimaxai/minimax-m3", "object": "model"},
            {"id": "z-ai/glm-5.2", "object": "model"},
            {"id": "thinkingmachines/inkling", "object": "model"}
        ]
    return {"data": available}

OBSCURA_BIN = shutil.which("obscura") or "/Users/hoshank/.local/bin/obscura"

async def run_obscura_fetch(url: str, dump_format: str = "markdown", timeout_sec: int = 15) -> Dict[str, Any]:
    try:
        proc = await asyncio.create_subprocess_exec(
            OBSCURA_BIN,
            "--stealth",
            "fetch",
            url,
            "--dump",
            dump_format,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout_sec)
        content = stdout.decode("utf-8", errors="replace")
        if proc.returncode != 0:
            err_msg = stderr.decode("utf-8", errors="replace")
            return {"url": url, "status": "error", "error": err_msg, "content": ""}
        
        token_est = len(content) // 4
        return {
            "url": url,
            "status": "ok",
            "content": content,
            "token_estimate": token_est,
            "length": len(content),
        }
    except asyncio.TimeoutError:
        return {"url": url, "status": "timeout", "error": "Obscura fetch timed out", "content": ""}
    except Exception as e:
        return {"url": url, "status": "error", "error": str(e), "content": ""}

@app.post("/obscura/scrape")
async def obscura_scrape_endpoint(request: Request):
    try:
        body = await request.json()
    except Exception:
        return JSONResponse({"error": "Invalid JSON body"}, status_code=400)
    url = body.get("url")
    if not url:
        return JSONResponse({"error": "Missing 'url' parameter"}, status_code=400)
    fmt = body.get("format", "markdown")
    timeout_sec = int(body.get("timeout", 20))
    result = await run_obscura_fetch(url, dump_format=fmt, timeout_sec=timeout_sec)
    return JSONResponse(result)

@app.post("/obscura/batch_scrape")
async def obscura_batch_scrape_endpoint(request: Request):
    try:
        body = await request.json()
    except Exception:
        return JSONResponse({"error": "Invalid JSON body"}, status_code=400)
    urls = body.get("urls", [])
    if not urls or not isinstance(urls, list):
        return JSONResponse({"error": "Missing or invalid 'urls' parameter (list required)"}, status_code=400)
    urls = urls[:8]
    fmt = body.get("format", "markdown")
    timeout_sec = int(body.get("timeout", 20))
    tasks = [run_obscura_fetch(u, dump_format=fmt, timeout_sec=timeout_sec) for u in urls]
    results = await asyncio.gather(*tasks)
    return JSONResponse({"results": results})

@app.post("/v1/messages")
async def messages_endpoint(request: Request):
    env = get_env()
    api_key = os.environ.get("NVIDIA_API_KEY") or env.get("NVIDIA_API_KEY")
    api_base = os.environ.get("NIM_BASE_URL") or env.get("NIM_BASE_URL") or "https://integrate.api.nvidia.com/v1"
    default_model = os.environ.get("NIM_MODEL") or env.get("NIM_MODEL") or "nvidia/nemotron-3-ultra-550b-a55b"

    if not api_key or api_key.strip() in ("", "nvapi-your-key-here"):
        return JSONResponse(
            status_code=401,
            content={
                "type": "error",
                "error": {
                    "type": "authentication_error",
                    "message": "NVIDIA_API_KEY is not set or is still the placeholder. Please set your NVIDIA API key in .env or run ./setup.sh"
                }
            }
        )

    try:
        body = await request.json()
    except Exception as e:
        return JSONResponse(
            status_code=400,
            content={"type": "error", "error": {"type": "invalid_request_error", "message": f"Invalid JSON body: {e}"}}
        )

    # 1. Sanitize unsupported parameters from Claude Code before forwarding to NVIDIA
    unsupported_keys = [
        "output_config",
        "context_management",
        "anthropic_beta",
        "beta",
        "cache_control"
    ]
    for k in unsupported_keys:
        body.pop(k, None)

    # 2. Normalize and map model name
    requested_model = body.get("model", default_model)
    if requested_model.endswith("[1m]"):
        requested_model = requested_model[:-4]

    # Map standard Claude aliases / names to the active NVIDIA model
    if any(alias in requested_model.lower() for alias in ["claude-", "haiku", "sonnet", "opus"]):
        model_to_use = default_model
    else:
        model_to_use = requested_model

    print(f"[NIM Proxy] Received request for '{requested_model}' -> forwarding to NIM model '{model_to_use}' at {api_base}", flush=True)

    stream = body.get("stream", False)
    max_tokens = body.get("max_tokens", 4096)
    messages = body.get("messages", [])
    system = body.get("system")
    tools = body.get("tools")
    tool_choice = body.get("tool_choice")
    temperature = body.get("temperature")
    top_p = body.get("top_p")
    top_k = body.get("top_k")
    stop_sequences = body.get("stop_sequences")

    def sse_event(event: str, data: Dict[str, Any]) -> bytes:
        return f"event: {event}\ndata: {json.dumps(data)}\n\n".encode("utf-8")

    try:
        (
            completion_kwargs,
            tool_name_mapping,
        ) = LiteLLMMessagesToCompletionTransformationHandler._prepare_completion_kwargs(
            max_tokens=max_tokens,
            messages=messages,
            model=model_to_use,
            stream=stream,
            system=system,
            tools=tools,
            tool_choice=tool_choice,
            temperature=temperature,
            top_p=top_p,
            top_k=top_k,
            stop_sequences=stop_sequences,
            extra_kwargs={
                "custom_llm_provider": "openai",
                "api_base": api_base,
                "api_key": api_key,
            },
        )

        # Prevent erroneous routing to responses API
        if isinstance(completion_kwargs.get("model"), str) and completion_kwargs["model"].startswith("responses/"):
            completion_kwargs["model"] = completion_kwargs["model"].replace("responses/", "")

        if stream:
            async def generate():
                try:
                    response_stream = await litellm.acompletion(**completion_kwargs)

                    msg_id = f"msg_{uuid.uuid4()}"
                    yield sse_event("message_start", {
                        "type": "message_start",
                        "message": {
                            "id": msg_id,
                            "type": "message",
                            "role": "assistant",
                            "content": [],
                            "model": model_to_use,
                            "stop_reason": None,
                            "stop_sequence": None,
                            "usage": {"input_tokens": 0, "output_tokens": 0},
                        },
                    })

                    current_block_type = None
                    current_block_index = -1
                    current_tool_id = None
                    current_tool_index = None
                    had_tool_call = False
                    finish_reason = None
                    input_tokens = 0
                    output_tokens = 0

                    async for chunk in response_stream:
                        if getattr(chunk, "usage", None):
                            input_tokens = getattr(chunk.usage, "prompt_tokens", 0) or input_tokens
                            output_tokens = getattr(chunk.usage, "completion_tokens", 0) or output_tokens

                        if not chunk.choices:
                            continue

                        choice = chunk.choices[0]
                        if choice.finish_reason:
                            finish_reason = choice.finish_reason

                        delta = choice.delta
                        if not delta:
                            continue

                        # 1. Reasoning / Thinking
                        reasoning = getattr(delta, "reasoning_content", None)
                        if reasoning:
                            if current_block_type != "thinking":
                                if current_block_type is not None:
                                    yield sse_event("content_block_stop", {"type": "content_block_stop", "index": current_block_index})
                                current_block_index += 1
                                current_block_type = "thinking"
                                yield sse_event("content_block_start", {
                                    "type": "content_block_start",
                                    "index": current_block_index,
                                    "content_block": {"type": "thinking", "thinking": ""},
                                })
                            yield sse_event("content_block_delta", {
                                "type": "content_block_delta",
                                "index": current_block_index,
                                "delta": {"type": "thinking_delta", "thinking": reasoning},
                            })

                        # 2. Text Content
                        content = delta.content
                        if content:
                            if current_block_type != "text":
                                if current_block_type is not None:
                                    yield sse_event("content_block_stop", {"type": "content_block_stop", "index": current_block_index})
                                current_block_index += 1
                                current_block_type = "text"
                                yield sse_event("content_block_start", {
                                    "type": "content_block_start",
                                    "index": current_block_index,
                                    "content_block": {"type": "text", "text": ""},
                                })
                            yield sse_event("content_block_delta", {
                                "type": "content_block_delta",
                                "index": current_block_index,
                                "delta": {"type": "text_delta", "text": content},
                            })

                        # 3. Tool Calls
                        tool_calls = getattr(delta, "tool_calls", None)
                        if tool_calls:
                            had_tool_call = True
                            for tc in tool_calls:
                                tc_id = getattr(tc, "id", None)
                                tc_idx = getattr(tc, "index", None)
                                tc_func = getattr(tc, "function", None)
                                tc_name = getattr(tc_func, "name", None) if tc_func else None
                                tc_args = getattr(tc_func, "arguments", None) if tc_func else None

                                is_new_tool = False
                                if tc_id and tc_id != current_tool_id:
                                    is_new_tool = True
                                elif tc_idx is not None and tc_idx != current_tool_index:
                                    is_new_tool = True
                                elif current_block_type != "tool_use":
                                    is_new_tool = True

                                if is_new_tool:
                                    if current_block_type is not None:
                                        yield sse_event("content_block_stop", {"type": "content_block_stop", "index": current_block_index})
                                    current_block_index += 1
                                    current_block_type = "tool_use"
                                    current_tool_id = tc_id or f"call_{uuid.uuid4()}"
                                    current_tool_index = tc_idx
                                    orig_name = tool_name_mapping.get(tc_name, tc_name) if (tool_name_mapping and tc_name) else (tc_name or "tool")
                                    yield sse_event("content_block_start", {
                                        "type": "content_block_start",
                                        "index": current_block_index,
                                        "content_block": {"type": "tool_use", "id": current_tool_id, "name": orig_name, "input": {}},
                                    })

                                if tc_args:
                                    yield sse_event("content_block_delta", {
                                        "type": "content_block_delta",
                                        "index": current_block_index,
                                        "delta": {"type": "input_json_delta", "partial_json": tc_args},
                                    })

                    # Close any open content block
                    if current_block_type is not None:
                        yield sse_event("content_block_stop", {"type": "content_block_stop", "index": current_block_index})
                    elif current_block_index == -1:
                        # Ensure at least one block exists
                        current_block_index = 0
                        yield sse_event("content_block_start", {"type": "content_block_start", "index": 0, "content_block": {"type": "text", "text": ""}})
                        yield sse_event("content_block_stop", {"type": "content_block_stop", "index": 0})

                    # Determine stop_reason
                    stop_reason = "end_turn"
                    if had_tool_call or finish_reason in ("tool_calls", "function_call"):
                        stop_reason = "tool_use"
                    elif finish_reason == "length":
                        stop_reason = "max_tokens"

                    yield sse_event("message_delta", {
                        "type": "message_delta",
                        "delta": {"stop_reason": stop_reason, "stop_sequence": None},
                        "usage": {"output_tokens": output_tokens},
                    })
                    yield sse_event("message_stop", {"type": "message_stop"})

                except Exception as stream_err:
                    print(f"[NIM Proxy Error in Stream]: {stream_err}", flush=True)
                    yield sse_event("error", {
                        "type": "error",
                        "error": {"type": "api_error", "message": str(stream_err)},
                    })

            return StreamingResponse(generate(), media_type="text/event-stream")

        else:
            completion_response = await litellm.acompletion(**completion_kwargs)
            if ANTHROPIC_ADAPTER is not None:
                anthropic_response = ANTHROPIC_ADAPTER.translate_completion_output_params(
                    completion_response,
                    tool_name_mapping=tool_name_mapping,
                )
                if hasattr(anthropic_response, "dict"):
                    return JSONResponse(content=anthropic_response.dict())
                elif isinstance(anthropic_response, dict):
                    return JSONResponse(content=anthropic_response)
                return JSONResponse(content=dict(anthropic_response))
            else:
                return JSONResponse(content=completion_response.dict())

    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"type": "error", "error": {"type": "api_error", "message": str(e)}}
        )

def main():
    import uvicorn
    parser = argparse.ArgumentParser(description="NVIDIA NIM Bridge Proxy for Claude Code")
    parser.add_argument("--port", type=int, default=None, help="Port to listen on (default: 8000)")
    parser.add_argument("--host", type=str, default="127.0.0.1", help="Host to bind (default: 127.0.0.1)")
    args = parser.parse_args()

    env = get_env()
    port = args.port or int(os.environ.get("NIM_PROXY_PORT") or env.get("NIM_PROXY_PORT") or 8000)
    host = args.host

    print(f"Starting NVIDIA NIM Bridge Proxy on http://{host}:{port}")
    uvicorn.run(app, host=host, port=port, log_level="warning")

if __name__ == "__main__":
    main()
