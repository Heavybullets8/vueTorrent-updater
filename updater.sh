#!/bin/bash

# Variables
latest_release_url="https://api.github.com/repos/WDaan/VueTorrent/releases/latest"
install_dir="/mnt/speed/apps/vuetorrent"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
tag_file="${script_dir}/current_release_tag.txt"

# Create the installation directory if it doesn't exist
mkdir -p "${install_dir}"

# Fetch the latest release tag and the download URL
latest_release_info=$(curl -s "${latest_release_url}")
latest_tag=$(jq -r '.tag_name' <<< "${latest_release_info}")
latest_asset=$(jq -r '.assets[] | select(.name | test(".zip$")) | .browser_download_url' <<< "${latest_release_info}")

# Check if the tag file exists and has the same tag as the latest release
if [[ -f "${tag_file}" ]] && [[ $(cat "${tag_file}") == "${latest_tag}" ]]; then
  echo "VueTorrent is already up-to-date. No update needed."
  exit 0
fi

# Download the latest release
temp_dir=$(mktemp -d)
download_file="${temp_dir}/vuetorrent.zip"
curl -s -L -o "${download_file}" "${latest_asset}"

# Unzip the downloaded file
unzip -q "${download_file}" -d "${temp_dir}"

# Remove the old installation and move the new one to the install directory
rm -rf "${install_dir}/vuetorrent"
mv "${temp_dir}/vuetorrent" "${install_dir}/vuetorrent"

# Save the current release tag to the tag file
echo "${latest_tag}" > "${tag_file}"

# Clean up
rm -rf "${temp_dir}"

echo "VueTorrent has been updated to the latest version: ${latest_tag}"

echo "Restarting qBittorrent"

initial=$(k3s kubectl get pods -A | grep -E '^(ix.*qbittorrent-|ix-qbittorrent\s)' | awk '{print $1, $2}')

# Grab namespace ix-*
namespace=$(awk '{print $1}' <<< "${initial}")

# Grab pod, remove anything after the second to last hyphen
pod=$(awk '{print $2}' <<< "${initial}" | sed -E 's/^(.*-)[^-.]+-[^-.]+$/\1/;s/-$//')

k3s kubectl -n "$namespace" rollout restart deploy "$pod"
