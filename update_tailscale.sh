#!/bin/bash

############################################################
#                       Config
############################################################

# Function to read a value from the .ini file with a default value
read_config_value() {
	local key=$1
	local config_file=$2
	local default_value=$3
	local value

	if [ -f "$config_file" ]; then
		value=$(awk -F '=' -v key="$key" '$1 == key {print $2}' "$config_file" | tr -d '[:space:]')
	else
		value=""
	fi

	# If the value is empty, return the default value
	if [ -z "$value" ]; then
		echo "$default_value"
	else
		echo "$value"
	fi
}


# Function to validate boolean values
validate_boolean() {
	local value=$1
	if [[ "$value" =~ ^(true|false)$ ]]; then
		echo "$value"
	else
		echo "false"  # Default value
	fi
}

# Function to validate configuration values
validate_value() {
	local value=$1
	local valid_values=("$@")
	for valid in "${valid_values[@]}"; do
		if [ "$value" == "$valid" ]; then
			return 0
		fi
	done
	return 1
}

# Function for outbound connections
outbound_connections() {
    local testmode=$1
    if [ "$testmode" = true ]; then
        echo "Test mode enabled. Skipping outbound connections configuration and restart."
    else
        echo "Configuring Tailscale outbound connections..."
        /var/packages/Tailscale/target/bin/tailscale configure-host > /dev/null
        /var/packages/Tailscale/target/bin/tailscale configure synology > /dev/null
        
        echo "Restarting Tailscale service..."
        synosystemctl restart pkgctl-Tailscale.service
        
        # Wait for the Tailscale service to restart
        echo "Waiting for Tailscale service to restart..."
        local timeout=60
        local interval=5
        local elapsed=0
        local service_status

        while [ $elapsed -lt $timeout ]; do
            service_status=$(synosystemctl get-active-status pkgctl-Tailscale.service)
            if [ "$service_status" = "active" ]; then
                echo "Tailscale service is running."
				sleep 5
                return
            fi
            sleep $interval
            elapsed=$((elapsed + interval))
            echo "Waiting... ($elapsed seconds elapsed)"
        done
        
        echo "Error: Tailscale service did not start within the expected time."
        exit 1
    fi
}

# Function for configuring certificates
configure_certificate() {
	local testmode=$1
	if [ "$testmode" = true ]; then
		echo "Test mode enabled. Skipping certificate configuration."
	else
		echo "Configuring Tailscale certificate..."
		/var/packages/Tailscale/target/bin/tailscale configure synology-cert
	fi

}

# Function to update Tailscale
update_tailscale() {
	local testmode=$1
	local archfamily=$2
	local dsmversion=$3
	local versionoverride=$4
	local force=$5
	local track=$6

	# Step 1: Fetch the latest version of the Tailscale package
	latest_version=$(curl -s "https://pkgs.tailscale.com/$track/" | grep -Po "<a.*tailscale-$archfamily-.*-$dsmversion.spk.*>.*</a>" | sed "s/<.*>\(.*\)<\/.*>/\1/")

	# Step 2: Extract the version number from the latest package filename
	latest_version_code=$(echo "$latest_version" | grep -oP "tailscale-$archfamily-\K[0-9]+\.[0-9]+\.[0-9]+")

	# Step 3: Get the currently installed version of Tailscale
	installed_version=$(tailscale --version | head -n 1)

	# Override the version comparison if a VersionOverride is set
	if [ -n "$versionoverride" ]; then
		echo "Version override is set. Using override version: $versionoverride instead of $latest_version_code"
		latest_version_code="$versionoverride"
	fi

	# Step 4: Compare the installed version with the latest available version
	echo "Latest version available: $latest_version_code"
	echo "Installed version: $installed_version"


	if [ "$force" = false ]; then
		if [ "$latest_version_code" == "$installed_version" ]; then
			echo "Tailscale is already up to date. No need to download or install."
			exit 0
		else
			echo "A new version of Tailscale is available. Proceeding with the download and update."
		fi
	fi
	# Step 5: Construct the download URL for the latest version
	download_url="https://pkgs.tailscale.com/$track/$latest_version"


	# Step 6: Download the latest version to a temporary directory
	temp_dir="/tmp/tailscale_update"
	mkdir -p "$temp_dir"
	if [ "$testmode" = true ]; then
		echo "Test mode enabled. Skipping download."
	else
		wget -q --show-progress "$download_url" -O "$temp_dir/$latest_version"
	fi

	# Step 7: Install the package
	if [ "$testmode" = true ]; then
		echo "Test mode enabled. Skipping installation."
	else
		synopkg install "$temp_dir/$latest_version"
	fi



	# Step 8: Clean up the temporary files
	if [ "$testmode" = true ]; then
		echo "Test mode enabled. Skipping cleanup."
	else
		rm -rf "$temp_dir"
		echo "Cleaned up temporary files."
	fi

	# Step 9: Confirm the update
	echo "Tailscale has been successfully updated to version $latest_version_code."
}

# Default values
force_update=false
skip_update=false
setup_cert=false
setup_outbound=false

# Parse command-line arguments
while [[ "$1" =~ ^- ]]; do
	case "$1" in
		-f|--force)
			force_update=true
			shift
			;;
		-s|--skip)
			skip_update=true
			shift
			;;
		-c|--cert)
			setup_cert=true
			shift
			;;
		-o|--outbound)
			setup_outbound=true
			shift
			;;
		*)
			echo "Invalid option: $1"
			exit 1
			;;
	esac
done


# Get the directory of the current script
script_dir=$(dirname "$(realpath "$0")")

# Path to the configuration file (same directory as the script)
config_file="$script_dir/config.ini"

# Check if the config file exists and print a warning if it does not
if [ ! -f "$config_file" ]; then
	echo "Warning: Configuration file '$config_file' not found. Using default values."
fi

# Read values from the configuration file with default values
ArchFamily=$(read_config_value "ArchFamily" "$config_file" "armv8")
DSMVersion=$(read_config_value "DSMVersion" "$config_file" "dsm7")
TestMode=$(validate_boolean "$(read_config_value "TestMode" "$config_file" "false")")
VersionOverride=$(read_config_value "VersionOverride" "$config_file" "")
OutboundConnections=$(validate_boolean "$(read_config_value "OutboundConnections" "$config_file" "true")")
Certificate=$(validate_boolean "$(read_config_value "Certificate" "$config_file" "true")")
Track=$(read_config_value "Track" "$config_file" "stable")


# Validate ArchFamily
valid_arch_families=(
		"x86_64" "armv8" "armv7" "armv5" "i686"
		"88f6281" "88f6282" "alpine" "armada370"
		"armada375" "armada38x" "armadaxp" "comcerto2k"
		"hi3535" "monaco"
	)
if ! validate_value "$ArchFamily" "${valid_arch_families[@]}"; then
	echo "Error: Invalid architecture family '$ArchFamily'. Valid options are: ${valid_arch_families[*]}."
	exit 1
fi

# Validate DSMVersion
valid_dsm_versions=("dsm7" "dsm6")
if ! validate_value "$DSMVersion" "${valid_dsm_versions[@]}"; then
	echo "Error: Invalid DSMVersion value '$DSMVersion'. Valid options are: ${valid_dsm_versions[*]}."
	exit 1
fi

# Validate Track
valid_tracks=("stable" "unstable")
if ! validate_value "$Track" "${valid_tracks[@]}"; then
	echo "Error: Invalid DSMVersion value '$Track'. Valid options are: ${valid_tracks[*]}."
	exit 1
fi

# Perform update if needed
if [ "$skip_update" = false ]; then
	update_tailscale "$TestMode" "$ArchFamily" "$DSMVersion" "$VersionOverride" "$force_update" "$Track"
fi

# Configure certificates
if [ "$setup_cert" = true ] || [ "$Certificate" = true ]; then
	configure_certificate "$TestMode"
fi



# Configure and restart Tailscale services
if [ "$setup_outbound" = true ] || [ "$OutboundConnections" = true ]; then
	outbound_connections "$TestMode"
fi

