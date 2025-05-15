#!/bin/bash

# ---------------- PARAMÈTRES ----------------
CLIENT_NAME="$1"
DOMAIN="$CLIENT_NAME.projet.local"
DB_NAME="${CLIENT_NAME}_db"
DB_USER="${CLIENT_NAME}_user"
DB_PASSWORD="$CLIENT_NAME"
SHARE_NAME="${CLIENT_NAME}_share"
CLIENT_PASSWORD="$CLIENT_NAME"  # Mot de passe = nom d’utilisateur
FTP_TEST_FILE="/tmp/ftp_test.txt"

if [ -z "$CLIENT_NAME" ]; then
    echo "[ERREUR] ➤ Usage : $0 <nom_utilisateur>"
    exit 1
fi

echo "[INFO] ➤ Tests pour le client : $CLIENT_NAME"
echo

# ---------------- TEST 1 : SITE WEB ----------------
echo "[TEST] ➤ Accès au site Web : http://$DOMAIN"
curl -s "http://$DOMAIN" | grep -q "Bienvenue" && echo "[OK] Site Web accessible" || echo "[FAIL] Site Web inaccessible"

# ---------------- TEST 2 : FTP ----------------
echo "[TEST] ➤ Connexion FTP avec l'utilisateur $CLIENT_NAME"
echo "Test FTP" > "$FTP_TEST_FILE"
ftp -inv localhost > /dev/null 2>&1 <<EOF
user $CLIENT_NAME $CLIENT_PASSWORD
put $FTP_TEST_FILE
bye
EOF

if [ $? -eq 0 ]; then
    echo "[OK] FTP fonctionne"
else
    echo "[FAIL] FTP ne fonctionne pas"
fi
rm -f "$FTP_TEST_FILE"

# ---------------- TEST 3 : SAMBA ----------------
echo "[TEST] ➤ Connexion Samba à //localhost/$SHARE_NAME"
echo "$CLIENT_PASSWORD" | smbclient "//localhost/$SHARE_NAME" -U "$CLIENT_NAME" -c "ls" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "[OK] Partage Samba accessible"
else
    echo "[FAIL] Erreur accès Samba"
fi

# ---------------- TEST 4 : BASE DE DONNÉES ----------------
echo "[TEST] ➤ Connexion MySQL/MariaDB avec l'utilisateur $DB_USER"
echo "SHOW DATABASES;" | mysql -u "$DB_USER" -p"$DB_PASSWORD" 2> /dev/null | grep -q "$DB_NAME"
if [ $? -eq 0 ]; then
    echo "[OK] Accès base de données OK"
else
    echo "[FAIL] Accès base de données échoué"
fi

# ---------------- TEST 5 : SERVICES ----------------
echo "[TEST] ➤ Vérification des services actifs"
for service in httpd vsftpd smb nfs-server mariadb; do
    systemctl is-active --quiet "$service" && echo "[OK] $service actif" || echo "[FAIL] $service inactif"
done

# ---------------- TEST 6 : PORTS ----------------
echo "[TEST] ➤ Vérification des ports ouverts"
PORTS=(80 21 139 445 2049 3306)
for port in "${PORTS[@]}"; do
    ss -tulpn | grep -q ":$port" && echo "[OK] Port $port ouvert" || echo "[FAIL] Port $port fermé"
done

echo
echo "[INFO] ➤ Tests terminés pour le client $CLIENT_NAME"
