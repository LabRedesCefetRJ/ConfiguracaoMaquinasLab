#!/bin/bash

# Executar o script na pasta em que se encontra e no login de root

# Debian nao tem sudo ... caso esteja se tentando fazer a instalacao no Ubuntu e derivados, comentar a linha abaixo
# O arquivo abaixo deverá conter a lista de pacotes do Debian a instalar. Devera estar na mesma pasta do setup.sh
packages="packages" 




function labredes_install_apps_Internet(){

    install_dir="`pwd`"
    log="${install_dir}"/installation.log

    > ${log}

    distro="$1"
    version="$2"

    case $distro in

        debian)
            echo "Distribution: Debian"
        ;;

        zorin)
            version="`lsb_release -r | grep "Release" | grep -o -E '[[:digit:]]+'`"
            echo "Distribution: Zorin"
            echo "Version: $version"
        ;;

        *)
            echo "Error: distribution not selected!"
            echo "Select between: debian, zorin"
            return -1
        ;;
    esac    

    if [[ ! -f packages ]]; then 

        echo "Error: file packages not found - aborting ";

        return 1;

    fi

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

        clear

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

    if [[ "$distro" == "debian" ]]; then 

        # O MySQL e o MSQL Workbench estão no sid mas não no bookworm 

        echo "\
deb http://ftp.br.debian.org/debian bookworm          main contrib non-free non-free-firmware 
deb http://ftp.br.debian.org/debian bookworm-updates  main contrib non-free non-free-firmware 
deb http://security.debian.org      bookworm-security  main contrib non-free

deb http://ftp.br.debian.org/debian bookworm-backports  main contrib non-free" | sudo tee /etc/apt/sources.list

        echo "deb [trusted=yes] http://bsi.cefet-rj.br/repo/~debian labredes main" | sudo tee /etc/apt/sources.list.d/labredes.list

    fi

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

    sudo apt update
    if [[ $? -ne 0 ]]; then
        echo "[`date`] ERROR during apt update!" | tee -a ${log}
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
                echo "Package not installed: $pkg" >> ${log} ;
            fi
        done

        sudo apt install linux-headers-`uname -r`
        sudo apt-get install -y `cat $ok_pkgs`

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
    ### MySQL Workbench ###
    #######################

    cd "${install_dir}/DEBS"

    if [[ ! -f "${install_dir}/.workbench-installed.stamp" ]]; then

        if [[ "$distro" == "debian" ]]; then 

            # O MySQL e o MSQL Workbench estão no sid mas não no bookworm 

            echo "\
deb http://ftp.br.debian.org/debian bookworm          main contrib non-free non-free-firmware 
deb http://ftp.br.debian.org/debian bookworm-updates  main contrib non-free non-free-firmware 
deb http://security.debian.org      bookworm-security  main contrib non-free

deb http://ftp.br.debian.org/debian bookworm-backports  main contrib non-free" | sudo tee /etc/apt/sources.list

echo "deb [trusted=yes] http://bsi.cefet-rj.br/repo/~debian labredes main" | sudo tee /etc/apt/sources.list.d/labredes.list

        fi

        # O Zorin jah possui o MySQL mas nao o Workbench
        if [[ "$distro" == "zorin" ]]; then 

            case $version in
                17)
                    echo "Installing MySQL workbench for Zorin/$version ..."

                    workbench_deb="mysql-workbench-community_8.0.43-1ubuntu22.04_amd64.deb"

                    if [[ ! -f $workbench_deb ]]; then 
                        wget "https://cdn.mysql.com//Downloads/MySQLGUITools/$workbench_deb"
                    fi

                    sudo apt install -y ./mysql-workbench-community_8.0.43-1ubuntu22.04_amd64.deb
                    sudo apt install -y -f 

                    if [[ $? -eq 0 ]]; then                    
                        echo "[`date`] Installation of MySQL Workbench for Zorin/${version} finished" | tee -a ${log}
                        touch "${install_dir}/.workbench-installed.stamp"
                    else 
                        echo "[`date`] ERROR installing MySQL Workbench for Zorin ${version}! " | tee -a ${log}
                    fi
                    ;;
                *)
                    echo "[`date`] ERROR couldn't install MySQL Workbench for ${distro} ${version}!" | tee -a ${log}
                    ;;
            esac;
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

    ###############
    ### PyCharm ###
    ###############

    if [[ ! -f "${install_dir}/.pycharm-installed.stamp" ]]; then
        
        if [[ "$distro" == "zorin" ]]; then

            # zorin has installation on flathub

            flatpak -y install PyCharm-Community

            if [[ $? -eq 0 ]]; then
                echo "[`date`] Installation of PyCharm finished" | tee -a ${log}
                touch "${install_dir}/.pycharm-installed.stamp"
            else 
                echo "[`date`] ERROR installing PyCharm for ${distro}/${version}! " | tee -a ${log}
            fi           

        else 
            # legacy installation

            cd "${install_dir}/DEBS"

            PYCHARM_VERSION="pycharm-community-2025.2.0.1"
            PYCHARM_TGZ="${PYCHARM_VERSION}.tar.gz"

            if [[ ! -f "${PYCHARM_TGZ}" ]]; then
                wget "https://download.jetbrains.com/python/${PYCHARM_TGZ}"
            fi

            if [[ -f "${PYCHARM_TGZ}" ]]; then

                sudo tar xzf pycharm-*.tar.gz -C /opt/

                cd /opt/pycharm-*/bin

                sh pycharm.sh

                if [[ $? -eq 0 ]]; then
                    echo "[`date`] Installation of PyCharm finished" | tee -a ${log}
                    touch "${install_dir}/.pycharm-installed.stamp"
                else 
                    echo "[`date`] ERROR installing PyCharm for ${distro}/${version}! " | tee -a ${log}
                fi         

            else
                echo "[`date`] ERROR! Couldn't download PyCharm!" | tee -a ${log}             
            fi

            if [[ 1 -eq 0 ]]; then 
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
            fi
        fi

    else 

        echo "[`date`] PyCharm already installed" | tee -a ${log}

    fi

    ################
    ### Eclipse  ###
    ################

    if [[ ! -f "${install_dir}/.eclipse-installed.stamp" ]]; then
        
        if [[ "$distro" == "zorin" ]]; then

            # zorin has installation on flathub

            flatpak -y install org.eclipse.Java

            if [[ $? -eq 0 ]]; then
                echo "[`date`] Installation of Eclipse for Java finished" | tee -a ${log}
                touch "${install_dir}/.eclipse-installed.stamp"
            else 
                echo "[`date`] ERROR installing Eclipse for Java for ${distro}/${version}! " | tee -a ${log}
            fi
        fi
    else 
        echo "[`date`] Eclipse already installed" | tee -a ${log}
    fi

    return 0;

    #####################
    ### Packet Tracer ###
    #####################

    # Tive que baixar o pacote da NetAcad e depois por no meu OneDrive ... 
    # Não tem jeito: tem que pegar do nosso repositório mesmo

    cd "${install_dir}/DEBS"

    if [[ ! -f "${install_dir}/.packet-tracer-installed.stamp" ]]; then

        wget "http://bsi.cefet-rj.br/repo/~debian/debs/packet_tracer.deb" \
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

    distro="$1"
    version="$2"

    case $distro in

        debian)
            echo "Distribution: Debian"

        ;;

        zorin)
            echo "Distribution: Zorin"
        ;;

        *)
            echo "Error: distribution not selected!"
            echo "Select between: debian, zorin"
            return -1
        ;;
    esac

    return 0;

    install_dir="`pwd`"

    ### Adicionando usuario 'aluno' ###
    echo "cefet" > senha.txt

    adduser --gecos=",,,," aluno < senha.txt

    ### Customizacao: colocando 'aluno' no grupo 'dialup' para usar o Arduino ###

    sudo usermod -aG dialout aluno

    ### Customizacao: autologin ###
    cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf-`date +"%Y-%m-%d_%H-%M"`.backup

    sed 's/#autologin-user=/autologin-user=aluno/g' /etc/lightdm/lightdm.conf | sudo tee /tmp/lightdm.conf
    sudo mv /tmp/lightdm.conf /etc/lightdm/lightdm.conf

    sed 's/#autologin-user-timeout=0/autologin-user-timeout=0/g' /etc/lightdm/lightdm.conf | sudo tee /tmp/lightdm.conf
    sudo mv /tmp/lightdm.conf /etc/lightdm/lightdm.conf

    ### Customizacao: Senha de root do MySQL ###

    root_passwd=root # mudar a senha do root aqui se quiser

    echo "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${root_passwd}'" | sudo mysql

    ### Customizacao: Atalhos para aplicativos na Área de Trabalho e não podem apagar ou salvar coisas nela ###

    if [[ ! -d /home/aluno/Desktop ]]; then 

        sudo mkdir /home/aluno/Desktop
        sudo chown aluno:aluno /home/aluno/Desktop

    fi

    sudo cp /usr/share/applications/lxterminal.desktop /home/aluno/Desktop/.
    sudo cp /usr/share/applications/firefox-esr.desktop /home/aluno/Desktop/.
    sudo cp /usr/share/applications/code.desktop /home/aluno/Desktop/.
    sudo cp /usr/share/applications/codeblocks.desktop /home/aluno/Desktop/.
    sudo cp /usr/share/applications/mysql-workbench.desktop /home/aluno/Desktop/.
    sudo cp /usr/share/applications/google-chrome.desktop /home/aluno/Desktop/.
    sudo cp /usr/share/applications/arduino.desktop /home/aluno/Desktop/.
    sudo cp /usr/share/applications/group.chon.ide.desktop /home/aluno/Desktop/.
    sudo cp /usr/share/applications/group.chon.simulide.desktop /home/aluno/Desktop/.
    sudo cp /usr/share/applications/webots.desktop /home/aluno/Desktop/.
    sudo cp /usr/share/applications/logisim.desktop /home/aluno/Desktop/.
    sudo cp /usr/share/applications/cisco-pt821.desktop /home/aluno/Desktop/.
    sudo cp /usr/share/applications/org.wireshark.Wireshark.desktop /home/aluno/Desktop/.

    # compilados e dpkgs ficam no /usr/local/share/applications
    sudo cp /usr/local/share/applications/org.wireshark.Wireshark.desktop /home/aluno/Desktop/.

    cd /home/aluno/Desktop/

    ls *.desktop | xargs -I{} sudo chown root:root '{}'
    ls *.desktop | xargs -I{} sudo chmod 555 '{}'

    # copiando tudo pro root tambem para facilitar nossa vida
    sudo cp /home/aluno/Desktop/* /root/Desktop/.

    # Customizacao: alunos nao podem alterar a pasta Desktop

    sudo chown root:root /home/aluno/Desktop
    sudo chmod a=rx /home/aluno/Desktop

    # Customizacao: alunos nao podem alterar .profile e .bashrc

    sudo chown root:root /home/aluno/.profile
    sudo chown root:root /home/aluno/.bashrc

    sudo chmod a=r /home/aluno/.profile
    sudo chmod a=r /home/aluno/.bashrc

    # Customizacao: todos podem escrever e alterar a pasta do servidor web

    sudo chown root:root /var/www/html
    sudo chmod a=rwx /var/www/html

    # Customizacao: alunos nao podem mudar o papel de parede

    cd /home/aluno/.config/pcmanfm

    sudo chown root:root LXDE
    sudo chmod a=rx LXDE

    cd LXDE

    wget https://images3.alphacoders.com/221/221297.png \
        -O labredes_wallpaper.png

    wallpaper_path="`pwd`/labredes_wallpaper.png"

    cp desktop-items-0.conf desktop-items-0.conf-`date +"%Y-%m-%d_%H-%M"`.backup

    sed "s|^wallpaper=.*|wallpaper=${wallpaper_path}|g" desktop-items-0.conf > novo_desktop.conf

    mv novo_desktop.conf desktop-items-0.conf

    sudo chown root:root ./desktop-items-0.conf
    sudo chmod a=r ./desktop-items-0.conf

    sudo cp /etc/xdg/pcmanfm/default/pcmanfm.conf .
    sudo chown root:root pcmanfm.conf
    sudo chmod a=r pcmanfm.conf

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
