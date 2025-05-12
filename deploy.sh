#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Démarrage du processus de déploiement...${NC}"

# (a) Vérifier les fichiers .ots dans le répertoire content/
echo -e "${YELLOW}Vérification des fichiers OpenTimestamps...${NC}"
for file in $(find content/ -type f -not -name "*.ots" -not -path "*/\.*" -not -path "*/images/*"); do
    if [ -f "${file}.ots" ]; then
        echo -e "${GREEN}Vérification de ${file}.ots${NC}"
        ots verify "${file}.ots" || echo -e "${RED}Échec de la vérification pour ${file}.ots${NC}"
    else
        echo -e "${YELLOW}Pas de fichier .ots trouvé pour ${file}${NC}"
    fi
done

# (b) Construire le site avec nix-build
echo -e "${YELLOW}Construction du site avec nix-build...${NC}"
nix-build || { echo -e "${RED}Échec de la construction avec nix-build${NC}"; exit 1; }
echo -e "${GREEN}Construction terminée avec succès${NC}"

# (c) Synchroniser vers le serveur distant
echo -e "${YELLOW}Synchronisation vers le serveur distant...${NC}"
rsync -avz --delete result/ root@192.168.162.128:/store/www/www/root/andrew/blog2/ || { 
    echo -e "${RED}Échec de la synchronisation vers le serveur distant${NC}"
    exit 1
}

echo -e "${GREEN}Déploiement terminé avec succès!${NC}"
