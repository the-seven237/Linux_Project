#!/bin/bash

# Adresse du serveur source (server1)
SOURCE_USER="ec2-user"
SOURCE_HOST="10.42.0.185"

# Adresse du serveur de sauvegarde (server2)
BACKUP_USER="ec2-user"
BACKUP_HOST="10.42.0.47"

# Dossiers à sauvegarder sur server1 (dossiers montés comme dans le plan de partitionnement)
DIRS_TO_BACKUP=("/var" "/home" "/srv" "/boot" "/etc")

# Dossier destination sur le serveur backup (server2)
BACKUP_DIR="/backup"

# Options rsync
RSYNC_OPTS="-avz --delete --exclude='lost+found'"

# Boucle pour sauvegarder chaque répertoire
for DIR in "${DIRS_TO_BACKUP[@]}"
do
    # Création de l'arborescence de répertoires sur le serveur de sauvegarde si elle n'existe pas
    echo "[INFO] Création des répertoires de sauvegarde sur $BACKUP_HOST:$BACKUP_DIR$(dirname $DIR)"
    ssh $BACKUP_USER@$BACKUP_HOST "mkdir -p $BACKUP_DIR$(dirname $DIR)"
    
    # Sauvegarde du répertoire depuis server1 vers server2
    echo "[INFO] Sauvegarde de $DIR vers $BACKUP_HOST:$BACKUP_DIR$(dirname $DIR)"
    rsync $RSYNC_OPTS "$SOURCE_USER@$SOURCE_HOST:$DIR" "$BACKUP_USER@$BACKUP_HOST:$BACKUP_DIR$(dirname $DIR)/"
done

echo "[INFO] Sauvegarde terminée."
