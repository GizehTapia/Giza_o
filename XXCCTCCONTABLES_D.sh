#!/bin/sh
# DESCRIPCION
# ===========
# Shell para bajar Concurrente de "XXCCT - GL Combinacion Cuentas Contables"
#
# Fecha         Quien        Que                                       Version
# -----------   ---------    ----------------------------------------  -------
# 02-SEP-2014   SPA (cct)    Creacion                                  1.0
#
#
# Parametros
# 1 usuario de la base de datos
# 2 contrasenya
echo '--------------------------------------------------------------'
echo 'BAJANDO CONCURRENTE'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 O Y DOWNLOAD $FND_TOP/patch/115/import/afcpprog.lct XXCCTCCONTABLES_CONC.ldt PROGRAM APPLICATION_SHORT_NAME="SQLGL" CONCURRENT_PROGRAM_NAME="XXCCTCCONTABLES";
echo '--------------------------------------------------------------'
echo 'BAJANDO REQUEST GROUP'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 O Y DOWNLOAD $FND_TOP/patch/115/import/afcpreqg.lct "XXCCTCCONTABLES_RGROUP.ldt" REQUEST_GROUP REQUEST_GROUP_NAME="GL Concurrent Program Group" APPLICATION_SHORT_NAME=SQLGL REQUEST_GROUP_UNIT UNIT_TYPE="P" UNIT_APP="SQLGL" UNIT_NAME="XXCCTCCONTABLES";
echo '--------------------------------------------------------------'
echo 'BAJANDO REQUEST GROUP'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 O Y DOWNLOAD $FND_TOP/patch/115/import/afcpreqg.lct "XXCCTCCONTABLES_RGROUP1.ldt" REQUEST_GROUP REQUEST_GROUP_NAME="GCE_GL Concurrent Program Grou" APPLICATION_SHORT_NAME=SQLGL REQUEST_GROUP_UNIT UNIT_TYPE="P" UNIT_APP="SQLGL" UNIT_NAME="XXCCTCCONTABLES";
echo '--------------------------------------------------------------'
echo 'BAJANDO REQUEST GROUP'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 O Y DOWNLOAD $FND_TOP/patch/115/import/afcpreqg.lct "XXCCTCCONTABLES_RGROUP2.ldt" REQUEST_GROUP REQUEST_GROUP_NAME="GALAK_CONCURRENT PROGRAM GROUP" APPLICATION_SHORT_NAME=SQLGL REQUEST_GROUP_UNIT UNIT_TYPE="P" UNIT_APP="SQLGL" UNIT_NAME="XXCCTCCONTABLES";
echo '--------------------------------------------------------------'
echo 'BAJANDO REQUEST GROUP'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 O Y DOWNLOAD $FND_TOP/patch/115/import/afcpreqg.lct "XXCCTCCONTABLES_RGROUP3.ldt" REQUEST_GROUP REQUEST_GROUP_NAME="DVM_Concurrent Program Gruop" APPLICATION_SHORT_NAME=SQLGL REQUEST_GROUP_UNIT UNIT_TYPE="P" UNIT_APP="SQLGL" UNIT_NAME="XXCCTCCONTABLES";
echo '--------------------------------------------------------------'
echo 'BAJANDO REQUEST GROUP'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 O Y DOWNLOAD $FND_TOP/patch/115/import/afcpreqg.lct "XXCCTCCONTABLES_RGROUP4.ldt" REQUEST_GROUP REQUEST_GROUP_NAME="JPAB_Concurrent_Program_Group" APPLICATION_SHORT_NAME=SQLGL REQUEST_GROUP_UNIT UNIT_TYPE="P" UNIT_APP="SQLGL" UNIT_NAME="XXCCTCCONTABLES";
echo '--------------------------------------------------------------'
echo 'BAJANDO DEFINICION DE DATOS Y TEMPLATE'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 0 Y DOWNLOAD $XDO_TOP/patch/115/import/xdotmpl.lct XXCCTCCONTABLES_XML.ldt XDO_DS_DEFINITIONS APPLICATION_SHORT_NAME="SQLGL" DATA_SOURCE_CODE="XXCCTCCONTABLES" TMPL_APP_SHORT_NAME="SQLGL" TEMPLATE_CODE="XXCCTCCONTABLES";
echo '--------------------------------------------------------------'
echo 'BAJANDO ARCHIVO DE TEMPLATE'
echo '--------------------------------------------------------------'
java oracle.apps.xdo.oa.util.XDOLoader DOWNLOAD -DB_USERNAME $1 -DB_PASSWORD $2 -JDBC_CONNECTION $3 -LOB_TYPE TEMPLATE -APPS_SHORT_NAME SQLGL -LOB_CODE XXCCTCCONTABLES -LANGUAGE en -TERRITORY 00;
