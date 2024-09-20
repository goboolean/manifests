#!/bin/bash

# usage: ./update_image_tag.sh -a APPLICATION -i IMAGE_TAG [-p PROFILE]
# -a: application name
# -i: image tag
# -p: profile

while getopts a:i:p: flag
do
    case "${flag}" in
        a) APPLICATION=${OPTARG};;
        i) IMAGE_TAG=${OPTARG};;
        p) PROFILE=${OPTARG};;
    esac
done

# Arguments check
if [ -z "$APPLICATION" ] || [ -z "$IMAGE_TAG" ] || [ -z "$PROFILE" ]; then
    echo "Usage: $0 -a APPLICATION -i IMAGE_TAG -p PROFILE"
    exit 1
fi

echo "Updating image tag for $APPLICATION to $IMAGE_TAG"

# Parsing APPLICATION
IFS='.' read -r app_name sub_name <<< "$APPLICATION"

# File path determination
if [ -z "$sub_name" ]; then
    file_path="${app_name}/overlays/${PROFILE}/patch.yaml"
    container_name="${app_name}"
else
    file_path="${app_name}/overlays/${PROFILE}/${sub_name}-patch.yaml"
    container_name="${app_name}-${sub_name}"
fi

# File existence check
if [ ! -f "$file_path" ]; then
    echo "Error: File $file_path does not exist."
    exit 1
fi

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: yq is not installed. Please install yq to proceed."
    exit 1
fi

# Create a temporary file
temp_file=$(mktemp)
if [ $? -ne 0 ]; then
    echo "Error: Failed to create a temporary file."
    exit 1
fi

# YAML file processing
yq eval ".spec.template.spec.containers[] |= select(.name == \"$container_name\").image |= sub(\":[^:]*$\"; \":$PROFILE-$IMAGE_TAG\")" "$file_path" > "$temp_file"

# Backup the original file
cp "$file_path" "${file_path}.bak"

# Move the temporary file to the original file
mv "$temp_file" "$file_path"

if [ $? -eq 0 ]; then
    echo "Successfully updated $file_path with new image tag: $PROFILE-$IMAGE_TAG for container: $container_name"
else
    echo "Error: Failed to update $file_path"
    mv "${file_path}.bak" "$file_path"  # Restore from backup on failure
    exit 1
fi

# Delete the backup file
rm "${file_path}.bak"

exit 0
