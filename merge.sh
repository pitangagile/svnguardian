#!/bin/bash

####################################
## ATENCAO
# altere o arquivo sudoers para que esse script possa ser executado pelo usuario do servidor que esta sendo usado para os checkout. 
# ex. 
# Cmnd_Alias MERGEP = /repos/svn/scm/svnguardian/producao/merge.sh,/repos/svn/scm/svnguardian/homologacao/merge.sh
# ALL      ALL=(scmprojeto)       NOPASSWD: MERGEP
####################################

##########################################################################################################
##########################################################################################################
# TODO: remove working copies not used
function gc_wcs() {
branches_list=$1 #branches list separated by commas that define a merge rule
dir_wcs=$2 #directory to run garbage

#echo $branches_list | sed -n 1'p' | tr ',' '\n' | while read wc_branch; do
#branches que nao estejam mais na lista devem ser apagados
#done
}
##########################################################################################################

##########################################################################################################
##########################################################################################################
#identify path after root, if exists. Otherwise, return ''. Ex.: repos/projectA/trunk -> return projectA. repos/projectB/branches/branch1 -> return projectB
function after_root_from_rep_revision() {
##########################################################################################################
t_repos=$1
t_rev=$2

branch_t=/tmp/branch_t$$

#what is the branch or if is the trunk
svnlook dirs-changed $t_repos -r $t_rev | grep -E "(trunk|branches)" | sed 's/branches\/.*/^/' | sed 's/trunk.*/^/' | cut -d^ -f1 | sort -u > $branch_t

head -1 $branch_t

rm -f $branch_t
}
##########################################################################################################

##########################################################################################################
##########################################################################################################
#return a dir name of directories in the pool
#O pool caracteriza-se por diretorios previamente criados, j com os checkout realizados.
#Eles sao nomeados com o nome do diretorio desejado seguido por _Numero
function available_directory_pool() {
##########################################################################################################
dir_pool=$1
dir_to_use=$2

#retorna o diretorio com maior numero, em tese, o mais recente, o que vai optimizar o update subsequente
if [ "$debug" != "" ]; then echo "find . -maxdepth 1 -type d -name '$dir_to_use\_pool*' | sort -u | tail -1" >> $log_temp; fi

find . -maxdepth 1 -type d -name "$dir_to_use\_pool*" | sort -u | tail -1
}
##########################################################################################################


##########################################################################################################
##########################################################################################################
#return if repo have the directory produtos/codigo
function dir_to_checkout() {
##########################################################################################################
svn_repo=$1
branch=$2

if [ "$debug" != "" ]; then echo "dir_to_checkout: svn list $svn_repo/$branch" >> $log_temp; fi

svn list $svn_repo/$branch > /dev/null 2>&1
if [ "$?" != "0" ]
then
	echo "Branch nao existe" 2>&1
	exit 1
else
	basename $branch
fi
}
##########################################################################################################

#####################################################
#merge revision(s) from banchSource to targetBranch
#####################################################
function merge_rev_sourceBranch_targetBranch {
rev=$1 #may be one or more revisions separated by commas
sourceBranch=$2
targetBranch=$3
msgCommit=$4
cv_root=$5
output_f=$6

svn_repo_url=svn+ssh://${cv_user}@${cv_server}/${cv_root}

targetBranch_co=$( dir_to_checkout $svn_repo_url $targetBranch )
merge_output=$?
echo "merge_output1:$merge_output||targetBranch_co:$targetBranch_co" >> $output_f
sourceBranch_co=$( dir_to_checkout $svn_repo_url $sourceBranch )
merge_output=$(($merge_output + $?))

echo "merge_output2:$merge_output||sourceBranch_co:$sourceBranch_co" >> $output_f


if [ "$merge_output" != "0" ]
then
	echo "Houve algum problema na localizacao do branch de origem ou destino" >> $output_f
	exit 1
fi

	cd $merge_checkout_path_proj
	rm -rf $rev
	mkdir -p $rev

		#search dir of pool
	if [ "$debug" != "" ]; then echo "achando pool:ANTES:$targetBranch_co" >> $log_temp; fi
	dir_to_use=$( available_directory_pool "." "$targetBranch_co" )
	if [ "$debug" != "" ]; then echo "achando pool:$dir_to_use:" >> $log_temp; fi

	if [ -e "$dir_to_use" -a "$dir_to_use" != "" ]
	then
		#if another merge of another revision, of course, need checkout, not have conflict. Move directory for temporary "revison's directory"
		mv $dir_to_use $rev/$targetBranch_co
				cd $rev

		#cleaning up wc
		if [ "$debug" != "" ]; then echo "svn revert TEMPO ANTES:|$rev|`date +'%T'`" >> $log_time_temp; fi
		svn cleanup $targetBranch_co
		svn revert -R $targetBranch_co
		if [ "$debug" != "" ]; then echo "svn revert $targetBranch_co svn update TEMPO DEPOIS:|$rev|`date +'%T'`" >> $log_time_temp; fi
	else
				cd $rev

		if [ "$debug" != "" ]; then echo "co $svn_repo_url/$targetBranch $targetBranch_co TEMPO ANTES:|$rev|`date +'%T'`" >> $log_time_temp; fi
		svn co $svn_repo_url/$targetBranch $targetBranch_co
		if [ "$debug" != "" ]; then echo "co $svn_repo_url/$targetBranch $targetBranch_co TEMPO DEPOIS:|$rev|`date +'%T'`" >> $log_time_temp; fi
	fi

	if [ "$debug" != "" ]; then echo "svn update2 TEMPO ANTES:|$rev|`date +'%T'`" >> $log_time_temp; fi
	svn update $targetBranch_co
	if [ "$debug" != "" ]; then echo "svn update2 TEMPO DEPOIS:|$rev|`date +'%T'`" >> $log_time_temp; fi

	#cherry-pick merge
	if [ "$debug" != "" ]; then echo "svn merge TEMPO ANTES:|$rev|`date +'%T'`" >> $log_time_temp; fi
	svn merge --non-interactive -x -b -c $rev $svn_repo_url/$sourceBranch $targetBranch_co
	if [ "$debug" != "" ]; then echo "svn merge TEMPO DEPOIS:|$rev|`date +'%T'`" >> $log_time_temp; fi

	status_t=/tmp/_status_temp$$
	svn status $targetBranch_co > $status_t
	mergeConflict=`cat $status_t | grep -P '^(?=.{0,6}C)'`
	rm -f $status_t

	if [ "$mergeConflict" !=  "" ]
	then
		if [ "$debug" != "" ]; then echo "svn revert2 TEMPO ANTES:|$rev|`date +'%T'`" >> $log_time_temp; fi
		svn revert -R $targetBranch_co
		if [ "$debug" != "" ]; then echo "svn revert2 TEMPO DEPOIS:|$rev|`date +'%T'`" >> $log_time_temp; fi
				#precisa gravar uma nota na CR indicando o conflito #$rev
				echo "Erro (Arquivos que tiveram conflitos): $mergeConflict" > $output_f
				merge_output=1
	else
		if [ "$debug" != "" ]; then echo "echo $msgCommit | sed 's/$merge_token/^/g' | cut -d^ -f1" >> $log_temp; fi
		msgCommit_t=`echo $msgCommit | sed "s/$merge_token/^/g" | cut -d^ -f1`  #filtrar mensagem original (retirar a partir, incluindo, o token)
		if [ "$msgCommit_t" = "" ]
		then
				msgCommit_t=$msgCommit;
		fi

				attempt_update=`echo $repeat_update | grep -E "^[0-9]+$"`
				if [ "$attempt_update" = ""  ]
				then
						attempt_update=2
				fi

				wait_update=`echo $sleep_update | grep -E "^[0-9]+[smhd]?$"`
				if [ "$wait_update" = ""  ]
				then
						wait_update=10s
				fi

		while [ $attempt_update -gt 0 ]
		do
				if [ "$debug" != "" ]; then echo "ANTES: svn update $targetBranch_co TEMPO ANTES:|$rev|`date +'%T'`" >> $log_time_temp; fi
				svn update $targetBranch_co 2>> $output_f
				if [ "$debug" != "" ]; then echo "DEPOIS: svn update $targetBranch_co TEMPO DEPOIS:|$rev|`date +'%T'`" >> $log_time_temp; fi

				if [ "$debug" != "" ]; then echo "svn ci -m '$msgCommit_t $merge_token $sourceBranch_co@$rev)' $targetBranch_co TEMPO ANTES:|$rev|`date +'%T'`" >> $log_time_temp; fi

				svn ci -m "$msgCommit_t $merge_token $sourceBranch_co@$rev)" $targetBranch_co 2>> $output_f
				merge_output=$?

				if [ "$merge_output" != "0" ]
				then
						let "attempt_update-=1"
						sleep $wait_update
				else
						attempt_update=0
				fi

				if [ "$debug" != "" ]; then echo "svn ci TEMPO DEPOIS:|$rev|`date +'%T'`" >> $log_time_temp; fi

		done

	fi

		#release directory to pool again
	mv $targetBranch_co ../$targetBranch_co\_pool$rev
	rm -rf ../$rev
        if [ "$debug" = "" ]; then rm -f $log_temp; rm -f $log_time_temp; fi

	return $merge_output
}


function merge() {
while getopts ":d:e:g:l:m:o:p:r:s:t:u:v:" Option
do
  case $Option in
	d ) debug=$OPTARG;;
	e ) merge_rules=$OPTARG;;	   #branches list separated by commas that define merge rule
	g ) guardianProperties=$OPTARG;;		#
	l ) msgCommit=$OPTARG;;					 #original message to commit
	m ) export mantisProperties=$OPTARG;;			   #properties to connect to mantis
	o ) output_f=$OPTARG;;			  #arquivo que deve guardar o resultado
	p ) idProject=$OPTARG;;					 #id project where is defined merge rule
	r ) repos=$OPTARG;;								 #path to repository on the server
	s ) branchSource=$OPTARG;;		  #branch source to merge to revision
	t ) branchTarget=$OPTARG;;		  #branch target to merge from revision (and related branch to this revision). Branches separated by commas
	u ) urlRoot=$OPTARG;;
	v ) rev=$OPTARG;;								   #revision number to merge
	* ) echo "Unimplemented option chosen.";;
  esac
done
shift $(($OPTIND - 1))

if [ "$guardianProperties" = "" ]
then
guardianProperties="svnguardian.properties"
fi

lang_tempM=`echo $LANG`
export LANG=en_US


export log_temp="/tmp/"$rev"_merge_out$$_rev"
export log_time_temp="/tmp/"$rev"_merge_time_out$$"
################################################
#Geral properties
#cv_user
#cv_server
#merge_checkout_path
################################################
source $guardianProperties

#trocando padrao para pegar sempre a quarta pasta, ja que usamos sempre o padrao dos repositorios em /repos/svn/repos/
#cv_root=`echo $repos | grep -Eo "[-_a-zA-Z0-9]+_root"`  #'repos' is path on the server. Retrieve only root of repository.
cv_root=`echo $repos | cut -d'/' -f5-`

export merge_checkout_path_proj="${merge_checkout_path}/${cv_root}"
mkdir -p ${merge_checkout_path_proj}
merge_rev_sourceBranch_targetBranch $rev $branchSource $branchTarget "$msgCommit" $cv_root $output_f
return $?
}

export LANG=$lang_tempM

if [ "$#" -lt 10 ]
then
	echo "Numero de parametros invalidos ($#):$@"
	exit 1
else
	merge "$@"
fi
