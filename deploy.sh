#!/usr/bin/env bash

# Colors for messages
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting deployment process...${NC}"

# (a) Upgrade existing .ots files and stamp new files
echo -e "${YELLOW}Processing OpenTimestamps files...${NC}"
unstamped_files=()

while IFS= read -r file; do
    if [ -f "${file}.ots" ]; then
        # Check if file has changed since OTS was created
        ots_timestamp=$(git log -1 --format=%at -- "${file}.ots")
        file_timestamp=$(git log -1 --format=%at -- "${file}")
        
        if [[ $file_timestamp -gt $ots_timestamp ]]; then
            echo -e "${YELLOW}File ${file} has changed since OTS was created, re-stamping...${NC}"
            rm "${file}.ots"
            unstamped_files+=("${file}")
        else
            echo -e "${GREEN}Upgrading ${file}.ots${NC}"
            if ! ots upgrade "${file}.ots"; then
                echo -e "${RED}Upgrade failed for ${file}.ots${NC}"
                # Check if failure is due to file content change
                if ots verify "${file}.ots" 2>&1 | grep -q "File content does not match"; then
                    echo -e "${YELLOW}File content changed, re-stamping ${file}...${NC}"
                    rm "${file}.ots"
                    unstamped_files+=("${file}")
                fi
            fi
        fi
    else
        echo -e "${YELLOW}Adding ${file} to unstamped files list${NC}"
        unstamped_files+=("${file}")
    fi
done < <(find content/ -type f -not -name "*.ots" -not -path "*/\.*")

# Stamp all unstamped files
if [ ${#unstamped_files[@]} -gt 0 ]; then
    echo -e "${YELLOW}Stamping ${#unstamped_files[@]} new files...${NC}"
    ots stamp "${unstamped_files[@]}" || echo -e "${RED}Stamping failed for some files${NC}"
fi

# Add all content to git and commit
echo -e "${YELLOW}Adding changes to git...${NC}"
git add content/
git commit -m "Update timestamps and deploy" --no-gpg-sign || echo -e "${RED}Git commit failed${NC}"

# (b) Build the site with nix-build
echo -e "${YELLOW}Building the site with nix-build...${NC}"
nix-build || { echo -e "${RED}Build failed with nix-build${NC}"; exit 1; }
echo -e "${GREEN}Build completed successfully${NC}"

# (c) Sync to remote server
echo -e "${YELLOW}Syncing to remote server...${NC}"
rsync -avz --delete result/ root@192.168.162.128:/store/www/www/root/andrew/blog/ || { 
    echo -e "${RED}Failed to sync to remote server${NC}"
    exit 1
}

echo -e "${GREEN}Deployment completed successfully!${NC}"
