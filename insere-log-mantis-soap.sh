#!/bin/bash
#REVISION HISTORY - insert-log-mantis-soap
#-----------------------------------------------------------------------
#DATA         AUTOR                 COMENTARIOS
#-----------------------------------------------------------------------
#20/03/2008   Joao Carlos B. Sousa  Versao Final
#06/05/2009   Joao Carlos B. Sousa  Ajustes para controle do NA
#21/06/2016   Joao Carlos B. Sousa  Implementando AutoMerge
#02/10/2019   Joao Carlos B. Sousa  Implementar escrita no mantis via webservice-soap
#
#DD/MM/YYYY   <Author>              <comentario>
#------------------------------------------------------------------------
#####################################################################
# SVN GUARDIAN - Inserindo log com dados do commit na(s) CR(s) associada(s)
#####################################################################

lang_temp=`echo $LANG`
#export LANG=pt_BR

REPOS="$1";
REV="$2";
guardian_properties="$3";
source $guardian_properties
id_project_mantis="$4";

##########################################################################################################
##########################################################################################################
#identify source branch from revision
function source_branch_from_rep_revision() {
##########################################################################################################
t_repos=$1
t_rev=$2
t_merge_rules=$3

branch_t=branch_t$$

#what is the branch or if is the trunk
svnlook dirs-changed $t_repos -r $t_rev > $branch_t
t_merge_r=`echo $t_merge_rules | tr ',' '|'`

grep -Eo "("$t_merge_r")" $branch_t | head -1
rm -f $branch_t
}
##########################################################################################################

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
#branches list separated by commas to a source branch
function branches_list() {
##########################################################################################################
idProject=$1
source $guardian_properties

arqrule_temp=/tmp/_temp_rule$$
cp ${template_merge_rules} ${arqrule_temp}

sed -i -e "s/#mantis_user/${mantis_user}/g" -e "s/#mantis_pass/${mantis_pass}/g" -e "s/#id_project/${idProject}/g" ${arqrule_temp};

resposta=$(curl -s --header "Content-Type: text/xml;charset=UTF-8" --header "SOAPAction: ${mantis_url}/${mantis_connect}/mc_project_get_merge_rules_from_id_project" --data @${arqrule_temp} ${mantis_url}:/${mantis_connect} --write-out '\nResult Code:%{http_code}')

rm -f $arqrule_temp;

echo $resposta | sed -E 's/(.*<return xsi:type="xsd:string">)(.*)(<\/return>.*)/\2/g'

#por enqaunto esta direto no properties
#echo ${merge_rules}
}
##########################################################################################################

##########################################################################################################
##########################################################################################################
#checks whether merging should be executed
function exec_automerge() {
##########################################################################################################
idsCRs=$1

source $guardian_properties
#TODO implmentar webservice para retornar se executa ou nao merge
}
##########################################################################################################

##########################################################################################################
##########################################################################################################
#identify first target branch (from branches list separated by commas) to a source branch
function target_branch() {
##########################################################################################################
sourceBranch=$1
merge_rules=$2

echo "$merge_rules" | grep -E "$sourceBranch," | sed "s^.*"$sourceBranch",^^" | cut -f1 -d,
}
##########################################################################################################

##########################################################################################################
##########################################################################################################
#Montando titulo da mensagem
function mensagem_titulo() {
##########################################################################################################
REPOS=$1
REV=$2
LOGMSG=$3
arquivoscommit_p=$4

arquivoscommit=temp$$_arquivoscommit_te;

cat $arquivoscommit_p | cut -c5- > $arquivoscommit;

user_svn=`svnlook author ${REPOS} -r ${REV}`;

arquivos="";
diretorio_ant="";

#Primeira linha (serve qualquer uma, ja que sera descoberto o caminho que seja comum a todos os arquivos)
linha1=`head -n1 $arquivoscommit`

# Ultimo Subdiretorio
dir_final=`dirname "$linha1"`
dir_final=`basename "$dir_final"`

# Primeiro subdiretorio
dir_num=1
dir_temp=`echo "$linha1" | cut -f$dir_num -d'/'`
dir_base=""

if [ "${dir_final}" != "." ]
then

    while [ "${dir_temp}" != "${dir_final}" ]
    do
        achou=`grep -Ev "$dir_temp" $arquivoscommit`

        #Se achar alguem que nao case com 'dir_temp', o caminho nao eh comum a todos os arquivos. Deve sair.
        if [ "$achou" != "" ]
        then
            dir_temp="${dir_final}"
        else
            dir_base=$dir_base"/"$dir_temp
            let "dir_num+=1"
            dir_temp=`echo "$linha1" | cut -f$dir_num -d'/'`
        fi
    done
fi

rm -f $arquivoscommit;

if [ "${dir_base}" = "" ]
then
    dir_base_msg=""
else
    dir_base_msg="\nBase Dir: ${dir_base}"
fi

echo "[SVN COMMIT]:\nUser: ${user_svn}\nComments: '${LOGMSG}'\nRepository: ${REPOS}${dir_base_msg}"

return $dir_num
}
##########################################################################################################



##########################################################################################################
##########################################################################################################
function mensagem_dados() {
##########################################################################################################
REPOS=$1
REV=$2
dir_num=$3 #nivel do diretorio que eh comum a todos os caminhos de arquivos que estao listados no log do commit
arquivoscommit=$4

arquivos="";
diretorio_ant="";

while read linha_arquivo
do
    #so o tipo da atualizacao (U,D,A)
    tipo_atualiza=`echo $linha_arquivo | cut -c1`

    #recuperando so o nome do arquivo com caminho
    arquivo=`echo $linha_arquivo | cut -c3-`

    #so o nome do diretorio, a partir do diretorio que nao eh comum a todos os arquivos envolvidos. O comum ficara em dir_base
    diretorio=`dirname "$arquivo" | cut -f$dir_num- -d'/'`

    arquivo=`basename "$arquivo"`;

    if [ "$diretorio" != "$diretorio_ant" -a "$arquivo" != "" ]
    then
        arquivos="$arquivos\n&lt;$diretorio&gt;\n\t\t$tipo_atualiza  $arquivo";
    else
        arquivos="$arquivos\n\t\t$tipo_atualiza  $arquivo";
    fi
    diretorio_ant=$diretorio;

done < $arquivoscommit;

echo "\nRevision: ${REV}\nDirectories/Files:$arquivos";
}
##########################################################################################################

##########################################################################################################
##########################################################################################################
#insert mantis note
function insert_mantis_note() {
##########################################################################################################
mensagem=$1
id_crs=$2
source $guardian_properties

nota_insert_temp=/tmp/_temp_insert_nota$$
arqnota_insert_temp=/tmp/_temp_insert_arqnota$$

echo $id_crs | sed -n 1'p' | tr ',' '\n' | while read id_cr; do

	echo $mensagem > ${nota_insert_temp}

	cp ${template_insert_nota} ${arqnota_insert_temp}

	sed -i "s/#mantis_user/${mantis_user}/g" ${arqnota_insert_temp}
	sed -i "s/#mantis_pass/${mantis_pass}/g" ${arqnota_insert_temp}
	sed -i "s/#id_cr/${id_cr}/g" ${arqnota_insert_temp}
	sed -i -e "/#msg/r $nota_insert_temp" -e "s///" ${arqnota_insert_temp};
	sed -i -e 's/\\n/\&lt;br\&gt;/g' -e 's/\\t\\t//g' ${arqnota_insert_temp};

	resposta=$(curl -s --header "Content-Type: text/xml;charset=UTF-8" --header "SOAPAction: ${mantis_url}/${mantis_connect}/mc_issue_note_add" --data @${arqnota_insert_temp} ${mantis_url}:/${mantis_connect} --write-out '\nResult Code:%{http_code}')

	if [ "$debug" = "" ]; then rm -f $nota_insert_temp; rm -f $arqnota_insert_temp; fi
done
}

##########################################################################################################
##########################################################################################################
#insert guardian log to mantis from svn log message
function insert_log_svn_mantis() {
##########################################################################################################
REPOS=$1
REV=$2
LOGMSG=$3
arquivoscommit_t=temp$$_arquivoscommit;
arquivoscommit2_t=temp$$_arquivoscommit2;
svnlook changed $REPOS -r $REV > $arquivoscommit2_t;
#excluir os paths que indicam apenas alteracao de propriedade, ja que nao precisa incluir essa informacao no log do mantis
grep -v "^_" $arquivoscommit2_t > $arquivoscommit_t;
rm -f $arquivoscommit2_t;

mensagemTitulo=$( mensagem_titulo $REPOS $REV "$LOGMSG" $arquivoscommit_t)
dir_num=$?

mensagemDados=$( mensagem_dados $REPOS $REV "$dir_num" $arquivoscommit_t )

rm -f $arquivoscommit_t;

mensagem="${mensagemTitulo}${mensagemDados}";

### consulta das CRs do comentario
id_crs=$( id_crs_list "$LOGMSG" )

insert_mantis_note "$mensagem" "$id_crs"

#merge_rev_sourceBranch_targetBranch $rev $sourceBranch $des $LOGMSG

#echo "[OK]LOG has been written to the respectives MANTIS CRs."

# APAGANDO ARQUIVOS TEMPORARIO
rm -f $mysql_temp
##########################################################################################################
}


##########################################################################################################
##########################################################################################################
# filter message and change invalid character to databasemantis
function log_msg_filter() {
##########################################################################################################
REPOS=$1
REV=$2
#antes de dobrar as aspas, ver se tem alguma ja duplicada pra depois dobrar
LOGMSG_temp=`svnlook log ${REPOS} -r ${REV} | sed 's/""/"/g' | sed 's/"/""/g'`;
#problemas com acentuacao. Retirando-a
echo $LOGMSG_temp | sed -e 's/?\\\\195//g' -e 's/?\\\\129/A/g' -e 's/?\\\\137/E/g' -e 's/?\\\\141/I/g' -e 's/?\\\\147/O/g' -e 's/?\\\\154/U/g' -e 's/?\\\\161/a/g' -e 's/?\\\\169/e/g' -e 's/?\\\\173/i/g' -e 's/?\\\\179/o/g' -e 's/?\\\\186/u/g' -e 's/?\\\\130/A/g' -e 's/?\\\\138/E/g' -e 's/?\\\\148/O/g' -e 's/?\\\\162/a/g' -e 's/?\\\\170/e/g' -e 's/?\\\\180/o/g' -e 's/?\\\\128/A/g' -e 's/?\\\\160/a/g' -e 's/?\\\\156/U/g' -e 's/?\\\\188/u/g' -e 's/?\\\\135/C/g' -e 's/?\\\\167/c/g' -e 's/?\\\\145/N/g' -e 's/?\\\\177/n/g' -e 's/?\\\\131/A/g' -e 's/?\\\\149/O/g' -e 's/?\\\\163/a/g' -e 's/?\\\\181/o/g'
}
##########################################################################################################

##########################################################################################################
##########################################################################################################
########################					##############################################################
########################        MAIN		##############################################################
########################					##############################################################
##########################################################################################################
##########################################################################################################

lang_temp=`echo $LANG`
export LANG=pt_BR

export log_temp="/tmp/"$rev"_merge_out$$_rev"

debug="" #coloque algo para debugar. ex. debug="Sim"
log_debug=/tmp/_temp_log_merge$$

rm -f temp*_crs$USER

LOGMSG="$( log_msg_filter $REPOS $REV )"

test=`echo $LOGMSG | grep "\[NA\]"`

if [ "$test" = "" ]
then

	insert_log_svn_mantis $REPOS $REV "$LOGMSG"

        merge_rules=$( branches_list "$id_project_mantis" )
	if [ "$debug" != "" ]; then echo "Merge.inicio:$merge_rules:" >> $log_debug; fi

	if [ "$merge_rules" != "" ]
	then

	sourceBranch=$( source_branch_from_rep_revision $REPOS $REV $merge_rules )
	if [ "$debug" != "" ]; then echo "Merge.sourceBranch:$sourceBranch:" >> $log_debug; fi

	    if [ "$sourceBranch" != "" ]
	    then
		id_crs=$( id_crs_list "$LOGMSG" )
		if [ "$debug" != "" ]; then echo "Merge.id_crs:$id_crs:" >> $log_debug; fi

        	#todo implementar como webservice exec_automerge
		#automerge=$( exec_automerge "$id_crs" )
        	automerge="Sim"

		if [ "$automerge" != "Nao" ]
		then
			targetBranch=$( target_branch $sourceBranch $merge_rules )
			if [ "$debug" != "" ]; then echo "Merge.targetBranch:$targetBranch:" >> $log_debug; fi				

			if [ "$targetBranch" != "" -a "$targetBranch" != "NULL" ]
			then
	                	output_f=/tmp/_temp_out$$
	        	        cp /dev/null $output_f
        	        	chmod a+w $output_f

                		sudo -u ${svnserver_user} ${path_guardian}/merge.sh -r $REPOS -v $REV -l "$LOGMSG" -t "$targetBranch" -s "$sourceBranch" -g "${guardian_properties}" -d "" -o "$output_f" -d "$debug" 2>> $output_f 

		                output_merge=$?

                		if [ "$output_merge" != "0" ]
		                then
                			insert_mantis_note "Nao foi possivel realizar o merge automatico: revisao $REV do branch `basename $sourceBranch` para o branch `basename $targetBranch`. \nProblema: `cat $output_f`. \nSera preciso fazer o merge da revisao $REV manualmente" "$id_crs"
                		fi
		                rm -f $output_f
            		else
				echo "Projeto sem target branch para efetuar o merge" >> $log_temp
			fi
		else
			echo "CR ($id_crs) com a opcap AUTOMERGE = Nao" >> $log_temp
		fi
	    else
		echo "Projeto sem o branch de origem na regra" >> $log_temp
	    fi	
	else
		echo "Projeto sem regra de merge" >> $log_temp
	fi
fi

################################################
# APAGANDO ARQUIVOS TEMPORARIOS     ############
if [ "$debug" = "" ]; then rm -f $log_debug; rm -f $arqtemp; rm -f $arquivoscommit; rm -f $error_merge; fi
################################################
export LANG=$lang_temp
