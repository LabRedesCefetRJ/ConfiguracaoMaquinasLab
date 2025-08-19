# ConfiguracaoMaquinasLab

Script para configurar as máquinas do LabReDes. 

O script atual suporta o Debian 12 LXDE e o Zorin 17

São utilizados 3 procedimentos: 
   
* **labredes_install_apps_Internet**: Instala os pacotes listados no packages usando repositórios da internet 

* **labredes_install_apps_privrepo**: Instala a partir de repositório privado

Nota: funciona só com o Debian

* **labredes_customizacao**: aplica customizações das máquinas do lab.

Como dependência, é necessário instalar o git:

```
sudo apt install git
```

## Utilização

1. Clone o repositório pelo terminal e entre na pasta do projeto

```
git clone https://github.com/LabRedesCefetRJ/ConfiguracaoMaquinasLab.git
cd ConfiguracaoMaquinasLab
```

Coloque a lista de pacotes Debian no arquivo **packages**

Se desejar, crie também uma pasta chamada DEBS e coloque nela os pacotes .deb baixados da Internet, caso deseje. Não é obrigatório já que o script os baixa automaticamente.

2. Pelo terminal, carregue os procedimentos do script e inicie a instalação.

O script começa fazendo uma atualização do sistema e será reiniciado automaticamente.

```
. setup.sh
labredes_install_apps_Internet zorin
```

3. Após a atualização do sistema, execute novamente o passo anterior para instalar as aplicações.

```
. setup.sh
labredes_install_apps_Internet zorin
```

4. Após a instalação dos aplicativos, execute o procedimento de customização a partir de um login com ***sudo*** (geralmente ***professor***):

A máquina será reiniciada mais uma vez, porém será logado automaticamente no login de ***aluno***

```
. setup.sh
labredes_customizacao zorin
```

5. Continue a instalação a partir da pasta _/opt/ConfiguracaoMaquinasLab_ ( a pasta será criada automaticamente ):

O script irá parar uma última vez para solicitar login de usuário com permissão de sudo (_professor_ nesse tutorial)

```
cd /opt/ConfiguracoesMaquinasLab
. setup.sh
labredes_customizacao zorin
```

6. Logue-se com um login de sudo (_professor_ no tutorial) e execute o script uma última vez.

```
su professor
cd /opt/ConfiguracoesMaquinasLab
. setup.sh
labredes_customizacao zorin
```


