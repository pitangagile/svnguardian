-------- IMPLANTANDO GUARDIAN ------------------
1) copiar a pasta do guardian no servidor do SVN em <path_guardian>

2) Criei o arquivo de propriedades svnguardian-soap.properties a partir do svnguardian-soap.properties.template e ajuste os valores que estao entre '<' e '>'. As propriedade sao intuitivas ou tem alguma explicao. O arquivo svnguardian-soap.properties.exemplo contem exemplos com valores reais

3) "No arquivo hooks/post-commit do repositorio acrescentar a chamada:
REPOS="$1"
REV="$2"
<path_svnguardian>/insere-log-mantis-soap.sh $REPOS $REV "<path_svnguardian>/svnguardian-soap.properties" <id_projeto_mantis>

#<id_projeto_mantis> para o projeto do cenpes (PRODUCAO) eh o 276
#<id_projeto_mantis> para o projeto do cenpes (TESTES), eh o 368
#Ex.: de chamada
#/repos/svn/scm/svnguardian/producao/insere-log-mantis-soap.sh $REPOS $REV /repos/svn/scm/svnguardian/producao/svnguardian-soap.properties 276 


4) "No arquivo hooks/pre-commit do repositorio acrescentar a chamada:
REPOS="$1"
TXN="$2"
<path_svnguardian>/valida-commit-soap.sh -r $REPOS -t $TXN -b "<path_svnguardian>/svnguardian-soap.properties"

#Ex.: de chamada
#/repos/svn/scm/svnguardian/producao/valida-commit-soap.sh -r $REPOS -t $TXN -b /repos/svn/scm/svnguardian/producao/svnguardian-soap.properties


#### ATENCAO ######
Avaliar se eh preciso alterar o arquivo sudoers para que o script merge.sh (chamado pelo insert-log-mantis) possa ser executado pelo usuario do servidor (${svnserver_user}) que esta sendo usado para os checkouts.
Exemplo de ajuste no arquivo sudoers para o usuario scmprojeto:

Cmnd_Alias MERGEP = /repos/svn/scm/svnguardian/producao/merge.sh
ALL      ALL=(scmprojeto)       NOPASSWD: MERGEP

