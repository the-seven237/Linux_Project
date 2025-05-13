#!/bin/bash

# Script de sécurisation de la connexion SSH
# Testé pour Amazon Linux 2023

CONFIG_FILE="/etc/ssh/sshd_config"
BACKUP_FILE="/etc/ssh/sshd_config.bak"

echo "[INFO] ➤ Sauvegarde du fichier de configuration SSH..."
sudo cp "$CONFIG_FILE" "$BACKUP_FILE"
if [ $? -ne 0 ]; then
    echo "[ERROR] Échec de la sauvegarde du fichier SSH. Abandon."
    exit 1
fi

echo "[INFO] ➤ Modification de la configuration SSH..."
# Désactiver la connexion root
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$CONFIG_FILE"
# Désactiver l'authentification par mot de passe
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$CONFIG_FILE"
# Désactiver GSSAPI
sudo sed -i 's/^#*GSSAPIAuthentication.*/GSSAPIAuthentication no/' "$CONFIG_FILE"

echo "[INFO] ➤ Vérification de la configuration SSH..."
sudo sshd -t
if [ $? -eq 0 ]; then
    echo "[SUCCESS] Configuration SSH valide. Redémarrage du service..."
    sudo systemctl restart sshd
    echo "[DONE] ✔ Connexion SSH sécurisée."
else
    echo "[ERROR] Erreur dans la configuration SSH. Restauration de la sauvegarde..."
    sudo cp "$BACKUP_FILE" "$CONFIG_FILE"
    sudo systemctl restart sshd
    echo "[INFO] ⚠ Configuration restaurée depuis la sauvegarde."
fi
