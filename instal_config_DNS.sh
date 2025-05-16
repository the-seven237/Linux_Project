#!/bin/bash

# ---------------- CONFIGURATION ----------------
DNS_DOMAIN="projet.local"
DNS_HOSTNAME="ns1"
DNS_IP="10.42.0.106"
ZONE_FILE="/var/named/db.$DNS_DOMAIN"
REVERSE_ZONE_FILE="/var/named/db.10.42"
BACKUP_FILE="/etc/named.conf.bak"

# Étape 1: Installer BIND et les utilitaires nécessaires
echo "[INFO] ➤ Installation de BIND..."
sudo yum install -y bind bind-utils || { echo "[ERROR] ➤ Échec installation BIND"; exit 1; }

# Étape 2: Sauvegarde de la configuration actuelle
echo "[INFO] ➤ Sauvegarde de named.conf..."
sudo cp /etc/named.conf "$BACKUP_FILE" || { echo "[ERROR] ➤ Échec sauvegarde named.conf"; exit 1; }

# Étape 2.1: Désactivation de l’écoute IPv6 (facultatif mais recommandé)
sudo sed -i 's/^.*listen-on-v6.*$/    listen-on-v6 port 53 { none; };/' /etc/named.conf

# Étape 3: Ajouter les zones au fichier de configuration
echo "[INFO] ➤ Configuration des zones DNS dans named.conf..."
sudo tee -a /etc/named.conf > /dev/null <<EOF

zone "$DNS_DOMAIN" IN {
    type master;
    file "$ZONE_FILE";
};

zone "42.10.in-addr.arpa" IN {
    type master;
    file "$REVERSE_ZONE_FILE";
};
EOF

# Étape 4: Création / mise à jour des fichiers de zone

update_serial() {
    local zonefile=$1
    local today=$(date +%Y%m%d)
    local current_serial=$(grep -Eo '([0-9]{10})' "$zonefile" | head -1)

    if [[ $current_serial =~ ^([0-9]{8})([0-9]{2})$ ]]; then
        local serial_date=${BASH_REMATCH[1]}
        local serial_count=${BASH_REMATCH[2]}
    else
        local serial_date=$today
        local serial_count="00"
    fi

    if [ "$serial_date" == "$today" ]; then
        serial_count=$(printf "%02d" $((10#$serial_count + 1)))
    else
        serial_date=$today
        serial_count="00"
    fi

    local new_serial="${serial_date}${serial_count}"

    # Remplacer l'ancien numéro de série par le nouveau
    sudo sed -i "0,/([0-9]\{10\})/s/([0-9]\{10\})/($new_serial)/" "$zonefile"

    echo "Nouveau numéro de série pour $zonefile : $new_serial"
}

echo "[INFO] ➤ Création/mise à jour des fichiers de zone..."

# Si le fichier n'existe pas, le créer avec un numéro de série initial
if [ ! -f "$ZONE_FILE" ]; then
    sudo tee "$ZONE_FILE" > /dev/null <<EOF
\$TTL 86400
@   IN  SOA $DNS_HOSTNAME.$DNS_DOMAIN. admin.$DNS_DOMAIN. (
        $(date +%Y%m%d)00 ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        86400 )    ; Negative Cache TTL

@       IN  NS      $DNS_HOSTNAME.$DNS_DOMAIN.
$DNS_HOSTNAME IN A $DNS_IP
alice   IN  A       $DNS_IP
EOF
else
    update_serial "$ZONE_FILE"
fi

if [ ! -f "$REVERSE_ZONE_FILE" ]; then
    sudo tee "$REVERSE_ZONE_FILE" > /dev/null <<EOF
\$TTL 86400
@   IN  SOA $DNS_HOSTNAME.$DNS_DOMAIN. admin.$DNS_DOMAIN. (
        $(date +%Y%m%d)00 ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        86400 )    ; Negative Cache TTL

@       IN  NS      $DNS_HOSTNAME.$DNS_DOMAIN.
185     IN  PTR     alice.$DNS_DOMAIN.
EOF
else
    update_serial "$REVERSE_ZONE_FILE"
fi

# Étape 5: Permissions
echo "[INFO] ➤ Permissions des fichiers de zone..."
sudo chown root:named "$ZONE_FILE" "$REVERSE_ZONE_FILE"
sudo chmod 640 "$ZONE_FILE" "$REVERSE_ZONE_FILE"

# Étape 6: Redémarrage du service BIND
echo "[INFO] ➤ Redémarrage de BIND..."
sudo systemctl enable named
sudo systemctl restart named || { echo "[ERROR] ➤ Échec démarrage BIND"; exit 1; }

# Étape 7: Test DNS
echo "[INFO] ➤ Test de résolution avec dig:"
dig @$DNS_IP alice.$DNS_DOMAIN +short
dig -x $DNS_IP @$DNS_IP +short

echo "[SUCCESS] ➤ Serveur DNS fonctionnel pour $DNS_DOMAIN"
