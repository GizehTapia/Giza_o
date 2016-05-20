/* Formatted on 28/08/2014 11:14:39 a. m. (QP5 v5.139.911.3011) */
CREATE OR REPLACE PACKAGE apps.xxcct_gl_cuentas_pkg 
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
   PROCEDURE print_message (p_type_output NUMBER, p_message VARCHAR2);
   
   FUNCTION get_chart_of_accounts_id
      RETURN NUMBER;

   PROCEDURE insert_accounts;

   PROCEDURE main (x_errormsg  OUT VARCHAR2, 
                               x_errorcode OUT NUMBER);                                
END xxcct_gl_cuentas_pkg;
/