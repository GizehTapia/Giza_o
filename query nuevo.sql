/* Formatted on 01/09/2014 02:31:33 p. m. (QP5 v5.139.911.3011) */
SELECT xep.name,
       reg.REGISTRATION_NUMBER,
          loc.address_line_1
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
       || t.territory_short_name
          registratered_address,
       t.territory_short_name territory,
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
       AND jtl.LANGUAGE = USERENV ('LANG')
       AND xep.NAME LIKE
              'MARCAS DE RENOMBRE, S.A. DE C.V.MARCAS DE RENOMBRE, S.A. DE C.V.';

--  G_ESTABLISHMENT



  SELECT DISTINCT *
    FROM xle_etb_profiles xetbp
GROUP BY legal_entity_id
  HAVING COUNT (*) > 2
        ,XLE_LOOKUPS xl