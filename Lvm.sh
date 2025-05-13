#!/bin/bash
# Script complet pour partitionner, créer LVM et monter automatiquement

set -e  # Arrête le script si une commande échoue

echo "[1/7] ➤ Installation de LVM2"
sudo dnf install -y lvm2

echo "[2/7] ➤ Création des partitions LVM"
for disk in /dev/nvme1n1 /dev/nvme2n1; do
    echo "  → Partitionnement de $disk"
    sudo parted -s "$disk" mklabel gpt
    sudo parted -s "$disk" mkpart primary 0% 100%
    sudo parted -s "$disk" set 1 lvm on
done

sleep 1  # Pause pour que le système reconnaisse les nouvelles partitions

echo "[3/7] ➤ Création des volumes physiques"
sudo pvcreate /dev/nvme1n1p1 /dev/nvme2n1p1

echo "[4/7] ➤ Création du groupe de volumes 'vgproject'"
sudo vgcreate vgproject /dev/nvme1n1p1 /dev/nvme2n1p1

echo "[5/7] ➤ Création des volumes logiques"
sudo lvcreate -L 1.5G -n lv_var vgproject
sudo lvcreate -L 1G -n lv_srv vgproject
sudo lvcreate -L 512M -n lv_swap vgproject

echo "[6/7] ➤ Formatage et activation"
sudo mkfs.ext4 /dev/vgproject/lv_var
sudo mkfs.ext4 /dev/vgproject/lv_srv
sudo mkswap /dev/vgproject/lv_swap
sudo mkdir -p /var_test /srv_test
sudo mount /dev/vgproject/lv_var /var_test
sudo mount /dev/vgproject/lv_srv /srv_test
sudo swapon /dev/vgproject/lv_swap

echo "[7/7] ➤ Mise à jour de /etc/fstab"
cat <<EOF | sudo tee -a /etc/fstab
/dev/vgproject/lv_var  /var_test  ext4  defaults  0 2
/dev/vgproject/lv_srv  /srv_test  ext4  defaults  0 2
/dev/vgproject/lv_swap none       swap  sw        0 0
EOF

echo "✅ Partitionnement et LVM terminés avec succès."