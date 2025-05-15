#!/bin/bash
set -e

# Variables
SERVER_IP="10.42.0.228"
FTP_CLIENT="lftp"
SAMBA_CLIENT="samba-client"

echo "[INFO] Mise à jour du système..."
sudo yum update -y

echo "[INFO] Installation et configuration de chrony (NTP)..."
sudo yum install -y chrony
if ! grep -q "^server $SERVER_IP iburst" /etc/chrony.conf; then
    echo "server $SERVER_IP iburst" | sudo tee -a /etc/chrony.conf
    sudo systemctl restart chronyd
    echo "[OK] Serveur NTP ajouté et chronyd redémarré."
else
    echo "[INFO] Serveur NTP déjà configuré."
fi
sudo systemctl enable chronyd
sudo systemctl start chronyd

echo "[INFO] Installation et démarrage de firewalld..."
sudo yum install -y firewalld
sudo systemctl enable firewalld
sudo systemctl start firewalld

sudo firewall-cmd --permanent --add-service=ftp
sudo firewall-cmd --permanent --add-service=samba
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=ntp
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload

echo "[INFO] Installation des clients FTP, Samba, Telnet et LFTP..."
sudo yum install -y $FTP_CLIENT $SAMBA_CLIENT telnet lftp

echo "[INFO] Installation et configuration de fail2ban..."
sudo yum install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Config fail2ban pour SSH et HTTP (apache)
sudo tee /etc/fail2ban/jail.d/sshd.conf > /dev/null <<EOF
[sshd]
enabled  = true
port     = ssh
logpath  = /var/log/secure
maxretry = 3
bantime  = 3600
EOF

sudo tee /etc/fail2ban/jail.d/httpd.conf > /dev/null <<EOF
[httpd]
enabled  = true
port     = http,https
logpath  = /var/log/httpd/*log
maxretry = 3
bantime  = 3600
EOF

sudo systemctl restart fail2ban

echo "[INFO] Vérification et activation de SELinux en mode enforcing..."
if sestatus | grep -q "SELinux status: disabled"; then
    sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
    sudo setenforce 1
    echo "[OK] SELinux activé et en mode enforcing."
else
    echo "[INFO] SELinux est déjà activé."
fi

echo "[INFO] Installation et démarrage de ClamAV antivirus..."
sudo yum install -y clamav clamav-update
sudo systemctl enable clamd
sudo systemctl start clamd

# Tests de connexion basiques
echo "[INFO] Tests de connexion :"

chronyc sources | grep "$SERVER_IP" >/dev/null && echo "[OK] Serveur NTP détecté." || echo "[FAIL] Serveur NTP absent."

lftp -e "exit" ftp://$SERVER_IP && echo "[OK] Connexion FTP OK." || echo "[FAIL] Connexion FTP échouée."

smbclient -L //$SERVER_IP -N > /dev/null 2>&1 && echo "[OK] Connexion Samba OK." || echo "[FAIL] Connexion Samba échouée."

echo "[SUCCESS] Configuration client terminée."
