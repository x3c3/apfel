# apfel-calc - MCP Calculator Server

Gives Apple's on-device LLM the ability to do math via tool calling.

```bash
apfel --serve &
python3 mcp/calculator/test_round_trip.py
# Question: What is 247 times 83?
# Step 1: Model called multiply({"a": 247, "b": 83})
# Step 2: Calculator result: 20501
# Step 3: Final answer: The product of 247 and 83 is 20,501.
```

Seven tools: `add`, `subtract`, `multiply`, `divide`, `sqrt`, `power`, `round_number`.

Zero dependencies (Python stdlib only). Standards-compliant MCP stdio transport.

Full documentation: [docs/mcp-calculator.md](../../docs/mcp-calculator.md)
