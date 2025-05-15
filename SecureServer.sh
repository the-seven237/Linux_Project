#!/bin/bash

# S'assurer que le script s'exécute en tant que root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root !" 1>&2
    exit 1
fi

# MISE À JOUR DU SYSTÈME
echo "[INFO] Mise à jour des paquets..."
yum update -y

# INSTALLATION DE FIREWALLD
echo "[INFO] Installation de firewalld..."
yum install -y firewalld

# DÉMARRAGE ET ACTIVATION DE FIREWALLD
echo "[INFO] Démarrage et activation de firewalld..."
systemctl start firewalld
systemctl enable firewalld

# OUVERTURE DES PORTS POUR LES SERVICES ESSENTIELS

# HTTP (Apache)
echo "[INFO] Configuration du pare-feu pour HTTP (port 80)..."
firewall-cmd --permanent --add-service=http

# HTTPS (Apache)
echo "[INFO] Configuration du pare-feu pour HTTPS (port 443)..."
firewall-cmd --permanent --add-service=https

# MySQL/MariaDB (port 3306)
echo "[INFO] Configuration du pare-feu pour MySQL/MariaDB (port 3306)..."
firewall-cmd --permanent --add-port=3306/tcp

# FTP (port 21)
echo "[INFO] Configuration du pare-feu pour FTP (port 21)..."
firewall-cmd --permanent --add-service=ftp

# NTP (Network Time Protocol, port 123)
echo "[INFO] Configuration du pare-feu pour NTP (port 123)..."
firewall-cmd --permanent --add-service=ntp

# DNS (port 53)
echo "[INFO] Configuration du pare-feu pour DNS (port 53)..."
firewall-cmd --permanent --add-service=dns

# SMTP (Simple Mail Transfer Protocol, port 25)
echo "[INFO] Configuration du pare-feu pour SMTP (port 25)..."
firewall-cmd --permanent --add-service=smtp

# RECHARGEMENT DU PARE-FEU
echo "[INFO] Application des nouvelles règles du pare-feu..."
firewall-cmd --reload

# CONFIRMATION DES RÈGLES DU PARE-FEU
echo "[INFO] Vérification des règles de pare-feu appliquées..."
firewall-cmd --list-all

# INSTALLATION ET CONFIGURATION SELINUX

echo "[INFO] Vérification de SELinux..."
if sestatus | grep -q "SELinux status: disabled"; then
    echo "[INFO] SELinux est désactivé, activation..."
    sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
    setenforce 1
    echo "[INFO] SELinux a été activé et mis en mode 'Enforcing'."
else
    echo "[INFO] SELinux est déjà activé."
fi

# INSTALLATION DE FAIL2BAN
echo "[INFO] Installation de fail2ban..."
yum install -y fail2ban
systemctl start fail2ban
systemctl enable fail2ban

# CONFIGURATION DE FAIL2BAN POUR PROTEGER SSH ET HTTP
echo "[INFO] Configuration de fail2ban pour SSH et Apache..."
cat << EOF > /etc/fail2ban/jail.d/httpd.conf
[httpd]
enabled  = true
port     = http,https
logpath  = /var/log/httpd/*log
maxretry = 3
bantime  = 3600
EOF

cat << EOF > /etc/fail2ban/jail.d/sshd.conf
[sshd]
enabled  = true
port     = ssh
logpath  = /var/log/secure
maxretry = 3
bantime  = 3600
EOF

# Redémarrer fail2ban pour appliquer la configuration
systemctl restart fail2ban

# VERIFICATION DES SERVICES
echo "[INFO] Vérification de l'état des services..."
systemctl status httpd
systemctl status mariadb
systemctl status sshd
systemctl status clamd
systemctl status fail2ban

# VÉRIFICATION DES PORTS OUVERTS
echo "[INFO] Vérification des ports ouverts et des règles de pare-feu..."
firewall-cmd --list-ports
firewall-cmd --list-services
getenforce

echo "[INFO] Configuration du pare-feu pour tous les services terminée."

