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

echo "Updating image tag for $APPLICATION to $IMAGE_TAG, profile: $PROFILE"

# Parsing APPLICATION
IFS='.' read -r app_name sub_name <<< "$APPLICATION"

# Container name determination
if [ -z "$sub_name" ]; then
    image="${app_name}"
else
    image="${app_name}/${sub_name}"
fi

# Define directory path
dir_path="$APPLICATION/kustomize/overlays/$PROFILE"

# Check if directory exists
if [ ! -d "$dir_path" ]; then
    echo "Error: Directory $dir_path does not exist."
    exit 1
fi

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: yq is not installed. Please install yq to proceed."
    exit 1
fi

# Find all deployment.yaml files
yaml_files=()
while IFS= read -r file; do
    yaml_files+=("$file")
done < <(find "$dir_path" -type f -name "*deployment.yaml")

if [ ${#yaml_files[@]} -eq 0 ]; then
    echo "Error: No deployment.yaml files found in $dir_path"
    exit 1
fi

# Process each deployment.yaml file
for file_path in "${yaml_files[@]}"; do
    echo "Processing $file_path..."
    
    # Create a temporary file
    temp_file=$(mktemp)
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create a temporary file."
        exit 1
    fi
    
    # YAML file processing
    yq eval ".spec.template.spec.containers[] |= select(.image | test(\"$image\")).image |= sub(\":[^:]*$\"; \":$IMAGE_TAG\")" "$file_path" > "$temp_file"

    # Backup the original file
    cp "$file_path" "${file_path}.bak"

    # Move the temporary file to the original file
    mv "$temp_file" "$file_path"

    if [ $? -eq 0 ]; then
        echo "Successfully updated $file_path with new image tag: $IMAGE_TAG for image: $image"
    else
        echo "Error: Failed to update $file_path"
        mv "${file_path}.bak" "$file_path"  # Restore from backup on failure
        exit 1
    fi

    # Delete the backup file
    rm "${file_path}.bak"

done

echo "Successfully updated all deployment.yaml files."

exit 0
