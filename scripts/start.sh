#!/bin/bash
#
MINECRAFT_DIR="/opt/minecraft-server"
BACKUP_DIR="/opt/minecraft-backups"
SERVICE_FILE="/etc/systemd/system/minecraft.service"
SERVER_JAR_URL="https://piston-data.mojang.com/v1/objects/4707d00eb834b446575d89a61a11b5d548d8c001/server.jar"
menu() {
    echo -e "1. Instalar servidor\n2. Desinstalar servidor\n3. Crear copia de seguridad\n0. Salir del programa"
}

if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ejecutarse con sudo o como root." >&2
   exit 1
fi

# Creamos el menú interactivo
echo "Bienvenido a la instalación de servidor de Minecraft"
menu
read -p "Seleccione una opción: " OP
    case $OP in
        1)
            echo "Instalando servidor..."
            # Actualización de repositorios
            apt update && apt upgrade -y

            # Instalar java y sus dependencias
            apt install openjdk-21-jre -y

            # Creamos directorio para server Minecraft y descargamos el server
            mkdir -p "${MINECRAFT_DIR}"
            wget "$SERVER_JAR_URL" -O "${MINECRAFT_DIR}"/server.jar

            # Aceptamos el EULA del servidor
            echo "eula=true" > ${MINECRAFT_DIR}eula.txt
            
            # Configuramos las propiedades de server
            sed -i "s/online-mode=true/online-mode=false/" ${MINECRAFT_DIR}/server.properties
            read -p "Cantidad de jugadores (máx. 10): " PLY
            while (( PLY > 10 || PLY < 1 )) ; do
                read -p "Debe estar entre 1 y 10. Introduzca cantidad de jugadores: " PLY
            done
            sed -i "s/max-players=20/max-players=${PLY}/" ${MINECRAFT_DIR}/server.properties
            read -p "¿Qué dificultad quiere [0=Pacífico, 1=Fácil, 2=Normal, 3=Difícil]? " DIF
            case $DIF in 
                0|1|2|3) sed -i "s/difficulty=.*/difficulty=${DIF}/" ${MINECRAFT_DIR}/server.properties
                ;;
                *) echo "Opción inválida. Usando dificultad predeterminada (Normal)."
                ;;
            esac
            read -p "Escriba el mensaje de bienvenida: " MESG
            sed -i sed -i "s/motd=.*/motd=${MESG}/" ${MINECRAFT_DIR}/server.properties
            # Convertimos el server en servicio
            touch ${SERVICE_FILE}
            chmod 777 ${SERVICE_FILE}
                        # Crear servicio systemd
            cat <<EOF > "${SERVICE_FILE}"
[Unit]
Description=Servidor de Minecraft
After=network.target

[Service]
User=root
WorkingDirectory=${MINECRAFT_DIR}
ExecStart=/usr/bin/java -Xmx1024M -Xms1024M -jar $MINECRAFT_DIR/server.jar nogui
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
            systemctl enable minecraft.service
            systemctl restart minecraft.service

            echo "Servidor de Minecraft instalado y en ejecución."
            exit 0
        ;;
        2)
            echo "Desinstalando servidor..."
            systemctl stop minecraft.service
            systemctl disable minecraft.service
            rm -rf "$MINECRAFT_DIR" "$SERVICE_FILE"
            apt purge openjdk-17-jre -y
            systemctl daemon-reload
            echo "Servidor y dependencias eliminados."
            exit 0
        ;;
        3)
            BACKUP_DIR=~/minecraft-backups
            mkdir -p $BACKUP_DIR
            tar -czvf $BACKUP_DIR/backup-$(date +%F-%H-%M).tar.gz ~/minecraft-server
            echo "Backup completado en $BACKUP_DIR"
            exit 0
        ;;
        0)
            echo "Saliendo del programa..."
            exit 0
        ;;
    esac
done