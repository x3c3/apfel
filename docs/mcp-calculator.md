# MCP Calculator Server

apfel ships with a standards-compliant [Model Context Protocol](https://modelcontextprotocol.io/) calculator server at `mcp/calculator/server.py`. It gives Apple's on-device LLM the ability to do math via tool calling.

## Quick start

```bash
apfel --serve &
python3 mcp/calculator/test_round_trip.py
```

```
Question: What is 247 times 83?
Step 1: Model called multiply({"a": 247, "b": 83})
Step 2: Calculator result: 20501
Step 3: Final answer: The product of 247 and 83 is 20,501.
```

## How it works

MCP servers provide tools to apfel via the OpenAI tool calling API. The round trip:

```
You: "What is 247 times 83?"
  |
  v
apfel --serve (/v1/chat/completions with tools defined)
  |  Apple's model sees the tools, calls multiply
  v
Response: finish_reason: "tool_calls", multiply({"a": 247, "b": 83})
  |
  v
MCP calculator server (stdin/stdout)
  |  Receives tools/call, computes 247 * 83 = 20501
  v
Feed result back to apfel as role: "tool" message
  |
  v
apfel: "The product of 247 and 83 is 20,501."
```

## Tools

| Tool | Arguments | Returns | Example |
|------|-----------|---------|---------|
| `add` | `a`, `b` (numbers) | Sum | add(10, 3) = 13 |
| `subtract` | `a`, `b` (numbers) | Difference | subtract(10, 3) = 7 |
| `multiply` | `a`, `b` (numbers) | Product | multiply(247, 83) = 20501 |
| `divide` | `a`, `b` (numbers) | Quotient | divide(1000, 7) = 142.857... |
| `sqrt` | `a` (number) | Square root | sqrt(2025) = 45 |
| `power` | `a`, `b` (numbers) | a^b | power(2, 16) = 65536 |
| `round_number` | `a` (number), `decimals` (int) | Rounded value | round_number(3.14159, 2) = 3.14 |

## Real examples

Five real round trips via apfel's server, unedited.

### 1. Multiplication

```
Question: What is 247 times 83?

Step 1: Model called multiply({"a": 247, "b": 83})
Step 2: Calculator result: 20501
Step 3: Final answer: The product of 247 and 83 is 20,501.
```

### 2. Square root

```
Question: What is the square root of 2025?

Step 1: Model called sqrt({"number": 2025})
Step 2: Calculator result: 45
Step 3: Final answer: The square root of 2025 is 45.
```

Note: the model sent `{"number": 2025}` instead of `{"a": 2025}`. The server handles this - it extracts numbers from any key name.

### 3. Division

```
Question: Divide 1000 by 7

Step 1: Model called divide({"numerator": 1000, "denominator": 7})
Step 2: Calculator result: 142.85714285714286
Step 3: Final answer: When you divide 1000 by 7, the result is approximately 142.857.
```

Note: the model sent `{"numerator": ..., "denominator": ...}` instead of `{"a": ..., "b": ...}`. Same flexibility.

### 4. Exponentiation

```
Question: What is 2 to the power of 16?

Step 1: Model called power({"base": 2, "exponent": 16})
Step 2: Calculator result: 65536
Step 3: Final answer: The result of 2^16 is 65,536.
```

### 5. Addition

```
Question: Add 1234 and 5678

Step 1: Model called add({"1234": 1234, "5678": 5678})
Step 2: Calculator result: 6912
Step 3: Final answer: The sum of 1234 and 5678 is 6912.
```

Note: the model used the numbers themselves as keys. Still works - the server finds all numeric values.

## Build your own MCP server for apfel

The calculator is a template. Here's how to add tools to apfel.

### Step 1: Write the MCP server

A minimal MCP server is a Python script that reads JSON-RPC from stdin and writes to stdout:

```python
#!/usr/bin/env python3
import json, sys

def read():
    line = sys.stdin.readline()
    return json.loads(line.strip()) if line else None

def send(msg):
    sys.stdout.write(json.dumps(msg) + "\n")
    sys.stdout.flush()

def respond(id, result):
    send({"jsonrpc": "2.0", "id": id, "result": result})

while True:
    msg = read()
    if not msg:
        break
    method = msg.get("method", "")
    id = msg.get("id")

    if method == "initialize":
        respond(id, {
            "protocolVersion": "2025-06-18",
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "my-tool", "version": "1.0.0"}
        })
    elif method == "notifications/initialized":
        pass
    elif method == "tools/list":
        respond(id, {"tools": [{
            "name": "my_tool",
            "description": "What it does",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "input": {"type": "string"}
                },
                "required": ["input"]
            }
        }]})
    elif method == "tools/call":
        args = msg["params"]["arguments"]
        result = "your result here"  # your logic
        respond(id, {
            "content": [{"type": "text", "text": result}],
            "isError": False
        })
    elif method == "ping":
        respond(id, {})
```

### Step 2: Define the tools for apfel

When calling apfel's `/v1/chat/completions`, include your tools in the OpenAI format:

```python
import httpx

response = httpx.post("http://localhost:11434/v1/chat/completions", json={
    "model": "apple-foundationmodel",
    "messages": [{"role": "user", "content": "your question"}],
    "tools": [{
        "type": "function",
        "function": {
            "name": "my_tool",
            "description": "What it does",
            "parameters": {
                "type": "object",
                "properties": {
                    "input": {"type": "string"}
                },
                "required": ["input"]
            }
        }
    }]
}).json()
```

### Step 3: Handle the tool call

When the model decides to use a tool, `finish_reason` is `"tool_calls"`:

```python
if response["choices"][0]["finish_reason"] == "tool_calls":
    tool_call = response["choices"][0]["message"]["tool_calls"][0]
    name = tool_call["function"]["name"]
    args = json.loads(tool_call["function"]["arguments"])

    # Call your MCP server
    result = call_mcp_server(name, args)

    # Feed the result back to apfel
    final = httpx.post("http://localhost:11434/v1/chat/completions", json={
        "model": "apple-foundationmodel",
        "messages": [
            {"role": "user", "content": "your question"},
            response["choices"][0]["message"],  # the assistant's tool_calls message
            {"role": "tool", "tool_call_id": tool_call["id"], "content": result}
        ]
    }).json()

    print(final["choices"][0]["message"]["content"])
```

See `mcp/calculator/test_round_trip.py` for a complete working example.

### Tips for Apple's ~3B model

- **Use multiple simple tools** instead of one complex tool. The model picks function names well but improvises argument structures.
- **Keep descriptions short** with an example: `"Add two numbers. Example: add(a=10, b=3) returns 13"`.
- **Use simple types.** `number` and `string` work best. Nested objects and enums are unreliable.
- **Tolerate improvised keys.** The model might send `{"number1": 5}` instead of `{"a": 5}`. Extract values by type, not key name.
- **Name tools as verbs.** `multiply`, `search`, `translate` work better than `math_operation`.

### Limitations

- **4096 token context window.** Tool definitions, question, tool result, and final answer must all fit. Large tool schemas eat into this budget.
- **One tool call per turn.** Multi-tool chains require multiple round trips.
- **No guaranteed schema compliance.** The model follows schemas loosely. Your server must handle unexpected argument formats.
- **No streaming for tool calls.** Tool call responses are always non-streaming.
- **Safety guardrails apply.** Apple's content filters can block tool calls containing flagged words.

## MCP protocol reference

### Transport

stdio - the client spawns the server as a subprocess. Each JSON-RPC message is one line on stdin/stdout.

### Required methods

| Method | Direction | Response required |
|--------|-----------|-------------------|
| `initialize` | client -> server | Yes |
| `notifications/initialized` | client -> server | No (notification) |
| `tools/list` | client -> server | Yes |
| `tools/call` | client -> server | Yes |
| `ping` | client -> server | Yes (empty result) |

### Example session

```
--> {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"apfel","version":"1.0"}}}
<-- {"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{}},"serverInfo":{"name":"apfel-calc","version":"1.0.0"}}}
--> {"jsonrpc":"2.0","method":"notifications/initialized"}
--> {"jsonrpc":"2.0","id":2,"method":"tools/list"}
<-- {"jsonrpc":"2.0","id":2,"result":{"tools":[...]}}
--> {"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"multiply","arguments":{"a":247,"b":83}}}
<-- {"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":"20501"}],"isError":false}}
```

## Design decisions

**Multiple simple tools instead of one `calculate(expression)` tool.** Apple's ~3B model picks function names reliably but improvises argument structures when given a complex schema. Separate tools work every time.

**Tolerates improvised argument keys.** The model might send `{"a": 247, "b": 83}` or `{"number1": 247, "number2": 83}`. The server extracts numbers from any key names.

**Zero dependencies.** The server uses only Python stdlib (`json`, `math`, `sys`). No pip install needed.

**Safe math.** No unrestricted `eval()`. Operations are explicit function calls with bounded inputs.
