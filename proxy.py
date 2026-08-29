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
from pathlib import Path
from typing import Optional, Dict, Any, List

from fastapi import FastAPI, Request, Response
from fastapi.responses import StreamingResponse, JSONResponse
import litellm
import litellm.llms.anthropic.experimental_pass_through.messages.handler as anthropic_handler

# Suppress verbose debug output & drop unsupported parameters
litellm.drop_params = True
litellm.suppress_debug_info = True

app = FastAPI(title="Claude Code NVIDIA NIM Bridge")

def get_env() -> Dict[str, str]:
    """Load settings from environment variables or local .env file."""
    env: Dict[str, str] = {}
    
    # Priority locations for .env
    potential_paths = [
        Path.cwd() / ".env",
        Path(__file__).parent / ".env",
        Path.home() / ".claude" / "nim" / ".env",
        Path.home() / ".nim-assistant-bridge" / ".env",
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
    model = os.environ.get("NIM_MODEL") or env.get("NIM_MODEL") or "meta/llama-3.3-70b-instruct"
    return {
        "data": [
            {"id": model, "object": "model"},
            {"id": f"{model}[1m]", "object": "model"},
            {"id": "meta/llama-3.3-70b-instruct", "object": "model"},
            {"id": "nvidia/nemotron-3-super-120b-a12b", "object": "model"},
            {"id": "qwen/qwen2.5-coder-32b-instruct", "object": "model"}
        ]
    }

@app.post("/v1/messages")
async def messages_endpoint(request: Request):
    env = get_env()
    api_key = os.environ.get("NVIDIA_API_KEY") or env.get("NVIDIA_API_KEY")
    api_base = os.environ.get("NIM_BASE_URL") or env.get("NIM_BASE_URL") or "https://integrate.api.nvidia.com/v1"
    default_model = os.environ.get("NIM_MODEL") or env.get("NIM_MODEL") or "meta/llama-3.3-70b-instruct"

    if not api_key:
        return JSONResponse(
            status_code=401,
            content={
                "type": "error",
                "error": {
                    "type": "authentication_error",
                    "message": "NVIDIA_API_KEY is not set. Please set it in .env or your environment."
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

    try:
        res = await anthropic_handler.anthropic_messages(
            model=model_to_use,
            messages=messages,
            max_tokens=max_tokens,
            system=system,
            tools=tools,
            tool_choice=tool_choice,
            temperature=temperature,
            top_p=top_p,
            top_k=top_k,
            stop_sequences=stop_sequences,
            stream=stream,
            custom_llm_provider="openai",
            api_base=api_base,
            api_key=api_key
        )

        if stream:
            async def generate():
                async for chunk in res:
                    if isinstance(chunk, bytes):
                        yield chunk
                    elif isinstance(chunk, str):
                        yield chunk.encode("utf-8")
                    else:
                        yield f"data: {json.dumps(chunk)}\n\n".encode("utf-8")
            return StreamingResponse(generate(), media_type="text/event-stream")
        else:
            if hasattr(res, "dict"):
                return JSONResponse(content=res.dict())
            elif isinstance(res, dict):
                return JSONResponse(content=res)
            return JSONResponse(content=dict(res))

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
