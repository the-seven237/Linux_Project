#!/bin/bash

# Variables pour la configuration DNS
DNS_DOMAIN="projet.local"
DNS_IP="10.42.0.185"
ZONE_FILE="/var/named/db.$DNS_DOMAIN"
REVERSE_ZONE_FILE="/var/named/db.10.42"
BACKUP_FILE="/etc/named.conf.bak"

# Étape 1: Installer BIND et les utilitaires nécessaires
echo "[INFO] Installation de BIND et des utilitaires nécessaires..."
sudo yum install -y bind bind-utils

if [ $? -ne 0 ]; then
    echo "[ERROR] Échec de l'installation de BIND. Abandon."
    exit 1
fi

echo "[INFO] BIND installé avec succès."

# Étape 2: Sauvegarde du fichier de configuration initial
echo "[INFO] Sauvegarde du fichier de configuration initial..."
sudo cp /etc/named.conf "$BACKUP_FILE"

if [ $? -ne 0 ]; then
    echo "[ERROR] Échec de la sauvegarde du fichier. Abandon."
    exit 1
fi

# Étape 2.1: Désactivation de l'écoute IPv6
echo "[INFO] Désactivation d'IPv6 dans named.conf..."
sudo sed -i 's/^.*listen-on-v6.*$/    listen-on-v6 port 53 { none; };/' /etc/named.conf

# Étape 3: Configuration du fichier /etc/named.conf
echo "[INFO] Configuration du fichier /etc/named.conf..."
sudo tee -a /etc/named.conf > /dev/null <<EOL

zone "$DNS_DOMAIN" IN {
    type master;
    file "/var/named/db.$DNS_DOMAIN";
};

zone "0.42.10.in-addr.arpa" IN {
    type master;
    file "/var/named/db.10.42";
};
EOL

# Étape 4: Création des fichiers de zone DNS
echo "[INFO] Création du fichier de zone pour $DNS_DOMAIN..."
sudo mkdir -p /var/named

# Fichier de zone pour le domaine
sudo tee /var/named/db.$DNS_DOMAIN > /dev/null <<EOL
\$TTL 86400
@   IN  SOA ns1.$DNS_DOMAIN. admin.$DNS_DOMAIN. (
        2023051201 ; Serial
        604800     ; Refresh
        86400      ; Retry
        2419200    ; Expire
        604800 )   ; Negative Cache TTL

@   IN  NS  ns1.$DNS_DOMAIN.
ns1 IN  A   $DNS_IP
EOL

# Fichier de zone inverse
echo "[INFO] Création du fichier de zone inverse..."
sudo tee /var/named/db.10.42 > /dev/null <<EOL
\$TTL 86400
@   IN  SOA ns1.$DNS_DOMAIN. admin.$DNS_DOMAIN. (
        2023051201 ; Serial
        604800     ; Refresh
        86400      ; Retry
        2419200    ; Expire
        604800 )   ; Negative Cache TTL

@   IN  NS  ns1.$DNS_DOMAIN.
185 IN  PTR  ns1.$DNS_DOMAIN.
EOL

# Étape 5: Vérification des permissions des fichiers
echo "[INFO] Vérification des permissions des fichiers de zone..."
sudo chown root:named /var/named/db.$DNS_DOMAIN
sudo chown root:named /var/named/db.10.42
sudo chmod 640 /var/named/db.$DNS_DOMAIN
sudo chmod 640 /var/named/db.10.42

# Étape 6: Redémarrer le service BIND
echo "[INFO] Redémarrage du service BIND..."
sudo systemctl restart named

if [ $? -ne 0 ]; then
    echo "[ERROR] Échec du redémarrage du service BIND. Abandon."
    exit 1
fi

# Étape 7: Vérification du statut du service BIND
echo "[INFO] Vérification du statut du service BIND..."
sudo systemctl status named

if [ $? -ne 0 ]; then
    echo "[ERROR] BIND ne fonctionne pas correctement. Abandon."
    exit 1
fi

# Étape 8: Tester la résolution DNS
echo "[INFO] Test de la résolution DNS avec dig..."
dig @$DNS_IP $DNS_DOMAIN

# Fin du script
echo "[SUCCESS] DNS installé et configuré avec succès."
