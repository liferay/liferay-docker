#!/bin/bash

vault operator init

echo ""

echo "Next steps:"
echo "1. Store these keys into the 1Password vault for Orca"
echo "2. Export the VAULT_TOKEN environment variable to the value of \"Initial Root Token on this container.\" (listed above)"
echo "3. Run init_secrets.sh"