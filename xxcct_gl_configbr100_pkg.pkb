/* Formatted on 27/08/2014 01:08:01 p. m. (QP5 v5.139.911.3011) */
CREATE OR REPLACE PACKAGE BODY apps.xxcct_gl_configbr100_pkg
IS
--$Id:$
/***********************************************************
                                   Condor Consulting Team S.C.
=====                                            
NAME        : xxcct_gl_configbr100_pkg
=========
DESCRIPTION : Su función es generar un reporte en excel de todas aquellas cuentas
                       de GL que cumplan con las caracteristicas mencionadas en el archivo
                       DS080 GL.
=======                       
HISTORY     :

    FECHA        VERSION     QUIEN              CAMBIOS
  ----------    ---------   ----------------    ----------------------------------
 28-08-14        1.0        GTL                
***********************************************************/
--- Variables globales

   g_type_output_summary   NUMBER           := 3;
   g_type_log_summary        NUMBER           := 2;
   g_chart_of_account          NUMBER;
--- Funcion para impresión de mensajes en diferentes tipos de salida.
   PROCEDURE print_message (p_type_output NUMBER, p_message VARCHAR2)
   AS
   BEGIN
      --
      IF p_type_output = 0
      THEN
         NULL;
      ELSIF p_type_output = 1
      THEN
         DBMS_OUTPUT.put_line (p_message);
      ELSIF p_type_output = 2
      THEN
         fnd_file.put_line (fnd_file.LOG, p_message);
      ELSIF p_type_output = 3
      THEN
         fnd_file.put_line (fnd_file.output, p_message);
      ELSIF p_type_output = 4
      THEN                            -- impresion de  mensaje en achivo Plano
         NULL;
      END IF;
   --
   EXCEPTION
      WHEN OTHERS
      THEN
         print_message (g_type_log_summary,
                        'Error en el procedimiento print_message : ' || SQLERRM
                       );
   END print_message;
 
--   Procedimiento que determinar el chart_of_account del libro contable configurado
   FUNCTION get_chart_of_accounts_id
   RETURN NUMBER
   IS
   l_chart_of_accounts_id NUMBER := 0;
   BEGIN 
        SELECT CHART_OF_ACCOUNTS_ID
           INTO l_chart_of_accounts_id
          FROM GL_SETS_OF_BOOKS
        WHERE 1 = 1 
             AND SET_OF_BOOKS_ID = fnd_profile.VALUE('GL_SET_OF_BKS_ID');
             
       RETURN l_chart_of_accounts_id;
             
   EXCEPTION
     WHEN OTHERS THEN
         print_message (g_type_log_summary,
                        'Error en la funcion get_chart_of_accounts_id  :' || SQLERRM
                       );      
          RETURN 0;    
   END get_chart_of_accounts_id;

--- Funcion para eliminar caracteres raros 
   FUNCTION replace_char (p_texto VARCHAR2)
      RETURN VARCHAR2
   IS
      v_return   VARCHAR2 (200);
   BEGIN
      v_return := REPLACE (p_texto, UNISTR ('\00D1'), 'N');
      v_return := REPLACE (v_return, UNISTR ('\00F1'), 'n');
      v_return := REPLACE (v_return, UNISTR ('\00C1'), 'A');
      v_return := REPLACE (v_return, UNISTR ('\00C9'), 'E');
      v_return := REPLACE (v_return, UNISTR ('\00CD'), 'I');
      v_return := REPLACE (v_return, UNISTR ('\00D3'), 'O');
      v_return := REPLACE (v_return, UNISTR ('\00D3'), 'U');
      v_return := REPLACE (v_return, UNISTR ('\00DC'), 'U');
      v_return := REPLACE (v_return, UNISTR ('\00E1'), 'a');
      v_return := REPLACE (v_return, UNISTR ('\00E9'), 'e');
      v_return := REPLACE (v_return, UNISTR ('\00ED'), 'i');
      v_return := REPLACE (v_return, UNISTR ('\00F3'), 'o');
      v_return := REPLACE (v_return, UNISTR ('\00FA'), 'u');
      RETURN v_return;
   END replace_char;
        
/*********  Procedimiento del llenado de la tabla temporal  **************/
 PROCEDURE insert_segment (P_NOMBRE_ESTRUCTURA VARCHAR2)
   IS
      CURSOR c_main (p_nombre_estructura VARCHAR2)
      IS
      SELECT fib.id_flex_name titulo_flex,
                  TO_CHAR (sysdate, 'DD-MON-YYYY') fecha,
                  b.id_flex_structure_code codigo,
                  FFS.ID_FLEX_STRUCTURE_NAME titulo,
                  FFS.DESCRIPTION DESCRIPCION,
                  b.STRUCTURE_VIEW_NAME Visualizar_Nombre,
                  DECODE (b.FREEZE_FLEX_DEFINITION_FLAG, 'N', 'No', 'Si')
                  Congelar_definicion,
                  DECODE (b.enabled_flag, 'N', 'No', 'Si') Activado,
                  b.CONCATENATED_SEGMENT_DELIMITER Separador_segmento,
                  DECODE (b.CROSS_SEGMENT_VALIDATION_FLAG, 'N', 'No', 'Si')
                  Segmentos_Cruzada,
                  DECODE (b.FREEZE_STRUCTURED_HIER_FLAG, 'N', 'No', 'Si')
                  Congelar_Grupos,
                  DECODE (B.DYNAMIC_INSERTS_ALLOWED_FLAG, 'N', 'No', 'Si')
                  AUT_INSERC_DINAMICS,
                  FIFS.SEGMENT_NUM Numero,
                  FIFS.SEGMENT_NAME Nombre,
                  ST.FORM_LEFT_PROMPT Promp_ventana,
                  FIFS.APPLICATION_COLUMN_NAME Columna,
                  DECODE (FIFS.DISPLAY_FLAG, 'N', 'No', 'Si') Desplegado,
                  DECODE (FIFS.ENABLED_FLAG, 'N', 'No', 'Si') Activado_s,
                  DECODE (FIFS.APPLICATION_COLUMN_INDEX_FLAG, 'N', 'No', 'Si') indexado,
                  DECODE (FIFS.DEFAULT_TYPE, 'C', 'Constante') tipo,
                  FIFS.DEFAULT_VALUE defecto,
                  DECODE (FIFS.REQUIRED_FLAG, 'N', 'No', 'Si') requerido,
                  DECODE (FIFS.SECURITY_ENABLED_FLAG, 'N', 'No', 'Si') segurida_activada,
                  FIFS.RANGE_CODE rango,
                  FIFS.DISPLAY_SIZE des_tamano,
                  FIFS.MAXIMUM_DESCRIPTION_LEN tamano_des,
                  FIFS.CONCATENATION_DESCRIPTION_LEN tamano_con,
                  ST.FORM_ABOVE_PROMPT l_valores,
                  FFVS.flex_value_set_name juego_valores,
                  st.DESCRIPTION DES,
                  fnd_global.user_id created_by,
                  fnd_global.conc_request_id request_id,
                  '' nombre_calificador,
                  '' calificador_activo,
                  TO_CHAR (SYSDATE, 'DD-MON-YYYY')  last_update_date,
                   fnd_global.user_id last_updated_by
         FROM FND_ID_FLEX_STRUCTURES_TL FFS,
                   FND_ID_FLEX_STRUCTURES B,
                   FND_ID_FLEXS FIB,
                   FND_ID_FLEX_SEGMENTS FIFS,
                   FND_ID_FLEX_SEGMENTS_TL ST,
                   Fnd_flex_value_sets FFVS
         WHERE     1 = 1
             AND B.ID_FLEX_CODE = FFS.ID_FLEX_CODE
             AND B.ID_FLEX_NUM = FFS.ID_FLEX_NUM
             AND FFS.APPLICATION_ID = FIB.APPLICATION_ID
             AND FIB.ID_FLEX_CODE = FFS.ID_FLEX_CODE
             AND FIFS.ID_FLEX_CODE = B.ID_FLEX_CODE
             AND FIFS.ID_FLEX_NUM = B.ID_FLEX_NUM
             AND FIFS.ID_FLEX_CODE = ST.ID_FLEX_CODE
             AND FIFS.ID_FLEX_NUM = ST.ID_FLEX_NUM
             AND FIFS.APPLICATION_COLUMN_NAME = ST.APPLICATION_COLUMN_NAME
             AND FFVS.flex_value_set_id = FIFS.flex_value_set_id
             AND FFS.LANGUAGE = USERENV ('LANG')
             AND ST.LANGUAGE = USERENV ('LANG')
             AND B.ID_FLEX_CODE = 'GL#'
             AND FFS.ID_FLEX_STRUCTURE_NAME = P_NOMBRE_ESTRUCTURA
         ORDER BY Columna;

      TYPE l_flex IS TABLE OF c_main%ROWTYPE
                        INDEX BY BINARY_INTEGER;

      l_values   l_flex;
      l_cont     NUMBER := 1;
   BEGIN
       FOR r_main IN c_main (P_NOMBRE_ESTRUCTURA) LOOP

             l_values (l_cont).TITULO_FLEX := r_main.TITULO_FLEX;
             l_values (l_cont).FECHA := SYSDATE;
             l_values (l_cont).Codigo := r_main.Codigo;
             l_values (l_cont).Titulo := r_main.Titulo;
             l_values (l_cont).DESCRIPCION := r_main.DESCRIPCION;
             l_values (l_cont).Visualizar_Nombre := r_main.Visualizar_Nombre;
             l_values (l_cont).Congelar_definicion := r_main.Congelar_definicion;
             l_values (l_cont).Activado := r_main.Activado;
             l_values (l_cont).Separador_segmento := r_main.Separador_segmento;
             l_values (l_cont).Segmentos_Cruzada := r_main.Segmentos_Cruzada;
             l_values (l_cont).Congelar_Grupos := r_main.Congelar_Grupos;
             l_values (l_cont).AUT_INSERC_DINAMICS := r_main.AUT_INSERC_DINAMICS;
             l_values (l_cont).Numero := r_main.Numero;
             l_values (l_cont).Nombre := r_main.Nombre;
             l_values (l_cont).Promp_ventana := r_main.Promp_ventana;
             l_values (l_cont).Columna := r_main.Columna;
             l_values (l_cont).Desplegado := r_main.Desplegado;
             l_values (l_cont).Activado_s := r_main.Activado_s;
             l_values (l_cont).Indexado := r_main.Indexado;
             l_values (l_cont).TIPO := r_main.TIPO;
             l_values (l_cont).DEFECTO := r_main.DEFECTO;
             l_values (l_cont).REQUERIDO := r_main.REQUERIDO;
             l_values (l_cont).SEGURIDA_ACTIVADA := r_main.SEGURIDA_ACTIVADA;
             l_values (l_cont).RANGO := r_main.RANGO;
             l_values (l_cont).DES_TAMANO := r_main.DES_TAMANO;
             l_values (l_cont).TAMANO_DES := r_main.TAMANO_DES;
             l_values (l_cont).TAMANO_CON := r_main.TAMANO_CON;
             l_values (l_cont).L_VALORES := r_main.L_VALORES;
             l_values (l_cont).JUEGO_VALORES := r_main.JUEGO_VALORES;
             l_values (l_cont).DES := r_main.DES;
             l_values (l_cont).NOMBRE_CALIFICADOR := r_main.NOMBRE_CALIFICADOR; --NOMBRE_CALIFICADOR
             l_values (l_cont).CALIFICADOR_ACTIVO := r_main.CALIFICADOR_ACTIVO;
             l_values (l_cont).LAST_UPDATE_DATE := r_main.LAST_UPDATE_DATE;
             l_values (l_cont).NOMBRE_CALIFICADOR := r_main.NOMBRE_CALIFICADOR;
             l_values (l_cont).CREATED_BY := r_main.created_by;
             l_values (l_cont).REQUEST_ID := r_main.request_id; 
             l_values (l_cont).LAST_UPDATED_BY := r_main.last_updated_by;
             l_cont := l_cont + 1;
      END LOOP;



      --Tabla de flex y segmentos............
      FORALL J IN l_values.FIRST .. l_values.LAST          
         INSERT INTO XXCCT_GL_FLEX_SEGMENTOS
              VALUES l_values (J);
              COMMIT;
         
              
   EXCEPTION
      WHEN OTHERS
      THEN
         print_message (g_type_log_summary,
                        'Error en el procedimiento insert_segment : ' || SQLERRM
                       );    
   END insert_segment;


 /****************************************************************
 Procedimiento para el llenado de la tabla Juego de valores
 */
 
 PROCEDURE insert_value_sets (P_NOM_ESTRUCTURA varchar2)
     IS
  CURSOR C_JUEGO_VALORES (P_NOM_ESTRUCTURA VARCHAR2)
   IS
        SELECT FS.ID_FLEX_STRUCTURE_NAME ESTRUCTURA_NOMBRE,
                   convert ( FVAL.DESCRIPTION,'WE8MSWIN1252','UTF8')DESCRIPCION,
                   convert (FVAL.flex_value_set_name,'WE8MSWIN1252','UTF8')NOMBRE_VALORES,
                   DECODE (FVAL.SECURITY_ENABLED_FLAG,   'N', 'No Security',
                                                                                   'H', 'Hierarchical Security',
                                                                                    'Y', 'Non-Hierarchical Security') SEGURIDAD,
               DECODE (FVAL.LONGLIST_FLAG, 'N', 'List of Values', 'Long List of Values') TIPO_DE_LISTA,
               DECODE (FVAL.FORMAT_TYPE, 'C', 'Car' ) TIPO_FORMATO,
               FVAL.MAXIMUM_SIZE TAMANO_MAX,
                DECODE(FVAL.UPPERCASE_ONLY_FLAG, 'N','NO'
                                                                          ,'Y','YES') MAY_O_MIN,
               DECODE (FVAL.NUMERIC_MODE_ENABLED_FLAG, 'N', 'NO', 'Y', 'YES') JUSTIFICACION,
               FVAL.MINIMUM_VALUE VALOR_MINIMO,
               FVAL.MAXIMUM_VALUE VALOR_MAXIMO,
               DECODE (FVAL.VALIDATION_TYPE, 'D', 'Dependent',
                                                                   'F', 'Table',
                                                                   'I', 'Independent',
                                                                   'N', 'None',
                                                                   'P', 'Pair',
                                                                   'U', 'Special',
                                                                   'X', 'Translatable Independent',
                                                                   'Y', 'Translatable Dependent')TIPO_VALIDACION,
               DECODE (FVAL.ALPHANUMERIC_ALLOWED_FLAG,'Y','YES', 'N', 'NO') NUMERICO,
                FVAL.NUMBER_PRECISION PRECISN,
                1 CREATED_BY,
                1 LAST_UPDATED_BY,
                TO_CHAR (SYSDATE, 'DD-MON-YYYY') LAST_UPDATE_DATE ,
                1 REQUEST_ID
       FROM   FND_ID_FLEX_STRUCTURES S,
                  FND_ID_FLEX_STRUCTURES_TL FS,--FLEX ESTRUCTURA LENGUAJE
                  FND_ID_FLEX_SEGMENTS B,   --SEGMENTOS FLEX
                   FND_ID_FLEXS FF,   --FLEX_ID
                   FND_FLEX_VALUE_SETS FVAL -- FLEX VALORES
         WHERE     1 = 1
           AND s.application_id = fs.application_id
           AND S.ID_FLEX_CODE = FS.ID_FLEX_CODE
           AND S.ID_FLEX_num = FS.ID_FLEX_num
           AND S.APPLICATION_ID = B.APPLICATION_ID
           and s.id_flex_code = b.id_flex_code
           and s.id_flex_num = b.id_flex_num                        
           AND S.APPLICATION_ID = FF.APPLICATION_ID
           AND S.ID_FLEX_CODE = Ff.ID_FLEX_CODE
         --  and ff.id_flex_name = 'Accounting Flexfield'
           AND B.FLEX_VALUE_SET_ID = FVAL.FLEX_VALUE_SET_ID   
           AND FS.LANGUAGE = USERENV ('LANG')
           and fs.id_flex_code = 'GL#'
           AND FS.ID_FLEX_STRUCTURE_NAME = P_NOM_ESTRUCTURA;   --GL_ESTRUCTURA_CONTABLE'        
                        

                
         TYPE l_Jval IS TABLE OF C_JUEGO_VALORES%ROWTYPE
                        INDEX BY BINARY_INTEGER;

--- variable l_jvalores
      l_jvalores   l_Jval;
      
        l_contador     NUMBER := 1;

         
BEGIN
      --    DELETE XXCCT_GL_JUEGO_VALORES;
   COMMIT;
   
   FOR C_MAIN IN C_JUEGO_VALORES (P_NOM_ESTRUCTURA)
    LOOP
      FND_FILE.PUT_LINE (FND_FILE.LOG,'LOOP');
      l_jvalores (l_contador).ESTRUCTURA_NOMBRE := C_MAIN.ESTRUCTURA_NOMBRE;          
      l_jvalores  (l_contador).DESCRIPCION  := C_MAIN.DESCRIPCION;
      l_jvalores  (l_contador).NOMBRE_VALORES  := C_MAIN.NOMBRE_VALORES;
      l_jvalores  (l_contador).SEGURIDAD := C_MAIN.SEGURIDAD;
      l_jvalores  (l_contador).TIPO_DE_LISTA  := C_MAIN.TIPO_DE_LISTA;
      l_jvalores  (l_contador).TIPO_FORMATO  := C_MAIN.TIPO_FORMATO;
      l_jvalores  (l_contador).TAMANO_MAX  := C_MAIN.TAMANO_MAX;
      l_jvalores  (l_contador).MAY_O_MIN  := C_MAIN.MAY_O_MIN;
      l_jvalores  (l_contador).JUSTIFICACION  := C_MAIN.JUSTIFICACION;
      l_jvalores (l_contador).VALOR_MINIMO  := C_MAIN.VALOR_MINIMO;
      l_jvalores (l_contador).VALOR_MAXIMO  := C_MAIN.VALOR_MAXIMO;
      l_jvalores (l_contador).TIPO_VALIDACION  := C_MAIN.TIPO_VALIDACION;
       l_jvalores (l_contador).NUMERICO  := C_MAIN.NUMERICO;
      l_jvalores (l_contador).PRECISN  := C_MAIN.PRECISN;
      l_jvalores (l_contador).CREATED_BY := fnd_global.user_id;
      l_jvalores (l_contador).LAST_UPDATED_BY := C_MAIN.LAST_UPDATED_BY;
      l_jvalores (l_contador).LAST_UPDATE_DATE := C_MAIN.LAST_UPDATE_DATE;
      l_jvalores (l_contador).REQUEST_ID := FND_GLOBAL.CONC_REQUEST_ID; 
      
      l_contador := l_contador + 1;
      END LOOP;

      --Tabla de JUEGO DE VALORES............
        FORALL i IN l_jvalores.FIRST .. l_jvalores.LAST    
        INSERT INTO XXCCT_GL_JUEGO_VALORES
        VALUES l_jvalores (i);
        COMMIT;
             
                 EXCEPTION 
                  WHEN OTHERS  THEN
                print_message (g_type_log_summary,
                        'Error en el procedimiento insert_value_sets : ' || SQLERRM
                       );
end insert_value_sets;

--************** INSERTA VALORES DE SEGMENTOS *****************
 procedure inserta_valores_segmentos
 is 
 cursor c_gl_valores_seg is
 SELECT FB.FLEX_VALUE VALOR,--valor
         FT.FLEX_VALUE_MEANING VALOR_TRADUCIDO,--valor traducido
         FT.DESCRIPTION DESCRIPCION,--descripcion
         FB.ENABLED_FLAG ACTIVADO,--activado
         FB.START_DATE_ACTIVE DESDE,--desde
         FB.END_DATE_ACTIVE HASTA,--hasta
         FB.SUMMARY_FLAG PRINCIPAL,--principal
         FB.HIERARCHY_LEVEL NIVEL,--nivel
         FB.STRUCTURED_HIERARCHY_LEVEL GRUPO--grupo
    FROM FND_FLEX_VALUES_TL FT, FND_FLEX_VALUES FB
   WHERE FB.FLEX_VALUE_ID = FT.FLEX_VALUE_ID 
   AND FT.LANGUAGE = USERENV ('LANG')
   AND ( ('' IS NULL)
          OR (structured_hierarchy_level IN
                 (SELECT BH.hierarchy_id
                    FROM FND_FLEX_HIERARCHIES_TL T, FND_FLEX_HIERARCHIES BH
                   WHERE     BH.FLEX_VALUE_SET_ID = T.FLEX_VALUE_SET_ID
                   AND BH.HIERARCHY_ID = T.HIERARCHY_ID
                   AND BH.flex_value_set_id = 1016178
                         AND T.hierarchy_name LIKE '')))
         AND (FB.FLEX_VALUE_SET_ID = 1016178)
ORDER BY FB.flex_value;

TYPE l_valores_seg IS TABLE OF segmentos_contabilidad%ROWTYPE
                        INDEX BY BINARY_INTEGER;
                        
       l_val_seg   l_valores_seg;
      
        l_contador     NUMBER := 1;
                          
 BEGIN      
--           
           -- DELETE XXCCT_GL_CALENDARIO;
           -- COMMIT;
            
            FOR C_CVAL1 IN c_gl_valores_seg
            LOOP
                        l_val_seg  (l_contador).VALOR := C_CVAL1.VALOR;
                        l_val_seg  (l_contador).VALOR_TRADUCIDO := C_CVAL1.VALOR_TRADUCIDO;
                        l_val_seg  (l_contador).DESCRIPCION:= C_CVAL1.DESCRIPCION;
                        l_val_seg  (l_contador).ACTIVADO := C_CVAL1.ACTIVADO;
                        l_val_seg  (l_contador).DESDE := C_CVAL1.DESDE;
                        l_val_seg  (l_contador).HASTA := C_CVAL1.HASTA;
                        l_val_seg  (l_contador).PRINCIPAL := C_CVAL1.PRINCIPAL;
                        l_val_seg  (l_contador).NIVEL := C_CVAL1.NIVEL;
                        l_val_seg  (l_contador).GRUPO := C_CVAL1.GRUPO;

                      l_contador := l_contador + 1;
 end loop;
 
 FORALL i IN l_val_seg.FIRST ..l_val_seg.LAST         
            INSERT INTO  segmentos_contabilidad
              VALUES l_val_seg (i);
              COMMIT;
  
                 EXCEPTION
                  WHEN OTHERS  THEN
                 print_message (g_type_log_summary,
                        'Error en el procedimiento inserta_valores_segmentos : ' || SQLERRM
                       );                     

end inserta_valores_segmentos;


--************** INSERTA tTIPOS DE PERIODOS *****************
 procedure inserta_tipos_periodo
 is 
 cursor C_TIPOS_PERIODOS is
SELECT USER_PERIOD_TYPE tipo_periodo,
         NUMBER_PER_FISCAL_YEAR periodo_por_anio,
         decode(YEAR_TYPE_IN_NAME,'F','Fiscal','Calendario') tipo_anio,
         DESCRIPTION descripcion
    FROM GL_PERIOD_TYPES
   WHERE (USER_PERIOD_TYPE LIKE '%')
ORDER BY user_period_type;

TYPE l_tipos_priod IS TABLE OF tipos_periodo%ROWTYPE
                        INDEX BY BINARY_INTEGER;
                        
       l_tipos_per   l_tipos_priod;
      
        l_contador     NUMBER := 1;
                          
 BEGIN      
--           
           -- DELETE XXCCT_GL_CALENDARIO;
           -- COMMIT;
            
            FOR C_CPER1 IN C_TIPOS_PERIODOS
            LOOP
                        l_tipos_per  (l_contador).tipo_periodo := C_CPER1.tipo_periodo;
                        l_tipos_per  (l_contador).periodo_por_anio := C_CPER1.periodo_por_anio;
                        l_tipos_per  (l_contador).tipo_anio:= C_CPER1.tipo_anio;
                        l_tipos_per  (l_contador).descripcion := C_CPER1.descripcion;

                      l_contador := l_contador + 1;
 end loop;
 
 FORALL i IN l_tipos_per.FIRST ..l_tipos_per.LAST         
            INSERT INTO  tipos_periodo
              VALUES l_tipos_per (i);
              COMMIT;
  
                 EXCEPTION
                  WHEN OTHERS  THEN
                                                 print_message (g_type_log_summary,
                        'Error en el procedimiento inserta_tipos_periodo : ' || SQLERRM
                       );                          

end inserta_tipos_periodo;

/****************************************************************
 inserta calendario contable
 */
 
 PROCEDURE insert_calendary(p_PERIOD_SET_NAME varchar2)
     IS
  CURSOR c_calendario_contable (p_PERIOD_SET_NAME VARCHAR2)
   IS
        SELECT gps.PERIOD_SET_NAME nombre,
          gps.DESCRIPTION descripcion,
          gps.SECURITY_FLAG seguridad, 
          per.period_name nombre_periodo,-- nombre
          per.start_date desde,-- desde
          per.end_date hasta,-- hasta
          pt.user_period_type  tipo, -- tipo
          per.period_year  anio, --anio
          per.period_num numero,-- Nro
          per.quarter_num trimestre,-- trimestre
          per.entered_period_name prefijo, --prefijo
          per.adjustment_period_flag ajuste,--ajuste
          per.period_type tipo_periodo
     FROM gl_periods per, gl_period_types pt,GL_PERIOD_SETS gps
    WHERE per.period_type = pt.period_type
    AND per.PERIOD_SET_NAME = gps.PERIOD_SET_NAME
    AND gps.PERIOD_SET_NAME = p_PERIOD_SET_NAME;
                        

                
         TYPE l_cal_contable IS TABLE OF calendario_contable%ROWTYPE
                        INDEX BY BINARY_INTEGER;

--- variable l_jvalores
      l_calendario   l_cal_contable;
      
        l_contador     NUMBER := 1;

         
BEGIN
      --    DELETE XXCCT_GL_JUEGO_VALORES;
   COMMIT;
   
   FOR C_CAL IN  c_calendario_contable (p_PERIOD_SET_NAME)
    LOOP
      l_calendario (l_contador).nombre := C_CAL.nombre;          
      l_calendario  (l_contador).descripcion  := C_CAL.descripcion;
      l_calendario  (l_contador).seguridad  := C_CAL.seguridad;
      l_calendario  (l_contador).nombre_periodo := C_CAL.nombre_periodo;
      l_calendario  (l_contador).desde  := C_CAL.desde;
      l_calendario  (l_contador).hasta  := C_CAL.hasta;
      l_calendario  (l_contador).tipo  := C_CAL.tipo;
      l_calendario  (l_contador).anio  := C_CAL.anio;
      l_calendario  (l_contador).Numero  := C_CAL.Numero;
      l_calendario (l_contador).trimestre  := C_CAL.trimestre;
      l_calendario (l_contador).prefijo  := C_CAL.prefijo;
      l_calendario (l_contador).ajuste  := C_CAL.ajuste;
       l_calendario (l_contador).tipo_periodo  := C_CAL.tipo_periodo;
      
      l_contador := l_contador + 1;
      END LOOP;

      --Tabla de JUEGO DE VALORES............
        FORALL i IN l_calendario.FIRST .. l_calendario.LAST    
        INSERT INTO calendario_contable
        VALUES l_calendario (i);
        COMMIT;
             
                 EXCEPTION 
                  WHEN OTHERS  THEN
          print_message (g_type_log_summary,
                        'Error en el procedimiento inserta_calendario_contable : ' || SQLERRM
                       );                        
end insert_calendary;


/****************************************************************
 inserta informacion divisas
 */
 
 PROCEDURE inserta_config_divisa (p_libro varchar2)
     IS
  CURSOR c_config_divisa (p_libro VARCHAR2)
   IS
       SELECT DISTINCT Rship.SOURCE_LEDGER_ID,
               Rship.TARGET_CURRENCY_CODE DIVISA,--divisa
               Rship.TARGET_LEDGER_NAME DIVISA_INFORMACION,--nombre de divisa de informacion
               LKup.MEANING CONVERSION_DIVISA,--nivel de conversion de divisa
               DECODE (
                  Rship.relationship_type_code,
                  'BALANCE', 'NA',
                  (DECODE (
                      Rship.RELATIONSHIP_ENABLED_FLAG,
                      'Y', DECODE (Rship.target_ledger_id,
                                   NULL, 'unassignEnabled',
                                   'unassignDisabled'),
                      'unassignDisabled')))
                  DESACTIVAR_CONVERSION,--desactivar conversion
                  Rship.TARGET_LEDGER_CATEGORY_CODE target,
               Lg.DESCRIPTION DESCRIPCION,--descripcion
               Rship.STATUS_CODE ESTADO--estado
          FROM GL_LEDGER_RELATIONSHIPS Rship,
               GL_LEDGER_RELATIONSHIPS SLRship,
               GL_LOOKUPS LKup,
               GL_LEDGERS Lg,
               GL_COA_MAPPINGS COAMap,
               GL_LEDGERS slg,
               GL_LEDGERS sla,
               GL_DAILY_CONVERSION_TYPES dc,
               GL_DAILY_CONVERSION_TYPES dc1,
               GL_DAILY_CONVERSION_TYPES dc2,
               GL_DAILY_CONVERSION_TYPES dc3
         WHERE     Rship.RELATIONSHIP_TYPE_CODE = LKup.LOOKUP_CODE
               AND Rship.SL_COA_MAPPING_ID = COAMap.COA_MAPPING_ID(+)
               AND LKup.LOOKUP_TYPE = 'GL_ASF_SL_RELATIONSHIP_LEVEL'
               AND Rship.APPLICATION_ID = fnd_global.resp_appl_id ----101
               AND Rship.TARGET_LEDGER_ID = Lg.LEDGER_ID
               AND SLRship.SOURCE_LEDGER_ID(+) = Rship.TARGET_LEDGER_ID
               AND SLRship.target_currency_code(+) =
                      Rship.target_currency_code
               AND SLRship.RELATIONSHIP_TYPE_CODE(+) =
                      Rship.relationship_type_code
               AND SLRship.TARGET_LEDGER_CATEGORY_CODE(+) = 'SECONDARY'
               AND SLRship.relationship_enabled_flag(+) = 'Y'
               AND slg.ledger_id = Rship.source_ledger_id
               AND sla.ledger_id = Rship.sla_ledger_id
               AND dc.conversion_type(+) = Rship.alc_default_conv_rate_type
               AND dc1.conversion_type(+) = Rship.ALC_INITIALIZING_RATE_TYPE
               AND dc2.conversion_type(+) = Rship.ALC_PERIOD_END_RATE_TYPE
               AND dc3.conversion_type(+) = Rship.ALC_PERIOD_AVERAGE_RATE_TYPE
               AND slg.name = p_libro
               AND Rship.TARGET_LEDGER_CATEGORY_CODE = 'ALC';
                        

                
         TYPE l_conf_divisa IS TABLE OF configuracion_divisa%ROWTYPE
                        INDEX BY BINARY_INTEGER;

--- variable l_jvalores
      l_divisa   l_conf_divisa;
      
        l_contador     NUMBER := 1;

         
BEGIN
      --    DELETE XXCCT_GL_JUEGO_VALORES;
   COMMIT;
   
   FOR C_DIV IN  c_config_divisa (p_libro)
    LOOP
      l_divisa (l_contador).SOURCE_LEDGER_ID := C_DIV.SOURCE_LEDGER_ID;          
      l_divisa  (l_contador).DIVISA  := C_DIV.DIVISA;
      l_divisa  (l_contador).DIVISA_INFORMACION  := C_DIV.DIVISA_INFORMACION;
      l_divisa  (l_contador).CONVERSION_DIVISA := C_DIV.CONVERSION_DIVISA;
      l_divisa  (l_contador).DESACTIVAR_CONVERSION  := C_DIV.DESACTIVAR_CONVERSION;
      l_divisa  (l_contador).target  := C_DIV.target;
      l_divisa  (l_contador).DESCRIPCION  := C_DIV.DESCRIPCION;
      l_divisa  (l_contador).ESTADO  := C_DIV.ESTADO;
      
      l_contador := l_contador + 1;
      END LOOP;

      --Tabla de JUEGO DE VALORES............
        FORALL i IN l_divisa.FIRST .. l_divisa.LAST    
        INSERT INTO configuracion_divisa
        VALUES l_divisa (i);
        COMMIT;
             
                 EXCEPTION 
                  WHEN OTHERS  THEN
                  print_message (g_type_log_summary,
                        'Error en el procedimiento inserta_config_divisa : ' || SQLERRM
                       );  
         
end inserta_config_divisa;

/****************************************************************
 inserta segmento a cuadrar
 */
 
 PROCEDURE inserta_seg_cuadrar(p_libro varchar2)
     IS
  CURSOR c_seg_cu (p_libro VARCHAR2)
   IS
       SELECT GLLedgerBSVEO.SEGMENT_VALUE segmento_cuadrar,-- valor de segmento a cuadrar
       GLLedgerBSVEO.START_DATE fecha_inicial,-- fecha inicial
       GLLedgerBSVEO.END_DATE fecha_final,--fecha final
       lep.name descripcion--descripcion
  FROM GL_LEDGER_CONFIG_DETAILS GLLedgerConfigDetailsEO,
       GL_LEDGER_NORM_SEG_VALS GLLedgerBSVEO,
       XLE_ENTITY_PROFILES lep,
       GL_LEDGER_CONFIGURATIONS glc,
       gl_ledgers lg
 WHERE     GLLedgerConfigDetailsEO.OBJECT_TYPE_CODE = 'LEGAL_ENTITY'
  and GLLedgerBSVEO.ledger_id = LG.LEDGER_ID
       AND lep.legal_entity_id = GLLedgerConfigDetailsEO.OBJECT_ID
       AND lep.legal_entity_id = GLLedgerBSVEO.legal_entity_id
       AND GLLedgerConfigDetailsEO.CONFIGURATION_ID = lg.CONFIGURATION_ID
       and lg.name = p_libro
       AND glc.configuration_id = GLLedgerConfigDetailsEO.CONFIGURATION_ID;
                        

                
         TYPE l_seg_cuad IS TABLE OF segmento_cuadrar%ROWTYPE
                        INDEX BY BINARY_INTEGER;

--- variable l_jvalores
      l_segmento   l_seg_cuad;
      
        l_contador     NUMBER := 1;

         
BEGIN
      --    DELETE XXCCT_GL_JUEGO_VALORES;
   COMMIT;
   
   FOR C_SE IN  c_seg_cu (p_libro)
    LOOP
      l_segmento (l_contador).segmento_cuadrar := C_SE.segmento_cuadrar;          
      l_segmento  (l_contador).fecha_inicial  := C_SE.fecha_inicial;
      l_segmento  (l_contador).fecha_final  := C_SE.fecha_final;
      l_segmento  (l_contador).descripcion := C_SE.descripcion;
      
      l_contador := l_contador + 1;
      END LOOP;

      --Tabla de JUEGO DE VALORES............
        FORALL i IN l_segmento.FIRST .. l_segmento.LAST    
        INSERT INTO segmento_cuadrar
        VALUES l_segmento (i);
        COMMIT;
             
                 EXCEPTION 
                  WHEN OTHERS  THEN
          print_message (g_type_log_summary,
                        'Error en el procedimiento inserta_seg_cuadrar : ' || SQLERRM
                       );  
         
end inserta_seg_cuadrar;


/****************************************************************
 inserta unidades operativas
 */
 
 PROCEDURE inserta_unidades_operativas(p_libro varchar2)
     IS
  CURSOR c_uni_op (p_libro VARCHAR2)
   IS
       SELECT hroutl_bg.name grupo_negocios,--grupo de negocios
       hroutl_ou.name unidad_operativa,-- nombre unidad operativa
       XFI.name contexto_legal,--contexto legal por defecto
       hro.short_code codigo_breve-- codigo breve de unidad operativa
  FROM hr_operating_units hro,
       XLE_ENTITY_PROFILES XFI,
       hr_all_organization_units_tl hroutl_bg,
       hr_all_organization_units_tl hroutl_ou,
       HR_ORGANIZATION_UNITS GLOperatingUnitsEO,
       gl_ledgers gl
 WHERE     XFI.legal_entity_id = hro.default_legal_context_id
       AND GLOperatingUnitsEO.organization_id = hro.organization_id
       AND hroutl_bg.organization_id = hro.business_group_id
       AND hroutl_ou.organization_id = hro.organization_id
       AND gl.ledger_id = hro.set_of_books_id
       AND hroutl_bg.language = USERENV ('LANG')
       AND hroutl_ou.language = USERENV ('LANG')
       AND gl.name = p_libro;
                        

                
         TYPE l_uni_op IS TABLE OF unidades_operativas%ROWTYPE
                        INDEX BY BINARY_INTEGER;

--- variable l_jvalores
      l_unidades   l_uni_op;
      
        l_contador     NUMBER := 1;

         
BEGIN
      --    DELETE XXCCT_GL_JUEGO_VALORES;
   COMMIT;
   
   FOR C_UNI IN  c_uni_op (p_libro)
    LOOP
      l_unidades (l_contador).grupo_negocios := C_UNI.grupo_negocios;          
      l_unidades  (l_contador).unidad_operativa  := C_UNI.unidad_operativa;
      l_unidades  (l_contador).contexto_legal  := C_UNI.contexto_legal;
      l_unidades  (l_contador).codigo_breve := C_UNI.codigo_breve;
      
      l_contador := l_contador + 1;
      END LOOP;

      --Tabla de JUEGO DE VALORES............
        FORALL i IN l_unidades.FIRST .. l_unidades.LAST    
        INSERT INTO unidades_operativas
        VALUES l_unidades (i);
        COMMIT;
             
                 EXCEPTION 
                  WHEN OTHERS  THEN
         print_message (g_type_log_summary,
                        'Error en el procedimiento inserta_unidades_operativas : ' || SQLERRM
                       );  
         
end inserta_unidades_operativas;

/****************************************************************
 inserta cuetas compañias intracompañias y secuenciacion
 */
 
 PROCEDURE inserta_cuentas_compania(p_libro varchar2)
     IS
  CURSOR c_com (p_libro VARCHAR2)
   IS
       SELECT LG.LEDGER_ID,
            primDet.OBJECT_NAME mayor_primario,--nombre mayor primario
            lg.CURRENCY_CODE divisa,--divisa
            le.NAME entidad_legal,--entidad legal
            hrlocTL.LOCATION_CODE direccion,-- direccion
            fifs.ID_FLEX_STRUCTURE_NAME plan_cuentas,--plan de cuentas
            lg.PERIOD_SET_NAME calendario,--calendario
            t.name metodo_submayor,--metodo contable de submayor
            LE.LE_INFORMATION_CONTEXT pais--pais
            --falta evento de secuencia - entidad de secuencia
     FROM GL_LEDGER_CONFIG_DETAILS primDet,
          GL_LEDGERS lg,
          xla_acctg_methods_tl t,
          GL_LEDGER_RELATIONSHIPS rs,
          GL_LEDGER_CONFIGURATIONS cfg,
          GL_LEDGER_CONFIG_DETAILS cfgDet,
          XLE_ENTITY_PROFILES le,
          XLE_REGISTRATIONS reg,
          HR_LOCATIONS_ALL_TL hrlocTL,
          FND_ID_FLEX_STRUCTURES_TL fifs  
    wHERE rs.application_id = fnd_global.resp_appl_id----101
          AND ( (rs.target_ledger_category_code = 'SECONDARY'
                 AND rs.relationship_type_code <> 'NONE')
               OR (rs.target_ledger_category_code = 'PRIMARY'
                   AND rs.relationship_type_code = 'NONE')
               OR (rs.target_ledger_category_code = 'ALC'
                   AND rs.relationship_type_code IN ('JOURNAL', 'SUBLEDGER')))
          AND lg.ledger_id = rs.target_ledger_id
          AND lg.ledger_category_code = rs.target_ledger_category_code
          AND NVL (lg.complete_flag, 'Y') = 'Y'
          AND primDet.object_id = rs.primary_ledger_id
          AND primDet.object_type_code = 'PRIMARY'
          AND primDet.setup_step_code = 'NONE'
          AND cfg.configuration_id = primDet.configuration_id
          AND cfgDet.configuration_id(+) = cfg.configuration_id
          AND cfgDet.object_type_code(+) = 'LEGAL_ENTITY'
          AND le.legal_entity_id(+) = cfgDet.object_id
          AND reg.source_id(+) = cfgDet.object_id
          AND reg.source_table(+) = 'XLE_ENTITY_PROFILES'
          AND reg.identifying_flag(+) = 'Y'
          AND hrlocTL.location_id(+) = reg.location_id
          AND fifs.ID_FLEX_NUM = lg.CHART_OF_ACCOUNTS_ID
          AND fifs.APPLICATION_ID = fnd_global.resp_appl_id---101
          AND fifs.ID_FLEX_CODE = 'GL#'
          AND t.ACCOUNTING_METHOD_CODE(+) = lg.SLA_ACCOUNTING_METHOD_CODE
          AND t.ACCOUNTING_METHOD_TYPE_CODE(+) = lg.SLA_ACCOUNTING_METHOD_TYPE
          AND fifs.LANGUAGE = USERENV ('LANG')
          AND hrlocTL.language(+) = USERENV ('LANG')
          AND t.language = USERENV ('LANG')
          and  lg.NAME = p_libro ;
                        

                
         TYPE l_comp_sec IS TABLE OF compania_intra_secuensiacion%ROWTYPE
                        INDEX BY BINARY_INTEGER;

--- variable l_jvalores
      l_company   l_comp_sec;
      
        l_contador     NUMBER := 1;

         
BEGIN
      --    DELETE XXCCT_GL_JUEGO_VALORES;
   COMMIT;
   
   FOR C_CM IN  c_com (p_libro)
    LOOP
      l_company (l_contador).LEDGER_ID := C_CM.LEDGER_ID;          
      l_company  (l_contador).mayor_primario  := C_CM.mayor_primario;
      l_company  (l_contador).divisa  := C_CM.divisa;
      l_company  (l_contador).entidad_legal := C_CM.entidad_legal;
      l_company (l_contador).direccion := C_CM.direccion;          
      l_company  (l_contador).plan_cuentas  := C_CM.plan_cuentas;
      l_company  (l_contador).calendario  := C_CM.calendario;
      l_company  (l_contador).metodo_submayor := C_CM.metodo_submayor;
      l_company  (l_contador).pais := C_CM.pais;
      
      l_contador := l_contador + 1;
      END LOOP;

      --Tabla de JUEGO DE VALORES............
        FORALL i IN l_company.FIRST .. l_company.LAST    
        INSERT INTO compania_intra_secuensiacion
        VALUES l_company (i);
        COMMIT;
             
                 EXCEPTION 
                  WHEN OTHERS  THEN
                  print_message (g_type_log_summary,
                        'Error en el procedimiento inserta_cuentas_compania : ' || SQLERRM
                       );  
         
end inserta_cuentas_compania;

/****************************************************************
 inserta cuentas contables
 */
 
 PROCEDURE inserta_cuentas_contables
     IS
  CURSOR c_cuentas_con
   IS
       select decode(cc.ENABLED_FLAG,'Y','Si','No')  Activado  
        ,decode(cc.SUMMARY_FLAG,'Y','Si','No') Preservado
        ,cc.SEGMENT1||'.'||
         cc.SEGMENT2||'.'||
         cc.SEGMENT3||'.'||
         cc.SEGMENT4||'.'||
         cc.SEGMENT5||'.'||
         cc.SEGMENT6 Cuenta
        ,lk.DESCRIPTION Tipo
        ,cc.START_DATE_ACTIVE Fecha_desde
        ,cc.END_DATE_ACTIVE Fecha_Hasta
        ,decode(cc.DETAIL_POSTING_ALLOWED_FLAG,'Y','Si', 'No') Autorizar_contabilizacion
        ,decode (cc.DETAIL_BUDGETING_ALLOWED_FLAG,'Y','Si', 'No') Autorizar_presupuesto
        ,cc.ALTERNATE_CODE_COMBINATION_ID Cuenta_alterna
       ,decode(cc.JGZZ_RECON_FLAG,'Y','Si', 'No')Conciliar
   FROM gl_code_combinations cc, gl_lookups lk
    WHERE     lk.lookup_type(+) = 'ACCOUNT TYPE'
       AND lk.lookup_code(+) = cc.ACCOUNT_TYPE
       AND CHART_OF_ACCOUNTS_ID = get_chart_of_accounts_id
       AND TEMPLATE_ID IS NULL;
--       AND (CODE_COMBINATION_ID IN
--               (SELECT CODE_COMBINATION_ID
--                  FROM GL_CODE_COMBINATIONS
--                 WHERE     1 = 1
--                       AND (SEGMENT1 LIKE '%' OR SEGMENT1 IS NULL)
--                       AND CHART_OF_ACCOUNTS_ID = 50669));
                        

                
         TYPE l_cuen_con IS TABLE OF cuentas_contables%ROWTYPE
                        INDEX BY BINARY_INTEGER;

--- variable l_jvalores
      l_contables   l_cuen_con;
      
        l_contador     NUMBER := 1;

         
BEGIN
      --    DELETE XXCCT_GL_JUEGO_VALORES;
   COMMIT;
   
   FOR C_CU IN  c_cuentas_con
    LOOP
      l_contables (l_contador).Activado := C_CU.Activado;          
      l_contables  (l_contador).Preservado  := C_CU.Preservado;
      l_contables  (l_contador).cuenta  := C_CU.cuenta;
      l_contables  (l_contador).Tipo := C_CU.Tipo;
      l_contables (l_contador).Fecha_desde := C_CU.Fecha_desde;          
      l_contables  (l_contador).Fecha_Hasta  := C_CU.Fecha_Hasta;
      l_contables  (l_contador).Autorizar_contabilizacion  := C_CU.Autorizar_contabilizacion;
      l_contables  (l_contador).Autorizar_presupuesto := C_CU.Autorizar_presupuesto;
      l_contables  (l_contador).Cuenta_alterna := C_CU.Cuenta_alterna;
       l_contables  (l_contador).Conciliar := C_CU.Conciliar;
      
      l_contador := l_contador + 1;
      END LOOP;

      --Tabla de JUEGO DE VALORES............
        FORALL i IN l_contables.FIRST .. l_contables.LAST    
        INSERT INTO cuentas_contables
        VALUES l_contables (i);
        COMMIT;
             
                 EXCEPTION 
                  WHEN OTHERS  THEN
                           print_message (g_type_log_summary,
                        'Error en el procedimiento inserta_cuentas_contables : ' || SQLERRM
                       );  
         
end inserta_cuentas_contables;

/****************************************************************
 inserta cambio diario
 */
 
 PROCEDURE inserta_cambio_diario
     IS
  CURSOR c_cambio_diario
   IS
      SELECT distinct primary.from_currency desde,--desde
          primary.to_currency hasta,--hasta
          primary.conversion_date fecha,--fecha
          ct.user_conversion_type tipo,--tipo
          ROUND (primary.conversion_rate, 10) usd_hasta_mxn,--usd a mxp
          ROUND (secondary.conversion_rate, 10) mxn_hasta_usd--mxp a usd
     FROM gl_daily_rates secondary,
          gl_daily_rates primary,
          gl_daily_conversion_types ct
    WHERE     secondary.to_currency = primary.from_currency || ''
          AND secondary.from_currency = primary.to_currency || ''
          AND secondary.conversion_date = primary.conversion_date + 0
          AND secondary.conversion_type = primary.conversion_type || ''
          AND ct.conversion_type = primary.conversion_type || '';
                        

                
         TYPE l_cambio_d IS TABLE OF cambio_diario%ROWTYPE
                        INDEX BY BINARY_INTEGER;

--- variable l_jvalores
      l_cambio   l_cambio_d;
      
        l_contador     NUMBER := 1;

         
BEGIN
      --    DELETE XXCCT_GL_JUEGO_VALORES;
   COMMIT;
   
   FOR C_CA IN  c_cambio_diario
    LOOP
      l_cambio (l_contador).desde := C_CA.desde;          
      l_cambio  (l_contador).hasta  := C_CA.hasta;
      l_cambio  (l_contador).fecha  := C_CA.fecha;
      l_cambio  (l_contador).tipo := C_CA.tipo;
      l_cambio (l_contador).usd_hasta_mxn := C_CA.usd_hasta_mxn;          
      l_cambio  (l_contador).mxn_hasta_usd  := C_CA.mxn_hasta_usd;
      
      l_contador := l_contador + 1;
      END LOOP;

      --Tabla de JUEGO DE VALORES............
        FORALL i IN l_cambio.FIRST .. l_cambio.LAST    
        INSERT INTO cambio_diario
        VALUES l_cambio (i);
        COMMIT;
             
                 EXCEPTION 
                  WHEN OTHERS  THEN
         print_message (g_type_log_summary,
                        'Error en el procedimiento inserta_cambio_diario : ' || SQLERRM
                       );  
end inserta_cambio_diario;

/****************************************************************
 inserta organizaciones presupuestos
 */
 
 PROCEDURE inserta_organizaciones_presup(p_libro varchar2)
     IS
  CURSOR c_org_pre(p_libro varchar2)
   IS
      select gbe.name organizacion,--organizacion
         gbe.description descripcion,--descripcion
         gbe.security_flag activar_seguridad,--activar seguridad
         gl.name mayor,--mayor
         gbe.budget_password_required_flag activado,--activado
         gbe.start_date desde,--desde
         gbe.end_date hasta,--hasta
         (gbe.segment1_type ||'.'|| 
         gbe.segment2_type||'.'||
         gbe.segment3_type||'.'||
         gbe.segment4_type||'.'||
         gbe.segment5_type||'.'||
         gbe.segment6_type||'.'||
         gbe.segment7_type||'.'||
         gbe.segment8_type||'.'||
         gbe.segment9_type||'.'||
         gbe.segment10_type)  cuenta
from gl_budget_entities gbe, gl_ledgers gl
where gbe.ledger_id = gl.ledger_id
and gl.name = p_libro;
                        

                
         TYPE l_org_pre IS TABLE OF organizaciones_presupuesto%ROWTYPE
                        INDEX BY BINARY_INTEGER;

--- variable l_jvalores
      l_organizaciones   l_org_pre;
      
        l_contador     NUMBER := 1;

         
BEGIN
      --    DELETE XXCCT_GL_JUEGO_VALORES;
   COMMIT;
   
   FOR C_OR IN  c_org_pre(p_libro)
    LOOP
      l_organizaciones (l_contador).organizacion := C_OR.organizacion;          
      l_organizaciones  (l_contador).descripcion  := C_OR.descripcion;
      l_organizaciones  (l_contador).activar_seguridad  := C_OR.activar_seguridad;
      l_organizaciones  (l_contador).mayor := C_OR.mayor;
      l_organizaciones (l_contador).activado := C_OR.activado;          
      l_organizaciones  (l_contador).desde  := C_OR.desde;
      l_organizaciones (l_contador).hasta := C_OR.hasta;          
      l_organizaciones  (l_contador).cuenta  := C_OR.cuenta;
      
      l_contador := l_contador + 1;
      END LOOP;

      --Tabla de JUEGO DE VALORES............
        FORALL i IN l_organizaciones.FIRST .. l_organizaciones.LAST    
        INSERT INTO organizaciones_presupuesto
        VALUES l_organizaciones (i);
        COMMIT;
             
                 EXCEPTION 
                  WHEN OTHERS  THEN
         print_message (g_type_log_summary,
                        'Error en el procedimiento inserta_organizaciones_presup : ' || SQLERRM
                       ); 
         
end inserta_organizaciones_presup;


/****************************************************************
 inserta rangos
 */
 
 PROCEDURE inserta_rangos(p_libro varchar2)
     IS
  CURSOR c_rangos(p_libro varchar2)
   IS
      SELECT 
          BAR.SEQUENCE_NUMBER LINEA,--linea
          BAR.CURRENCY_CODE DIVISA,--divisa
          BAR.ENTRY_CODE TIPO,--tipo
          (BAR.SEGMENT1_LOW|| '.' ||
          BAR.SEGMENT2_LOW|| '.' ||
          BAR.SEGMENT3_LOW|| '.' ||
          BAR.SEGMENT4_LOW|| '.' ||
          BAR.SEGMENT5_LOW|| '.' ||
          BAR.SEGMENT6_LOW) INFERIOR,--inferior
          (BAR.SEGMENT1_HIGH|| '.' ||
          BAR.SEGMENT2_HIGH|| '.' ||
          BAR.SEGMENT3_HIGH|| '.' ||
          BAR.SEGMENT4_HIGH|| '.' ||
          BAR.SEGMENT5_HIGH|| '.' ||
          BAR.SEGMENT6_HIGH) SUPERIOR--superior
     FROM GL_BUDGET_ASSIGNMENT_RANGES BAR, gl_ledgers gl
     WHERE bar.ledger_id = gl.ledger_id
     and gl.name = p_libro;
                        

                
         TYPE l_rangos IS TABLE OF rangos%ROWTYPE
                        INDEX BY BINARY_INTEGER;

--- variable l_jvalores
      l_rang   l_rangos;
      
        l_contador     NUMBER := 1;

         
BEGIN
      --    DELETE XXCCT_GL_JUEGO_VALORES;
   COMMIT;
   
   FOR C_RA IN  c_rangos(p_libro)
    LOOP
      l_rang (l_contador).LINEA := C_RA.LINEA;          
      l_rang  (l_contador).DIVISA  := C_RA.DIVISA;
      l_rang  (l_contador).TIPO  := C_RA.TIPO;
      l_rang  (l_contador).INFERIOR := C_RA.INFERIOR;
      l_rang (l_contador).SUPERIOR := C_RA.SUPERIOR;          
      
      l_contador := l_contador + 1;
      END LOOP;

      --Tabla de JUEGO DE VALORES............
        FORALL i IN l_rang.FIRST .. l_rang.LAST    
        INSERT INTO rangos
        VALUES l_rang (i);
        COMMIT;
             
                 EXCEPTION 
                  WHEN OTHERS  THEN
                  print_message (g_type_log_summary,
                        'Error en el procedimiento inserta_rangos : ' || SQLERRM
                       ); 
         
         
end inserta_rangos;

/****************************************************************
 inserta asignaciones
 */
 
 PROCEDURE inserta_asignaciones
     IS
  CURSOR c_asignaciones
   IS
      SELECT
          ba.currency_code DIVISA,--divisa
          ba.entry_code TIPO,--tipo
          (cc.segment1 || '.' ||
          cc.segment2 || '.' ||
          cc.segment3 || '.' ||
          cc.segment4 || '.' ||
          cc.segment5 || '.' ||
          cc.segment6) CUENTA-- cuenta
     FROM gl_budget_assignments ba, gl_code_combinations cc
     WHERE cc.code_combination_id = ba.code_combination_id
     AND (ba.BUDGET_ENTITY_ID = 3000)
ORDER BY ba.ordering_value, cc.code_combination_id;
                        

                
         TYPE l_asignaciones IS TABLE OF asignaciones%ROWTYPE
                        INDEX BY BINARY_INTEGER;

--- variable l_jvalores
      l_asig   l_asignaciones;
      
        l_contador     NUMBER := 1;

         
BEGIN
      --    DELETE XXCCT_GL_JUEGO_VALORES;
   COMMIT;
   
   FOR C_ASG IN  c_asignaciones
    LOOP
      l_asig (l_contador).DIVISA := C_ASG.DIVISA;          
      l_asig  (l_contador).TIPO  := C_ASG.TIPO;
      l_asig  (l_contador).CUENTA  := C_ASG.CUENTA;       
      
      l_contador := l_contador + 1;
      END LOOP;

      --Tabla de JUEGO DE VALORES............
        FORALL i IN l_asig.FIRST .. l_asig.LAST    
        INSERT INTO asignaciones
        VALUES l_asig (i);
        COMMIT;
             
                 EXCEPTION 
                  WHEN OTHERS  THEN
         print_message (g_type_log_summary,
                        'Error en el procedimiento inserta_asignaciones : ' || SQLERRM
                       ); 
         
end inserta_asignaciones;

/***************************************************************/

PROCEDURE INSERTA_CALENDARIO (  P_PERIOD_SET_NAME VARCHAR2)
is 
   CURSOR C_GL_CALENDAR (P_PERIOD_SET_NAME VARCHAR2)
   IS
      SELECT TP.user_period_type TIPO_PERIODO,
                 TP.number_per_fiscal_year PERIODOS_POR_ANIO,
                  DECODE (TP.year_type_in_name,  'C', 'Calendar',  'F', 'Fiscal')  TIPO_ANIO,
                  convert (TP.DESCRIPTION,'WE8MSWIN1252','UTF8') TIPO_PERIODO_DESCRIP,
                   convert (PS.period_set_name,'WE8MSWIN1252','UTF8') CALENDARIO,
                  PS.SECURITY_FLAG SEGURIDAD,
                   convert (PS.description,'WE8MSWIN1252','UTF8') DESCRIPCION,
                  SUBSTR (PER.entered_period_name, 1, 3) PREFIJO,
                convert (PER.period_type,'WE8MSWIN1252','UTF8') TIPO_PERIODO_per,
                 PER.period_year ANIO,
                 convert (PER.quarter_num,'WE8MSWIN1252','UTF8') TRIMESTRE,
                 TO_CHAR (PER.start_date, 'DD-MON-YYYY') DESDE,
                 TO_CHAR (PER.end_date, 'DD-MON-YYYY') HASTA,
              convert (PER.entered_period_name,'WE8MSWIN1252','UTF8')NOMBRE_PERIODO_entered,
                  DECODE (PER.adjustment_period_flag,  'Y', 'Yes',  'N', 'No') AJUSTE_PERIODO,
                 PER.period_num NUMERO_PERIODO,
                 convert (PER.period_name,'WE8MSWIN1252','UTF8')  NOMBRE_PERIODO,
                 convert (PER.period_set_name,'WE8MSWIN1252','UTF8') NOMBRE_PERIODO_per,
                 convert (PS.description,'WE8MSWIN1252','UTF8') CUENTA_CALENDARIO_DESCRIP,
                TO_CHAR (SYSDATE, 'DD-MON-YYYY') LAST_UPDATE_DATE,
                1 LAST_UPDATED_BY,
                1 CREATED_BY,
                1 REQUEST_ID
        FROM GL_PERIODS PER, GL_PERIOD_TYPES TP, GL_PERIOD_SETS PS
       WHERE     1 = 1
             AND PER.PERIOD_TYPE = TP.PERIOD_TYPE
             AND PER.PERIOD_SET_NAME = PS.PERIOD_SET_NAME
             AND PER.PERIOD_SET_NAME =P_PERIOD_SET_NAME
             AND PS.DESCRIPTION = 'GL CALENDARIO CONTABLE';
--            oRDER BY TP.user_period_type,PS.period_set_name;

TYPE l_calend IS TABLE OF C_GL_CALENDAR%ROWTYPE
                        INDEX BY BINARY_INTEGER;

      l_calendario   l_calend;
      
        l_contador     NUMBER := 1;
                          
 BEGIN      
--           
           -- DELETE XXCCT_GL_CALENDARIO;
           -- COMMIT;
            
            FOR C_CALD1 IN C_GL_CALENDAR (P_PERIOD_SET_NAME)
            LOOP
                        l_calendario  (l_contador).TIPO_PERIODO := C_CALD1.TIPO_PERIODO;
                        l_calendario  (l_contador).PERIODOS_POR_ANIO := C_CALD1.PERIODOS_POR_ANIO;
                        l_calendario  (l_contador).TIPO_ANIO:= C_CALD1.TIPO_ANIO;
                        l_calendario  (l_contador).TIPO_PERIODO_DESCRIP := C_CALD1.TIPO_PERIODO_DESCRIP;
                        l_calendario  (l_contador).CALENDARIO := C_CALD1.CALENDARIO;
                        l_calendario  (l_contador).SEGURIDAD := C_CALD1.SEGURIDAD;
                        l_calendario  (l_contador).DESCRIPCION := C_CALD1.descripcion;
                        l_calendario  (l_contador).PREFIJO := C_CALD1.PREFIJO;
                        l_calendario  (l_contador).TIPO_PERIODO_per := C_CALD1.TIPO_PERIODO_per;
                        l_calendario  (l_contador).ANIO := C_CALD1.ANIO;
                        l_calendario  (l_contador).TRIMESTRE:= C_CALD1.TRIMESTRE;
                        l_calendario  (l_contador).DESDE := C_CALD1.DESDE;
                        l_calendario  (l_contador).HASTA := C_CALD1.HASTA;
                        l_calendario  (l_contador).NOMBRE_PERIODO_entered := C_CALD1.NOMBRE_PERIODO_entered;
                        l_calendario  (l_contador).AJUSTE_PERIODO := C_CALD1.AJUSTE_PERIODO;
                        l_calendario  (l_contador).NUMERO_PERIODO:= C_CALD1.NUMERO_PERIODO;
                         l_calendario  (l_contador).NOMBRE_PERIODO_per := C_CALD1.NOMBRE_PERIODO_per;
                        l_calendario  (l_contador).NOMBRE_PERIODO := C_CALD1.NOMBRE_PERIODO;
                        l_calendario  (l_contador).TIPO_PERIODO_per := C_CALD1.TIPO_PERIODO_per;
                        l_calendario  (l_contador).CUENTA_CALENDARIO_DESCRIP := C_CALD1.CUENTA_CALENDARIO_DESCRIP;
                        l_calendario (l_contador).LAST_UPDATE_DATE := C_CALD1.LAST_UPDATE_DATE;
                        l_calendario (l_contador).LAST_UPDATED_BY := C_CALD1.LAST_UPDATED_BY; 
                         l_calendario (l_contador).CREATED_BY := fnd_global.user_id;
                        l_calendario (l_contador).REQUEST_ID := FND_GLOBAL.CONC_REQUEST_ID; 

                      l_contador := l_contador + 1;
 end loop; 
-- 


      --Tabla de Calendarios............
            FORALL i IN l_calendario.FIRST ..l_calendario.LAST         
            INSERT INTO  XXCCT_GL_CALENDARIO
              VALUES l_calendario (i);
              COMMIT;
        
               

  
                 EXCEPTION
                  WHEN OTHERS  THEN
                                print_message (g_type_log_summary,
                        'Error en el procedimiento INSERTA_CALENDARIO : ' || SQLERRM
                       ); 
 end INSERTA_CALENDARIO;
/* *******************************************************************************************  
Procedimineto del llenado de la tabla tempora de las cuentas contables*/

 PROCEDURE INSERTAR_TABLA_ENTIDADES
   IS
      CURSOR c_entidad 
      IS
      select  xep.NAME  LEGAL_NAME
          ,hp.party_name ORGANIZATION_NAME
          ,xep.legal_entity_identifier LEGAL_ENTITY_IDENTIFIER 
          ,convert (T.TERRITORY_SHORT_NAME,'WE8MSWIN1252','UTF8') Pais
          ,convert (loc.address_line_1||','||loc.address_line_2||decode(nvl(loc.address_line_2,'x'),'x','',',')||loc.address_line_3||decode(nvl(loc.address_line_3,'y'),'y','',',')
                                      ||loc.town_or_city||','||loc.country||','||t.territory_short_name||','||loc.country ,'WE8MSWIN1252','UTF8') REGISTERED_ADDRESS
         ,xep.LEGAL_ENTITY_ID
         ,hp.party_number ORGANIZATION_NUMBER   
         ,reg.registration_number Numero_Registro  
         ,xetbp.name ESTABLISHMENT_NAME 
        ,xep.activity_code
        ,xl.MEANING Legal_type
        ,jtl.name JURISDICTION
        ,jur.registration_code_le CODE
        ,decode(xep.TRANSACTING_ENTITY_FLAG,'N','No','Si') Transacting_flag
        ,xep.EFFECTIVE_FROM Inception_Date
        ,1 CREATED_BY
        ,1 REQUEST_ID
        ,TO_CHAR (SYSDATE, 'DD-MON-YYYY') LAST_UPDATE_DATE
        ,1 LAST_UPDATED_BY
        ,xep.LE_INFORMATION2 Divisa
        ,xep.EFFECTIVE_TO Fecha_Final
        ,xep.ACTIVITY_CODE Actividad_Primaria
        ,xep.TYPE_OF_COMPANY Tipo_compania
        ,xep.LE_INFORMATION1 Capital_acciones
        ,xep.LE_INFORMATION3 Final_Ano
     from xle_entity_profiles xep
        ,hz_parties hp
        ,xle_registrations reg
        ,hr_locations loc
        ,FND_TERRITORIES_TL T
        ,xle_etb_profiles xetbp
        ,XLE_LOOKUPS xl
        ,xle_jurisdictions_b jur
       ,xle_jurisdictions_tl jtl
 where 1=1
-- and hg.geography_id = xep.geography_id
  AND hp.party_id = xep.party_id      
  AND reg.source_id = xep.legal_entity_id
  AND reg.location_id = loc.location_id
  AND t.territory_code = loc.country
 -- AND reg.source_id = xep.legal_entity_id
  AND reg.source_id=xep.legal_entity_id
  AND reg.location_id = loc.location_id
  AND reg.source_id=xetbp.legal_entity_id
  AND reg.jurisdiction_id = jur.jurisdiction_id
  AND jur.jurisdiction_id=jtl.jurisdiction_id
  AND xl.LOOKUP_TYPE = 'XLE_LEGAL_TYPE'
  AND T.LANGUAGE = USERENV ('LANG')
  AND jtl.LANGUAGE = USERENV ('LANG');
  
  
    TYPE l_entidades IS TABLE OF c_entidad%ROWTYPE
                        INDEX BY BINARY_INTEGER;

      l_valuesen   l_entidades;


      l_conent     NUMBER := 1;
      
       BEGIN
      FOR r_ent IN c_entidad
      
      LOOP
            
       l_valuesen (l_conent).LEGAL_NAME := r_ent.LEGAL_NAME;
       l_valuesen (l_conent).ORGANIZATION_NAME := r_ent.ORGANIZATION_NAME;
       l_valuesen (l_conent).LEGAL_ENTITY_IDENTIFIER := r_ent.LEGAL_ENTITY_IDENTIFIER;
       l_valuesen (l_conent).Pais := replace_char(r_ent.Pais);
       l_valuesen (l_conent).REGISTERED_ADDRESS := replace_char(r_ent.REGISTERED_ADDRESS);
       l_valuesen (l_conent).LEGAL_ENTITY_ID := r_ent.LEGAL_ENTITY_ID;
       l_valuesen (l_conent).ORGANIZATION_NUMBER := r_ent.ORGANIZATION_NUMBER;
       l_valuesen (l_conent).Numero_Registro := r_ent.Numero_Registro;
       l_valuesen (l_conent).ESTABLISHMENT_NAME := r_ent.ESTABLISHMENT_NAME;
       l_valuesen (l_conent).activity_code := r_ent.activity_code;
       l_valuesen (l_conent).Legal_type := r_ent.Legal_type;
       l_valuesen (l_conent).JURISDICTION := r_ent.JURISDICTION;      
       l_valuesen (l_conent).CODE := r_ent.CODE; 
       l_valuesen (l_conent).Transacting_flag := r_ent.Transacting_flag; 
       l_valuesen (l_conent).Inception_Date := r_ent.Inception_Date;   
       l_valuesen (l_conent).LAST_UPDATE_DATE  := r_ent.LAST_UPDATE_DATE;
       l_valuesen (l_conent).CREATED_BY := fnd_global.user_id;
       l_valuesen (l_conent).REQUEST_ID := FND_GLOBAL.CONC_REQUEST_ID;
       l_valuesen (l_conent).LAST_UPDATED_BY  := r_ent.LAST_UPDATED_BY;
       l_valuesen (l_conent).Divisa  := r_ent.Divisa;
       l_valuesen (l_conent).Fecha_Final  := r_ent.Fecha_Final;
       l_valuesen (l_conent).Actividad_Primaria  := r_ent.Actividad_Primaria;
       l_valuesen (l_conent).Tipo_compania  := r_ent.Tipo_compania;
       l_valuesen (l_conent).Capital_acciones  := r_ent.Capital_acciones;
       l_valuesen (l_conent).Final_Ano  := r_ent.Final_Ano;
         
        l_conent := l_conent + 1;
         
        end loop;
        
        
             --Tabla de Entidades Legales............
      FORALL Y IN l_valuesen.FIRST .. l_valuesen.LAST           
         INSERT INTO XXCCT_ENTIDADES_LEGALES_T
              VALUES l_valuesen (Y);
              COMMIT;
            
              
   EXCEPTION
      WHEN OTHERS
      THEN
         print_message (g_type_log_summary,
                        'Error en el procedimiento INSERTAR_TABLA_ENTIDADES : ' || SQLERRM
                       ); 
         
         
           END INSERTAR_TABLA_ENTIDADES ;
 /*
 =============================
 Procedimiento para la inserccion de los libros en la tabla temporal
 */

 PROCEDURE INSERTA_LIBROSR (P_BOOK_NAME VARCHAR2)
IS 
    CURSOR C_LIBROS (P_BOOK_NAME VARCHAR2)
       IS 
           SELECT    ledgers.ledger_id,
                -- <Definición Libro>
               convert  (ledgers.name,'WE8MSWIN1252','UTF8') mayor,
              convert (gllookups.meaning,'WE8MSWIN1252','UTF8') tipo_mayor,
               convert (glcd.object_name,'WE8MSWIN1252','UTF8') libro_mayor,
               DECODE (
                   glconfig.completion_status_code,
                   'NOT_STARTED', 'notstartedind_status.gif',
                   'UPDATED', 'inprogressind_status.gif',
                   'IN_PROGRESS', 'inprogressind_status.gif',
                   'CONFIRMED', DECODE (
                                   ledgers.ledger_category_code,
                                   'SECONDARY', DECODE (
                                                   ledgers.complete_flag,
                                                   'N','NO',-- 'inprogressind_status.gif',
                                                  'Y'), 'YES' --'okind_status.gif'),
                                   --'okind_status.gif'
                                   ))
                   AS ESTADO,
                -- <Informacion Estándar >
               --ledgers.name mayor,
             convert (ledgers.short_name,'WE8MSWIN1252','UTF8') abreviatura,
               convert (ledgers.description,'WE8MSWIN1252','UTF8') descripcion,
               ledgers.currency_code divisa,
              convert (coa.id_flex_structure_name,'WE8MSWIN1252','UTF8') plan_de_cuentas,
               
               -- <Calendario Contable>
               convert (ledgers.period_set_name,'WE8MSWIN1252','UTF8') calendario_contable,
               ledgers.accounted_period_type tipo_periodo,
               ledgers.first_ledger_period_name primer_periodo_abierto,
               ledgers.future_enterable_periods_limit num_per_ingresables_futuros,
               
               --<Opciones Contables de Submayor>
               convert (t.name,'WE8MSWIN1252','UTF8') met_contable_submayor,
               convert (xl.meaning,'WE8MSWIN1252','UTF8') propie_cont_submayor,                
               convert (fnd.description,'WE8MSWIN1252','UTF8') idioma_asiento_diario,
               (select  segment1 || '-'||segment2||'-'||segment3||'-'||segment4||'-'||segment5||'-'||segment6||'-'||segment7 from gl_code_combinations where code_combination_id = ledgers.sla_entered_cur_bal_sus_ccid) cta_cuadrar_divisa_ingresada,
               DECODE(ledgers.sla_ledger_cash_basis_flag,'Y','Activado','Desactivado')   usar_cont_base_efectivo,
               DECODE(ledgers.sla_bal_by_ledger_curr_flag,'Y','Activado','Desactivado')  saldar_ing_submay_divisa_mayor,--
               (select  segment1 || '-'||segment2||'-'||segment3||'-'||segment4||'-'||segment5||'-'||segment6||'-'||segment7 from gl_code_combinations where code_combination_id = ledgers.sla_ledger_cur_bal_sus_ccid) cuenta_cuadrar_divisa_mayor,
               
               --<Procesamiento de fin de año>
               (select  segment1 || '-'||segment2||'-'||segment3||'-'||segment4||'-'||segment5||'-'||segment6||'-'||segment7 from gl_code_combinations where code_combination_id = ledgers.ret_earn_code_combination_id)  cuenta_ganancias_retenidas,
               
               --<Procesamiento de Asiento>
               (select  segment1 || '-'||segment2||'-'||segment3||'-'||segment4||'-'||segment5||'-'||segment6||'-'||segment7 from gl_code_combinations where code_combination_id = ledgers.sla_ledger_cur_bal_sus_ccid) cuenta_transitoria,
               (select  segment1 || '-'||segment2||'-'||segment3||'-'||segment4||'-'||segment5||'-'||segment6||'-'||segment7 from gl_code_combinations where code_combination_id = ledgers.rounding_code_combination_id) cuenta_diferencias_redondeo,--DUDA
               DECODE(ledgers.allow_intercompany_post_flag,'Y','Activado','Desactivado')  balance_intracompania,
               DECODE(ledgers.enable_je_approval_flag,'Y','Activado','Desactivado')  aprobacion_asiento,
               DECODE(ledgers.enable_automatic_tax_flag,'Y','Activado','Desactivado')  impuesto_asiento_diario,
               convert (autorev.criteria_set_name,'WE8MSWIN1252','UTF8') juego_crit_revision_asientos,

               --<Opcion de traslación de divisa>
               ledgers.period_end_rate_type clase_tipo_cambio_final,
               ledgers.period_average_rate_type clase_tipo_cambio_prom,
               (select  segment1 || '-'||segment2||'-'||segment3||'-'||segment4||'-'||segment5||'-'||segment6||'-'||segment7 from gl_code_combinations where code_combination_id = ledgers.cum_trans_code_combination_id) cta_ajus_trans,
               
               --<Conciliacion de asiento>
               DECODE(ledgers.enable_reconciliation_flag,'Y','Activado','Desactivado')  conciliacion_asiento,
               
               --<Control presupuestario>
                DECODE(ledgers.enable_budgetary_control_flag,'Y','Activado','Desactivado')  control_presupuestario,
               (select  segment1 || '-'||segment2||'-'||segment3||'-'||segment4||'-'||segment5||'-'||segment6||'-'||segment7 from gl_code_combinations where code_combination_id = ledgers.res_encumb_code_combination_id)   reserva_promesas,
                DECODE(ledgers.require_budget_journals_flag,'Y','Activado','Desactivado')  requerir_asientos_presupuesto,
                
               --<Saldos promedio>
               DECODE(ledgers.enable_average_balances_flag,'Y','Activado','Desactivado')  saldos_promedio,
               DECODE(ledgers.consolidation_ledger_flag,'Y','Activado','Desactivado')  consolidacion_saldo_promedio,
               (select  segment1 || '-'||segment2||'-'||segment3||'-'||segment4||'-'||segment5||'-'||segment6||'-'||segment7 from gl_code_combinations where code_combination_id = ledgers.net_income_code_combination_id) cuenta_ingresos_netos,
               gltcv.name calendario_transacciones,
                              
               --<Opciones de traslación>
                ledgers.daily_translation_rate_type clase_tipo_cambio,
                DECODE(ledgers.translate_eod_flag,'Y','Activado','Desactivado') mantener_importe_final,
                DECODE(ledgers.translate_qatd_flag,'Y','Activado','Desactivado') mant_imp_acum_prom_trim,
                DECODE(ledgers.translate_yatd_flag,'Y','Activado','Desactivado') mant_imp_acum_prom_anual,
--                 Rship.TARGET_LEDGER_NAME NOM_DIVISA_INF,  --NOMBRE DIVISA INFORMACION
--                 LKup.MEANING RELATIONSHIP_LEVEL_MEANING , --NIVEL DE CONVERSION DE DIVISA
                    
                  
                TO_CHAR (SYSDATE, 'DD-MON-YYYY') LAST_UPDATE_DATE,
                10000 LAST_UPDATED_BY,
                10000 CREATED_BY,
                100000000 REQUEST_ID
                
               
          FROM gl_ledgers ledgers,
               xla_acctg_methods_tl t,
               fnd_languages_tl fnd,
               fnd_id_flex_structures_vl coa,
               gl_transaction_calendar gltcv,
               gl_suspense_accounts sus,
               gl_period_types gpt,
               xla_lookups xl,
               gl_autorev_criteria_sets autorev
               ,gl_ledger_configurations glconfig
               ,gl_ledger_config_details glcd
               ,GL_LOOKUPS gllookups
               --,GL_LEDGER_RELATIONSHIPS Rship

         WHERE ledgers.Sla_Accounting_Method_Type =
                  t.accounting_method_type_code(+)
               AND ledgers.Sla_Accounting_Method_Code =
                      t.accounting_method_code(+)
               AND NVL (t.language, USERENV ('LANG')) = USERENV ('LANG')
               AND ledgers.SLA_DESCRIPTION_LANGUAGE =
                      fnd.language_code(+)
               AND fnd.source_lang(+) = USERENV ('LANG')
               AND ledgers.CHART_OF_ACCOUNTS_ID = coa.id_flex_num
               AND coa.application_id = fnd_global.resp_appl_id----101
               AND coa.id_flex_code = 'GL#'
               AND coa.enabled_flag = 'Y'
               AND ledgers.TRANSACTION_CALENDAR_ID =
                      gltcv.transaction_calendar_id(+)
               AND sus.LEDGER_ID(+) = ledgers.LEDGER_ID
               AND sus.JE_SOURCE_NAME(+) = 'Other'
               AND sus.JE_CATEGORY_NAME(+) = 'Other'
               AND gpt.period_type = ledgers.ACCOUNTED_PERIOD_TYPE
               AND xl.lookup_type(+) = 'XLA_OWNER_TYPE'
               AND ledgers.SLA_ACCOUNTING_METHOD_TYPE = xl.lookup_code(+)
               AND ledgers.CRITERIA_SET_ID = autorev.CRITERIA_SET_ID(+)               
               AND glconfig.configuration_id = ledgers.configuration_id
               AND glcd.configuration_id = glconfig.configuration_id
               AND glcd.object_type_code = 'PRIMARY'
               AND glcd.setup_step_code = 'NONE'               
               AND GLLookups.lookup_type = 'GL_ASF_LEDGER_CATEGORY'
               AND GLLookups.lookup_code = ledgers.ledger_category_code 
               AND ledgers.NAME= P_BOOK_NAME;
    
             TYPE l_lib IS TABLE OF C_LIBROS%ROWTYPE
                                     INDEX BY BINARY_INTEGER;


      l_libros l_lib;
       l_contador     NUMBER := 1;
         
 BEGIN       
        
   
          COMMIT;
   
               FOR C_LIB IN C_LIBROS (P_BOOK_NAME)
                LOOP
           
                                    l_libros(l_contador).LEDGER_ID :=C_LIB.LEDGER_ID;
                                    l_libros(l_contador).MAYOR :=C_LIB.MAYOR;
                                    l_libros(l_contador).TIPO_MAYOR :=C_LIB.TIPO_MAYOR;
                                    l_libros(l_contador).LIBRO_MAYOR :=C_LIB.LIBRO_MAYOR;
                                    l_libros(l_contador).ESTADO :=C_LIB.ESTADO;
                                    l_libros(l_contador).ABREVIATURA :=C_LIB.ABREVIATURA;
                                    l_libros(l_contador).DESCRIPCION :=C_LIB.DESCRIPCION;
                                    l_libros(l_contador).DIVISA :=C_LIB.DIVISA;
                                    l_libros(l_contador).PLAN_DE_CUENTAS :=C_LIB.PLAN_DE_CUENTAS;
                                    l_libros(l_contador).CALENDARIO_CONTABLE :=C_LIB.CALENDARIO_CONTABLE;
                                    l_libros(l_contador).TIPO_PERIODO :=C_LIB.TIPO_PERIODO;
                                    l_libros(l_contador).PRIMER_PERIODO_ABIERTO :=C_LIB.PRIMER_PERIODO_ABIERTO;
                                    l_libros(l_contador).NUM_PER_INGRESABLES_FUTUROS :=C_LIB.NUM_PER_INGRESABLES_FUTUROS;
                                    l_libros(l_contador).MET_CONTABLE_SUBMAYOR :=C_LIB.MET_CONTABLE_SUBMAYOR;
                                    l_libros(l_contador).PROPIE_CONT_SUBMAYOR :=C_LIB.PROPIE_CONT_SUBMAYOR;
                                    l_libros(l_contador).IDIOMA_ASIENTO_DIARIO :=C_LIB.IDIOMA_ASIENTO_DIARIO;
                                    l_libros(l_contador).CTA_CUADRAR_DIVISA_INGRESADA :=C_LIB.CTA_CUADRAR_DIVISA_INGRESADA;
                                    l_libros(l_contador).USAR_CONT_BASE_EFECTIVO :=C_LIB.USAR_CONT_BASE_EFECTIVO;
                                    l_libros(l_contador).SALDAR_ING_SUBMAY_DIVISA_MAYOR :=C_LIB.SALDAR_ING_SUBMAY_DIVISA_MAYOR;
                                    l_libros(l_contador).CUENTA_CUADRAR_DIVISA_MAYOR :=C_LIB.CUENTA_CUADRAR_DIVISA_MAYOR;
                                    l_libros(l_contador).CUENTA_GANANCIAS_RETENIDAS :=C_LIB.CUENTA_GANANCIAS_RETENIDAS;
                                    l_libros(l_contador).CUENTA_TRANSITORIA :=C_LIB.CUENTA_TRANSITORIA;
                                    l_libros(l_contador).CUENTA_DIFERENCIAS_REDONDEO :=C_LIB.CUENTA_DIFERENCIAS_REDONDEO;
                                    l_libros(l_contador).BALANCE_INTRACOMPANIA :=C_LIB.BALANCE_INTRACOMPANIA;
                                    l_libros(l_contador).APROBACION_ASIENTO :=C_LIB.APROBACION_ASIENTO;
                                    l_libros(l_contador).IMPUESTO_ASIENTO_DIARIO :=C_LIB.IMPUESTO_ASIENTO_DIARIO;
                                    l_libros(l_contador).JUEGO_CRIT_REVISION_ASIENTOS :=C_LIB.JUEGO_CRIT_REVISION_ASIENTOS;
                                    l_libros(l_contador).CLASE_TIPO_CAMBIO_FINAL :=C_LIB.CLASE_TIPO_CAMBIO_FINAL;
                                    l_libros(l_contador).CLASE_TIPO_CAMBIO_PROM :=C_LIB.CLASE_TIPO_CAMBIO_PROM;
                                    l_libros(l_contador).CTA_AJUS_TRANS :=C_LIB.CTA_AJUS_TRANS;
                                    l_libros(l_contador).CONCILIACION_ASIENTO :=C_LIB.CONCILIACION_ASIENTO;
                                    l_libros(l_contador).CONTROL_PRESUPUESTARIO :=C_LIB.CONTROL_PRESUPUESTARIO;
                                    l_libros(l_contador).RESERVA_PROMESAS :=C_LIB.RESERVA_PROMESAS;
                                    l_libros(l_contador).REQUERIR_ASIENTOS_PRESUPUESTO :=C_LIB.REQUERIR_ASIENTOS_PRESUPUESTO;
                                    l_libros(l_contador).SALDOS_PROMEDIO :=C_LIB.SALDOS_PROMEDIO;
                                    l_libros(l_contador).CONSOLIDACION_SALDO_PROMEDIO :=C_LIB.CONSOLIDACION_SALDO_PROMEDIO;
                                    l_libros(l_contador).CUENTA_INGRESOS_NETOS :=C_LIB.CUENTA_INGRESOS_NETOS;
                                    l_libros(l_contador).CALENDARIO_TRANSACCIONES :=C_LIB.CALENDARIO_TRANSACCIONES;
                                    l_libros(l_contador).CLASE_TIPO_CAMBIO :=C_LIB.CLASE_TIPO_CAMBIO;
                                    l_libros(l_contador).MANTENER_IMPORTE_FINAL :=C_LIB.MANTENER_IMPORTE_FINAL;
                                    l_libros(l_contador).MANT_IMP_ACUM_PROM_TRIM :=C_LIB.MANT_IMP_ACUM_PROM_TRIM;
                                    l_libros(l_contador).MANT_IMP_ACUM_PROM_ANUAL :=C_LIB.MANT_IMP_ACUM_PROM_ANUAL;
                                    l_libros (l_contador).LAST_UPDATE_DATE := C_LIB.LAST_UPDATE_DATE;
                                    l_libros (l_contador).LAST_UPDATED_BY := C_LIB.LAST_UPDATED_BY; 
                                    l_libros (l_contador).CREATED_BY := fnd_global.user_id;
                                    l_libros (l_contador).REQUEST_ID := FND_GLOBAL.CONC_REQUEST_ID; 
                                    
                                 l_contador := l_contador + 1;
             end loop;               
                                    
                                        
                                
                   --Tabla de Libros.........
                    FORALL i IN l_libros.FIRST .. l_libros.LAST    
                    INSERT INTO XXCCT_GL_LIBROSR
                    VALUES l_libros (i);
                    COMMIT;
              
                      
                      EXCEPTION
                                         WHEN OTHERS   THEN
                print_message (g_type_log_summary,
                        'Error en el procedimiento INSERTA_LIBROSR : ' || SQLERRM
                       );                                              
 END    INSERTA_LIBROSR ;
 
 
 /*
 
 Procedimineto del llenado de la tabla temporal de los perfiles*/
 procedure  INSERTAR_TABLA_PROFILES (P_RESPONSABILIDADES varchar2)
                                 
    IS
     
    CURSOR C_PROFILES  (P_RESPONSABILIDADES varchar2)
   
      IS
      SELECT USER_PROFILE_OPTION_NAME NOMBRE
                 ,PROFILE_OPTION_VALUE Valor_aplication
                 ,1 CREATED_BY
                 ,1 REQUEST_ID
                 ,TO_CHAR (SYSDATE, 'DD-MON-YYYY') LAST_UPDATE_DATE
               ,1 LAST_UPDATED_BY
 FROM fnd_profile_option_values V
         ,FND_PROFILE_OPTIONS_TL fpot
         ,FND_PROFILE_OPTIONS fpo
 WHERE V.profile_option_id = fpo.profile_option_id
      AND fpo.PROFILE_OPTION_NAME = fpot.PROFILE_OPTION_NAME
      AND fpot.LANGUAGE = USERENV ('LANG')
      AND V.application_id = fpo.application_id
      AND V.level_value = 
                                  (SELECT RESPONSIBILITY_ID 
                                    FROM fnd_responsibility_tl
                                         WHERE 1=1
                                    AND application_id=fnd_global.resp_appl_id---101 
                                    AND responsibility_name= P_RESPONSABILIDADES 
                                    AND LANGUAGE=USERENV ('LANG'))
    AND V.level_value_application_id = fnd_global.resp_appl_id;---101;
     
     TYPE l_profiles IS TABLE OF C_PROFILES%ROWTYPE
                        INDEX BY BINARY_INTEGER;

             l_prof l_profiles;

      l_conp NUMBER := 1;
    
    
      BEGIN
   
 
      FOR r_perfiles IN C_PROFILES (P_RESPONSABILIDADES)
      
      LOOP
                
        
       l_prof (l_conp).NOMBRE := r_perfiles.NOMBRE;
       l_prof (l_conp).Valor_aplication := r_perfiles.Valor_aplication;
       l_prof (l_conp).LAST_UPDATE_DATE  := r_perfiles.LAST_UPDATE_DATE;
       l_prof (l_conp).CREATED_BY := fnd_global.user_id;
       l_prof (l_conp).REQUEST_ID := FND_GLOBAL.CONC_REQUEST_ID;
       l_prof (l_conp).LAST_UPDATED_BY  := r_perfiles.LAST_UPDATED_BY;
       
          l_conp := l_conp + 1; 
        
        END LOOP;



      --Tabla de Perfiles............
      FORALL Y IN l_prof.FIRST .. l_prof.LAST           
         INSERT INTO XXCCT_PROFILES_T
              VALUES l_prof (Y);
              COMMIT;
            
              
   EXCEPTION
      WHEN OTHERS
      THEN
         print_message (g_type_log_summary,
                        'Error en el procedimiento INSERTAR_TABLA_PROFILES : ' || SQLERRM
                       ); 
  
 END INSERTAR_TABLA_PROFILES;
 /*
 Procedimiento para insertar en la tabla temporarl el abrir y cerrar de los periodos
 */
 
 
PROCEDURE INSERTA_CERR_ABR (P_BOOK_NAME VARCHAr2)
IS
      CURSOR C_CER_ABR  (P_BOOK_NAME VARCHAR2)
           IS
              SELECT P.PERIOD_YEAR ANIO_PERIODO
                ,P.PERIOD_NAME NOMBRE_PERIODO
                ,P.PERIOD_NUM NUM_PERIODO
                ,P.START_DATE INICO_PER
                ,P.END_DATE FIN_PER
                ,LD.NAME LIBRO 
                , LD.LEDGER_ID ID_LIBRO
                ,DECODE (PS.CLOSING_STATUS ,'O', 'Open'
                                                                , 'C', 'Closed'
                                                                ,'F', 'Future'
                                                                ,'N', 'Never' ) ESTATUS
                ,1 CREATED_BY
                , 1 LAST_UPDATED_BY
               ,TO_CHAR (SYSDATE, 'DD-MON-YYYY') LAST_UPDATE_DATE 
               ,1 REQUEST_ID                                                      
FROM GL_LEDGERS LD
            ,GL_PERIOD_STATUSES PS
            ,GL_PERIOD_SETS PES
            ,GL_PERIODS P
WHERE   1= 1
            AND LD.NAME =P_BOOK_NAME--'PL_AHM'
            AND  LD.LEDGER_ID = PS.LEDGER_ID
            AND PS.APPLICATION_ID = fnd_global.resp_appl_id----101
            AND PES.PERIOD_SET_NAME = LD.PERIOD_SET_NAME
            AND P.PERIOD_SET_NAME = PES.PERIOD_SET_NAME
            AND P.PERIOD_NAME = PS.PERIOD_NAME
            AND PS.END_DATE =(SELECT MAX(PS2.END_DATE)
                                             FROM GL_PERIOD_STATUSES PS2
                                            WHERE PS2.LEDGER_ID = PS.LEDGER_ID
                                            AND PS2.APPLICATION_ID = PS.APPLICATION_ID
                                            AND PS2.CLOSING_STATUS = 'O');
                                       
           TYPE l_CeAb IS TABLE OF C_CER_ABR%ROWTYPE
                        INDEX BY BINARY_INTEGER;

          l_per_ca   l_CeAb;
           l_contador     NUMBER := 1;
                   

BEGIN
          

-- DELETE XXCCT_GL_CERRAR_ABRIR;
          COMMIT;
   
               FOR R_CA IN C_CER_ABR (P_BOOK_NAME)
               
                LOOP
                  
                  
                            l_per_ca  (l_contador).ANIO_PERIODO  := R_CA.ANIO_PERIODO;
                            l_per_ca  (l_contador).NOMBRE_PERIODO  := R_CA.NOMBRE_PERIODO;
                            l_per_ca  (l_contador).NUM_PERIODO  := R_CA.NUM_PERIODO;
                            l_per_ca  (l_contador).INICO_PER  := R_CA.INICO_PER;
                            l_per_ca  (l_contador).FIN_PER  := R_CA.FIN_PER;
                            l_per_ca  (l_contador).LIBRO  := R_CA.LIBRO;
                            l_per_ca  (l_contador).ID_LIBRO  := R_CA.ID_LIBRO;
                            l_per_ca  (l_contador).ESTATUS  := R_CA.ESTATUS;
                            l_per_ca  (l_contador).CREATED_BY  := R_CA.CREATED_BY;
                            l_per_ca  (l_contador).LAST_UPDATED_BY  := R_CA.LAST_UPDATED_BY;
                            l_per_ca  (l_contador).LAST_UPDATE_DATE  := R_CA.LAST_UPDATE_DATE;
                            l_per_ca  (l_contador).REQUEST_ID  := FND_GLOBAL.CONC_REQUEST_ID;

                          l_contador := l_contador + 1;
             end loop;               
                           
                        
             
      --Tabla de  CERRAR Y ABRIR PERIODOS............
        FORALL i IN l_per_ca.FIRST ..l_per_ca.LAST     --..l_per_ca.COUNT 
        INSERT INTO XXCCT_GL_CERRAR_ABRIR
        VALUES l_per_ca (i);
        COMMIT;
                               

                      EXCEPTION
                                         WHEN OTHERS   THEN
                                           print_message (g_type_log_summary,
                        'Error en el procedimiento INSERTA_CERR_ABR : ' || SQLERRM
                       ); 
                                   
  END INSERTA_CERR_ABR;
/*
*/

 PROCEDURE INSERTAR_DIVISAS (P_BOOK_NAME VARCHAR2)
IS 
        CURSOR C_DIVISAS (P_BOOK_NAME VARCHAR2)
        IS         
                        SELECT  CU.CURRENCY_CODE  CODIGO_DIVISA
                                     ,TCU.NAME DIVISA
                                     ,CU.DESCRIPTION DESCRIPCION
                                    ,CU.ISSUING_TERRITORY_CODE TERRITORIO_DIV
                                    ,CU.SYMBOL SIMBOLO
                                    ,CU.PRECISION  PRECISION_DIV
                                    ,CU.EXTENDED_PRECISION PRECISION_EXT
                                    ,CU.MINIMUM_ACCOUNTABLE_UNIT  UNIDAD_MIN
                                    ,CU.DERIVE_TYPE   TIPO_DIV
                                       ,CU.DERIVE_FACTOR FACTOR
                                       ,CU.DERIVE_EFFECTIVE EFECTIVO
                                       ,CU.START_DATE_ACTIVE FECHA_INICIO
                                       ,CU.END_DATE_ACTIVE FECHA_FIN
                                       ,CU.ENABLED_FLAG ACTIVO
                                       ,1 CREATED_BY
                                        ,1 LAST_UPDATED_BY
                                        ,TO_CHAR (SYSDATE, 'DD-MON-YYYY') LAST_UPDATE_DATE 
                                       , 1 REQUEST_ID
                         FROM   FND_CURRENCIES_TL  TCU
                                   , FND_CURRENCIES CU
                                   , GL_LEDGERS GL
                        WHERE 1=1
                                  AND   CU.CURRENCY_CODE = TCU.CURRENCY_CODE
                                  AND GL.CURRENCY_CODE = CU.CURRENCY_CODE
                                  AND CU.ENABLED_FLAG ='Y'
                                  AND TCU.LANGUAGE = USERENV ('LANG')
                                  AND GL.NAME ='PL_AHM';---P_BOOK_NAME;
                                  --PL_AHM

  
  TYPE l_div IS TABLE OF C_DIVISAS%ROWTYPE
                        INDEX BY BINARY_INTEGER;

--- variable l_jvalores
      l_divisas  l_div;
       l_contador     NUMBER := 1;
         
 BEGIN       
        
          DELETE XXCCT_GL_DIVISAS;
   COMMIT;
   
   FOR C_DIV IN C_DIVISAS (P_BOOK_NAME)
    LOOP
  
      
            l_divisas (l_contador).CODIGO_DIVISA := C_DIV.CODIGO_DIVISA;
            l_divisas (l_contador).DIVISA := C_DIV.DIVISA;
            l_divisas (l_contador).DESCRIPCION := C_DIV.DESCRIPCION;
            l_divisas (l_contador).TERRITORIO_DIV := C_DIV.TERRITORIO_DIV;
            l_divisas (l_contador).SIMBOLO := C_DIV.SIMBOLO;
            l_divisas (l_contador).PRECISION_DIV := C_DIV.PRECISION_DIV;
            l_divisas (l_contador).PRECISION_EXT := C_DIV.PRECISION_EXT;
            l_divisas (l_contador).UNIDAD_MIN := C_DIV.UNIDAD_MIN;
            l_divisas (l_contador).TIPO_DIV := C_DIV.TIPO_DIV;
            l_divisas (l_contador).FACTOR := C_DIV.FACTOR;
            l_divisas (l_contador).EFECTIVO := C_DIV.EFECTIVO;
            l_divisas (l_contador).FECHA_INICIO := C_DIV.FECHA_INICIO;
            l_divisas (l_contador).FECHA_FIN := C_DIV.FECHA_FIN;
            l_divisas (l_contador).ACTIVO := C_DIV.ACTIVO;
            l_divisas (l_contador).CREATED_BY := C_DIV.CREATED_BY;
            l_divisas (l_contador).LAST_UPDATED_BY := C_DIV.LAST_UPDATED_BY;
            l_divisas (l_contador).LAST_UPDATE_DATE := C_DIV.LAST_UPDATE_DATE;
            l_divisas (l_contador).REQUEST_ID := FND_GLOBAL.CONC_REQUEST_ID;

                  
      l_contador := l_contador + 1;
      END LOOP;

      --Tabla de Divisas............
        FORALL i IN l_divisas.FIRST .. l_divisas.LAST     
        INSERT INTO XXCCT_GL_DIVISAS
        VALUES l_divisas (i);
        COMMIT;
  
   EXCEPTION
      WHEN OTHERS   THEN
print_message (g_type_log_summary,
                        'Error en el procedimiento INSERTAR_DIVISAS : ' || SQLERRM
                       ); 
 END     INSERTAR_DIVISAS;


 /*
  Procedimineto del llenado de la tabla temporal del origen del asiento
 */

 PROCEDURE INSERTAR_TABLA_ORIGEN_ASIENTO
    IS
      CURSOR C_ORIGEN 
          IS
    select USER_JE_SOURCE_NAME Origen
            ,JE_SOURCE_KEY Clave_Origen
             ,DESCRIPTION Descripcion 
            ,decode (JOURNAL_REFERENCE_FLAG, 'Y','*',' ') Importar_referencias
            ,JOURNAL_APPROVAL_FLAG Requerir_Aprovacion 
            ,IMPORT_USING_KEY_FLAG Importar_clave
            ,decode (OVERRIDE_EDITS_FLAG,'N', 'No','Si') Congelar_Asiento
            ,1 CREATED_BY
            ,1 REQUEST_ID
            ,TO_CHAR (SYSDATE, 'DD-MON-YYYY') LAST_UPDATE_DATE
            ,1 LAST_UPDATED_BY
  from gl_je_sources_tl
      where 1=1
       and language = USERENV ('LANG');
     
      TYPE l_origen IS TABLE OF C_ORIGEN%ROWTYPE
       INDEX BY BINARY_INTEGER;

      l_valorigen   l_origen;


      l_conorigen     NUMBER := 1;
      
       BEGIN
      FOR r_origen IN C_ORIGEN
      
      LOOP
      
         l_valorigen (l_conorigen).Origen := r_origen.Origen;
         l_valorigen (l_conorigen).Clave_Origen := r_origen.Clave_Origen;
         l_valorigen (l_conorigen).Descripcion := r_origen.Descripcion;
         l_valorigen (l_conorigen).Importar_referencias := r_origen.Importar_referencias;
         l_valorigen (l_conorigen).Requerir_Aprovacion := r_origen.Requerir_Aprovacion;
         l_valorigen (l_conorigen).Importar_clave := r_origen.Importar_clave;  
         l_valorigen (l_conorigen).Congelar_Asiento := r_origen.Congelar_Asiento;
         l_valorigen (l_conorigen).LAST_UPDATE_DATE := r_origen.LAST_UPDATE_DATE;  
         l_valorigen (l_conorigen).CREATED_BY := fnd_global.user_id;
         l_valorigen (l_conorigen).REQUEST_ID := FND_GLOBAL.CONC_REQUEST_ID; 
         l_valorigen (l_conorigen).LAST_UPDATED_BY := r_origen.LAST_UPDATED_BY;
        
         l_conorigen := l_conorigen + 1;  
        
      end loop;
        -- Tabla Origen del asiento  
        FORALL J IN l_valorigen.FIRST .. l_valorigen.LAST         
         INSERT INTO XXCCT_ORIGEN_ASIENTO_T
              VALUES l_valorigen (J);
              COMMIT;
        
     EXCEPTION
        WHEN OTHERS THEN
		print_message (g_type_log_summary,
                        'Error en el procedimiento INSERTAR_TABLA_ORIGEN_ASIENTO : ' || SQLERRM
                       ); 
  
 END INSERTAR_TABLA_ORIGEN_ASIENTO;   
 /* *******************************************************************************************  
Procedimineto del llenado de la tabla temporal de las categorias*/
 
 PROCEDURE INSERTAR_TABLA_CATEGORIA
             IS
      CURSOR C_CATEGORIA
          IS
   select USER_JE_CATEGORY_NAME
           ,JE_CATEGORY_KEY
           ,DESCRIPTION
           ,1 CREATED_BY
           ,1 REQUEST_ID
           ,TO_CHAR (SYSDATE, 'DD-MON-YYYY') LAST_UPDATE_DATE
           ,1 LAST_UPDATED_BY
   from GL_JE_CATEGORIES
     where 1=1 
    and language = USERENV ('LANG');
     
      TYPE l_categoria IS TABLE OF C_CATEGORIA%ROWTYPE
       INDEX BY BINARY_INTEGER;

      l_valcat   l_categoria;

      l_concat     NUMBER := 1;
      
       BEGIN
      
      FOR r_cat IN C_CATEGORIA
      
      LOOP
                  
         l_valcat (l_concat).USER_JE_CATEGORY_NAME := r_cat.USER_JE_CATEGORY_NAME;
         l_valcat (l_concat).JE_CATEGORY_KEY := r_cat.JE_CATEGORY_KEY;
         l_valcat (l_concat).DESCRIPTION := r_cat.DESCRIPTION;
         l_valcat (l_concat).LAST_UPDATE_DATE := r_cat.LAST_UPDATE_DATE;  
         l_valcat (l_concat).CREATED_BY := fnd_global.user_id;
         l_valcat (l_concat).REQUEST_ID := FND_GLOBAL.CONC_REQUEST_ID; 
         l_valcat (l_concat).LAST_UPDATED_BY := r_cat.LAST_UPDATED_BY;
       
             l_concat := l_concat + 1;  
            
      end loop;
         
    
    -- Tabla de la categoria del asiento 
      
        FORALL J IN l_valcat.FIRST .. l_valcat.LAST        
         INSERT INTO XXCCT_CATEGORIA_ASIENTO_T
              VALUES l_valcat (J);
              COMMIT;
        
     EXCEPTION
        WHEN OTHERS THEN
     print_message (g_type_log_summary,
                        'Error en el procedimiento INSERTAR_TABLA_CATEGORIA : ' || SQLERRM
                       ); 
    
   END INSERTAR_TABLA_CATEGORIA;  
 
/********************************************************************************************  
   Procedimineto del llenado de la tabla temporal de las secuencias del documento*/ 
 
 PROCEDURE INSERTAR_SECUENCIAS_DOC
   IS
      CURSOR C_SEQ
          IS
      SELECT fd.NAME Nombre,
                  fa.application_name APLICACION,
                  fd.START_DATE Desde,
                  fd.END_DATE Hasta,
                 decode (fd.TYPE,'A','Automatico'
                                        ,'M','Manual'
                                       ,'G','Sin Brechas' ) Tipo,
                 decode(fd.MESSAGE_FLAG, 'Y', 'Si', 'N', ' ') Mensaje,
                 fd.INITIAL_VALUE Valor_inicial,
                 fds.category_code Categoria,
                 gsb.NAME Mayor,
                 --fl.meaning
                --  ''Metod,
                 decode (fds.METHOD_CODE , 'A', 'Automatic', 'M', 'Manuals','Nulo') Metodo
                ,1 CREATED_BY
                ,1 REQUEST_ID
                ,TO_CHAR (SYSDATE, 'DD-MON-YYYY') LAST_UPDATE_DATE
                ,1 LAST_UPDATED_BY
       FROM fnd_doc_sequence_assignments fds,
                 fnd_application_tl fa,
                 gl_sets_of_books gsb,
                 fnd_document_sequences fd
                -- fnd_lookups fl
            WHERE 1=1
               AND fa.application_id = fds.application_id
               AND gsb.set_of_books_id = fds.set_of_books_id
               AND fd.doc_sequence_id = fds.doc_sequence_id
              -- AND fl.lookup_code = fds.method_code
               AND fa.LANGUAGE = USERENV ('LANG')
               and  fa.application_name = 'General Ledger';  
               
      TYPE l_secuencia IS TABLE OF C_SEQ%ROWTYPE
       INDEX BY BINARY_INTEGER;

      l_valseq   l_secuencia;


      l_conseq     NUMBER := 1;
      
       BEGIN
      FOR r_seq IN C_SEQ
      
      LOOP
                  
         l_valseq (l_conseq).Nombre := r_seq.Nombre;
         l_valseq (l_conseq).APLICACION := r_seq.APLICACION;
         l_valseq (l_conseq).Desde := r_seq.Desde; 
         l_valseq (l_conseq).Hasta := r_seq.Hasta;
         l_valseq (l_conseq).Tipo := r_seq.Tipo;
         l_valseq (l_conseq).Mensaje := r_seq.Mensaje;
         l_valseq (l_conseq).Valor_inicial := r_seq.Valor_inicial;
         l_valseq (l_conseq).Categoria := r_seq.Categoria;
         l_valseq (l_conseq).Mayor := r_seq.Mayor;
       --  l_valseq (l_conseq).Metod := r_seq.Metod;
         l_valseq (l_conseq).Metodo := r_seq.Metodo; 
         l_valseq (l_conseq).LAST_UPDATE_DATE := r_seq.LAST_UPDATE_DATE;  
         l_valseq (l_conseq).CREATED_BY := fnd_global.user_id;
         l_valseq (l_conseq).REQUEST_ID := FND_GLOBAL.CONC_REQUEST_ID; 
         l_valseq (l_conseq).LAST_UPDATED_BY := r_seq.LAST_UPDATED_BY;
       
             l_conseq := l_conseq + 1;  
            
      end loop;
         
        FORALL J IN l_valseq.FIRST .. l_valseq.LAST          
         INSERT INTO XXCCT_SECUENCIAS_DOC_T
              VALUES l_valseq (J);
              COMMIT;
        
     EXCEPTION
        WHEN OTHERS THEN
          print_message (g_type_log_summary,
                        'Error en el procedimiento INSERTAR_SECUENCIAS_DOC : ' || SQLERRM
                       ); 
  
 END INSERTAR_SECUENCIAS_DOC;    
 
 
 /**************************************************
 Procedimiento para Presupuestos
 *************************************************/
 PROCEDURE  INSERTA_PRESUPUESTOS   (P_BOOK_NAME VARCHAR2, P_BUDGET_NAME VARCHAR2 )
IS 
     CURSOR C_PRESUPUESTO (P_BOOK_NAME VARCHAR2, P_BUDGET_NAME VARCHAR2)
        IS 
           SELECT UNIQUE(g.BUDGET_NAME) PRESUPUESTO
                              ,g.description DESCRIPCION
                                                            ,DECODE (g.status, 'O','Abierto'--Open
                                                           ,'C','Actual'--Current
                                                           ,'F', 'Congelado') ESTADO --frozen
                              ,DECODE (g.require_budget_journals_flag, 'Y', 'Si', 'N', 'No' ) REQUERIR_ASIENTOS_PRESUP
                              ,g.creation_date FECHA_CREACION
                              ,g.date_closed CONGELADO
                              ,g.first_valid_period_name PRIMER_PER_VAL
                              , g.last_valid_period_name ULTIMO_PER_VAL
                              ,g.latest_opened_year ULT_EJERC_ABIER
                              , ldg.name LIBRO
--                             ,mbv.budget_name MASTER_BUDGET_NAME,
                               ,1 CREATED_BY
                               ,1 REQUEST_ID
                              ,TO_CHAR (SYSDATE, 'DD-MON-YYYY') LAST_UPDATE_DATE
                              ,1 LAST_UPDATED_BY
                    FROM gl_budgets g 
                            ,gl_period_statuses l
                            ,gl_ledgers ldg
                    WHERE 1=1
                    AND l.ledger_id = g.ledger_id
                    AND ldg.ledger_id = g.ledger_id 
                    AND g.ledger_id = ldg.ledger_id
                    AND g.BUDGET_NAME = P_BUDGET_NAME--'BGT_PRUEBA'
                    AND   ldg.name= P_BOOK_NAME
                     ;
                    
                    
                     TYPE l_Pres IS TABLE OF C_PRESUPUESTO%ROWTYPE
                        INDEX BY BINARY_INTEGER;

          l_presup  l_Pres;
           l_contador     NUMBER := 1;
                   

BEGIN
          

-- DELETE XXCCT_GL_PRESUPUESTOS;
          COMMIT;
   
               FOR R_PRE IN C_PRESUPUESTO (P_BOOK_NAME, P_BUDGET_NAME)
               
                LOOP
                  
                  
                            l_presup  (l_contador).PRESUPUESTO  := R_PRE.PRESUPUESTO;
                            l_presup  (l_contador).DESCRIPCION  := R_PRE.DESCRIPCION;
                            l_presup  (l_contador).ESTADO  := R_PRE.ESTADO;
                            l_presup  (l_contador).REQUERIR_ASIENTOS_PRESUP  := R_PRE.REQUERIR_ASIENTOS_PRESUP;
                            l_presup  (l_contador).FECHA_CREACION  := R_PRE.FECHA_CREACION;
                            l_presup  (l_contador).CONGELADO  := R_PRE.CONGELADO;
                            l_presup  (l_contador).PRIMER_PER_VAL  := R_PRE.PRIMER_PER_VAL;
                            l_presup  (l_contador).ULTIMO_PER_VAL  := R_PRE.ULTIMO_PER_VAL;
                            l_presup  (l_contador).ULT_EJERC_ABIER  := R_PRE.ULT_EJERC_ABIER;
                            l_presup  (l_contador).LIBRO := R_PRE.LIBRO;
                            l_presup  (l_contador).CREATED_BY  := R_PRE.CREATED_BY;
                            l_presup  (l_contador).LAST_UPDATED_BY  := R_PRE.LAST_UPDATED_BY;
                            l_presup  (l_contador).LAST_UPDATE_DATE  := R_PRE.LAST_UPDATE_DATE;
                            l_presup  (l_contador).REQUEST_ID  := FND_GLOBAL.CONC_REQUEST_ID;

                          l_contador := l_contador + 1;
             end loop;               
                           
                        
             
      --Tabla de  PRESUPUESTOS............
        FORALL i IN l_presup.FIRST ..l_presup.LAST     --..l_presup.COUNT 
        INSERT INTO XXCCT_GL_PRESUPUESTOS
        VALUES l_presup (i);
        COMMIT;
                               

                      EXCEPTION
                                         WHEN OTHERS   THEN
                                           print_message (g_type_log_summary,
                        'Error en el procedimiento INSERTA_PRESUPUESTOS : ' || SQLERRM
                       ); 
                    
 END INSERTA_PRESUPUESTOS;
             
                     
 /*
 ==============================================================================================
  Procedimiento para ejecutar el concurrente XXCCT - GL Combinacion Cuentas Contables
 ==============================================================================================  
 */
 PROCEDURE importador_cuentas_contables
IS

     l_request_id    NUMBER := 0;
     l_call_status   BOOLEAN;
     l_dphase        VARCHAR2 (240);
     l_dstatus       VARCHAR2 (240);
     l_dev_phase     VARCHAR2 (240);
     l_dev_status    VARCHAR2 (240);
     l_message       VARCHAR2 (2000);
     l_layout       BOOLEAN;
BEGIN

  l_layout :=
                fnd_request.add_layout ('SQLGL',
                                                    'XXCCTCCONTABLES',
                                                    'EN',
                                                    'MX',
                                                    'EXCEL');

              l_request_id := fnd_request.submit_request
                                (application      => 'SQLGL',
                                 program          => 'XXCCTCCONTABLES',
                                 description      => NULL,
                                 sub_request      => FALSE,
                                 start_time       => NULL
--                                 argument1        => NULL,
--                                 argument2        => NULL,
--                                 argument3        => NULL,
--                                 argument4        => NULL,
--                                 argument5        => NULL
                               );
                                                      
                               
      COMMIT;

  IF l_request_id > 0 THEN
         LOOP
                l_call_status :=
                        fnd_concurrent.get_request_status (l_request_id,
                                                           NULL,
                                                           NULL,
                                                           l_dphase,
                                                           l_dstatus,
                                                           l_dev_phase,
                                                           l_dev_status,
                                                           l_message);
            EXIT WHEN l_dev_phase NOT IN ('RUNNING', 'PENDING')
                                OR l_dev_status IN ('TERMINATED', 'ERROR');
         END LOOP;
      END IF;
	EXCEPTION
	  WHEN OTHERS THEN
	    print_message (g_type_log_summary,
                        'Error en el procedimiento importador_cuentas_contables : ' || SQLERRM
                       ); 
END importador_cuentas_contables;    
 






   
 /* 
 ============================================================================================================
 Procedimiento Principal manda a llamar todos los procedimientos para salida en xml pblisher mediante un concurrente */

   PROCEDURE MAIN (x_errormsg  OUT   VARCHAR2,
                   x_errorcode              OUT   NUMBER,
                   p_nom_estructura      IN     VARCHAR2,
                   p_period_set_name    IN     VARCHAR2,
                   p_responsabilidades   IN     VARCHAR2,
                   p_book_name            IN     VARCHAR2,
                   p_budget_name         IN     VARCHAR2)
                                 
    IS
        l_validate      BOOLEAN:=FALSE;
        l_call_status  BOOLEAN;
        l_request_id  NUMBER;
        l_dphase       VARCHAR2(240);
        l_dstatus       VARCHAR2(240);
        l_dev_phase  VARCHAR2(240);
        l_dev_status  VARCHAR2(240);
        l_message     VARCHAR2(2000);                               

        CURSOR c_flex_segment
         IS
        SELECT *
        FROM XXCCT_GL_FLEX_SEGMENTOS
          WHERE 1 = 1 
               AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
          
       CURSOR c_value_sets
       IS 
       SELECT * 
         FROM XXCCT_GL_JUEGO_VALORES
       WHERE 1 = 1 
            AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
       
       CURSOR c_segmentos_contabilidad
       IS
          SELECT *
            FROM segmentos_contabilidad
          WHERE 1 = 1;
       --AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
       
       CURSOR C_TIPOS_PERIODO
       IS
          SELECT * 
            FROM tipos_periodo
          WHERE 1 = 1; 
      -- AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
       
       CURSOR C_CALENDARIO_CONTABLE
       is 
          SELECT * FROM calendario_contable
       WHERE 1 = 1;
      -- AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
       
       CURSOR C_CONFIGURACION_DIVISA
       is 
          SELECT * FROM configuracion_divisa
       WHERE 1 = 1; 
       --AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
       
       CURSOR C_SEGMENTO_CUADRAR
       is 
          SELECT * FROM segmento_cuadrar
       WHERE 1 = 1;
       --AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
       
       CURSOR C_UNIDADES_OPERATIVAS
       is 
          SELECT * FROM unidades_operativas
       WHERE 1 = 1; 
       --AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
       
        CURSOR C_COMP_INTRA_SEC
       is 
          SELECT * FROM compania_intra_secuensiacion
       WHERE 1 = 1; 
       --AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
        
       CURSOR C_CUENTAS_CONTABLES
       is 
          SELECT * FROM cuentas_contables
       WHERE 1 = 1; 
       --AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
       
       CURSOR C_CAMBIO_DIARIO
       is 
          SELECT * FROM cambio_diario
       WHERE 1 = 1; 
       --AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
       
       CURSOR C_ORG_PRESUPUESTOS
       is 
          SELECT * FROM organizaciones_presupuesto
       WHERE 1 = 1; 
       --AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
       
       CURSOR C_RANGOS
       is 
          SELECT * FROM rangos
       WHERE 1 = 1; 
       --AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
       
       CURSOR C_ASIGNACIONES
       is 
          SELECT * FROM asignaciones
       WHERE 1 = 1; 
       --AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;

     CURSOR c_entidad 
       IS 
     SELECT *
     FROM XXCCT_ENTIDADES_LEGALES_T
      WHERE 1 = 1 
     AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;

     CURSOR c_registrations
     IS
     select convert(T.TERRITORY_SHORT_NAME,'WE8MSWIN1252','UTF8') Pais
         , convert(loc.address_line_1||','||loc.address_line_2||decode(nvl(loc.address_line_2,'x'),'x','',',')||loc.address_line_3
                ||decode(nvl(loc.address_line_3,'y'),'y','',',') || loc.postal_code || ','|| t.territory_short_name  || ','|| loc.region_2  || ','||t.territory_short_name,'WE8MSWIN1252','UTF8')  registratered_address  
        ,jtl.name JURISDICTION
        ,jur.registration_code_le CODE
        ,reg.REGISTRATION_NUMBER
        ,reg.EFFECTIVE_FROM active
     from xle_entity_profiles xep
        ,hz_parties hp
        ,xle_registrations reg
        ,hr_locations loc
        ,FND_TERRITORIES_TL T
        ,xle_jurisdictions_b jur
       ,xle_jurisdictions_tl jtl
 where 1=1
  AND hp.party_id = xep.party_id      
  AND reg.source_id = xep.legal_entity_id
  AND reg.location_id = loc.location_id
  AND t.territory_code = loc.country
  AND reg.source_id=xep.legal_entity_id
  AND reg.location_id = loc.location_id
  AND reg.jurisdiction_id = jur.jurisdiction_id
  AND jur.jurisdiction_id=jtl.jurisdiction_id
  AND T.LANGUAGE = USERENV ('LANG')
  AND jtl.LANGUAGE = USERENV ('LANG');
     
       CURSOR c_establishment
       IS
       SELECT convert (xep.name,'WE8MSWIN1252','UTF8')  name ,
       reg.REGISTRATION_NUMBER,
        convert ( loc.address_line_1
       || ','
       || loc.address_line_2
       || DECODE (NVL (loc.address_line_2, 'x'), 'x', '', ',')
       || loc.address_line_3
       || DECODE (NVL (loc.address_line_3, 'y'), 'y', '', ',')
       || loc.postal_code
       || ','
       || t.territory_short_name
       || ','
       || loc.region_2
       || ','
       || t.territory_short_name,'WE8MSWIN1252','UTF8') 
          registratered_address,
       convert (t.territory_short_name,'WE8MSWIN1252','UTF8')   territory,
       reg.EFFECTIVE_TO active,
       to_char(reg.effective_from,'DD-MON-RRRR') registratered_activity
  FROM xle_etb_profiles xep,
       hz_parties hp,
       xle_registrations reg,
       hr_locations loc,
       FND_TERRITORIES_TL T,
       xle_jurisdictions_b jur,
       xle_jurisdictions_tl jtl
 WHERE     1 = 1
       AND hp.party_id = xep.party_id
       AND reg.source_id = xep.legal_entity_id
       AND reg.location_id = loc.location_id
       AND t.territory_code = loc.country
       AND reg.source_id = xep.legal_entity_id
       AND reg.location_id = loc.location_id
       AND reg.jurisdiction_id = jur.jurisdiction_id
       AND jur.jurisdiction_id = jtl.jurisdiction_id
       AND T.LANGUAGE = USERENV ('LANG')
       AND jtl.LANGUAGE = USERENV ('LANG');
       
       
       CURSOR C_LIBROS
                IS
                   SELECT *
                   FROM  XXCCT_GL_LIBROSR
                   WHERE 1 = 1 AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
  
     CURSOR c_origen
       IS
     SELECT * 
     FROM XXCCT_ORIGEN_ASIENTO_T
     WHERE 1 = 1 
     AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;   
     
     CURSOR c_categoria
       IS
     SELECT *
     FROM XXCCT_CATEGORIA_ASIENTO_T
     WHERE 1 = 1 
     AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;   
     
    CURSOR c_secuencia
      IS
     SELECT * 
     FROM XXCCT_SECUENCIAS_DOC_T
     WHERE 1 = 1 
     AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;   
     
     cursor C_PROFILES
     IS 
     SELECT *
     from XXCCT_PROFILES_T 
    WHERE 1 = 1 
     AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;   
 
     CURSOR  C_CER_ABR
                IS
                   SELECT *
                   FROM  XXCCT_GL_CERRAR_ABRIR
                   WHERE 1 = 1 AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;


 CURSOR  C_DIVISAS
                IS
                   SELECT *
                   FROM  XXCCT_GL_DIVISAS
                   WHERE 1 = 1 AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
                   
  CURSOR  C_PRESUPUESTO
                IS
                   SELECT *
                   FROM  XXCCT_GL_PRESUPUESTOS
                   WHERE 1 = 1 AND REQUEST_ID = FND_GLOBAL.CONC_REQUEST_ID;
                   
    l_active VARCHAR2(100) := NULL;                   
    BEGIN
     
    
    EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''AMERICAN''';              
                                FND_GLOBAL.APPS_INITIALIZE(
                                        USER_ID =>fnd_profile.VALUE ('USER_ID'),
                                         RESP_ID =>fnd_profile.VALUE ('RESP_ID'),
                                         RESP_APPL_ID =>fnd_profile.VALUE ('RESP_APPL_ID'));

                                MO_GLOBAL.SET_POLICY_CONTEXT('S',fnd_profile.value('org_id'));
                                
      /*
    =============== llamado de los procedimientos
    */
      insert_segment (P_NOM_ESTRUCTURA);
      insert_value_sets (P_NOM_ESTRUCTURA);
      inserta_valores_segmentos;
 inserta_tipos_periodo;
 insert_calendary(P_PERIOD_SET_NAME);
 inserta_config_divisa (P_BOOK_NAME);
 inserta_seg_cuadrar(P_BOOK_NAME);
  inserta_unidades_operativas(P_BOOK_NAME);
 inserta_cuentas_compania(P_BOOK_NAME);
  inserta_cuentas_contables;
 inserta_cambio_diario;
 inserta_organizaciones_presup(P_BOOK_NAME);
 inserta_rangos(P_BOOK_NAME);
 inserta_asignaciones;
       INSERTA_LIBROSR (P_BOOK_NAME ); 
     INSERTAR_TABLA_ENTIDADES;
      INSERTAR_TABLA_ORIGEN_ASIENTO;
      INSERTAR_TABLA_CATEGORIA;
      INSERTAR_SECUENCIAS_DOC;
      INSERTAR_TABLA_PROFILES (P_RESPONSABILIDADES);
      INSERTA_CERR_ABR  (P_BOOK_NAME);
      INSERTAR_DIVISAS (P_BOOK_NAME);
      INSERTA_PRESUPUESTOS   (P_BOOK_NAME, P_BUDGET_NAME);
      
    /*
    ==================================================================
    llamado del importador para ejecutar el  concurrente XXCCT - GL Combinacion Cuentas Contables
    ==================================================================
    */ 
      
      importador_cuentas_contables;
     
       
--  LOOP       
--        v_call_status := fnd_concurrent.get_request_status (l_request_id,
--                                                 9,
--                                                 NULL,
--                                                 v_dphase,
--                                                 v_dstatus,
--                                                 v_dev_phase,
--                                                 v_dev_status,
--                                                 v_message
--                                                );
--           EXIT WHEN v_dev_phase NOT IN ('RUNNING', 'PENDING')
--                 OR v_dev_status IN ('TERMINATED', 'ERROR');
--        END LOOP;


      -- ===========   Inicio de XML 
      FND_FILE.PUT_LINE (FND_FILE.OUTPUT, q'[<?xml version="1.0" encoding="ISO-8859-1"?>]');

     
    /*
   ========================================================================= Etiquetas de XML
   */
    
      FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G_PRINCIPAL>');
      
      FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<P_RESPONSABILIDADES>' || P_RESPONSABILIDADES || '</P_RESPONSABILIDADES>');
    

     FOR r_main IN c_flex_segment
      
      LOOP
      
 
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G_ENCABEZADO>');

         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<TITULO_FLEX>' || r_main.TITULO_FLEX || '</TITULO_FLEX>');
         FND_FILE. PUT_LINE (FND_FILE.OUTPUT, '<FECHA>' || r_main.FECHA || '</FECHA>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<Codigo>' || r_main.Codigo || '</Codigo>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<Titulo>' || r_main.Titulo || '</Titulo>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<DESCRIPCION>' || r_main.DESCRIPCION || '</DESCRIPCION>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Visualizar_Nombre>'|| r_main.Visualizar_Nombre|| '</Visualizar_Nombre>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<Congelar_definicion>'|| r_main.Congelar_definicion|| '</Congelar_definicion>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<Activado>' || r_main.Activado || '</Activado>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Separador_segmento>'|| r_main.Separador_segmento|| '</Separador_segmento>');
         FND_FILE.PUT_LINE ( FND_FILE.OUTPUT,'<Segmentos_Cruzada>'|| r_main.Segmentos_Cruzada || '</Segmentos_Cruzada>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Congelar_Grupos>'|| r_main.Congelar_Grupos || '</Congelar_Grupos>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<AUT_INSERC_DINAMICS>'|| r_main.AUT_INSERC_DINAMICS || '</AUT_INSERC_DINAMICS>');
        
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<G_SEGMENTOS>');
       
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Numero>' || r_main.Numero || '</Numero>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Nombre>'|| TRANSLATE (r_main.Nombre, 'Ññ', 'Nn')|| '</Nombre>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Promp_ventana>'|| TRANSLATE (r_main.Promp_ventana, 'Ññ', 'Nn') || '</Promp_ventana>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Columna>' || r_main.Columna || '</Columna>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<JUEGO_VALORES>'|| TRANSLATE (r_main.JUEGO_VALORES, 'Ññ', 'Nn') || '</JUEGO_VALORES>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Desplegado>' || r_main.Desplegado || '</Desplegado>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Activado_s>' || r_main.Activado_s || '</Activado_s>');

         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_SEGMENTOS>');

         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G_DES_SEG>');

         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Nombre>' || TRANSLATE (r_main.Nombre, 'Ññ', 'Nn') || '</Nombre>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Columna>' || r_main.Columna || '</Columna>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Numero>' || r_main.Numero || '</Numero>');
         FND_FILE. PUT_LINE (FND_FILE.OUTPUT,'<Activado_s>' || r_main.Activado_s || '</Activado_s>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Desplegado>' || r_main.Desplegado || '</Desplegado>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Indexado>' || r_main.Indexado || '</Indexado>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<JUEGO_VALORES>'|| TRANSLATE (r_main.JUEGO_VALORES, 'Ññ', 'Nn') || '</JUEGO_VALORES>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DES>' || r_main.DES || '</DES>');     --
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<TIPO>' || r_main.TIPO || '</TIPO>');
         FND_FILE. PUT_LINE (FND_FILE.OUTPUT,'<DEFECTO>' || r_main.DEFECTO || '</DEFECTO>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<REQUERIDO>' || r_main.REQUERIDO || '</REQUERIDO>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<SEGURIDA_ACTIVADA>'|| r_main.SEGURIDA_ACTIVADA || '</SEGURIDA_ACTIVADA>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<RANGO>' || r_main.RANGO || '</RANGO>');
        FND_FILE. PUT_LINE (FND_FILE.OUTPUT,'<DES_TAMANO>' || r_main.DES_TAMANO || '</DES_TAMANO>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<TAMANO_DES>' || r_main.TAMANO_DES || '</TAMANO_DES>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<TAMANO_CON>' || r_main.TAMANO_CON || '</TAMANO_CON>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<L_VALORES>'|| TRANSLATE (r_main.L_VALORES, 'Ññ', 'Nn')|| '</L_VALORES>');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Promp_ventana>'|| TRANSLATE (r_main.Promp_ventana, 'Ññ', 'Nn') || '</Promp_ventana>');


         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_DES_SEG>');


         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_ENCABEZADO>');
        
     END LOOP;
     
     --===========================================

    
------ Empieza grupo juego de valores 
    FOR C_MAIN IN c_value_sets
        LOOP
        
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<G1_JV>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<NOMBRE_VALORES>' || C_MAIN.NOMBRE_VALORES || '</NOMBRE_VALORES>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<DESCRIPCION>' || C_MAIN.DESCRIPCION || '</DESCRIPCION>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<SEGURIDAD>' || C_MAIN.SEGURIDAD || '</SEGURIDAD>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<TIPO_DE_LISTA>' || C_MAIN.TIPO_DE_LISTA || '</TIPO_DE_LISTA>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</G1_JV>');

                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<G2_JV>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<NOMBRE_VALORES>' || C_MAIN.NOMBRE_VALORES  || '</NOMBRE_VALORES>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<TIPO_FORMATO>' || C_MAIN.TIPO_FORMATO || '</TIPO_FORMATO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<TAMANO_MAX>' || C_MAIN.TAMANO_MAX || '</TAMANO_MAX>'); 
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<NUMERICO>' || C_MAIN.NUMERICO || '</NUMERICO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,  '<MAY_O_MIN>'|| C_MAIN.MAY_O_MIN || '</MAY_O_MIN>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,  '<JUSTIFICACION>'|| C_MAIN.JUSTIFICACION || '</JUSTIFICACION>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,  '<VALOR_MAXIMO>'|| C_MAIN.VALOR_MAXIMO || '</VALOR_MAXIMO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,  '<VALOR_MINIMO>'|| C_MAIN.VALOR_MINIMO || '</VALOR_MINIMO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,  '<TIPO_VALIDACION>'|| C_MAIN.TIPO_VALIDACION || '</TIPO_VALIDACION>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</G2_JV>');
       
     END LOOP;
     
    FOR C_VAL_SEG IN C_SEGMENTOS_CONTABILIDAD
        LOOP
        
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<SEGMENTO>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<VALOR>' || C_VAL_SEG.VALOR || '</VALOR>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<VALOR_TRADUCIDO>' || C_VAL_SEG.VALOR_TRADUCIDO || '</VALOR_TRADUCIDO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<DESCRIPCION>' || C_VAL_SEG.DESCRIPCION || '</DESCRIPCION>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<ACTIVADO>' || C_VAL_SEG.ACTIVADO || '</ACTIVADO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DESDE>' || C_VAL_SEG.DESDE || '</DESDE>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<HASTA>' || C_VAL_SEG.HASTA || '</HASTA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<PRINCIPAL>' || C_VAL_SEG.PRINCIPAL || '</PRINCIPAL>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<NIVEL>' || C_VAL_SEG.NIVEL || '</NIVEL>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<GRUPO>' || C_VAL_SEG.GRUPO || '</GRUPO>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</SEGMENTO>');
       
     END LOOP;
     
     FOR C_TIP_P IN C_TIPOS_PERIODO
        LOOP
        
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<TIPOS_PERIODO>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<TIPO_PERIODO>' || C_TIP_P.TIPO_PERIODO || '</TIPO_PERIODO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<PERIODO_POR_ANIO>' || C_TIP_P.PERIODO_POR_ANIO || '</PERIODO_POR_ANIO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<TIPO_ANIO>' || C_TIP_P.TIPO_ANIO || '</TIPO_ANIO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<DESCRIPCION>' || C_TIP_P.DESCRIPCION || '</DESCRIPCION>');
                
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</TIPOS_PERIODO>');
       
     END LOOP;
     
     
     FOR C_CAL_CON IN C_CALENDARIO_CONTABLE
        LOOP
        
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CALENDARIO_CONTABLE>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<NOMBRE>' || C_CAL_CON.NOMBRE || '</NOMBRE>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<DESCRIPCION>' || C_CAL_CON.DESCRIPCION || '</DESCRIPCION>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<SEGURIDAD>' || C_CAL_CON.SEGURIDAD || '</SEGURIDAD>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<NOMBRE_PERIODO>' || C_CAL_CON.NOMBRE_PERIODO || '</NOMBRE_PERIODO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DESDE>' || C_CAL_CON.DESDE || '</DESDE>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<HASTA>' || C_CAL_CON.HASTA || '</HASTA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<TIPO>' || C_CAL_CON.TIPO || '</TIPO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<ANIO>' || C_CAL_CON.ANIO || '</ANIO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<NUMERO>' || C_CAL_CON.NUMERO || '</NUMERO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<TRIMESTRE>' || C_CAL_CON.TRIMESTRE || '</TRIMESTRE>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<PREFIJO>' || C_CAL_CON.PREFIJO || '</PREFIJO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<AJUSTE>' || C_CAL_CON.AJUSTE || '</AJUSTE>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<TIPO_PERIODO>' || C_CAL_CON.TIPO_PERIODO || '</TIPO_PERIODO>');
                
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</CALENDARIO_CONTABLE>');
       
     END LOOP;
     
     
    FOR C_CON_DIV IN C_CONFIGURACION_DIVISA
        LOOP
        
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CONFIGURACION_DIVISA>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<SOURCE_LEDGER_ID>' || C_CON_DIV.SOURCE_LEDGER_ID || '</SOURCE_LEDGER_ID>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<DIVISA>' || C_CON_DIV.DIVISA || '</DIVISA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<DIVISA_INFORMACION>' || C_CON_DIV.DIVISA_INFORMACION || '</DIVISA_INFORMACION>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<CONVERSION_DIVISA>' || C_CON_DIV.CONVERSION_DIVISA || '</CONVERSION_DIVISA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DESACTIVAR_CONVERSION>' || C_CON_DIV.DESACTIVAR_CONVERSION || '</DESACTIVAR_CONVERSION>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<TARGET>' || C_CON_DIV.TARGET || '</TARGET>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<DESCRIPCION>' || C_CON_DIV.DESCRIPCION || '</DESCRIPCION>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<ESTADO>' || C_CON_DIV.ESTADO || '</ESTADO>');

                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</CONFIGURACION_DIVISA>');
       
     END LOOP;
     
     FOR C_SEG_CU IN C_SEGMENTO_CUADRAR
        LOOP
        
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<SEGMENTOS_CUADRAR>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<SEGMENTO_CUADRAR>' || C_SEG_CU.SEGMENTO_CUADRAR || '</SEGMENTO_CUADRAR>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<FECHA_INICIAL>' || C_SEG_CU.FECHA_INICIAL || '</FECHA_INICIAL>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<FECHA_FINAL>' || C_SEG_CU.FECHA_FINAL || '</FECHA_FINAL>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<DESCRIPCION>' || C_SEG_CU.DESCRIPCION || '</DESCRIPCION>');

                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</SEGMENTOS_CUADRAR>');
       
     END LOOP;
     
     
     FOR C_UN_OP IN C_UNIDADES_OPERATIVAS
        LOOP
        
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<UNIDADES_OPERATIVAS>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<GRUPO_NEGOCIOS>' || C_UN_OP.GRUPO_NEGOCIOS || '</GRUPO_NEGOCIOS>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<UNIDAD_OPERATIVA>' || C_UN_OP.UNIDAD_OPERATIVA || '</UNIDAD_OPERATIVA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<CONTEXTO_LEGAL>' || C_UN_OP.CONTEXTO_LEGAL || '</CONTEXTO_LEGAL>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<CODIGO_BREVE>' || C_UN_OP.CODIGO_BREVE || '</CODIGO_BREVE>');

                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</UNIDADES_OPERATIVAS>');
       
     END LOOP;
     
     FOR C_COMP_INTRA IN C_COMP_INTRA_SEC
        LOOP
        
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<COMPANIAS_INTRA_SEC>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<LEDGER_ID>' || C_COMP_INTRA.LEDGER_ID || '</LEDGER_ID>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<MAYOR_PRIMARIO>' || C_COMP_INTRA.MAYOR_PRIMARIO || '</MAYOR_PRIMARIO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<DIVISA>' || C_COMP_INTRA.DIVISA || '</DIVISA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<ENTIDAD_LEGAL>' || C_COMP_INTRA.ENTIDAD_LEGAL || '</ENTIDAD_LEGAL>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<DIRECCION>' || C_COMP_INTRA.DIRECCION || '</DIRECCION>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<PLAN_CUENTAS>' || C_COMP_INTRA.PLAN_CUENTAS || '</PLAN_CUENTAS>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<CALENDARIO>' || C_COMP_INTRA.CALENDARIO || '</CALENDARIO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<METODO_SUBMAYOR>' || C_COMP_INTRA.METODO_SUBMAYOR || '</METODO_SUBMAYOR>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<PAIS>' || C_COMP_INTRA.PAIS || '</PAIS>');
                
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</COMPANIAS_INTRA_SEC>');
       
     END LOOP;
     
     FOR C_CU_CON IN C_CUENTAS_CONTABLES
        LOOP
        
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CUENTAS_CONTABLES>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ACTIVADO>' || C_CU_CON.ACTIVADO || '</ACTIVADO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<PRESERVADO>' || C_CU_CON.PRESERVADO || '</PRESERVADO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<CUENTA>' || C_CU_CON.CUENTA || '</CUENTA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<TIPO>' || C_CU_CON.TIPO || '</TIPO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<FECHA_DESDE>' || C_CU_CON.FECHA_DESDE || '</FECHA_DESDE>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<FECHA_HASTA>' || C_CU_CON.FECHA_HASTA || '</FECHA_HASTA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<AUTORIZAR_CONTABILIZACION>' || C_CU_CON.AUTORIZAR_CONTABILIZACION || '</AUTORIZAR_CONTABILIZACION>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<AUTORIZAR_PRESUPUESTO>' || C_CU_CON.AUTORIZAR_PRESUPUESTO || '</AUTORIZAR_PRESUPUESTO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<CUENTA_ALTERNA>' || C_CU_CON.CUENTA_ALTERNA || '</CUENTA_ALTERNA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<CONCILIAR>' || C_CU_CON.CONCILIAR || '</CONCILIAR>');
                
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</CUENTAS_CONTABLES>');
       
     END LOOP;
     
     FOR C_CAM_D IN C_CAMBIO_DIARIO
        LOOP
        
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CAMBIO_DIARIO>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DESDE>' || C_CAM_D.DESDE || '</DESDE>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<HASTA>' || C_CAM_D.HASTA || '</HASTA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<FECHA>' || C_CAM_D.FECHA || '</FECHA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<TIPO>' || C_CAM_D.TIPO || '</TIPO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<USD_HASTA_MXN>' || C_CAM_D.USD_HASTA_MXN || '</USD_HASTA_MXN>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<MXN_HASTA_USD>' || C_CAM_D.MXN_HASTA_USD || '</MXN_HASTA_USD>');

                
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</CAMBIO_DIARIO>');
       
     END LOOP;
     
     
     FOR C_ORG_P IN C_ORG_PRESUPUESTOS
        LOOP
        
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ORG_PRESUPUESTOS>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ORGANIZACION>' || C_ORG_P.ORGANIZACION || '</ORGANIZACION>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DESCRIPCION>' || C_ORG_P.DESCRIPCION || '</DESCRIPCION>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<ACTIVAR_SEGURIDAD>' || C_ORG_P.ACTIVAR_SEGURIDAD || '</ACTIVAR_SEGURIDAD>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<MAYOR>' || C_ORG_P.MAYOR || '</MAYOR>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ACTIVADO>' || C_ORG_P.ACTIVADO || '</ACTIVADO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<DESDE>' || C_ORG_P.DESDE || '</DESDE>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<HASTA>' || C_ORG_P.HASTA || '</HASTA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<CUENTA>' || C_ORG_P.CUENTA || '</CUENTA>');

                
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</ORG_PRESUPUESTOS>');
       
     END LOOP;
     
     FOR C_RAN IN C_RANGOS
        LOOP
        
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<RANGOS>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<LINEA>' || C_RAN.LINEA || '</LINEA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DIVISA>' || C_RAN.DIVISA || '</DIVISA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<TIPO>' || C_RAN.TIPO || '</TIPO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<INFERIOR>' || C_RAN.INFERIOR || '</INFERIOR>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<SUPERIOR>' || C_RAN.SUPERIOR || '</SUPERIOR>');
       
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</RANGOS>');
       
     END LOOP;
     
     FOR C_ASG IN C_ASIGNACIONES
        LOOP
        
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ASIGNACIONES>');
               
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DIVISA>' || C_ASG.DIVISA || '</DIVISA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<TIPO>' || C_ASG.TIPO || '</TIPO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<CUENTA>' || C_ASG.CUENTA || '</CUENTA>');
       
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</ASIGNACIONES>');
       
     END LOOP;
     
      --==========================================
     
      FOR r_ent IN c_entidad
      
      LOOP
      
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G_ENTIDADES>');
           
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<LEGAL_NAME>'|| TRANSLATE (r_ent.LEGAL_NAME , 'Ññéó','Nneo') || '</LEGAL_NAME>');
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Legal_type>' || r_ent.Legal_type || '</Legal_type>');
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<REGISTERED_ADDRESS>' ||TRANSLATE( r_ent.REGISTERED_ADDRESS,'Ññí','Nni' )|| '</REGISTERED_ADDRESS>');
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Pais>' || r_ent.Pais || '</Pais>');
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<LEGAL_ENTITY_IDENTIFIER>' || r_ent.LEGAL_ENTITY_IDENTIFIER || '</LEGAL_ENTITY_IDENTIFIER>');
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ORGANIZATION_NUMBER>' || r_ent.ORGANIZATION_NUMBER || '</ORGANIZATION_NUMBER>');
         
        FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_ENTIDADES>');
        
         
        FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G_ENTIDADESDES>');
       
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<LEGAL_NAME>'|| TRANSLATE (r_ent.LEGAL_NAME , 'Ññéó<', 'Nneom') || '</LEGAL_NAME>');
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<LEGAL_ENTITY_IDENTIFIER>' || r_ent.LEGAL_ENTITY_IDENTIFIER || '</LEGAL_ENTITY_IDENTIFIER>'); 
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ORGANIZATION_NAME>' ||TRANSLATE (r_ent.ORGANIZATION_NAME, 'Ññéó<', 'Nneom')|| '</ORGANIZATION_NAME>');
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ORGANIZATION_NUMBER>' || r_ent.ORGANIZATION_NUMBER || '</ORGANIZATION_NUMBER>');
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ACTIVIDAD_PRIMARIA>' ||TRANSLATE ( r_ent.Actividad_Primaria,'Ññéó', 'Nneo' )|| '</ACTIVIDAD_PRIMARIA>');
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<TIPO_COMPANIA>' || r_ent.Tipo_compania || '</TIPO_COMPANIA>');
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CAPITAL_ACCIONES>' || r_ent.Capital_acciones || '</CAPITAL_ACCIONES>'); 
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DIVISA>' || r_ent.Divisa || '</DIVISA>'); 
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<FINAL_ANO>' || r_ent.Final_Ano || '</FINAL_ANO>');   
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<PAIS>' || r_ent.Pais || '</PAIS>');
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<TRANSACTING_FLAG>' || r_ent.Transacting_flag || '</TRANSACTING_FLAG>');  
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<INCEPTION_DATE>' || r_ent.Inception_Date || '</INCEPTION_DATE>');   
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<FECHA_FINAL>' || r_ent.Fecha_Final || '</FECHA_FINAL>');
        
      -- FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Pais>' || r_ent.Pais || '</Pais>'); 
       --FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Transacting_flag>' || r_ent.Transacting_flag || '</Transacting_flag>'); 
       --FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Inception_Date>' || r_ent.Inception_Date || '</Inception_Date>'); 
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_ENTIDADESDES>');
       
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G_ENTREG>');
        
        --FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Pais>' || r_ent.Pais || '</Pais>'); 
       -- FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<JURISDICTION>' || r_ent.JURISDICTION || '</JURISDICTION>');  
       --  FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CODE>' || r_ent.CODE || '</CODE>'); 
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<LEGAL_NAME>'|| TRANSLATE (r_ent.LEGAL_NAME , 'Ññéó', 'Nneo') || '</LEGAL_NAME>');
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ORGANIZATION_NUMBER>' || r_ent.ORGANIZATION_NUMBER || '</ORGANIZATION_NUMBER>');   
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<INCEPTION_DATE>' || r_ent.Inception_Date || '</INCEPTION_DATE>');   
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<FECHA_FINAL>' || r_ent.Fecha_Final || '</FECHA_FINAL>');
        
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_ENTREG>');
       
       
         END LOOP;
    
    FOR r_reg IN c_registrations LOOP
        print_message (g_type_output_summary, '<G_REGISTRATIONS>');
        print_message (g_type_output_summary, '<PAIS>' || r_reg.pais || '</PAIS>'); 
        print_message (g_type_output_summary, '<JURISDICTION>' || r_reg.JURISDICTION || '</JURISDICTION>');       
        print_message (g_type_output_summary, '<CODE>' || r_reg.code || '</CODE>');
        print_message (g_type_output_summary, '<REGISTRATION_NUMBER>' || r_reg.REGISTRATION_NUMBER || '</REGISTRATION_NUMBER>');
        print_message (g_type_output_summary, '<REGISTRATERED_ADDRESS>' || r_reg.registratered_address || '</REGISTRATERED_ADDRESS>');
        print_message (g_type_output_summary, '<ACTIVE>' || r_reg.active || '</ACTIVE>');
        print_message (g_type_output_summary, '</G_REGISTRATIONS>');
    END LOOP; 
    --===================================
    
    FOR r_establish  IN c_establishment LOOP
        print_message (g_type_output_summary, '<G_ESTABLISHMENT>');
        print_message (g_type_output_summary, '<NAME>' || r_establish.name || '</NAME>');
        print_message (g_type_output_summary, '<REGISTRATION_NUMBER>' || r_establish.REGISTRATION_NUMBER || '</REGISTRATION_NUMBER>');
        print_message (g_type_output_summary, '<REGISTRATERED_ADDRESS>' || r_establish.registratered_address || '</REGISTRATERED_ADDRESS>');
        print_message (g_type_output_summary, '<TERRITORY>' || r_establish.territory || '</TERRITORY>');
        IF r_establish.active IS NULL OR r_establish.active > SYSDATE THEN
            l_active := 'Si';
        ELSE
            l_active := 'No';
        END IF;
        print_message (g_type_output_summary, '<ACTIVE>' || l_active || '</ACTIVE>'); 
        print_message (g_type_output_summary, '<REGISTRATERED_ACTIVITY>' || r_establish.registratered_activity || '</REGISTRATERED_ACTIVITY>');        
        print_message (g_type_output_summary, '</G_ESTABLISHMENT>');
    END LOOP;
    
    
 FOR C_LIB IN  C_LIBROS
        LOOP
         
                  FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<G1_RL>');
                   FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<MAYOR>' || C_LIB.MAYOR || '</MAYOR>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<TIPO_MAYOR>' || C_LIB.TIPO_MAYOR || '</TIPO_MAYOR>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<LIBRO_MAYOR>' || C_LIB.LIBRO_MAYOR || '</LIBRO_MAYOR>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ESTADO>' || C_LIB.ESTADO || '</ESTADO>');
              
                  FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</G1_RL>');
                  
                  
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G2_RL>');
        
                  FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<MAYOR>' || C_LIB.MAYOR || '</MAYOR>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ABREVIATURA>' || C_LIB.ABREVIATURA || '</ABREVIATURA>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DESCRIPCION>' || C_LIB.DESCRIPCION || '</DESCRIPCION>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DIVISA>' || C_LIB.DIVISA || '</DIVISA>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<PLAN_DE_CUENTAS>' || C_LIB.PLAN_DE_CUENTAS || '</PLAN_DE_CUENTAS>');
                 
                   FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G2_RL>');
                    
                    
                    
                   FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G3_RL>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CALENDARIO_CONTABLE>' || C_LIB.CALENDARIO_CONTABLE || '</CALENDARIO_CONTABLE>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<TIPO_PERIODO>' || C_LIB.TIPO_PERIODO || '</TIPO_PERIODO>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<PRIMER_PERIODO_ABIERTO>' || C_LIB.PRIMER_PERIODO_ABIERTO || '</PRIMER_PERIODO_ABIERTO>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<NUM_PER_INGRESABLES_FUTUROS>' || C_LIB.NUM_PER_INGRESABLES_FUTUROS || '</NUM_PER_INGRESABLES_FUTUROS>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G3_RL>');
                    
                    
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G4_RL>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<MET_CONTABLE_SUBMAYOR>' || C_LIB.MET_CONTABLE_SUBMAYOR || '</MET_CONTABLE_SUBMAYOR>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<PROPIE_CONT_SUBMAYOR>' || C_LIB.PROPIE_CONT_SUBMAYOR || '</PROPIE_CONT_SUBMAYOR>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<IDIOMA_ASIENTO_DIARIO>' || C_LIB.IDIOMA_ASIENTO_DIARIO || '</IDIOMA_ASIENTO_DIARIO>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CTA_CUADRAR_DIVISA_INGRESADA>' || C_LIB.CTA_CUADRAR_DIVISA_INGRESADA || '</CTA_CUADRAR_DIVISA_INGRESADA>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<USAR_CONT_BASE_EFECTIVO>' || C_LIB.USAR_CONT_BASE_EFECTIVO || '</USAR_CONT_BASE_EFECTIVO>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<SALDAR_ING_SUBMAY_DIVISA_MAYOR>' || C_LIB.SALDAR_ING_SUBMAY_DIVISA_MAYOR || '</SALDAR_ING_SUBMAY_DIVISA_MAYOR>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CUENTA_CUADRAR_DIVISA_MAYOR>' || C_LIB.CUENTA_CUADRAR_DIVISA_MAYOR || '</CUENTA_CUADRAR_DIVISA_MAYOR>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G4_RL>');
                    
                  
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G5_RL>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CUENTA_GANANCIAS_RETENIDAS>' || C_LIB.CUENTA_GANANCIAS_RETENIDAS || '</CUENTA_GANANCIAS_RETENIDAS>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G5_RL>');
                   
                   
                   FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G6_RL>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CUENTA_TRANSITORIA>' || C_LIB.CUENTA_TRANSITORIA || '</CUENTA_TRANSITORIA>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CUENTA_DIFERENCIAS_REDONDEO>' || C_LIB.CUENTA_DIFERENCIAS_REDONDEO || '</CUENTA_DIFERENCIAS_REDONDEO>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<BALANCE_INTRACOMPANIA>' || C_LIB.BALANCE_INTRACOMPANIA || '</BALANCE_INTRACOMPANIA>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<APROBACION_ASIENTO>' || C_LIB.APROBACION_ASIENTO || '</APROBACION_ASIENTO>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<IMPUESTO_ASIENTO_DIARIO>' || C_LIB.IMPUESTO_ASIENTO_DIARIO || '</IMPUESTO_ASIENTO_DIARIO>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<JUEGO_CRIT_REVISION_ASIENTOS>' || C_LIB.JUEGO_CRIT_REVISION_ASIENTOS || '</JUEGO_CRIT_REVISION_ASIENTOS>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G6_RL>');
                    
                    
                    
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G7_RL>');
                    
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CLASE_TIPO_CAMBIO_FINAL>' || C_LIB.CLASE_TIPO_CAMBIO_FINAL || '</CLASE_TIPO_CAMBIO_FINAL>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CLASE_TIPO_CAMBIO_PROM>' || C_LIB.CLASE_TIPO_CAMBIO_PROM || '</CLASE_TIPO_CAMBIO_PROM>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CTA_AJUS_TRANS>' || C_LIB.CTA_AJUS_TRANS || '</CTA_AJUS_TRANS>');
                    
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G7_RL>');
                    
                    
                    
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G8_RL>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CONCILIACION_ASIENTO>' || C_LIB.CONCILIACION_ASIENTO || '</CONCILIACION_ASIENTO>');
                   FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G8_RL>');
                   
                   
                   FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G9_RL>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CONTROL_PRESUPUESTARIO>' || C_LIB.CONTROL_PRESUPUESTARIO || '</CONTROL_PRESUPUESTARIO>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<RESERVA_PROMESAS>' || C_LIB.RESERVA_PROMESAS || '</RESERVA_PROMESAS>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<REQUERIR_ASIENTOS_PRESUPUESTO>' || C_LIB.REQUERIR_ASIENTOS_PRESUPUESTO || '</REQUERIR_ASIENTOS_PRESUPUESTO>');
                   FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G9_RL>');
                   
                   
                   FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G10_RL>');
                   
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<SALDOS_PROMEDIO>' || C_LIB.SALDOS_PROMEDIO || '</SALDOS_PROMEDIO>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CONSOLIDACION_SALDO_PROMEDIO>' || C_LIB.CONSOLIDACION_SALDO_PROMEDIO || '</CONSOLIDACION_SALDO_PROMEDIO>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CUENTA_INGRESOS_NETOS>' || C_LIB.CUENTA_INGRESOS_NETOS || '</CUENTA_INGRESOS_NETOS>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CALENDARIO_TRANSACCIONES>' || C_LIB.CALENDARIO_TRANSACCIONES || '</CALENDARIO_TRANSACCIONES>');
                    
                   FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G10_RL>'); 
                    
                    
                   FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G11_RL>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CLASE_TIPO_CAMBIO>' || C_LIB.CLASE_TIPO_CAMBIO || '</CLASE_TIPO_CAMBIO>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<MANTENER_IMPORTE_FINAL>' || C_LIB.MANTENER_IMPORTE_FINAL || '</MANTENER_IMPORTE_FINAL>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<MANT_IMP_ACUM_PROM_TRIM>' || C_LIB.MANT_IMP_ACUM_PROM_TRIM || '</MANT_IMP_ACUM_PROM_TRIM>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<MANT_IMP_ACUM_PROM_ANUAL>' || C_LIB.MANT_IMP_ACUM_PROM_ANUAL || '</MANT_IMP_ACUM_PROM_ANUAL>');
                    FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G11_RL>');
               
        
        
        END LOOP;
    
    --====================================
    
    FOR r_prof in C_PROFILES
     
            LOOP
              
              FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G_PROFILE>');    
                
                   FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<NOMBRE>' || r_prof.NOMBRE || '</NOMBRE>');
                   FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<Valor_aplication>' || r_prof.Valor_aplication || '</Valor_aplication>');
              
              FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_PROFILE>');  
              
            END LOOP;


   --===============================
  FOR C_CA IN  C_CER_ABR
        LOOP 
          
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G1_UPER>');
            
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<NOMBRE_PERIODO>' || C_CA.NOMBRE_PERIODO || '</NOMBRE_PERIODO>');
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ANIO_PERIODO>' || C_CA.ANIO_PERIODO || '</ANIO_PERIODO>');
             
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G1_UPER>');
       
        
              FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<GRUPO_ANIOCOMP>');
             
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<ESTATUS>' || C_CA.ESTATUS || '</ESTATUS>');
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<NOMBRE_PERIODO>' || C_CA.NOMBRE_PERIODO || '</NOMBRE_PERIODO>');
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<NUM_PERIODO>' || C_CA.NUM_PERIODO || '</NUM_PERIODO>');
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ANIO_PERIODO>' || C_CA.ANIO_PERIODO || '</ANIO_PERIODO>');
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<INICO_PER>' || C_CA.INICO_PER || '</INICO_PER>');
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<FIN_PER>' || C_CA.FIN_PER || '</FIN_PER>');
             
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</GRUPO_ANIOCOMP>');
           
      END LOOP; 
   
   --===============================

--=======================================
FOR C_DIV IN C_DIVISAS
        
        LOOP
              
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G1_Div>');
                
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CODIGO_DIVISA>' || C_DIV.CODIGO_DIVISA || '</CODIGO_DIVISA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<DIVISA>' || C_DIV.DIVISA || '</DIVISA>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<DESCRIPCION >' || C_DIV.DESCRIPCION  || '</DESCRIPCION >');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<TERRITORIO_DIV>' || C_DIV.TERRITORIO_DIV || '</TERRITORIO_DIV>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<SIMBOLO >' || C_DIV.SIMBOLO  || '</SIMBOLO >');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<PRECISION_DIV>' || C_DIV.PRECISION_DIV || '</PRECISION_DIV>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<PRECISION_EXT>' || C_DIV.PRECISION_EXT || '</PRECISION_EXT>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<UNIDAD_MIN>' || C_DIV.UNIDAD_MIN || '</UNIDAD_MIN>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<FECHA_INICIO>' || C_DIV.FECHA_INICIO || '</FECHA_INICIO>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<FECHA_FIN>' || C_DIV.FECHA_FIN || '</FECHA_FIN>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<ACTIVO>' || C_DIV.ACTIVO || '</ACTIVO>');
              
               FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'</G1_Div>');
         
        END LOOP; 

--=======================================




       FOR r_origen in c_origen
       
       LOOP
        
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G_ORIGEN>');      
          
       FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ORIGEN>' || r_origen.Origen || '</ORIGEN>'); 
       FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CLAVE_ORIGEN>' || r_origen.Clave_Origen || '</CLAVE_ORIGEN>'); 
       FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DESCRIPCION>' || r_origen.Descripcion || '</DESCRIPCION>'); 
       FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<IMPORTAR_REFERENCIAS>' || r_origen.Importar_referencias || '</IMPORTAR_REFERENCIAS>'); 
       FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CONGELAR_ASIENTO>' || r_origen.Congelar_Asiento || '</CONGELAR_ASIENTO>'); 
       FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<REQUERIR_APROVACION>' || r_origen.Requerir_Aprovacion || '</REQUERIR_APROVACION>'); 
                  
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_ORIGEN>');
             
       END LOOP;

      FOR r_cat IN c_categoria
    
       LOOP
        
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G_CATEGORIA>');     
      FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<USER_JE_CATEGORY_NAME>' || r_cat.USER_JE_CATEGORY_NAME || '</USER_JE_CATEGORY_NAME>');
      FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<JE_CATEGORY_KEY>' || r_cat.JE_CATEGORY_KEY || '</JE_CATEGORY_KEY>');
      FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DESCRIPTION>' || r_cat.DESCRIPTION || '</DESCRIPTION>');
       
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_CATEGORIA>'); 
        
      END LOOP;
      
      
   --===============================
      
       FOR r_sec IN c_secuencia
       
       LOOP
         
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G_SECUENCIAS>');  
           
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<NOMBRE>'|| TRANSLATE (r_sec.Nombre, 'Ññ', 'Nn')|| '</NOMBRE>');
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<APLICACION>' || r_sec.APLICACION || '</APLICACION>');
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DESDE>' || r_sec.Desde || '</DESDE>');
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<HASTA>' || r_sec.Hasta || '</HASTA>');
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<TIPO>' || r_sec.Tipo || '</TIPO>');
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<MENSAJE>' || r_sec.Mensaje || '</MENSAJE>');
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<VALOR_INICIAL>' || r_sec.Valor_inicial || '</VALOR_INICIAL>');
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<MENSAJE>' || r_sec.Mensaje || '</MENSAJE>');
           
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_SECUENCIAS>');    
       
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G_SECDOC>'); 
           
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<APLICACION1>' || r_sec.APLICACION || '</APLICACION1>');
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CATEGORIA>' || r_sec.Categoria || '</CATEGORIA>');
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<MAYOR>' || r_sec.Mayor || '</MAYOR>');
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<METODO>' || r_sec.Metodo || '</METODO>');
           
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_SECDOC>'); 
         
           FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G_SEC>'); 
           
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<APLICACION1>' || r_sec.APLICACION || '</APLICACION1>'); 
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CATEGORIA1>' || r_sec.Categoria || '</CATEGORIA1>'); 
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DESDE1>' || r_sec.Desde || '</DESDE1>');
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<HASTA1>' || r_sec.Hasta || '</HASTA1>');
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<NOMBRE>'|| TRANSLATE (r_sec.Nombre, 'Ññ', 'Nn')|| '</NOMBRE>'); 
          
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_SEC>'); 
         
       END LOOP;



   --===============================

       FOR R_PRE IN  C_PRESUPUESTO 
     
       LOOP
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G_PRES>'); 
       
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<PRESUPUESTO>' || R_PRE.PRESUPUESTO || '</PRESUPUESTO>'); 
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<DESCRIPCION>' || R_PRE.DESCRIPCION || '</DESCRIPCION>'); 
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ESTADO>' || R_PRE.ESTADO || '</ESTADO>');
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<REQUERIR_ASIENTOS_PRESUP>' || R_PRE.REQUERIR_ASIENTOS_PRESUP || '</REQUERIR_ASIENTOS_PRESUP>'); 
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<FECHA_CREACION>' || R_PRE.FECHA_CREACION || '</FECHA_CREACION>');
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<CONGELADO>' || R_PRE.CONGELADO || '</CONGELADO>'); 
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<PRIMER_PER_VAL>' || R_PRE.PRIMER_PER_VAL || '</PRIMER_PER_VAL>');  
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ULTIMO_PER_VAL>' || R_PRE.ULTIMO_PER_VAL || '</ULTIMO_PER_VAL>');
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<ULT_EJERC_ABIER>' || R_PRE.ULT_EJERC_ABIER || '</ULT_EJERC_ABIER>');          
             FND_FILE.PUT_LINE (FND_FILE.OUTPUT,'<LIBRO>' || R_PRE.LIBRO || '</LIBRO>'); 
       
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_PRES>');

       END LOOP;
        FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_PRINCIPAL>');
   EXCEPTION
      WHEN OTHERS THEN
	  
	   print_message (g_type_log_summary,
                        'Error en el procedimiento main : ' || SQLERRM
                       ); 
   END MAIN;
END xxcct_gl_configbr100_pkg;
/