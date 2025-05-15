#!/bin/bash
set -e

SERVER_IP="10.42.0.228"

# Couleurs pour le rapport
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

function info() {
    echo -e "${YELLOW}[INFO]${RESET} $1"
}
function ok() {
    echo -e "${GREEN}[OK]${RESET} $1"
}
function fail() {
    echo -e "${RED}[FAIL]${RESET} $1"
}

# Vérifier si le serveur est joignable
info "Ping du serveur $SERVER_IP..."
if ping -c 3 "$SERVER_IP" > /dev/null 2>&1; then
    ok "Serveur $SERVER_IP joignable."
else
    fail "Serveur $SERVER_IP INJOIGNABLE."
    exit 1
fi

# Vérification synchronisation NTP
info "Vérification synchronisation NTP avec $SERVER_IP..."
if chronyc sources | grep -q "$SERVER_IP"; then
    ok "Serveur NTP $SERVER_IP est actif et utilisé comme source."
else
    fail "Serveur NTP $SERVER_IP absent des sources chrony."
fi

# Test connexion FTP
info "Test de connexion FTP vers $SERVER_IP..."
if lftp -e "exit" ftp://"$SERVER_IP" > /dev/null 2>&1; then
    ok "Connexion FTP réussie vers $SERVER_IP."
else
    fail "Connexion FTP échouée vers $SERVER_IP."
fi

# Test connexion Samba
info "Test de connexion Samba vers $SERVER_IP..."
if smbclient -L "//$SERVER_IP" -N > /dev/null 2>&1; then
    ok "Connexion Samba réussie vers $SERVER_IP."
else
    fail "Connexion Samba échouée vers $SERVER_IP."
fi

echo -e "\n${GREEN}Rapport de vérification terminé.${RESET}"
