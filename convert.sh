#!/bin/bash

# ==========================================
# CONFIGURATION
# ==========================================
SSH_KEY_ID="60638563" 
DROPLET_NAME="m4b-worker"
DROPLET_SIZE="c2-16vcpu-32gb"
IMAGE="ubuntu-22-04-x64"

echo "🚀 Spinning up 16 CPU droplet ($DROPLET_NAME)..."
DROPLET_IP=$(doctl compute droplet create "$DROPLET_NAME" \
  --size "$DROPLET_SIZE" \
  --image "$IMAGE" \
  --ssh-keys "$SSH_KEY_ID" \
  --format PublicIPv4 \
  --no-header \
  --wait)

echo "✅ Droplet created with IP: $DROPLET_IP"
echo "⏳ Waiting for SSH to become available (sleeping for 30s)..."
sleep 30

# ==========================================
# SERVER SETUP
# ==========================================
echo "🛠️ Installing prerequisites on the server..."
ssh -o StrictHostKeyChecking=no root@$DROPLET_IP << 'EOF'
  apt-get update
  apt-get install -y unzip libimage-exiftool-perl
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  docker pull sandreas/m4b-tool
EOF
echo "✅ Server setup complete!"

# ==========================================
# TRACKING VARIABLES
# ==========================================
TOTAL_ATTEMPTED=0
SUCCESSFUL_DOWNLOADS=0
FAILED_FOLDERS=()

# ==========================================
# PROCESS FOLDERS
# ==========================================
# Loop through all directories in the current folder
for d in */; do
  # Skip if no directories exist
  [ -d "$d" ] || continue 
  
  # Remove trailing slash
  FOLDER="${d%/}"
  
  # Extract Author and Title assuming "Author - Title" format
  AUTHOR=$(echo "$FOLDER" | awk -F' - ' '{print $1}')
  TITLE=$(echo "$FOLDER" | awk -F' - ' '{print $2}')

  if [ -z "$TITLE" ]; then
    echo "⚠️ Skipping '$FOLDER' - Does not match 'Author - Title' format."
    continue
  fi

  ((TOTAL_ATTEMPTED++))

  echo "---------------------------------------------------"
  echo "🎧 Processing: $AUTHOR - $TITLE"
  
  echo "📦 Zipping folder..."
  zip -r -q "${FOLDER}.zip" "$FOLDER"

  echo "⬆️ SCPing zip to server..."
  scp -o StrictHostKeyChecking=no "${FOLDER}.zip" root@$DROPLET_IP:/root/

  echo "⚙️ Running remote conversion tasks..."
  ssh root@$DROPLET_IP << EOF
    unzip -q "${FOLDER}.zip"
    cd "${FOLDER}"
    
    # Run Exiftool to rename mp3 files
    exiftool -ext mp3 '-FileName<\${Track#;\$_=sprintf("%03d",\$_)}. %f.%e' .
    
    # Run m4b-tool merge
    docker run --rm -v "\$(pwd):/mnt" sandreas/m4b-tool merge "/mnt" \
      --output-file="/mnt/output.m4b" \
      --audio-bitrate=64k \
      --prefer-metadata-tags \
      --debug \
      --jobs=16 \
      --ffmpeg-threads=16
      
    # Run ffmpeg to clean output and set metadata
    docker run --rm -v "\$(pwd):/mnt" --entrypoint ffmpeg sandreas/m4b-tool \
      -i /mnt/output.m4b \
      -map_metadata -1 \
      -map_chapters 0 \
      -c copy \
      -metadata title="$TITLE" \
      -metadata artist="$AUTHOR" \
      -metadata album="$TITLE" \
      /mnt/clean_output.m4b
EOF

  echo "⬇️ Downloading completed m4b..."
  scp -o StrictHostKeyChecking=no root@$DROPLET_IP:"/root/${FOLDER}/clean_output.m4b" "${AUTHOR} - ${TITLE}.m4b"
  
  # Check if SCP succeeded and the file exists locally
  if [ $? -eq 0 ] && [ -f "${AUTHOR} - ${TITLE}.m4b" ]; then
    ((SUCCESSFUL_DOWNLOADS++))
    echo "✅ Finished: ${AUTHOR} - ${TITLE}.m4b"
  else
    echo "❌ Failed to download m4b for: $FOLDER"
    FAILED_FOLDERS+=("$FOLDER")
  fi

  echo "🧹 Cleaning up local and remote temporary files..."
  ssh root@$DROPLET_IP "rm -rf \"/root/${FOLDER}\" \"/root/${FOLDER}.zip\""
  rm -f "${FOLDER}.zip"

done

# ==========================================
# TEARDOWN
# ==========================================
echo "---------------------------------------------------"
echo "🗑️ Destroying the Droplet automatically..."
doctl compute droplet delete "$DROPLET_NAME" -f
echo "✅ Droplet destroyed."

# ==========================================
# SUMMARY
# ==========================================
echo "---------------------------------------------------"
echo "📊 SUMMARY"
echo "---------------------------------------------------"
echo "Folders attempted: $TOTAL_ATTEMPTED"
echo "m4bs downloaded:   $SUCCESSFUL_DOWNLOADS"

if [ ${#FAILED_FOLDERS[@]} -gt 0 ]; then
  echo ""
  echo "⚠️ Failed Folders:"
  for failed in "${FAILED_FOLDERS[@]}"; do
    echo "   - $failed"
  done
else
  echo ""
  echo "🎉 All attempted folders processed successfully!"
fi