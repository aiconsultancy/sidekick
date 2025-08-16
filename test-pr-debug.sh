#!/bin/bash

echo "Testing PR extraction..."

# Test directly
echo "1. Direct execution:"
bash plugins/sidekick-get-pr-comments -j https://github.com/facebook/react/pull/1 2>&1 | head -5 || echo "Failed with: $?"

echo ""
echo "2. Via sidekick:"
./sidekick get pr-comments -j https://github.com/facebook/react/pull/1 2>&1 | head -5 || echo "Failed with: $?"

echo ""
echo "3. Check if main function is called:"
bash -x plugins/sidekick-get-pr-comments https://github.com/facebook/react/pull/1 2>&1 | grep "main " | head -1

echo "Done"