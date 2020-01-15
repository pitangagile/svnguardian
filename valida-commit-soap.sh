#!/bin/bash
#REVISION HISTORY - insert-log-mantis
#-----------------------------------------------------------------------
#DATA         AUTOR                 COMENTARIOS
#-----------------------------------------------------------------------
#07/10/2019   Joao Carlos B. Sousa  Simplificando para expressao regular apenas  
#
#DD/MM/YYYY   <Author>              <comentario>
#------------------------------------------------------------------------
#####################################################################

REPOS=""
TXN=""
mantis_properties=""
NA=""
configfile_na=""
#padrao usado para informar os logins dos cms e permitir que estes possam fazer qq tipo de operacao no diretorio tags.So descomentar se extremamente necessario
while getopts ":r:t:b:n:p:s:m:h" Option
do
  case $Option in
    r ) REPOS=$OPTARG;;
    t ) TXN=$OPTARG;;
    b ) mantis_properties=$OPTARG;;
    n ) NA="PERMITIDO";;
    * ) echo "Unimplemented option chosen.";;
  esac
done
shift $(($OPTIND - 1))

##########################################################################################################
##########################################################################################################
# list crs ids from log message.
function id_crs_list() {
##########################################################################################################
LOGMSG=$1
echo $LOGMSG | grep -Eo  "^(\[CR[0-9]+\])+" |  sed "s/\]\[CR/,/g" | sed "s/\[CR//g" | sed "s/\]//g"
}
##########################################################################################################

##########################################################################################################
##########################################################################################################
# retorna true se issue existir
function issue_exists() {
IDCR=$1 
source ${mantis_properties}

arqexists_temp=/tmp/_temp_rule$$
cp ${template_exists_issue} ${arqexists_temp}
sed -i -e "s/#mantis_user/${mantis_user}/g" -e "s/#mantis_pass/${mantis_pass}/g" -e "s/#id_cr/${id_cr}/g" ${arqexists_temp}

resposta=$(curl -s --header "Content-Type: text/xml;charset=UTF-8" --header "SOAPAction: ${mantis_url}/${mantis_connect}/mc_issue_exists" --data @${arqexists_temp} ${mantis_url}:/${mantis_connect} --write-out '\nResult Code:%{http_code}')

rm -f $arqexists_temp

echo $resposta | sed -E 's/(.*<return xsi:type="xsd:boolean">)(.*)(<\/return>.*)/\2/g'
}
##########################################################################################################

#nao necesssario mais
    LOGMSG=`svnlook log -t "$TXN" "$REPOS"`	

    if [ "$NA" = "PERMITIDO" ]
    then
        LOGMSG_E=`echo $LOGMSG | grep -E "(?\[CR[0-9]+\]|\[NA\]*):.[a-zA-Z0-9]+"`
    else
        LOGMSG_E=`echo $LOGMSG | grep -E "?\[CR[0-9]+\]:.[a-zA-Z0-9]+"`
    fi

    if [ "$LOGMSG_E" = "" ]; then
        echo -e "--------------------------------------------------------- " 1>&2
        echo -e "[ERRO] COMMIT NAO PERMITIDO" 1>&2;
        echo -e "[MOTIVO] PROBLEMAS NO PADRAO DA MENSAGEM DO COMMIT" 1>&2
        echo -e "[SOLUCAO] PARA UM COMMIT VALIDO, FAVOR SEGUIR ESSE PADRAO:" 1>&2
        echo -e "[SOLUCAO] [CRXXX]: <Comentario>" 1>&2
        echo -e "[SOLUCAO] Ex.: [CR12345]: Troca na chamada ao webservice principal." 1>&2
        echo -e "--------------------------------------------------------- " 1>&2;
        exit 1
        break
    else
        source ${mantis_properties}
        id_crs=$( id_crs_list "$LOGMSG" )

        echo $id_crs | sed -n 1'p' | tr ',' '\n' | while read id_cr; do
            i_exists=$( issue_exists $id_cr) 
            if [ "$i_exists" != "true" ]; then  
                echo -e "--------------------------------------------------------- " 1>&2
                echo -e "[ERRO] COMMIT NAO PERMITIDO" 1>&2;
                echo -e "[MOTIVO] CR $id_cr NAO EXISTE NO MANTIS" 1>&2
                echo -e "[SOLUCAO] INFORMAR UM NUMERO DE CR QUE EXISTE NO MANTIS " 1>&2
                echo -e "--------------------------------------------------------- " 1>&2;
                exit 1
                break
            fi
        done
    fi ##Se tiver fora do padrao


