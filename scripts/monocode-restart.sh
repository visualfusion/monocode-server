#!/usr/bin/env bash
echo "Restarting monocode-host service..."
sudo supervisorctl restart monocode-host
echo "Done."
