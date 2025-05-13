#!/bin/bash

# Variables
CLIENT_NAME="client1"
NFS_SHARE_DIR="/srv_test/partage"   # Répertoire à partager avec NFS
SAMBA_SHARE_DIR="/srv_test/partage" # Répertoire à partager avec Samba

# Mise à jour des paquets
echo "Mise à jour des paquets..."
sudo yum update -y

# --------------- NFS Configuration ---------------

# Installation de NFS
echo "Installation de NFS..."
sudo yum install nfs-utils -y

# Création du répertoire à partager
echo "Création du répertoire à partager avec NFS..."
sudo mkdir -p $NFS_SHARE_DIR
sudo chmod -R 777 $NFS_SHARE_DIR

# Configuration de NFS (exporter le répertoire)
echo "Configuration de NFS pour partager $NFS_SHARE_DIR..."
echo "$NFS_SHARE_DIR *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports

# Appliquer les changements NFS
sudo exportfs -ra

# Démarrer le service NFS
sudo systemctl enable nfs-server
sudo systemctl start nfs-server
echo "NFS installé et configuré."

# --------------- Samba Configuration ---------------

# Installation de Samba
echo "Installation de Samba..."
sudo yum install samba samba-client samba-common -y

# Démarrer le service Samba
sudo systemctl enable smb
sudo systemctl start smb

# Création du répertoire à partager avec Samba
echo "Création du répertoire à partager avec Samba..."
sudo mkdir -p $SAMBA_SHARE_DIR
sudo chmod -R 777 $SAMBA_SHARE_DIR

# Créer un utilisateur système pour le client (si nécessaire)
echo "Création de l'utilisateur système pour $CLIENT_NAME..."
sudo useradd -m $CLIENT_NAME
sudo chown -R $CLIENT_NAME:$CLIENT_NAME $SAMBA_SHARE_DIR

# Ajouter la configuration globale dans le fichier smb.conf
echo "Ajout de la configuration globale dans smb.conf..."
sudo bash -c 'cat >> /etc/samba/smb.conf <<EOF
[global]
   workgroup = WORKGROUP
   security = user
   map to guest = bad user
   guest account = nobody
   smb ports = 445

[partage]
   path = $SAMBA_SHARE_DIR
   browseable = yes
   writable = yes
   guest ok = yes
   read only = no
EOF'

# Redémarrer le service Samba
sudo systemctl restart smb
echo "Samba configuré pour $CLIENT_NAME."

# --------------- Vérification des services ---------------

# Vérification du service NFS
echo "Vérification du service NFS..."
sudo systemctl status nfs-server

# Vérification du service Samba
echo "Vérification du service Samba..."
sudo systemctl status smb

echo "Installation et configuration de NFS et Samba terminées sur le serveur 2."
