# 3 cadena de conexion host:puerto:sid
#!/bin/sh
# DESCRIPCION
# ===========
# Shell para subir Concurrente y complementos de "XXCCT - GL Combinacion Cuentas Contables"
#
# Fecha         Quien        Que                                       Version
# -----------   ---------    ----------------------------------------  -------
# 02-SEP-2014   SPA (cct)    Creacion                                  1.0
#
#
#OPCION PARA REESCRIBIR UN CONCURRENTE UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
# Parametros
# 1 usuario de la base de datos
# 2 contrasenya
# 3 cadena de conexion host:puerto:sid
echo '--------------------------------------------------------------'
echo 'SUBIENDO CONCURRENTE'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 0 Y UPLOAD @FND:/patch/115/import/afcpprog.lct XXCCTCCONTABLES_CONC.ldt CUSTOM_MODE=FORCE;
echo '--------------------------------------------------------------'
echo 'SUBIENDO REQUEST GROUP'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 0 Y UPLOAD @FND:/patch/115/import/afcpreqg.lct "XXCCTCCONTABLES_RGROUP.ldt";
echo '--------------------------------------------------------------'
echo 'SUBIENDO REQUEST GROUP'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 0 Y UPLOAD @FND:/patch/115/import/afcpreqg.lct "XXCCTCCONTABLES_RGROUP1.ldt";
echo '--------------------------------------------------------------'
echo 'SUBIENDO REQUEST GROUP'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 0 Y UPLOAD @FND:/patch/115/import/afcpreqg.lct "XXCCTCCONTABLES_RGROUP2.ldt";
echo '--------------------------------------------------------------'
echo 'SUBIENDO REQUEST GROUP'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 0 Y UPLOAD @FND:/patch/115/import/afcpreqg.lct "XXCCTCCONTABLES_RGROUP3.ldt";
echo '--------------------------------------------------------------'
echo 'SUBIENDO REQUEST GROUP'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 0 Y UPLOAD @FND:/patch/115/import/afcpreqg.lct "XXCCTCCONTABLES_RGROUP4.ldt";
echo '--------------------------------------------------------------'
echo 'SUBIENDO DATA DEFINITION Y TEMPLATE'
echo '--------------------------------------------------------------'
FNDLOAD $1/$2 0 Y UPLOAD @XDO:/patch/115/import/xdotmpl.lct "XXCCTCCONTABLES_XML.ldt";
echo '--------------------------------------------------------------'
echo 'SUBIENDO ARCHIVO TEMPLATE'
echo '--------------------------------------------------------------'
java oracle.apps.xdo.oa.util.XDOLoader UPLOAD -DB_USERNAME $1 -DB_PASSWORD $2 -JDBC_CONNECTION $3 -LOB_TYPE TEMPLATE -APPS_SHORT_NAME SQLGL -LOB_CODE XXCCTCCONTABLES -XDO_FILE_TYPE RTF -LANGUAGE en -TERRITORY 00 -FILE_NAME $XBOL_TOP/bin/XXCCTCCONTABLES.rtf -CUSTOM_MODE FORCE;
