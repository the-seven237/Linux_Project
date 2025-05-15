#!/bin/bash

# ---------------- CONFIGURATION ----------------
CLIENT_NAME="$1"
CLIENT_PASSWORD="$2"
DOMAIN="$CLIENT_NAME.projet.local"
WEB_DIR="/var/www/$CLIENT_NAME"
DB_NAME="${CLIENT_NAME}_db"
DB_USER="${CLIENT_NAME}_user"
DB_PASSWORD="${CLIENT_NAME}"
SHARE_DIR="/srv/$CLIENT_NAME"
LOG_FILE="/home/ec2-user/${CLIENT_NAME}_setup.log"
MYSQL_ROOT_PASSWORD="${CLIENT_NAME}"
HOSTS_LINE="127.0.0.1 $DOMAIN"

# Désactiver l'affichage du mot de passe dans les logs
exec > >(tee -a "$LOG_FILE") 2>&1

# ---------------- VÉRIFICATION DES ARGUMENTS ----------------
if [ -z "$CLIENT_NAME" ] || [ -z "$CLIENT_PASSWORD" ]; then
    echo "[ERREUR] ➤ Usage: $0 <client_name> <password>"
    exit 1
fi

echo "[INFO] ➤ Déploiement pour le client: $CLIENT_NAME"

# ---------------- MISE À JOUR DU SYSTÈME ----------------
sudo yum update -y

# ---------------- DNS LOCAL ----------------
echo "[INFO] ➤ Ajout de $DOMAIN à /etc/hosts..."
if ! grep -q "$HOSTS_LINE" /etc/hosts; then
    echo "$HOSTS_LINE" | sudo tee -a /etc/hosts
fi

# ---------------- APACHE ----------------
echo "[INFO] ➤ Installation d’Apache..."
sudo yum install -y httpd
sudo mkdir -p "$WEB_DIR"
echo "<html><h1>Bienvenue sur $DOMAIN</h1></html>" | sudo tee "$WEB_DIR/index.html" > /dev/null
sudo chown -R apache:apache "$WEB_DIR"
sudo chmod -R 755 "$WEB_DIR"

VHOST_FILE="/etc/httpd/conf.d/$CLIENT_NAME.conf"
sudo tee "$VHOST_FILE" > /dev/null <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@$DOMAIN
    DocumentRoot $WEB_DIR
    ServerName $DOMAIN
    ErrorLog /var/log/httpd/${CLIENT_NAME}_error.log
    CustomLog /var/log/httpd/${CLIENT_NAME}_access.log combined
</VirtualHost>
EOF

sudo sed -i 's/Listen 80/Listen 0.0.0.0:80/' /etc/httpd/conf/httpd.conf
sudo systemctl enable httpd
sudo systemctl restart httpd

# ---------------- MARIA DB ----------------
echo "[INFO] ➤ Installation de MariaDB 10.5..."
sudo yum install -y mariadb105-server.x86_64
sudo systemctl enable mariadb
sudo systemctl start mariadb

echo "[INFO] ➤ Création BDD pour $CLIENT_NAME..."
sudo mysql <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# ---------------- FTP ----------------
echo "[INFO] ➤ Installation de vsftpd..."
sudo yum install -y vsftpd

# Configuration propre sans doublons
sudo sed -i 's/^#*\s*user_sub_token=.*/user_sub_token=\$USER/' /etc/vsftpd/vsftpd.conf
sudo sed -i "s|^#*\s*local_root=.*|local_root=$WEB_DIR|" /etc/vsftpd/vsftpd.conf

sudo grep -q '^local_enable=YES' /etc/vsftpd/vsftpd.conf || echo "local_enable=YES" | sudo tee -a /etc/vsftpd/vsftpd.conf
sudo grep -q '^write_enable=YES' /etc/vsftpd/vsftpd.conf || echo "write_enable=YES" | sudo tee -a /etc/vsftpd/vsftpd.conf
sudo grep -q '^chroot_local_user=YES' /etc/vsftpd/vsftpd.conf || echo "chroot_local_user=YES" | sudo tee -a /etc/vsftpd/vsftpd.conf

sudo useradd -d "$WEB_DIR" -s /sbin/nologin "$CLIENT_NAME"
echo "$CLIENT_PASSWORD" | sudo passwd --stdin "$CLIENT_NAME"
sudo systemctl enable vsftpd
sudo systemctl restart vsftpd

# ---------------- SAMBA ----------------
echo "[INFO] ➤ Installation de Samba..."
sudo yum install -y samba samba-client samba-common
sudo mkdir -p "$SHARE_DIR"
sudo chown -R "$CLIENT_NAME:$CLIENT_NAME" "$SHARE_DIR"
sudo chmod -R 770 "$SHARE_DIR"

if ! grep -q "\[${CLIENT_NAME}_share\]" /etc/samba/smb.conf; then
    sudo tee -a /etc/samba/smb.conf > /dev/null <<EOF

[${CLIENT_NAME}_share]
   path = $SHARE_DIR
   valid users = $CLIENT_NAME
   writable = yes
   create mask = 0700
   directory mask = 0700
   read only = no
EOF
fi

(echo "$CLIENT_PASSWORD"; echo "$CLIENT_PASSWORD") | sudo smbpasswd -s -a "$CLIENT_NAME"
sudo smbpasswd -e "$CLIENT_NAME"

sudo systemctl enable smb
sudo systemctl restart smb

# ---------------- NFS ----------------
echo "[INFO] ➤ Installation de NFS..."
sudo yum install -y nfs-utils
echo "$SHARE_DIR *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
sudo exportfs -ra
sudo systemctl enable nfs-server
sudo systemctl start nfs-server

# ---------------- OUTILS CLIENT (OPTIONNEL) ----------------
echo "[INFO] ➤ Installation de lftp (client FTP avancé)..."
sudo yum install -y lftp

# ---------------- RÉSUMÉ ----------------
echo "[SUCCESS] ➤ Client $CLIENT_NAME configuré !"
echo " ➤ Site web: http://$DOMAIN"
echo " ➤ FTP: ftp://<IP>/$CLIENT_NAME"
echo " ➤ Samba: \\\\<IP>\\${CLIENT_NAME}_share"
echo " ➤ Base de données: $DB_NAME / $DB_USER"
