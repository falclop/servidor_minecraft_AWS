#!/bin/bash
# Backup del servidor de Minecraft
BACKUP_DIR=~/minecraft-backups
mkdir -p $BACKUP_DIR
tar -czvf $BACKUP_DIR/backup-$(date +%F-%H-%M).tar.gz ~/minecraft-server
echo "Backup completado en $BACKUP_DIR"
