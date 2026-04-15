#!/bin/bash

# Executar o script na pasta em que se encontra e no login de root

# Debian nao tem sudo ... caso esteja se tentando fazer a instalacao no Ubuntu e derivados, comentar a linha abaixo
# O arquivo abaixo deverá conter a lista de pacotes do Debian a instalar. Devera estar na mesma pasta do setup.sh
packages="packages" 




function labredes_install_apps_Internet(){

    install_dir="`pwd`"
    log="${install_dir}"/installation.log

    distro="$1"
    version="$2"

    distro="`lsb_release -i | tail -1 | cut -f2 -d':' | xargs`"
    release="`lsb_release -r | tail -1 | cut -f2 -d':' | xargs`"
    codename="`lsb_release -c | tail -1 | cut -f2 -d':' | xargs`"

    echo "Installing for $distro $release ( $codename )"
 
    which sudo
    if [[ $? -ne 0 ]]; then

        alias sudo=""

    fi

    [[ ! -d DEBS ]] && mkdir DEBS

    # Na primeira vez que executar o script, faz um full-upgrade e reboota a maquina
    if [[ ! -f "${install_dir}/.full-upgrade.stamp"  ]]; then 

        # distro update & upgrade
        echo "Fazendo um upgrade ... "

        echo "Fazendo upgrade ... "
        sudo apt update
        sudo apt-get -y full-upgrade

        touch "${install_dir}/.full-upgrade.stamp"

        sudo apt install -y flatpak

        clear

        echo "[`date`] Full upgrade finished" | tee -a ${log}

        echo "O computador será reiniciado em 10s"
        echo
        echo "Certifique-se de fazer um login no usuário 'aluno' a fim de serem criadas as pastas e arquivos do usuário"
        echo "O processo de configuração irá alterar tais pastas e arquivos"
        sleep 10

        sudo reboot
    else
        echo "[`date`] Full upgrade already done" | tee -a ${log}
    fi

    ##############
    ### MySQL ###
    #############

    if [[ ! -f "${install_dir}/.mysql-repo.stamp" ]]; then 

        cd "${install_dir}/DEBS"

        # O MySQL e o MSQL Workbench estão no sid mas não no bookworm 
        wget https://repo.mysql.com//mysql-apt-config_0.8.36-1_all.deb

        sudo apt install -y ./mysql-apt-config_0.8.36-1_all.deb

        echo "[`date`] MySQL repository added" | tee -a ${log}
        touch "${install_dir}/.mysql-repo.stamp"
    else 
        echo "[`date`] MySQL repository already added" | tee -a ${log}
    fi

    cd "${install_dir}"

    ##############
    ### ChonOS ###
    ##############

    if [[ ! -f "${install_dir}/.chonos-repo.stamp" ]]; then 
        echo "deb [trusted=yes] http://packages.chon.group/ chonos main" | sudo tee /etc/apt/sources.list.d/chonos.list

        echo "[`date`] ChonOS repository added" | tee -a ${log}
        touch "${install_dir}/.chonos-repo.stamp"
    else 
        echo "[`date`] ChonOS repository already added" | tee -a ${log}
    fi

    ##########################
    ### Visual Studio Code ###
    ##########################

    if [[ ! -f "${install_dir}/.vscode-repo.stamp" ]]; then 

        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list'
        rm -f packages.microsoft.gpg

        echo "[`date`] VSCode repository added" | tee -a ${log}
        touch "${install_dir}/.vscode-repo.stamp"
    else 
        echo "[`date`] VSCode repository already added" | tee -a ${log}
    fi

    ##################
    ### VirtualBox ###
    ##################

    if [[ ! -f "${install_dir}/.virtualbox.stamp" ]]; then

        wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg --dearmor

        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian $codename contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list

        sudo apt-get -y update
        sudo apt-get -y -q -s install virtualbox-7.2

        if [[ $? -eq 0 ]]; then
            echo "virtualbox-7.2" >> ${install_dir}/packages

            echo "[`date`] Added VirtualBox repository" | tee -a ${log}
            touch "${install_dir}/.virtualbox.stamp"
        else 
            echo "[`date`] ERROR adding VirtualBox repository ${distro}/${version}! " | tee -a ${log}
        fi

    else
        echo "[`date`] VirtualBox repository already installed " | tee -a ${log}
    fi    

    ##############    
    ### WeBOTS ###
    ##############    

    if [[ ! -f "${install_dir}/.webots-repo.stamp" ]]; then 

        echo "Configuring new repositories in the package manager"
        sudo mkdir -p /etc/apt/keyrings
        cd /etc/apt/keyrings
        sudo wget -q https://cyberbotics.com/Cyberbotics.asc
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/Cyberbotics.asc] https://cyberbotics.com/debian binary-amd64/" | sudo tee /etc/apt/sources.list.d/Cyberbotics.list

        echo "[`date`] WeBOTS repository added" | tee -a ${log}
        touch "${install_dir}/.webots-repo.stamp"
    else 
        echo "[`date`] WeBOTS repository already added" | tee -a ${log}
    fi        

    sudo apt -y update
    if [[ $? -ne 0 ]]; then
        echo "[`date`] ERROR during apt update after WeBOTS!" | tee -a ${log}
    fi

    ################################################
    ### Instalação dos pacotes via repositorios. ###
    ################################################
    
    if [[ ! -f "${install_dir}/.apt-install.stamp"  ]]; then

        cd "${install_dir}"
        echo "Starting packages installation on ${install_dir} ..."

        ok_pkgs=`mktemp`
        
        for pkg in $(cat "$packages"); do
            echo -n "Checando $pkg ...";
            apt-get install -q -s -y $pkg > /dev/null
            if [[ $? -eq 0 ]]; then 
                echo "ok";
                echo "$pkg" >> $ok_pkgs ;

            else 
                echo "ERROR";
                echo "Package cannot installed: $pkg" >> ${log} ;
            fi
        done

        # pegando a ultima versao do OpenJDK
        openjdk_pkg="`apt-cache search openjdk | egrep 'openjdk-[[:digit:]]{2,}-jdk ' | cut -f1 -d ' ' | sort | tail -1`"

        if [[ "$openjdk_pkg" != "" ]]; then 
            apt-get install -q -s -y $openjdk_pkg

            if [[ $? -eq 0 ]]; then 
                echo "[`date`] OpenJDK package '$openjdk_pkg' added" | tee -a ${log}
                echo "$openjdk_pkg" >> $ok_pkgs
            else 
                echo "[`date`] ERROR: package '$openjdk_pkg' for OpenJDK doesn't exist!" | tee -a ${log}
            fi

        else 
            echo "[`date`] ERROR: couldn't find latest OpenJDK APT package!" | tee -a ${log}            
        fi
        
        sudo apt install -y linux-headers-`uname -r`
        sudo apt-get install -y `cat $ok_pkgs`

        # pegando e instalando a ultima versao do openjdk
        if [[ $? -eq 0 ]]; then
            echo "[`date`] Packages from APT installed" | tee -a ${log}
            touch "${install_dir}/.apt-install.stamp"
        else 
            echo "[`date`] ERROR installing packages from APT! " | tee -a ${log}
        fi

    else
        echo "[`date`] Packages from APT already installed" | tee -a ${log}
    fi

    #######################
    ### Pacotes ###
    #######################

    # Colocando o flatpak no ubuntu
    case $distro in
        Ubuntu|Debian|Zorin)
            sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

            echo "[`date`] Added flathub repository" | tee -a ${log}

            sudo flatpak update
        ;;
        *)
            echo "[`date`] No Flatpak update" | tee -a ${log}
        ;;
    esac

    if [[ ! -f "${install_dir}/.flatpak-install.stamp"  ]]; then

        flatpaks_ok=1

        for pkg in $( cat packages-flatpak ); do 

            flatpak -y install $pkg

            if [[ $? -ne 0 ]]; then 
                flatpaks_ok=0
                echo "[`date`] ERROR: installing $pkg from flatpak" | tee -a ${log}
            fi

        done

        # pegando e instalando a ultima versao do openjdk
        if [[ $flatpaks_ok -eq 0 ]]; then
            echo "[`date`] Packages from Flatpak installed" | tee -a ${log}
            touch "${install_dir}/.flatpak-install.stamp"
        else 
            echo "[`date`] ERROR installing packagesfrom Flatpak! " | tee -a ${log}
        fi

    else
        echo "[`date`] Packages from Flatpak already installed" | tee -a ${log}
    fi



    #######################
    ### MySQL Workbench ###
    #######################

    cd "${install_dir}/DEBS"

    if [[ ! -f "${install_dir}/.workbench-installed.stamp" ]]; then

        case $distro in

            Debian)
            # O MySQL e o MSQL Workbench estão no sid mas não no bookworm 

            echo "\
deb http://ftp.br.debian.org/debian bookworm          main contrib non-free non-free-firmware 
deb http://ftp.br.debian.org/debian bookworm-updates  main contrib non-free non-free-firmware 
deb http://security.debian.org      bookworm-security  main contrib non-free

deb http://ftp.br.debian.org/debian bookworm-backports  main contrib non-free" | sudo tee /etc/apt/sources.list.d/bookworm.list

echo "deb [trusted=yes] http://bsi.cefet-rj.br/repo/~debian labredes main" | sudo tee /etc/apt/sources.list.d/labredes.list
                ;;
        
            Zorin)
                # O Zorin jah possui o MySQL mas nao o Workbench
                case $version in
                    17)
                        # O Zorin 17 eh baseado no Ubuntu 22.04
                        echo "Installing MySQL workbench for Zorin/$version ..."

                        workbench_deb="mysql-workbench-community_8.0.43-1ubuntu22.04_amd64.deb"

                        if [[ ! -f $workbench_deb ]]; then 
                            wget "https://cdn.mysql.com//Downloads/MySQLGUITools/$workbench_deb"
                        fi

                        sudo apt install -y ./mysql-workbench-community_8.0.43-1ubuntu22.04_amd64.deb
                        sudo apt install -y -f 
                        ;;
                    *)
                        echo "[`date`] ERROR couldn't install MySQL Workbench for ${distro} ${version}!" | tee -a ${log}
                        ;;
                esac
                ;;
            Ubuntu)
                case $version in
                    24.04)
                        echo "Installing MySQL workbench for $distro/$version ..."
                        workbench_deb="mysql-workbench-community_8.0.43-1ubuntu24.04_amd64.deb"

                        if [[ ! -f $workbench_deb ]]; then 
                            wget "https://cdn.mysql.com//Downloads/MySQLGUITools/${workbench_deb}"
                        fi

                        sudo apt install -y ./${workbench_deb}
                        sudo apt install -y -f
                        ;;
                    *)
                        echo "[`date`] ERROR couldn't install MySQL Workbench for ${distro} ${version}!" | tee -a ${log}
                        ;;
                esac
                ;;
        esac

        which mysql-workbench 2> /dev/null
        if [[ $? -eq 0 ]]; then                    
            echo "[`date`] Installation of MySQL Workbench for ${distro} ${version} finished" | tee -a ${log}
            touch "${install_dir}/.workbench-installed.stamp"
        else 
            echo "[`date`] ERROR installing MySQL Workbench for ${distro} ${version}! " | tee -a ${log}
        fi
    else
        echo "[`date`] MySQL Workbench already installed" | tee -a ${log}
    fi

    #####################
    ### Google Chrome ###
    #####################

    cd "${install_dir}/DEBS"

    if [[ ! -f "${install_dir}/.google-chrome.stamp" ]]; then 

        GOOGLE_CHROME_DEB=google-chrome-stable_current_amd64.deb

        if [[ ! -f ${GOOGLE_CHROME_DEB} ]]; then

            wget https://dl.google.com/linux/direct/${GOOGLE_CHROME_DEB}
            sudo apt install -y ./google-chrome-stable_current_amd64.deb
            sudo apt install -y -f

            if [[ $? -eq 0 ]]; then
                echo "[`date`] Installation of Google Chrome finished" | tee -a ${log}
                touch "${install_dir}/.google-chrome.stamp"
            else 
                echo "[`date`] ERROR installing Google Chrome for ${distro}/${version}! " | tee -a ${log}
            fi

        fi    

    else    
        echo "[`date`] Google Chrome already installed " | tee -a ${log}
    fi

    #####################
    ### Packet Tracer ###
    #####################

    # Tive que baixar o pacote da NetAcad e depois por no meu OneDrive ... 
    # Não tem jeito: tem que pegar do nosso repositório mesmo

    cd "${install_dir}/DEBS"

    if [[ ! -f "${install_dir}/.packet-tracer-installed.stamp" ]]; then

        wget "http://bsi.cefet-rj.br/repo/~debian/debs/packettracer.deb" \
            -O packettracer.deb

        sudo apt install -y ./packettracer.deb

        if [[ $? -eq 0 ]]; then
            echo "[`date`] Installation of Packet Tracer finished" | tee -a ${log}
            touch "${install_dir}/.packet-tracer-installed.stamp"
        else 
            echo "[`date`] ERROR installing Packet Tracer for ${distro}/${version}! " | tee -a ${log}
        fi
    else
        echo "[`date`] Packet Tracer already installed"
    fi

    return 0;

    #################
    ### Wireshark ###
    #################

    if [[ "$distro" == "debian" ]]; then 

        # No Debian 12 sid ele está com a instalação quebrada, portanto pegando a versão do repositório bookworm
        # Se isso mudar ou parar de funcionar, logo abaixo está como compilar o programa na unha

        sudo apt install -t bookworm -y wireshark

    fi

    #sudo apt install -y libpcap-dev libglib2.0-dev flex asciidoctor qt6-base-dev cmake libgcrypt20-dev libc-ares-dev qt6-tools-dev libqt6core5compat6-dev libspeexdsp-dev

    #cd "${install_dir}"

    #wget https://2.na.dl.wireshark.org/src/wireshark-4.2.3.tar.xz

    #tar xaf wireshark-4.2.3.tar.xz

    #cd wireshark-4.2.3
    #wireshark_src_dir="`pwd`"

    #mkdir build
    #cd build
    #cmake "${wireshark_src_dir}"
    #make all
    #make install


    cd "${install_dir}"

    return 0;
}

function labredes_install_apps_privrepo(){

    install_dir="`pwd`"
    error_log="${install_dir}"/errors.log

    if [[ ! -f packages ]]; then

        echo "Error: packages file not found - aborting"
        return 1;

    fi

    echo "deb [trusted=yes] http://bsi.cefet-rj.br/repo/~debian labredes main" | sudo tee /etc/apt/sources.list

echo "\
deb http://ftp.br.debian.org/debian bookworm          main contrib non-free non-free-firmware 
deb http://ftp.br.debian.org/debian bookworm-updates  main contrib non-free non-free-firmware 
deb http://security.debian.org      bookworm-security  main contrib non-free
deb http://ftp.br.debian.org/debian bookworm-backports  main contrib non-free" | sudo tee /etc/apt/sources.list.d/debian.list

    sudo apt update
    sudo apt full-upgrade -y

    cd "${install_dir}"

    echo "Starting packages installation on ${install_dir} ..."

    ok_pkgs=`mktemp`
    # Pacotes inexistentes serão salvos no arquivo ${error_pkgs}
    error_pkgs=missingpackages-`date +"%Y-%m-%d_%H-%M"`.txt
    
    for pkg in $(cat "$packages"); do
        echo -n "Checando $pkg ...";
        apt-get install -q -s -y $pkg > /dev/null
        if [[ $? -eq 0 ]]; then 
            echo "ok";
            echo "$pkg" >> $ok_pkgs ;

        else 
            echo "ERROR";
            echo "Package installation error: $pkg" >> "${error_log}" ;
        fi
        
    done

    sudo apt install linux-headers-`uname -r` -y
    sudo apt-get install -y `cat $ok_pkgs`

    ###############
    ### PyCharm ###
    ###############    

    PYCHARM_VERSION="pycharm-community-2023.3.3"
    PYCHARM_TGZ="${PYCHARM_VERSION}.tar.gz"

    cd "${install_dir}/DEBS"
        
    wget "http://bsi.cefet-rj.br/repo/~jetbrains/${PYCHARM_TGZ}"        

    tar xaf "${PYCHARM_TGZ}"

    chown -R aluno:aluno ${PYCHARM_VERSION}
    chmod a+x ${PYCHARM_VERSION}/bin/pycharm.sh

    mv ${PYCHARM_VERSION} /home/aluno/.local/.

    if [[ ! -d /home/aluno/.local ]]; then 
        
        mkdir /home/aluno/.local
        sudo chown aluno:aluno /home/aluno/.local
        
    fi

    echo "export PATH=\"/home/aluno/.local/${PYCHARM_VERSION}/bin:\${PATH}\"" | sudo tee -a /home/aluno/.profile

    cd /home/aluno/Desktop

    ln -s /home/aluno/.local/${PYCHARM_VERSION}/bin/pycharm.sh

    #####################
    ### Packet Tracer ###
    #####################    

    sudo apt install -y packettracer

    #################
    ### WireShark ###
    #################    

    sudo apt install -y wireshark

    #####################
    ### Google Chrome ###
    #####################    

    apt install -y google-chrome-stable

    cd "${install_dir}"

    return 0;

}

function labredes_customizacao(){

    if [[ ! -d scripts ]]; then 
        echo "Scripts folder not found - aborting"

        return 1;
    fi

    install_dir="`pwd`"

    log="${install_dir}/installation.log"

    distro="$1"
    version="$2"

    distro="`lsb_release -i | tail -1 | cut -f2 -d':' | xargs`"
    release="`lsb_release -r | tail -1 | cut -f2 -d':' | xargs`"
    codename="`lsb_release -c | tail -1 | cut -f2 -d':' | xargs`"  

    echo "[`date`] Customizing for $distro $release ( $codename )" | tee -a ${log}

    ### Adicionando usuario 'aluno' ###
    id aluno > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Adicionando 'aluno' com senha 'cefet' ..."
    
        echo "cefet" > senha.txt
        echo "cefet" >> senha.txt

        sudo adduser --gecos=",,," aluno < senha.txt
        rm senha.txt

        ### Customizacao: colocando 'aluno' no grupo 'dialup' para usar o Arduino ###
        # Grupos complementares: plugdev (pendive), cdrom, lpadmin (impressoras)
        sudo usermod -aG dialout,plugdev,cdrom,users,lpadmin aluno     

        echo "[`date`] User 'aluno' configured" | tee -a ${log}
    else
        echo "[`date`] User 'aluno' already configured" | tee -a ${log}
    fi

    ### Customizacao: Senha de root do MySQL ###

    if [[ ! -f ${install_dir}/.mysql-password.stamp ]]; then 

        root_passwd=root # mudar a senha do root aqui se quiser
        echo "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${root_passwd}'" | sudo mysql    

        touch ${install_dir}/.mysql-password.stamp
        echo "[`date`] MySQL password configured" | tee -a ${log}
    else
        echo "[`date`] MySQL password already configured" | tee -a ${log}
    fi    

    ### Customizacao: autologin ###

    if [[ ! -f ${install_dir}/.autologin.stamp ]]; then 
        case $distro in
            Debian)
                # Supondo utilizacao do ambiente LXDE
                cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf-`date +"%Y-%m-%d_%H-%M"`.backup

                sed 's/#autologin-user=/autologin-user=aluno/g' /etc/lightdm/lightdm.conf | sudo tee /tmp/lightdm.conf
                sudo mv /tmp/lightdm.conf /etc/lightdm/lightdm.conf

                sed 's/#autologin-user-timeout=0/autologin-user-timeout=0/g' /etc/lightdm/lightdm.conf | sudo tee /tmp/lightdm.conf
                sudo mv /tmp/lightdm.conf /etc/lightdm/lightdm.conf

                touch ${install_dir}/.autologin.stamp
                echo "[`date`] Autologin for Debian configured" | tee -a ${log}
                ;;
            Zorin)
                # Zorin 17 utiliza o Gnome 3 (gdm)
                cp /etc/gdm3/custom.conf /etc/gdm3/custom.conf-`date +"%Y-%m-%d_%H-%M"`.backup

                sed 's/#.*AutomaticLoginEnable.*/   AutomaticLoginEnable = true/' /etc/gdm3/custom.conf | sudo tee /tmp/custom.conf
                sudo mv /tmp/custom.conf /etc/gdm3/custom.conf

                sed 's/#.*AutomaticLogin[[:space:]]*=.*/   AutomaticLogin = aluno/' /etc/gdm3/custom.conf | sudo tee /tmp/custom.conf
                sudo mv /tmp/custom.conf /etc/gdm3/custom.conf       

                touch ${install_dir}/.autologin.stamp
                echo "[`date`] Autologin for Zorin configured" | tee -a ${log}

                ;;
            *)
                echo "[`date`] ERROR! Unsupported autologin distro!" | tee -a ${log}
                ;;
        esac;
    else
        echo "[`date`] Autologin already configured" | tee -a ${log}
    fi

    if [[ ! -f ${install_dir}/.1st-reboot.stamp ]]; then

        touch ${install_dir}/.1st-reboot.stamp

        sudo cp -r ${install_dir}/ /opt/ConfiguracaoMaquinasLab/
        sudo chown aluno:aluno -R /opt/ConfiguracaoMaquinasLab/
        sudo chmod a=rwx -R /opt/ConfiguracaoMaquinasLab/

        echo "Restarting machine in 10 seconds ... continue the procedure from login 'aluno' and folder '/opt/ConfiguracaoMaquinasLab/' "
        sleep 10
        sudo reboot
    fi

    ### Customizacao: Atalhos para aplicativos na Área de Trabalho e não podem apagar ou salvar coisas nela ###

    # A partir desta parte, deve-se utilizar o script do proprio login de aluno

    if [[ ! -f ${install_dir}/.shortcuts.stamp ]]; then

        if [[ "$USER" != "aluno" ]]; then
            echo "Not logged as 'aluno', run the script again with that login to continue"
            return -1;
        fi

        if [[ ! -d /home/aluno/Desktop ]]; then 

            sudo mkdir /home/aluno/Desktop
            sudo chown aluno:aluno /home/aluno/Desktop

        fi
        
        cp /usr/share/applications/arduino.desktop /home/$USER/Desktop/.
        cp /usr/share/applications/group.chon.ide.desktop /home/$USER/Desktop/.
        cp /usr/share/applications/group.chon.simulide.desktop /home/$USER/Desktop/.        
        cp /usr/share/applications/lxterminal.desktop /home/$USER/Desktop/.
        cp /usr/share/applications/firefox-esr.desktop /home/$USER/Desktop/.
        cp /usr/share/applications/code.desktop /home/$USER/Desktop/.
        cp /usr/share/applications/codeblocks.desktop /home/$USER/Desktop/.
        cp /usr/share/applications/org.fritzing.Fritzing.desktop /home/$USER/Desktop/.
        cp /usr/share/applications/logisim.desktop /home/$USER/Desktop/.
        cp /usr/share/applications/mysql-workbench.desktop /home/$USER/Desktop/.
        cp /usr/share/applications/google-chrome.desktop /home/$USER/Desktop/.
        cp /usr/share/applications/webots.desktop /home/$USER/Desktop/.        
        cp /usr/share/applications/cisco-pt821.desktop /home/$USER/Desktop/.
        cp /usr/share/applications/org.wireshark.Wireshark.desktop /home/$USER/Desktop/.

        for fpak in $( ls /var/lib/flatpak/exports/share/applications/*.desktop ); do
            cp $fpak /home/$USER/Desktop/.
        done
        
        #cp /var/lib/flatpak/exports/share/applications/com.jetbrains.PyCharm-Community.desktop /home/$USER/Desktop/.
        #cp /var/lib/flatpak/exports/share/applications/com.jetbrains.IntelliJ-IDEA-Community.desktop /home/$USER/Desktop/.

        # compilados e dpkgs ficam no /usr/local/share/applications
        cp /usr/local/share/applications/org.wireshark.Wireshark.desktop /home/$USER/Desktop/.

        for shortcut in $( find /home/aluno/Desktop/ -name \*.desktop ); do        

            gio set $shortcut metadata::trusted true

            chmod a=rx $shortcut
        done

        ln -s /var/www /home/aluno/Desktop/www

        touch ${install_dir}/.shortcuts.stamp
        echo "[`date`] Shortcuts configured" | tee -a ${log}

    else
        echo "[`date`] Shortcuts already configured" | tee -a ${log}
    fi     

    ### Customizacao: alunos nao podem mudar o papel de parede ###

    if [[ ! -f ${install_dir}/.wallpaper1.stamp ]]; then 

        cd /home/aluno/.local/share

        [[ ! -d backgrounds ]] && mkdir backgrounds

        cd backgrounds

        cp ${install_dir}/wallpapers/uned_friburgo01.jpg labredes_wallpaper.jpg

        wallpaper_path="`pwd`/labredes_wallpaper.jpg"

        case $distro in
            Debian)
                # supondo ambiente grafico LXDE
                cd /home/aluno/.config/pcmanfm/LXDE

                cp desktop-items-0.conf desktop-items-0.conf-`date +"%Y-%m-%d_%H-%M"`.backup

                sed "s|^wallpaper=.*|wallpaper=${wallpaper_path}|g" desktop-items-0.conf > novo_desktop.conf

                mv novo_desktop.conf desktop-items-0.conf
                ;;

            Zorin)
                # Zorin 17 usa o Gnome

                cd /home/aluno/.local/share

                [[ ! -d backgrounds ]] && mkdir backgrounds

                cd backgrounds

                cp ${install_dir}/wallpapers/cyberpunk1.jpg labredes_wallpaper.jpg

                wallpaper_path="`pwd`/labredes_wallpaper.jpg"

                # Zorin 17 usa o Gnome
                gsettings set org.gnome.desktop.background picture-uri "file://${wallpaper_path}"
                ;;

            *) 
                echo "[`date`] ERROR! Distribution not supported!" | tee -a ${log}
        esac

        touch ${install_dir}/.wallpaper1.stamp
        echo "[`date`] Wallpaper configured" | tee -a ${log}
    else
        echo "[`date`] Wallpaper already configured" | tee -a ${log}
    fi     


    if [[ "$USER" != "labredes" ]]; then
        echo "Not logged as 'labredes', run the script again with that login to continue"
        return -1;
    fi

    # copiando tudo pro root tambem para facilitar nossa vida

    if [[ ! -f ${install_dir}/.permissions-aluno.stamp ]]; then

        sudo cp /home/aluno/Desktop/* /root/Desktop/.
        sudo cp /home/aluno/Desktop/* /home/labredes/Desktop/.

        # Customizacao: alunos nao podem alterar a pasta Desktop

        sudo chown root:root /home/aluno/Desktop
        sudo chmod a=rx /home/aluno/Desktop
        
        # Customizacao : ao fazer login, remove qualquer configuração global do git no usuario 'aluno'
        echo "rm -f ~/.git-credentials" | sudo tee -a /home/aluno/.profile
        echo "rm -f ~/.gitconfig" | sudo tee -a /home/aluno/.profile

        # Customizacao: alunos nao podem alterar .profile e .bashrc

        sudo chown root:root /home/aluno/.profile
        sudo chown root:root /home/aluno/.bashrc
        sudo chown root:root /home/aluno/.bash_logout

        sudo chmod a=r /home/aluno/.profile
        sudo chmod a=r /home/aluno/.bashrc
        sudo chmod a=r /home/aluno/.bash_logout

        # Customizacao: todos podem escrever e alterar a pasta do servidor web

        sudo chown root:root /var/www/
        sudo chmod a=rwx -R /var/www/

        # Customizacao: alunos 
        sudo touch /etc/dconf/db/local.d/00-wallpaper

        touch ${install_dir}/.permissions-aluno.stamp
        echo "[`date`] Permissions for 'aluno' configured" | tee -a ${log}
    else
        echo "[`date`] Permissions for 'aluno' already configured" | tee -a ${log}
    fi     


    if [[ ! -f ${install_dir}/.wallpaper2.stamp ]]; then
        # A parte 2 envolve usar sudo
        
        case $distro in
            Debian)
                # supondo ambiente grafico LXDE
                base="/home/aluno/.config/pcmanfm"

                sudo chown root:root "${base}/LXDE"
                sudo chmod a=rx "${base}/LXDE"

                sudo chown root:root "${base}/LXDE/desktop-items-0.conf"
                sudo chmod a=r "${base}/LXDE/desktop-items-0.conf"
                sudo chattr +i "${base}/LXDE/desktop-items-0.conf"

                sudo cp /etc/xdg/pcmanfm/default/pcmanfm.conf "${base}/LXDE/pcmanfm.conf"
                sudo chown root:root "${base}/LXDE/pcmanfm.conf"
                sudo chmod a=r "${base}/LXDE/pcmanfm.conf"
                sudo chattr +i "${base}/LXDE/pcmanfm.conf"
                ;;
            Zorin)
                # Zorin 17 usa o Gnome
                wallpaper_path="/home/aluno/.local/share/backgrounds/labredes_wallpaper.jpg"

                sudo chown root:root /home/aluno/.local/share/backgrounds                

                sudo chattr +i /home/aluno/.config/dconf/user

                sudo chattr +i /home/aluno/.local/share/backgrounds

                sudo chmod a=rx /home/aluno/.local/share/backgrounds
                ;;

            *) 
                echo "[`date`] ERROR! Distribution not supported!" | tee -a ${log}
        esac        

        touch ${install_dir}/.wallpaper2.stamp
        echo "[`date`] Wallpaper configured" | tee -a ${log}
    else
        echo "[`date`] Wallpaper already configured" | tee -a ${log}
    fi 

    # Customizacao: adicionando algumas aplicacoes padrao ao sistema

    echo "application/pdf=org.kde.okular.desktop" | sudo tee -a /usr/share/applications/defaults.list

    # Customizacao: limpando os cookies do Chrome e Firefox ao dar login 
    cd "${install_dir}"

    # crontab -l | sudo tee /tmp/crontab.old

    # chmod +x "./scripts/clearcookies.sh"

    # echo "@reboot \"${install_dir}/scripts/clearcookies.sh\"" | sudo tee -a /tmp/crontab.old

    # crontab /tmp/crontab.old

    #echo "exit 0" | sudo tee -a /etc/rc.local

    # Finalizando instalacao: limpando pacotes desnecessarios e reconstruindo o sources.list
    sudo apt -y autoremove

    return 0;

}
