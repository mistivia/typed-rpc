#!/bin/bash

curl -X POST http://localhost:18888 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"hello","params":{"name":"World"},"id":1}'
echo

curl -X POST http://localhost:18888 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"echo","params":{"content":"test"},"id":1}'
echo