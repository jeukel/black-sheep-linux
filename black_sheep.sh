#!/bin/bash

##########################
# Variables              #
##########################

INSTALL='sudo install --owner=root --group=root --mode=644'


##########################
# Check permissions      #
##########################

# Check for permissions errors
if [ `id -u` == 0 ]; then
    echo "[ERROR] This script should not be executed as root. Run it a a sudo-capable user."
    exit 1
fi

# Check if user can do sudo
echo "This application needs root privileges."
if [ `sudo id -u` != 0 ]; then
    echo "This user cannot cast sudo or you typed an incorrect password (several times)."
    exit 1
else
    echo "Correctly authenticated."
fi


##########################
# Meta-distribution      #
##########################

function depends {

    # Dependencias para ejecutar este script
    sudo apt-get --yes install devscripts debhelper gdebi
}

function repos {

    # Erlang
    wget -q http://binaries.erlang-solutions.com/debian/erlang_solutions.asc -O- | sudo apt-key add -
    sudo sh -c 'echo "deb http://binaries.erlang-solutions.com/debian $(lsb_release -sc) contrib" > /etc/apt/sources.list.d/erlang.list'

    # Skype
    sudo sh -c 'echo "deb http://archive.canonical.com/ $(lsb_release -sc) partner" > /etc/apt/sources.list.d/skype.list'

    # VirtualBox
    wget -q http://download.virtualbox.org/virtualbox/debian/oracle_vbox.asc -O- | sudo apt-key add -
    sudo sh -c 'echo "deb http://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib" > /etc/apt/sources.list.d/virtualbox.list'

    # Google Talk Plugin
    if [ -f  ./cache/google.asc ]; then
        sudo apt-key add ./cache/google.asc
    else
        wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
    fi
    sudo sh -c 'echo "deb http://dl.google.com/linux/talkplugin/deb/ stable main" > /etc/apt/sources.list.d/google-talkplugin.list'

    # Dropbox
    if [ -f  ./cache/dropbox.asc ]; then
        sudo apt-key add ./cache/dropbox.asc
    else
        sudo apt-key adv --keyserver pgp.mit.edu --recv-keys 5044912E
    fi
    sudo sh -c 'echo "deb http://linux.dropbox.com/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/dropbox.list'

    # Gummi
    sudo add-apt-repository --yes ppa:gummi/gummi

    # Cinnamon
    sudo add-apt-repository --yes ppa:gwendal-lebihan-dev/cinnamon-stable

    # Gimp
    sudo add-apt-repository --yes ppa:otto-kesselgulasch/gimp

    sudo apt-get update
}

function branding {

    # Instala tipografía del sistema
    sudo apt-get --yes install ttf-dejavu

    # Elimina las barras overlay de Ubuntu
    sudo apt-get --yes remove overlay-scrollbar*

    # Establecer la página de la escuela como página inicial
    sudo apt-get --yes remove xul-ext-ubufox
    $INSTALL ./conf/usr/lib/firefox/defaults/preferences/all-itcr.js /usr/lib/firefox/defaults/preferences/all-itcr.js
    $INSTALL ./conf/etc/firefox/itcr.properties /etc/firefox/itcr.properties

    # Adaptar el escritorio
    $INSTALL ./conf/usr/share/backgrounds/blacksheep.png /usr/share/backgrounds/blacksheep.png
    $INSTALL ./conf/usr/share/gnome-background-properties/blacksheep-wallpapers.xml /usr/share/gnome-background-properties/blacksheep-wallpapers.xml
    $INSTALL ./conf/usr/share/glib-2.0/schemas/zz_blacksheep_settings.gschema.override /usr/share/glib-2.0/schemas/zz_blacksheep_settings.gschema.override
    sudo fc-cache -fv
    sudo glib-compile-schemas /usr/share/glib-2.0/schemas

    # Cambiar el splash screen
    sudo cp -R ./conf/lib/plymouth/themes/blacksheep /lib/plymouth/themes/
    sudo update-alternatives --install /lib/plymouth/themes/default.plymouth default.plymouth /lib/plymouth/themes/blacksheep/blacksheep.plymouth 100
    sudo update-alternatives --set default.plymouth /lib/plymouth/themes/blacksheep/blacksheep.plymouth
    sudo update-initramfs -u
    sudo update-grub

    # Configurar GIMP para ventana única
    sudo mkdir -p /etc/gimp/2.0/
    $INSTALL ./conf/etc/gimp/2.0/sessionrc /etc/gimp/2.0/sessionrc

    # Eliminar las configuraciones actuales del usuario
    mkdir -p ~/.pre-bs
    cp ~/.config/dconf/user ~/.pre-bs/
    rm -f ~/.config/dconf/user
}

function packages {

    # Copiar cache de paquetes Debian en caso de existir
    if [ -d ./cache/ ]; then
        sudo cp -f ./cache/*.deb /var/cache/apt/archives/
        sudo apt-get update
    fi

    # Instalar todos los paquetes de Black Sheep
    ./package_builder.py build
    sudo gdebi --n `find build/ -name *.deb | head -n 1`

    # Actualiza el cache de archivos de archivos
    sudo apt-file update

    # Instalar aplicaciones al inicio
    $INSTALL ./conf/etc/xdg/autostart/*.desktop /etc/xdg/autostart/
}

function apps {

    # Ejecutar instalador adicionales
    cd ./apps/
    for app in `find . -executable -type f`; do
        echo "Running: $app"
        ./$app
    done
    cd ../
}


##########################
# Station configuration  #
##########################

function environments {

    sudo apt-get --yes install cinnamon
}

function updates {

    # Desactiva actualizaciones
    sudo apt-get --yes remove update-notifier
    $INSTALL ./conf/etc/apt/apt.conf.d/10periodic /etc/apt/apt.conf.d/10periodic
}

function hostname {

    # Instala el script de cambio de nombre de estacion
    $INSTALL ./conf/sbin/changehostname /sbin/changehostname
    sudo chmod 755 /sbin/changehostname

    # Nota: Correr como root el siguiente comando en cada una de las estaciones:
    # /sbin/changehostname cic01
}

function nfs {

    sudo apt-get install nfs-common

    if [ -z "`cat /etc/fstab | grep nilo`" ]; then
        echo "Adding fstab line..."
        sudo sh -c 'echo "nilo.ic-itcr.ac.cr:/storage/home    /home           nfs     defaults,_netdev,auto 0 0" >> /etc/fstab'
    else
        echo "Ignoring insertion of fstab line."
    fi
}

function ldap {

    # Instalación de paquetes para autenticar vía LDAP
    #  (Responder que se desea mantener la versión instalada)
    $INSTALL ./conf/etc/ldap/ldap.conf /etc/ldap/ldap.conf
    sudo apt-get install libpam-ldapd

    # Instalación de archivos de configuración
    sudo cp /etc/nslcd.conf /etc/nslcd.conf.original
    sudo install --owner=root --group=nslcd --mode=640 ./conf/etc/nslcd.conf /etc/nslcd.conf

    sudo cp /etc/nsswitch.conf /etc/nsswitch.conf.original
    $INSTALL ./conf/etc/nsswitch.conf /etc/nsswitch.conf

    # Configurar LigthDM para ingreso vía LDAP
    sudo cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.original
    $INSTALL ./conf/etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf
}

function users {

    # Crea home para usuarios locales
    sudo mkdir -p /local/home/

    # Crear usuarios locales/invitado
    if [ -z  "`cat /etc/passwd | grep curso`" ]; then
        echo "Adding users..."
        sudo useradd --create-home --home /local/home/curso/ --skel /etc/skel/ --shell /bin/bash --password $(perl -e 'print crypt("curso", "blacksheep")') curso
    else
        echo "Ignoring the addition of local users"
    fi

    # Mover el home del administrador a la carpeta de homes locales
    # Ejecutar los siguientes comandos como root:
    #sudo mkdir -p /local/home/administrator
    #sudo cp /etc/skel/* /local/home/administrator
    #sudo cp /etc/skel/.* /local/home/administrator
    #sudo chown -R administrator:administrator /local/home/administrator
    #sudo usermod -d /local/home/administrator administrator
}

function clean {

    # Elimina el cache de paquetes
    sudo apt-get clean

    # Elimina el archivo de MAC Address
    sudo rm -f /etc/udev/rules.d/70-persistent-net.rules
}

function help {

    # Imprime la lista de funciones disponibles
    cat $0 | grep "function " | sed 's/ {//' | sed 's/function //'  #Ignore this
}


##########################
# Arguments handling     #
##########################

case "$1" in
check)
    # Verifica la disponibilidad de los paquetes
    repos
    ./package_builder.py check
;;

install)
    # Instala la meta-distribución
    depends
    repos
    packages
    apps
    branding
;;

config)
    # Configura la estación
    updates
    nfs
    ldap
    users
    hostname
    #clean
;;

manual)
    echo "WARNING this mode can perform unsafe actions."

    # Manually insert the name of the function_ or execute it.
    if [ "$2" == "" ]; then
        echo "Insert the name of a function: (CTRL-C to exit)"
        echo "Type \"help\" for a list of available functions."
        read
        $REPLY
        echo "[DONE]"
    else
        $2
        echo "[DONE]"
    fi
;;

*)
    echo "Usage: `basename $0` [check|install|config|manual]"
    exit 1
;;

esac
