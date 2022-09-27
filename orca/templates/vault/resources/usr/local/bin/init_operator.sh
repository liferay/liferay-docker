#!/bin/bash

vault operator init

echo ""
echo "Next steps:"
echo ""
echo "1. Store the generated keys in 1Password."
echo ""
echo "2. Export the environment variable ORCA_VAULT_TOKEN to the initial root token on this container (see above)."
echo ""
echo "3. Run init_secrets.sh"