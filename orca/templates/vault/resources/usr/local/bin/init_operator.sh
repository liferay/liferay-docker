#!/bin/bash

vault operator init -key-shares=1 -key-threshold=1

echo ""
echo "Next steps:"
echo ""
echo "1. Store the generated keys in 1Password."
echo ""
echo "2. Export the environment variable ORCA_VAULT_TOKEN to the initial root token on this container (see above)."
echo ""
echo "3. Run \"orca unseal\" on the host."
echo ""
echo "4. Run init_secrets.sh"
echo ""
echo "5. Create BACKUP, DB, LIFERAY files in /opt/liferay/passwords on the host with the given passwords."
