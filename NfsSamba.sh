#!/bin/bash

# Variables
CLIENT_NAME="client1"
CLIENT_PASSWORD="motdepasse123"  # à modifier ou à générer dynamiquement
SHARE_DIR="/srv_test/partage"

echo "[INFO] ➤ Mise à jour des paquets..."
sudo yum update -y

# --------------------- NFS ---------------------

echo "[INFO] ➤ Installation de NFS..."
sudo yum install -y nfs-utils

echo "[INFO] ➤ Création du répertoire de partage NFS..."
sudo mkdir -p "$SHARE_DIR"
sudo chmod -R 755 "$SHARE_DIR"

echo "[INFO] ➤ Configuration de /etc/exports..."
NFS_LINE="$SHARE_DIR *(rw,sync,no_subtree_check,no_root_squash)"
if ! grep -qF "$NFS_LINE" /etc/exports; then
    echo "$NFS_LINE" | sudo tee -a /etc/exports
else
    echo "[INFO] ➤ La ligne d’export NFS existe déjà, rien à faire."
fi

echo "[INFO] ➤ Activation du service NFS..."
sudo exportfs -ra
sudo systemctl enable nfs-server
sudo systemctl start nfs-server

# --------------------- SAMBA ---------------------

echo "[INFO] ➤ Installation de Samba..."
sudo yum install -y samba samba-client samba-common

echo "[INFO] ➤ Création du répertoire de partage Samba..."
sudo mkdir -p "$SHARE_DIR"
sudo chmod -R 770 "$SHARE_DIR"

# Création d’un utilisateur système (s’il n’existe pas)
if ! id "$CLIENT_NAME" &>/dev/null; then
    echo "[INFO] ➤ Création de l’utilisateur système $CLIENT_NAME..."
    sudo useradd -M -s /sbin/nologin "$CLIENT_NAME"
fi

# Définir les droits d’accès au dossier
sudo chown -R "$CLIENT_NAME:$CLIENT_NAME" "$SHARE_DIR"

# Ajouter l’utilisateur à Samba avec un mot de passe
echo "[INFO] ➤ Ajout de $CLIENT_NAME à Samba..."
(echo "$CLIENT_PASSWORD"; echo "$CLIENT_PASSWORD") | sudo smbpasswd -a "$CLIENT_NAME"
sudo smbpasswd -e "$CLIENT_NAME"

# Ajouter la configuration Samba si non présente
if ! grep -q "\[${CLIENT_NAME}_share\]" /etc/samba/smb.conf; then
    echo "[INFO] ➤ Ajout de la section [$CLIENT_NAME\_share] à smb.conf..."
    sudo tee -a /etc/samba/smb.conf > /dev/null <<EOF

[${CLIENT_NAME}_share]
   path = $SHARE_DIR
   valid users = $CLIENT_NAME
   browseable = yes
   writable = yes
   read only = no
   create mask = 0700
   directory mask = 0700
EOF
else
    echo "[INFO] ➤ La section Samba [$CLIENT_NAME\_share] existe déjà."
fi

# Redémarrer les services
echo "[INFO] ➤ Redémarrage de Samba..."
sudo systemctl enable smb
sudo systemctl start smb
sudo systemctl restart smb

# --------------------- Résumé ---------------------

echo "[SUCCESS] ➤ NFS et Samba configurés avec un partage privé pour '$CLIENT_NAME'."
echo "  ➤ Partage : $SHARE_DIR"
echo "  ➤ Accès Samba : \\<IP_SERVEUR>\${CLIENT_NAME}_share"
echo "  ➤ Utilisateur : $CLIENT_NAME"
