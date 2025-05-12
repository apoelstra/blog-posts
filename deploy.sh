#!/bin/bash

# Colors for messages
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting deployment process...${NC}"

# (a) Verify .ots files in the content/ directory
echo -e "${YELLOW}Verifying OpenTimestamps files...${NC}"
for file in $(find content/ -type f -not -name "*.ots" -not -path "*/\.*" -not -path "*/images/*"); do
    if [ -f "${file}.ots" ]; then
        echo -e "${GREEN}Verifying ${file}.ots${NC}"
        ots verify "${file}.ots" || echo -e "${RED}Verification failed for ${file}.ots${NC}"
    else
        echo -e "${YELLOW}No .ots file found for ${file}${NC}"
    fi
done

# (b) Build the site with nix-build
echo -e "${YELLOW}Building the site with nix-build...${NC}"
nix-build || { echo -e "${RED}Build failed with nix-build${NC}"; exit 1; }
echo -e "${GREEN}Build completed successfully${NC}"

# (c) Sync to remote server
echo -e "${YELLOW}Syncing to remote server...${NC}"
rsync -avz --delete result/ root@192.168.162.128:/store/www/www/root/andrew/blog2/ || { 
    echo -e "${RED}Failed to sync to remote server${NC}"
    exit 1
}

echo -e "${GREEN}Deployment completed successfully!${NC}"
