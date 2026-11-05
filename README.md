# Audiobook-Conversion
Convert an audiobook with multiple .mp3 files to a single .m4b file


./convert.sh > convert.log 2>&1 &
tail -f convert.log



Here are the prerequisites required to successfully run this script on your local machine:

Local Software & Command Line Tools

A Unix-like environment: Linux, macOS, or Windows Subsystem for Linux (WSL) to execute the bash script.

DigitalOcean CLI (doctl): Must be installed and authenticated to your DigitalOcean account so the script can create and destroy droplets.

zip utility: Must be installed locally to compress the folders before transferring them (zip -r -q ...).

SSH Client: ssh and scp must be installed (standard on most Unix systems) to connect to and transfer files to the droplet.

DigitalOcean Account Configuration

Specific SSH Key ID: Your DigitalOcean account must have an SSH key saved with the ID 60638563 (or you must edit the SSH_KEY_ID variable in the script to match your actual key ID).

Droplet Limit Allowance: Your DigitalOcean account limits must allow the creation of a 16 vCPU, 32GB RAM droplet (c2-16vcpu-32gb). Brand new accounts often have lower default limits and may require a limit increase request.

File and Folder Structure

Execution Location: The script must be executed in a parent directory that contains subfolders.

Naming Convention: The subfolders must be named in a strict Author - Title format (e.g., J.R.R. Tolkien - The Hobbit). If the folder does not contain -, the script will skip it.

Source Files: The subfolders should contain .mp3 files with appropriate track number metadata (the server-side exiftool command relies on track numbers to rename them sequentially).

rm -rf ~/snap/vlc/common/.cache/vlc/art
misc to clear vlc cover art^
