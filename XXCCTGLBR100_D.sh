#!/bin/sh
# DESCRIPCION
# ===========
# Shell para bajar Concurrente de "XXCCT - GL BR100 PROGRAM"
#
# Fecha         Quien        Que                                       Version
# -----------   ---------    ----------------------------------------  -------
# 27-AGO-2014   SPA (cct)    Creacion                                  1.0
#
#
# Parametros
# 1 usuario de la base de datos
# 2 contrasenya
echo '--------------------------------------------------------------'
echo 'BAJANDO CONCURRENTE'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 O Y DOWNLOAD $FND_TOP/patch/115/import/afcpprog.lct XXCCTGLBR100_CONC.ldt PROGRAM APPLICATION_SHORT_NAME="SQLGL" CONCURRENT_PROGRAM_NAME="XXCCTGLBR100";
echo '--------------------------------------------------------------'
echo 'BAJANDO REQUEST GROUP'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 O Y DOWNLOAD $FND_TOP/patch/115/import/afcpreqg.lct "XXCCTGLBR100_RGROUP.ldt" REQUEST_GROUP REQUEST_GROUP_NAME="GL Concurrent Program Group" APPLICATION_SHORT_NAME=SQLGL REQUEST_GROUP_UNIT UNIT_TYPE="P" UNIT_APP="SQLGL" UNIT_NAME="XXCCTGLBR100";
echo '--------------------------------------------------------------'
echo 'BAJANDO REQUEST GROUP'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 O Y DOWNLOAD $FND_TOP/patch/115/import/afcpreqg.lct "XXCCTGLBR100_RGROUP1.ldt" REQUEST_GROUP REQUEST_GROUP_NAME="GCE_GL Concurrent Program Grou" APPLICATION_SHORT_NAME=SQLGL REQUEST_GROUP_UNIT UNIT_TYPE="P" UNIT_APP="SQLGL" UNIT_NAME="XXCCTGLBR100";
echo '--------------------------------------------------------------'
echo 'BAJANDO REQUEST GROUP'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 O Y DOWNLOAD $FND_TOP/patch/115/import/afcpreqg.lct "XXCCTGLBR100_RGROUP2.ldt" REQUEST_GROUP REQUEST_GROUP_NAME="GALAK_CONCURRENT PROGRAM GROUP" APPLICATION_SHORT_NAME=SQLGL REQUEST_GROUP_UNIT UNIT_TYPE="P" UNIT_APP="SQLGL" UNIT_NAME="XXCCTGLBR100";
echo '--------------------------------------------------------------'
echo 'BAJANDO REQUEST GROUP'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 O Y DOWNLOAD $FND_TOP/patch/115/import/afcpreqg.lct "XXCCTGLBR100_RGROUP3.ldt" REQUEST_GROUP REQUEST_GROUP_NAME="DVM_Concurrent Program Gruop" APPLICATION_SHORT_NAME=SQLGL REQUEST_GROUP_UNIT UNIT_TYPE="P" UNIT_APP="SQLGL" UNIT_NAME="XXCCTGLBR100";
echo '--------------------------------------------------------------'
echo 'BAJANDO REQUEST GROUP'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 O Y DOWNLOAD $FND_TOP/patch/115/import/afcpreqg.lct "XXCCTGLBR100_RGROUP4.ldt" REQUEST_GROUP REQUEST_GROUP_NAME="JPAB_Concurrent_Program_Group" APPLICATION_SHORT_NAME=SQLGL REQUEST_GROUP_UNIT UNIT_TYPE="P" UNIT_APP="SQLGL" UNIT_NAME="XXCCTGLBR100";
echo '--------------------------------------------------------------'
echo 'BAJANDO DEFINICION DE DATOS Y TEMPLATE'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 0 Y DOWNLOAD $XDO_TOP/patch/115/import/xdotmpl.lct XXCCTGLBR100_XML.ldt XDO_DS_DEFINITIONS APPLICATION_SHORT_NAME="SQLGL" DATA_SOURCE_CODE="XXCCTGLBR100" TMPL_APP_SHORT_NAME="SQLGL" TEMPLATE_CODE="XXCCTGLBR100";
echo '--------------------------------------------------------------'
echo 'BAJANDO ARCHIVO DE TEMPLATE'
echo '--------------------------------------------------------------'
java oracle.apps.xdo.oa.util.XDOLoader DOWNLOAD -DB_USERNAME $1 -DB_PASSWORD $2 -JDBC_CONNECTION $3 -LOB_TYPE TEMPLATE -APPS_SHORT_NAME SQLGL -LOB_CODE XXCCTGLBR100 -LANGUAGE en -TERRITORY 00;
