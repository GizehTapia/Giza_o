/* Formatted on 27/08/2014 01:02:16 p. m. (QP5 v5.139.911.3011) */
CREATE OR REPLACE PACKAGE apps.xxcct_gl_configbr100_pkg
IS
--$Id:$
/***********************************************************
                                   Condor Consulting Team S.C.
                                              
NAME        : xxcct_gl_configbr100_pkg
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
   
   FUNCTION replace_char (p_texto VARCHAR2)
   RETURN VARCHAR2;
      
   PROCEDURE insert_segment (p_nombre_estructura IN VARCHAR2);

   PROCEDURE insert_value_sets (p_nom_estructura IN VARCHAR2);

   PROCEDURE insert_calendary (p_period_set_name IN VARCHAR2);

   PROCEDURE inserta_librosr (p_book_name VARCHAR2);

   PROCEDURE insertar_tabla_entidades;

   PROCEDURE insertar_tabla_profiles (p_responsabilidades VARCHAR2);

   PROCEDURE inserta_cerr_abr (p_book_name VARCHAR2);

   PROCEDURE insertar_divisas (p_book_name IN VARCHAR2);

   PROCEDURE insertar_tabla_origen_asiento;

   PROCEDURE insertar_tabla_categoria;

   PROCEDURE insertar_secuencias_doc;

   PROCEDURE inserta_presupuestos (p_book_name     IN VARCHAR2,
                                   p_budget_name   IN VARCHAR2);

   PROCEDURE importador_cuentas_contables;

   PROCEDURE main (x_errormsg               OUT VARCHAR2,
                   x_errorcode              OUT NUMBER,
                   p_nom_estructura      IN     VARCHAR2,
                   p_period_set_name     IN     VARCHAR2,
                   p_responsabilidades   IN     VARCHAR2,
                   p_book_name           IN     VARCHAR2,
                   p_budget_name         IN     VARCHAR2);
END xxcct_gl_configbr100_pkg;
/