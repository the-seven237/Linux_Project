#!/bin/bash

# Variables
SERVER_IP="10.42.0.185"  # L'IP du serveur NTP
NETWORK="10.42.0.0/24"   # Plage d'IP des clients autorisés à se synchroniser

# Étape 1 : Installer chrony
echo "[INFO] Installation de chrony..."
sudo yum install -y chrony

if [ $? -ne 0 ]; then
    echo "[ERROR] Échec de l'installation de chrony. Abandon."
    exit 1
fi

echo "[INFO] chrony installé avec succès."

# Étape 2 : Configurer le serveur NTP
echo "[INFO] Configuration du serveur NTP..."
sudo sed -i 's/^.*allow .*$/allow $NETWORK/' /etc/chrony.conf

# Autoriser les clients à se synchroniser avec le serveur NTP
echo "[INFO] Configuration du fichier /etc/chrony.conf pour permettre la synchronisation des clients NTP..."
sudo tee -a /etc/chrony.conf > /dev/null <<EOL
# Réseau autorisé à se synchroniser avec ce serveur
allow $NETWORK
EOL

# Démarrer et activer chronyd
echo "[INFO] Démarrage et activation de chronyd..."
sudo systemctl enable chronyd
sudo systemctl start chronyd

# Vérifier que chrony fonctionne correctement
echo "[INFO] Vérification de l'état de chronyd..."
sudo systemctl status chronyd

if [ $? -ne 0 ]; then
    echo "[ERROR] chronyd ne fonctionne pas correctement. Abandon."
    exit 1
fi

echo "[INFO] Serveur NTP configuré avec succès."
