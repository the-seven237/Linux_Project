#!/bin/bash

# Variables
SERVER_IP="10.42.0.185"  # L'IP du serveur NTP (le serveur principal)

# Étape 1 : Installer chrony sur le client
echo "[INFO] Installation de chrony sur le client..."
sudo yum install -y chrony

if [ $? -ne 0 ]; then
    echo "[ERROR] Échec de l'installation de chrony sur le client. Abandon."
    exit 1
fi

# Étape 2 : Configurer le client pour utiliser le serveur NTP
echo "[INFO] Configuration du client pour se synchroniser avec le serveur NTP..."

# Ajouter l'adresse du serveur NTP dans le fichier de configuration
sudo tee -a /etc/chrony.conf > /dev/null <<EOL
server $SERVER_IP iburst
EOL

# Démarrer et activer chronyd sur le client
echo "[INFO] Démarrage et activation de chronyd sur le client..."
sudo systemctl enable chronyd
sudo systemctl start chronyd

# Vérifier que chronyd fonctionne sur le client
echo "[INFO] Vérification de l'état de chronyd sur le client..."
sudo systemctl status chronyd

if [ $? -ne 0 ]; then
    echo "[ERROR] chronyd ne fonctionne pas correctement sur le client. Abandon."
    exit 1
fi

echo "[INFO] Client NTP configuré avec succès."
