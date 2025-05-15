#!/bin/bash

# Variables
SERVER_IP="10.42.0.228"  # L'IP du serveur NTP (info inutile ici sauf documentation)
NETWORK="10.42.0.0/24"   # Plage d'IP autorisée à se synchroniser

# Étape 1 : Installer chrony
echo "[INFO] ➤ Installation de chrony..."
sudo yum install -y chrony || {
    echo "[ERROR] ➤ Échec de l'installation de chrony."
    exit 1
}
echo "[INFO] ➤ chrony installé avec succès."

# Étape 2 : Configurer chrony
echo "[INFO] ➤ Configuration du serveur NTP..."

if ! grep -q "^allow $NETWORK" /etc/chrony.conf; then
    echo "allow $NETWORK" | sudo tee -a /etc/chrony.conf > /dev/null
    echo "[INFO] ➤ Autorisation du réseau $NETWORK ajoutée à chrony.conf"
fi

# Étape 3 : Démarrer et activer le service
echo "[INFO] ➤ Activation de chronyd..."
sudo systemctl enable chronyd
sudo systemctl restart chronyd

# Étape 4 : Vérification de l’état
if sudo systemctl is-active --quiet chronyd; then
    echo "[SUCCESS] ➤ Serveur NTP chronyd actif et configuré."
else
    echo "[ERROR] ➤ Échec au démarrage de chronyd."
    exit 1
fi
