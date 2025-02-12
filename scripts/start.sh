#!/bin/bash
# El siguiente script debe lanzarse con permisos de sudo
source .env
# Función para crear una copia de seguridad del servidor de Minecraft
hacer_backup() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p ${BACKUP_DIR}
    fi
    tar -czvf ${BACKUP_DIR}/backup-$(date +%F_%H:%M).tar.gz ${MINECRAFT_DIR} > /dev/null 2>&1
    echo -e "\nBackup completado en $BACKUP_DIR"
}
# Función para programar con crontab un copia de seguridad en caliente del servidor a las 3:00 AM
programar_backup() {
    BACKUP_CRON="tar -czvf ${BACKUP_DIR}/backup-$(date +%F_%H:%M).tar.gz ${MINECRAFT_DIR}"
    if crontab -l 2>/dev/null | grep -q "${BACKUP_CRON}"; then
        echo "Ya hay una copia de seguridad programada en cron."
    else
        (crontab -l 2>/dev/null; echo "0 3 * * * ${BACKUP_CRON}") | crontab -
        echo "¡Backup programado a las 3:00 AM todos los días!"
    fi
}

menu() {
    echo -e "1. Instalar servidor\n2. Desinstalar servidor\n3. Crear copia de seguridad\n0. Salir del programa"
}

if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ejecutarse con sudo o como root." >&2
   exit 1
fi

# Creamos el menú interactivo
clear
echo -e "⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿  ███╗   ███╗██╗███╗   ██╗███████╗ ██████╗██████╗  █████╗ ███████╗████████╗"
echo -e "⣿⣿⣿⣿⠛⠛⠛⠛⢿⣿⣿⣿⡟⠛⠛⠛⠛⣿⣿⣿  ████╗ ████║██║████╗  ██║██╔════╝██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝"
echo -e "⣿⣿⣿⣿⠀⠀⠀ ⢸⣿⣿⣿⡇  ⠀ ⣿⣿⣿  ██╔████╔██║██║██╔██╗ ██║█████╗  ██║     ██████╔╝███████║█████╗     ██║   "
echo -e "⣿⣿⣿⣿⣶⣶⣶⣶⠈⠉⠉⠉⠁⣶⣶⣶⣶⣿⣿⣿  ██║╚██╔╝██║██║██║╚██╗██║██╔══╝  ██║     ██╔══██╗██╔══██║██╔══╝     ██║   "
echo -e "⣿⣿⣿⣿⣿⡟⠛⠛⠀⠀⠀ ⠀⠛⠛⢻⣿⣿⣿⣿  ██║ ╚═╝ ██║██║██║ ╚████║███████╗╚██████╗██║  ██║██║  ██║██║        ██║   "      
echo -e "⣿⣿⣿⣿⣿⡇  ⢰⣶⣶⣶⡆ ⠀⢸⣿⣿⣿⣿  ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝   "     
echo -e "⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿"
echo -e "\n                 🎮 ¡Bienvenido al Instalador del Servidor de Minecraft! 🎮\n"

menu
echo -e "\nSeleccione una opción: " 
read OP
    case $OP in
        1)
            echo -e "\nInstalando servidor..."
            # Actualización de repositorios
            echo -e "\nActualizando repositorios..."
            # Usamos aquí la salida del comando a /dev/null, para que el usuario no vea la salida del comando
            # los errores 2> los lanzamos al mismo lugar que 1, es decir a /dev/null
            apt update && apt upgrade -y > /dev/null 2>&1

            # Instalar java y sus dependencias
            echo -e "\nInstalando dependencias de java..."
            apt install openjdk-21-jre -y > /dev/null 2>&1

            # Creamos directorio para server Minecraft y descargamos el server
            mkdir -p ${MINECRAFT_DIR} && cd ${MINECRAFT_DIR}
            wget "${SERVER_JAR_URL}" -O server.jar
            java -Xmx1024M -Xms1024M -jar server.jar nogui > /var/log/server_mine.log 2>&1 &
            sleep 10
            # Aceptamos el EULA del servidor
            echo "eula=true" > eula.txt
            
            # Configuramos las propiedades de server
            sed -i "s/online-mode=true/online-mode=false/" server.properties
            echo -e "\nCantidad de jugadores (máx. 10): " 
            read PLY
            while (( PLY > 10 || PLY < 1 )) ; do
                read -p "\nDebe estar entre 1 y 10. Introduzca cantidad de jugadores: " PLY
            done
            sed -i "s/max-players=20/max-players=${PLY}/" ${MINECRAFT_DIR}/server.properties
            echo -e "\n¿Qué dificultad quiere [0=Pacífico, 1=Fácil, 2=Normal, 3=Difícil]? " 
            read DIF
            case $DIF in 
                0|1|2|3) sed -i "s/difficulty=.*/difficulty=${DIF}/" ${MINECRAFT_DIR}/server.properties
                ;;
                *) echo -e "\nOpción inválida. Usando dificultad predeterminada (Normal)."
                ;;
            esac
            echo -e "\nEscriba el mensaje de bienvenida: " 
            read MESG
            sed -i "s/motd=.*/motd=${MESG}/" ${MINECRAFT_DIR}/server.properties
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
ExecStart=/usr/bin/java -Xmx1024M -Xms1024M -jar ${MINECRAFT_DIR}/server.jar nogui
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
            # Aquí los errores los lanzamos al log personalizados
            systemctl enable minecraft.service > /var/log/server_mine.log 2>&1
            systemctl restart minecraft.service > /var/log/server_mine.log 2>&1
            echo -e "\nServidor de Minecraft instalado y en ejecución."
            exit 0
        ;;
        2)
            echo -e "\nDesinstalando servidor..."
            systemctl stop minecraft.service > /var/log/server_mine.log 2>&1
            systemctl disable minecraft.service > /var/log/server_mine.log 2>&1
            rm -rf "${MINECRAFT_DIR}" "${SERVICE_FILE}"
            apt purge openjdk-21-jre -y > /dev/null 2>&1
            systemctl daemon-reload
            echo -e "\nServidor y dependencias eliminados."
            exit 0
        ;;
        3)
            echo -e "\nCreando copia de seguridad..."
            hacer_backup
            echo -e "\n¿Quiere programar la copia de seguridad [S/N]?"
            read B_OP
            if [[ ${B_OP} == [sS] ]]; then
                programar_backup
            fi
            echo -e "\nSaliendo del programa..."
            exit 0
        ;;
        0)
            echo "Saliendo del programa..."
            exit 0
        ;;
    esac
done