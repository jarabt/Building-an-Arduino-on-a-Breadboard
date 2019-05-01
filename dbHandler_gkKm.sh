#!/bin/bash - 

### Znak křížek říká interpretru, že od tohoto místa až do konce řádku je to poznámka a tudíž si textu tam uvedeného nemá všímat. Vykřičník zde slouží jako uvození informace o tom, kde najde### systém interpretr pro spuštění daného skriptu.


#===============================================================================
#
#          FILE: dbHandler_gkKm.sh
# 
#         USAGE: ./dbHandler_gkKm.sh propertyFile app actionType
#         EXAMPLE: ./dbHandler_gkKm.sh UZTST012_kc70-dev_ora12c.properties gk update
# 
#   DESCRIPTION: Handle GK and KM via CLI through action type.
# 
#       OPTIONS: $1 - propertiesFile, $2 - app, $3 - actionType
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Tomik Iglo (), tomas.iglo@unymira.com
#  ORGANIZATION: USU AG
#       CREATED: 11/28/2018 08:10:26 AM
#      REVISION:  ---
#===============================================================================

### Hlavička skriptu formou komentáře


set -o nounset                              # Treat unset variables as an error
propertiesFile=$1
app=$2
actionType=$3

### Při spuštění skriptu je zapotřebí tří parametrů, pokud ne, bude se to považovat za chybu.
### Je zde určeno v jakém pořadí budou zadané parametry přiřazeny k proměnným


### Dále následují definice funkcí, které skript využívá: 

getVariableFromFile (){
	#---  FUNCTION  ----------------------------------------------------------------
	#          NAME:  getVariableFromFile
	#   DESCRIPTION:  Get variable from specific file
	#    PARAMETERS:  - property
	#		  - file
	#       RETURNS:  Variable
	#-------------------------------------------------------------------------------

	if [[ ! -a "$2" ]] ; then					
		echo -e "File not specified / doesn't exist .."				
		exit 1
	fi
	while read -r name hu value; do
		if [[ $name == $1 ]] ; then
			hodnota="$value"
		fi
	done < "$2"
	echo $hodnota
}	# ----------  end of function getVariableFromFile  ----------

### Přečti hodnotu proměnné v parametru 1 ze souboru v parametru 2
### Pokud nebude druhý parametr obsahovat znaky, napiš zprávu a ukonči shell se statusem 1
### Vrať hodnotu přiřazenou k zadanému parametru 1


updateGK (){
	echo -e "Update DB schema in GK."
	timeout 90 bash -x dbutil.sh -update > "$dir_kcVersion/$app/server/log/updateDB.log" 2>&1
}	# ----------  end of function updateGK  ----------

### Aktualizuje GK
### Napíše zprávu o této činnosti
### V časovém horizontu 90s spusť skript "dbutil.sh" v debug módu s parametrem "updade" a 
### průběh zapiš do souboru .log


exportGK (){
	echo -e "Export data of Gatekeeper."	
	bash -x export.sh -file gk_export.xml -pwd kc > "$dir_kcVersion/$app/server/log/exportDump.log" 2>&1
}   # ----------  end of function exportGK  ----------

### Exportuje data GK
### Napíše zprávu o této činnotsi
### V debug módu spustí skript "export.sh" s parametrem "file", který má hodnotu "gk_export.xml" a
### parametrem "pwd", který má hodnotu "kc"
### průběh zapiš do souboru .log


importGK (){
	echo -e "Clear all data in GK DB schema."
	timeout 90 bash -x dbutil.sh -clear > "$dir_kcVersion/$app/server/log/clearDB.log" 2>&1
	echo -e "Import data of Gatekeeper."
	bash -x import.sh -file "$dir_exports_NAS_app"/gk_export.xml -pwd kc > "$dir_kcVersion/$app/server/log/importDump.log" 2>&1
}	# ----------  end of function importGK  ----------

### Importuje data GK
### Napíše, co právě dělá
### V horizontu 90s spustí v debug módu skript "dbutil.sh" s parametrem "clear" a průběh zapíše do .log
### V debug módu spustí skript "import.sh" s hodnotou parametru "file" a "pwd", průběh zapíše do .log


createConfsKM (){
	echo -e "Create basic files in KM."
	$dir_kcVersion/$app/ant/bin/./ant create-conf-km create-db-scripts create-conf-web > "$dir_kcVersion/$app/server/log/createConfsKM.log" 2>&1
	cp $dir_kcVersion/gk/server/conf/gatekeeper.domain.properties $dir_kcVersion/$app/server/conf
	cd $dir_kcVersion/$app/server/conf
	find . -type f -name "gatekeeper.domain.properties" -exec sed -i 's/gatekeeper\.domain\.server=.*/gatekeeper\.domain\.server='$zookeeper_bind_host'\:'$zookeeper_bind_port'/g' {} +
}	# ----------  end of function createConfsKM  ----------

### Vytváří konfigurační soubory
### Napíše zprávu
### Za pomocí nástroje ant jeho 3 parametrů vytvoř soubory
### Nakopíruj soubor "gatekeeper.domain.properties" do adresáře aplikace stanovené parametrem při spouštění tohoto skriptu


updateKM (){
	echo -e "Update DB schema in KM."
	$dir_kcVersion/$app/ant/bin/./ant db-update > "$dir_kcVersion/$app/server/log/updateDB.log" 2>&1
}	# ----------  end of function updateKM  ----------
exportKM (){
	echo -e "Export data of KMiner."	
	$dir_kcVersion/$app/ant/bin/./ant export-db-dump > "$dir_kcVersion/$app/server/log/exportDump.log" 2>&1
}   # ----------  end of function exportKM  ----------
copyDumpsToNAS (){
	if [[ "$app" == "gk" ]] ; then
		mkdir -p $dir_exports_NAS_app && rsync -a gk_export.xml $dir_exports_NAS_app
	elif [[ "$app" == "km" ]] ; then
		mkdir -p $dir_exports_NAS_app && rsync -a $dir_kcVersion/$app/server/dump/dump.exportedDump.objectdata $dir_exports_NAS_app && rsync -a $dir_kcVersion/$app/server/dump/dump.exportedDump.systemdata $dir_exports_NAS_app
	fi
}	# ----------  end of function copyDumpsToNAS  ----------
copyDumpsFromNAS (){
	if [[ "$app" == "gk" ]] ; then
		cp $dir_exports_NAS_app/* $dir_kcVersion/$app/server/bin
	elif [[ "$app" == "km" ]] ; then
		mkdir -p $dir_kcVersion/$app/server/dump && cp $dir_exports_NAS_app/dump.exportedDump.objectdata $dir_kcVersion/$app/server/dump/dump.initial.objectdata && cp $dir_exports_NAS_app/dump.exportedDump.systemdata $dir_kcVersion/$app/server/dump/dump.initial.systemdata
	fi
}	# ----------  end of function copyDumpsFromNAS  ----------
importKM (){
	echo -e "Import data to KMiner."
	$dir_kcVersion/$app/ant/bin/./ant import-db-dump > "$dir_kcVersion/$app/server/log/importDump.log" 2>&1
}	# ----------  end of function importKM  ----------






dir_kcVersion=$(getVariableFromFile "dir_kcVersion" $propertiesFile)
zookeeper_bind_port=$(getVariableFromFile "zookeeper_bind_port" $propertiesFile)
zookeeper_bind_host=$(getVariableFromFile "zookeeper_bind_host" $propertiesFile)
kc_branch=$(getVariableFromFile "kc_branch" $propertiesFile)
dir_NAS=$(getVariableFromFile "dir_NAS" $propertiesFile)
dir_exports_NAS="$dir_NAS/exports/template_dumps/$kc_branch"
dir_exports_NAS_app="$dir_exports_NAS/$app"
cd "$dir_kcVersion/$app/server/bin" || exit 1
if [[ $app == "gk" ]] ; then
	case $actionType in
		update)
			updateGK
			;;
		import)
			copyDumpsFromNAS
			importGK
			;;
		export)
			exportGK
			copyDumpsToNAS
			;;
		copyDumpsToNAS)
			copyDumpsToNAS
			;;
		copyDumpsFromNAS)
			copyDumpsFromNAS
			;;

		esac    # --- end of case ---
elif [[ $app == "km" ]] ; then
	case $actionType in
		update)
			updateKM
			;;			
		createConfs) 
			createConfsKM
			;;
		import)
			copyDumpsFromNAS
			importKM
			;;
		export)
			exportKM
			copyDumpsToNAS
			;;
		copyDumpsToNAS)
			copyDumpsToNAS
			;;
		copyDumpsFromNAS)
			copyDumpsFromNAS
			;;
		esac    # --- end of case ---
fi
