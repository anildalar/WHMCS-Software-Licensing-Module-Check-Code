#!/bin/bash

# Configuration Values
WHMCS_URL="https://whmcs.com/"
LICENSING_SECRET_KEY="abc123"
LOCALKEYDAYS=15
ALLOWCHECKFAILDAYS=5

# License Key
LICENSEKEY="d1391c06ea81b8b47644083793ffc8ea8b9539d3"
LOCALKEY=""

# Prepare data for the remote check
CHECK_TOKEN=$(date +%s | md5sum | cut -d' ' -f1)
CHECKDATE=$(date +"%Y%m%d")
DOMAIN=$(hostname)
USERSIP=$(hostname -I | awk '{print $1}')
DIRPATH="$(dirname "$(readlink -f "$0")")"
VERIFY_FILEPATH="modules/servers/licensing/verify.php"

# Prepare POST data
POSTFIELDS="licensekey=${LICENSEKEY}&domain=${DOMAIN}&ip=${USERSIP}&dir=${DIRPATH}&check_token=${CHECK_TOKEN}"

# Function to perform remote check
function check_license {
    RESPONSE=$(curl -s -X POST "${WHMCS_URL}${VERIFY_FILEPATH}" --data "${POSTFIELDS}")

    # Check if response is valid
    if [[ $? -ne 0 ]]; then
        echo "Remote Check Failed"
        return 1
    fi

    # Parse response
    local STATUS=$(echo "$RESPONSE" | grep -oP '<status>\K.*?(?=</status>)')
    local MD5HASH=$(echo "$RESPONSE" | grep -oP '<md5hash>\K.*?(?=</md5hash>)')

    if [[ -z "$STATUS" ]]; then
        echo "Invalid License Server Response"
        return 1
    fi

    # Check status
    case "$STATUS" in
        "Active")
            echo "License is Active"
            ;;
        "Invalid")
            echo "License key is Invalid"
            return 1
            ;;
        "Expired")
            echo "License key is Expired"
            return 1
            ;;
        "Suspended")
            echo "License key is Suspended"
            return 1
            ;;
        *)
            echo "Invalid Response"
            return 1
            ;;
    esac

    # MD5 Checksum Verification
    if [[ "$MD5HASH" != "$(echo -n "${LICENSING_SECRET_KEY}${CHECK_TOKEN}" | md5sum | cut -d' ' -f1)" ]]; then
        echo "MD5 Checksum Verification Failed"
        return 1
    fi

    echo "License check successful."
}

# Call the function
check_license
