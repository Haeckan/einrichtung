#!/bin/bash
# ================================================
# Proxmox ZFS + Directory Storage Setup
# Datasets werden automatisch erstellt, Thin-Provision für VM/CT
# Logs entfernt, Backups → Backup-lokal
# Templates mit vzdump, iso, snippets
# ================================================

# --------------------------------
# 0️⃣ ZFS Datasets erstellen, falls nicht vorhanden
# --------------------------------
datasets_to_create=("rpool/vms" "rpool/ct" "rpool/backups" "rpool/data" "rpool/templates")

for ds in "${datasets_to_create[@]}"; do
    if ! zfs list "$ds" &> /dev/null; then
        echo "Erstelle ZFS Dataset $ds ..."
        zfs create "$ds"
    else
        echo "ZFS Dataset $ds existiert bereits, überspringe..."
    fi
done

# --------------------------------
# 1️⃣ ZFS Datasets definieren für Proxmox Storage
# --------------------------------
declare -A zfs_datasets=(
  ["VMDisks"]="rpool/vms"
  ["CTDisks"]="rpool/ct"
)

declare -A dir_datasets=(
  ["Backup-lokal"]="/rpool/backups"
  ["Data"]="/rpool/data"
  ["Templates"]="/rpool/templates"
)

# Content-Typen für ZFS-Pools
declare -A zfs_content=(
  ["VMDisks"]="images"
  ["CTDisks"]="rootdir"
)

# Thin-Provision für ZFS-Pools
declare -A zfs_thin=(
  ["VMDisks"]=1
  ["CTDisks"]=1
)

# Content-Typen für Directory-Storage
declare -A dir_content=(
  ["Backup-lokal"]="backup"
  ["Data"]="iso"
  ["Templates"]="vztmpl,iso,snippets"
)

# --------------------------------
# 2️⃣ ZFS Eigenschaften setzen
# --------------------------------
echo "=== Schritt 1: ZFS Eigenschaften setzen ==="
for ds in "${zfs_datasets[@]}" "${dir_datasets[@]}"; do
    echo "Setze Eigenschaften für $ds"
    zfs set compression=lz4 "$ds"
    zfs set atime=off "$ds"
done

# --------------------------------
# 3️⃣ ZFS-Pools als Proxmox Storage hinzufügen (mit Thin-Provision)
# --------------------------------
echo "=== Schritt 2: ZFS-Pools als Storage hinzufügen ==="
for id in "${!zfs_datasets[@]}"; do
    ds="${zfs_datasets[$id]}"
    ct="${zfs_content[$id]}"
    sparse="${zfs_thin[$id]}"

    if pvesh get /storage | grep -q "$id"; then
        echo "Storage $id existiert bereits, überspringe..."
        continue
    fi

    echo "Füge Storage $id hinzu..."
    pvesh create /storage \
        --storage "$id" \
        --type zfspool \
        --pool "$ds" \
        --content "$ct" \
        --sparse "$sparse" \
        --nodes "$(hostname)"
done

# --------------------------------
# 4️⃣ Directory-Storages hinzufügen
# --------------------------------
echo "=== Schritt 3: Directory-Storages hinzufügen ==="
for id in "${!dir_datasets[@]}"; do
    ds="${dir_datasets[$id]}"
    ct="${dir_content[$id]}"

    if pvesh get /storage | grep -q "$id"; then
        echo "Storage $id existiert bereits, überspringe..."
        continue
    fi

    echo "Füge Directory-Storage $id hinzu..."
    pvesh create /storage \
        --storage "$id" \
        --type dir \
        --path "$ds" \
        --content "$ct" \
        --nodes "$(hostname)"
done

echo "=== Fertig! ==="
echo "Prüfen Sie die Storages in der Proxmox GUI unter Datacenter → Storage"
