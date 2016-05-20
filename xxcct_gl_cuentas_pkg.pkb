/* Formatted on 29/08/2014 01:11:09 p. m. (QP5 v5.139.911.3011) */
CREATE OR REPLACE PACKAGE BODY xxcct_gl_cuentas_pkg
IS
--$Id:$
/***********************************************************
                                   Condor Consulting Team S.C.
                                              
NAME        : xxcct_gl_cuentas_pkg
DESCRIPTION : Su función es generar un reporte en excel de todas aquellas cuentas
                       de GL que cumplan con las caracteristicas mencionadas en el archivo
                       DS080 GL.
HISTORY     :

    FECHA        VERSION     QUIEN              CAMBIOS
  ----------    ---------   ----------------    ----------------------------------
 28-08-14        1.0        GTL                
***********************************************************/
--- Variables globales

   g_type_output_summary   NUMBER           := 3;
   g_type_log_summary        NUMBER           := 2;
   g_chart_of_accounts          NUMBER;
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
   
/***********************************************************
  ----   Procedimiento Para insertar Cuentas Contables en la tabla temporal 
                                 XXCCT_GL_COMBINATIONS_CON
***********************************************************/   
   PROCEDURE insert_accounts
   IS
    CURSOR c_cuentas 
    IS
    SELECT DECODE (cc.enabled_flag, 'N', ' ', '*') activado,
                DECODE (cc.summary_flag, 'N', ' ', '*') preservado,
                cc.segment1
               || '.' || cc.segment2
               || '.' || cc.segment3
               || '.' || cc.segment4
               || '.' || cc.segment5
               || '.' || cc.segment6  Cuenta,
               lk.description Tipo,
               cc.start_date_active fecha_desde,
               cc.end_date_active fecha_hasta,
               DECODE (cc.detail_posting_allowed_flag, 'N', ' ', '*')
               Autorizar_contabilizacion,
               DECODE (cc.detail_budgeting_allowed_flag, 'N', ' ', '*')
               autorizar_presupuesto,
               cc.alternate_code_combination_id cuenta_alterna,
               DECODE (cc.jgzz_recon_flag, 'N', ' ', '*') conciliar,
                fnd_global.user_id created_by,
                fnd_global.conc_request_id request_id,
                               TO_CHAR (SYSDATE, 'DD-MON-YYYY') last_update_date,
                fnd_global.user_id last_updated_by                             
      FROM gl_code_combinations cc, gl_lookups lk
    WHERE     lk.lookup_type(+) = 'ACCOUNT TYPE'
        AND lk.lookup_code(+) = cc.account_type
        AND chart_of_accounts_id = g_chart_of_accounts
       AND template_id IS NULL;
 
 
   TYPE l_cuentas IS TABLE OF c_cuentas%ROWTYPE
   INDEX BY BINARY_INTEGER;

   l_valuesc l_cuentas;
   l_contador NUMBER := 1;
   BEGIN
    
    
         FOR r_con IN c_cuentas LOOP 
            l_valuesc (l_contador).activado := r_con.Activado;
            l_valuesc (l_contador).preservado := r_con.Preservado;
            l_valuesc (l_contador).cuenta := r_con.Cuenta;
            l_valuesc (l_contador).tipo := r_con.Tipo;
            l_valuesc (l_contador).fecha_desde := r_con.Fecha_desde;
            l_valuesc (l_contador).fecha_Hasta := r_con.Fecha_Hasta;
            l_valuesc (l_contador).autorizar_contabilizacion := r_con.Autorizar_contabilizacion;
            l_valuesc (l_contador).autorizar_presupuesto := r_con.Autorizar_presupuesto;
            l_valuesc (l_contador).cuenta_alterna := r_con.Cuenta_alterna;
            l_valuesc (l_contador).conciliar := r_con.Conciliar;
            l_valuesc (l_contador).last_update_date := r_con.last_update_date;
            l_valuesc (l_contador).created_by := r_con.created_by ;
            l_valuesc (l_contador).request_id := r_con.request_id;
            l_valuesc (l_contador).last_updated_by := r_con.last_updated_by;
            
            l_contador := l_contador + 1;
           
         END LOOP;

        --Tabla de Cuentas contables............
        FORALL Y IN l_valuesc.FIRST .. l_valuesc.LAST 
             INSERT INTO XXCCT_GL_COMBINATIONS_CON
                     VALUES l_valuesc (Y);
        COMMIT; 
   EXCEPTION
      WHEN OTHERS THEN
         print_message (g_type_log_summary,
                        'Error en el procedimiento insert_accounts  :' || SQLERRM
                       );      
    
   END insert_accounts;
 
   PROCEDURE main ( x_errormsg OUT VARCHAR2
                             , x_errorcode OUT NUMBER ) 
   IS  
        CURSOR c_cuentas
        IS
        SELECT * 
          FROM XXCCT_GL_COMBINATIONS_CON
        WHERE 1 = 1
            AND request_id = fnd_global.conc_request_id;
   BEGIN  
    ---
    execute immediate 'ALTER SESSION SET NLS_LANGUAGE = ''AMERICAN'''; 
    ---
    ---
    g_chart_of_accounts := get_chart_of_accounts_id;
    ---
    ---
    insert_accounts;
    ---
    ---
    print_message (g_type_output_summary, q'[<?xml version="1.0" encoding="UTF-8"?>]');
    print_message (g_type_output_summary, '<G_PRINCIPAL>'); 

        FOR r_con IN c_cuentas LOOP
             print_message (g_type_output_summary, '<G_CUENTAS>'); 
             print_message (g_type_output_summary, '<Activado>' || r_con.Activado || '</Activado>');
             print_message (g_type_output_summary, '<Preservado>' || r_con.Preservado || '</Preservado>');
             print_message (g_type_output_summary, '<Cuenta>' || r_con.Cuenta || '</Cuenta>');
             print_message (g_type_output_summary, '<Tipo>' || r_con.Tipo || '</Tipo>');
             print_message (g_type_output_summary, '<Fecha_desde>' || r_con.Fecha_desde || '</Fecha_desde>');
             print_message (g_type_output_summary, '<Fecha_Hasta>' || r_con.Fecha_Hasta || '</Fecha_Hasta>');
             print_message (g_type_output_summary, '<Autorizar_contabilizacion>' || r_con.Autorizar_contabilizacion || '</Autorizar_contabilizacion>');
             print_message (g_type_output_summary, '<Autorizar_presupuesto>' || r_con.Autorizar_presupuesto || '</Autorizar_presupuesto>');
             print_message (g_type_output_summary, '<Cuenta_alterna>' || r_con.Cuenta_alterna || '</Cuenta_alterna>');
             print_message (g_type_output_summary, '<Conciliar>' || r_con.Conciliar || '</Conciliar>');
             print_message (g_type_output_summary,  '</G_CUENTAS>');
        END LOOP; 

    print_message (g_type_output_summary,  '</G_PRINCIPAL>'); 
    EXCEPTION
      WHEN OTHERS THEN
         print_message (g_type_log_summary,
                        'Error en el procedimiento main  :' || SQLERRM
                       );      
   END main ; 
 END xxcct_gl_cuentas_pkg;
/