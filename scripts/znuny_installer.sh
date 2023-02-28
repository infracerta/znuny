#!/bin/bash

# Script de instalação do OTRS/Znuny para o Sistema Operacional Ubuntu
#
# Desenvolvido por Infracerta Consultoria
# Sempre recomendamos analisar o script antes de instala-lo!
# Homologado para ubuntu 20.04 - usar um SO diferente pode trazer resultados inesperados.
#
#Variaveis
# Coloque a versão do OTRS que deseja instalar na variavel abaixo
export ZNUNY_VERSION="6.0.48"
export ZNUNY_INSTALL_DIR="/opt/"
export REQ_PACKAGES="libapache2-mod-perl2 libdbd-mysql-perl libtimedate-perl libnet-dns-perl libnet-ldap-perl libio-socket-ssl-perl libpdf-api2-perl libdbd-mysql-perl libsoap-lite-perl libgd-text-perl libtext-csv-xs-perl libjson-xs-perl libgd-graph-perl libapache-dbi-perl libdigest-md5-perl apache2 libapache2-mod-perl2 mariadb-client mariadb-server libarchive-zip-perl libxml-libxml-perl libtemplate-perl libyaml-libyaml-perl libdatetime-perl libmail-imapclient-perl libmoo-perl"
export MYSQL_CONF_DIR="/etc/mysql/mariadb.conf.d"

function MainMenu()
{
        clear
        echo "########################################################"
        echo "# Bem-vindo ao Instalador do OTRS/Znuny                #"
        echo "#  -------------------------------------------------   #"
        echo "########################################################"

        echo "########################################################"
        echo "# Opções disponíveis:                                  #"
        echo "#  -------------------------------------------------   #"
        echo "# 1 - Verificar requisitos de instalacao(Recomendavel) #"
        echo "# 2 - Instalar pacotes necesários para o OTRS/Znuny    #"
        echo "# 3 - Iniciar a instalacao do OTRS/Znuny               #"
        echo "# 4 - Sair do Instalador                               #"
        echo "########################################################"
        echo ""
        echo -n "Digite uma opção: "
        read OPTION

        CallCase
}

# Instalação dos pacotes necessários para o OTRS/Znuny
function InstallREQPKG()
{
        echo -n "Iniciando a instalacao as dependencias..........."
        apt-get -qq update && apt-get -y -qq install ${REQ_PACKAGES}
        if [ $? != 0 ]; then
                echo "Ocorreu um erro, execute "bash -x nomedoscript" para mais informacoes...";exit
        else
                clear
                echo "Iniciando a instalacao as dependencias...........OK"
        fi
        echo -n "Pressione q para sair do script ou qualquer outra tecla para voltar ao menu inicial..."
        read KEY
        if [ ${KEY} = "q"]; then
                exit
        else
                MainMenu
        fi
}

# Essa etapa faz uma verificação básica no sistema
function BasicCheck()
{
        echo "Executando verificacoes basicas do sistema"
        #Resolucao DNS
        nslookup znuny.org | grep "Non-authoritative answer:" 1> /dev/null
        if [ $? = 1 ];then
                echo "ERRO: Impossivel resolver znuny.org, favor verificar suas configuracoes de DNS..."
                exit
        else
                echo "Resolucao DNS.........................OK"
        fi
        #Verifica se o usuario atual e o root
        id |grep "uid=0" 1> /dev/null
        if [ $? = 1 ] ;then
                echo "ERRO: E necessario fazer login como root para iniciar a instalacao.";exit
        else
                echo "Usuario root..........................OK"
        fi

        echo -n "Pressione uma tecla pra continuar..."
        read KEY

        MainMenu
}

# Instalação e configuração do pacote OTRS/Znuny
function InstallZnuny
{

        #Fazendo o download do pacote do OTRS/Znuny:
        echo -n "Baixar arquivo do OTRS/Znuny..............."
        cd ${ZNUNY_INSTALL_DIR}
        if [[ ! -f otrs-${ZNUNY_VERSION}.tar.gz ]]; then
                wget https://download.znuny.org/releases/znuny\-${ZNUNY_VERSION}.tar.gz 1> /dev/null
        fi
        if [ $? != 0 ]; then
                clear
                echo "Ocorreu um erro ao baixar o pacote do OTRS/Znuny,  execute "bash -x nomedoscript" para mais informacoes...;exit"
        else
                echo "OK"
        fi

        # Descompactando o arquivo
        echo -n "Descompactando o arquivo..................."
        cd ${ZNUNY_INSTALL_DIR}
        tar -zxvf znuny\-${ZNUNY_VERSION}\.tar\.gz 1> /dev/null
        if [ $? = 0 ]; then
                echo "OK"
        else
                clear
                echo "Ocorreu um erro ao descompactar, verifique o arquivo e tente novamente.";exit
        fi

        # Renomeando o diretorio OTRS/Znuny
        echo -n "Renomeando o diretorio do OTRS/Znuny......."
        mv znuny-${ZNUNY_VERSION} otrs 1> /dev/null
        if [ $? = 0 ]; then
                echo "OK"
        else
                clear
                echo "Erro ao renomear o diretorio , verifique se o diretorio existe ou ja foi renomeado. ";exit
        fi

        #Criando links simbolicos e movendo os arquivos
        echo -n "Criando links simbolicos..................."
        ln -s ${ZNUNY_INSTALL_DIR}otrs/scripts/apache2-httpd.include.conf /etc/apache2/conf-enabled/ 1> /dev/null
        if [ $? = 0 ]; then
                echo "OK"
        else
                echo "Erro ao criar link simbólico, verifique se o arquivo existe...";exit
        fi

        echo -n "Movendo arquivos necessários..............."
        mv ${ZNUNY_INSTALL_DIR}otrs/Kernel/Config.pm.dist ${ZNUNY_INSTALL_DIR}/otrs/Kernel/Config.pm 1> /dev/null
        if [ $? = 0 ]; then
                echo "OK"
        else
                echo "Erro ao mover os arquivos, verifique se ja nao foram foram movidos ou se eles existem";exit
        fi

        #Adicionando o user OTRS e setando as permissoes necessarias
        echo -n "Configurando usuarios e  permissoes........"
        useradd -d ${ZNUNY_INSTALL_DIR}otrs/ -s /bin/bash -c 'OTRS user' otrs 1> /dev/null
        usermod -G www-data otrs 1> /dev/null
        ${ZNUNY_INSTALL_DIR}otrs/bin/otrs.SetPermissions.pl --otrs-user otrs --web-group www-data ${ZNUNY_INSTALL_DIR}otrs 1> /dev/null
        if [ $? = 0 ]; then
                echo "OK"
        else
                echo "Ocorreu durante essa etapa, verifique o log acima";exit
        fi

        #Configurando a cron
        echo -n "Configurando e iniciando a crontab........."
        cd ${ZNUNY_INSTALL_DIR}otrs/var/cron/ && for foo in *.dist; do cp $foo `basename $foo .dist`; done
        chown otrs:www-data /opt/otrs/var/cron/otrs_daemon
        if [ $? = 0 ]; then
                echo "OK"
        else
                echo "Ocorreu durante essa etapa, verifique o log acima";exit
        fi

        # Ativando o modo headers e
        echo -n "Ativando modulos e reiniciando o apache...."
        a2enmod headers 1> /dev/null
        a2dismod mpm_event 1> /dev/null
        a2enmod mpm_prefork 1> /dev/null
        systemctl restart apache2 1> /dev/null
        if [ $? = 0 ]; then
                echo "OK"
        else
                echo "Erro ao reiniciar o apache.";exit
        fi

        # Ajustando parametros necessarios do MySQL:
        echo -n "Alterando parametros do MariaDB.............."
                sed -i "s/.*max_allowed_packet.*/#max_allowed_packet = 128M/" ${MYSQL_CONF_DIR}/50-server.cnf
                echo "[mysqld]" > ${MYSQL_CONF_DIR}/70-znuny.cnf
                echo "character-set-server = utf8" >> ${MYSQL_CONF_DIR}/70-znuny.cnf
                echo "collation-server= utf8_general_ci" >> ${MYSQL_CONF_DIR}/70-znuny.cnf
                echo "innodb_log_file_size = 512M" >> ${MYSQL_CONF_DIR}/70-znuny.cnf
                echo "max_allowed_packet = 128M" >> ${MYSQL_CONF_DIR}/70-znuny.cnf
        if [ $? = 0 ]; then
                echo "OK"
        else
                echo "Erro ao configurar o Mysql.";exit
        fi
        
        echo -n "Reiniciando o MariaDB........................"
        systemctl restart mariadb 1> /dev/null
        if [ $? = 0 ]; then
                echo "OK"
        else
                echo "Erro ao reiniciar o MySQL.";exit
        fi

        echo -n "Adicionando senha ao MariaDB........................"
        export MARIADB_PASS=$(tr -dc 'A-Za-z0-9!"#$%&*+@' </dev/urandom | head -c 18 ; echo)
        mysql -u root -e 'ALTER USER 'root'@'localhost' IDENTIFIED BY "'${MARIADB_PASS}'";'
        if [ $? = 0 ]; then
                echo "OK"
        else
                echo "Erro ao alterar a senha do MariaDB.";exit
        fi

        echo ""
        echo "OTRS/Znuny instalado com sucesso! Acesse o endereço http://$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')/otrs/installer.pl para finalizar a configuração do sistema."
        echo "Durante a configuração será solicitada a senha do banco de dados. Utilize o usuário root com a seguinte senha: ${MARIADB_PASS}"
}

function CallCase()
{
        case "$OPTION" in
    1) BasicCheck
                ;;
                2) InstallREQPKG
                ;;
                3) InstallZnuny
                ;;
                4) exit
                ;;
                *) MainMenu
        esac
}
MainMenu
