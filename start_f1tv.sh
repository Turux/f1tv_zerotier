#!/bin/bash

# A script to ensure a VPN interface is up, verify the connection, 
# launch F1TV in Chromium, and then bring the interface down.

# --- Configuration ---
# The name of your VPN network interface.
ZT_NETWORK="d5e5fb65371ef164"
URL="https://f1tv.formula1.com"
# The city you expect your VPN to be in.
EXPECTED_COUNTRY="DE"
# How many times to check the connection before giving up.
MAX_RETRIES=6
# How many seconds to wait between checks.
RETRY_DELAY=5

# --- Script Logic ---

# Set -e ensures that the script will exit immediately if any command fails.
set -e

# Function to clean up and bring the interface down on failure or exit.
cleanup() {
    echo "Disabling routing on VPN network '$ZT_NETWORK'..."
    # The '|| true' prevents the script from failing if the interface is already down.
    sudo zerotier-cli set "$ZT_NETWORK" allowDefault=0 || true
    echo "Interface is down. Exiting."
}

# Trap the EXIT signal to ensure cleanup runs no matter how the script ends.
trap cleanup EXIT

echo "--- F1TV Launcher Initialized ---"

CURRENT_ALLOW_DEFAULT=$(sudo zerotier-cli get "$ZT_NETWORK" allowDefault)

# 1. Bring up the network interface if it's down.
if (( CURRENT_ALLOW_DEFAULT == 1 )); then
    echo "Routing on network '$ZT_NETWORK' is already enabled."
else
    echo "Routing on network '$ZT_NETWORK' is disabled. Enabling..."
    sudo zerotier-cli set "$ZT_NETWORK" allowDefault=1
    echo "Routing is now enabled."
fi

# 2. Verify the VPN connection by checking public IP location.
echo "Verifying VPN connection. Expecting location: $EXPECTED_CITY"
for (( i=1; i<=$MAX_RETRIES; i++ )); do
    # We use 'curl -s' for silent mode. 'ipinfo.io/country' is a simple service that returns the city name.
    CURRENT_COUNTRY=$(curl -s ipinfo.io/country)
    
    echo "Attempt $i: Detected location is '$CURRENT_COUNTRY'."

    if [[ "$CURRENT_COUNTRY" == "$EXPECTED_COUNTRY" ]]; then
        echo "Success! VPN connection confirmed in $EXPECTED_CITY."
        # The 'break' command exits the loop.
        break
    fi

    if (( i == MAX_RETRIES )); then
        echo "Error: Failed to verify VPN location after $MAX_RETRIES attempts."
        echo "Your current location appears to be '$CURRENT_CITY', not '$EXPECTED_CITY'."
        # The script will now exit, and the 'trap' will run the cleanup function.
        exit 1
    fi

    echo "Location does not match. Retrying in $RETRY_DELAY seconds..."
    sleep $RETRY_DELAY
done

# 3. Start Chromium. The script will wait for it to close.
echo "Starting Chromium in kiosk mode..."
# We run chromium and then immediately clear the trap.
# This ensures the 'cleanup' function only runs AFTER the browser is closed.
chromium --new-window "$URL" & wait $!

echo "Chromium has been closed."

# The script will now exit naturally, and the EXIT trap will handle bringing the interface down.
exit 0

