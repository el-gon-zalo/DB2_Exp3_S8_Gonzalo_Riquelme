--YO USO ORACLE CLOUD--

DROP USER PRY2205_USER1 CASCADE;
DROP USER PRY2205_USER2 CASCADE;

-- Usuario 1: dueño
CREATE USER PRY2205_USER1
IDENTIFIED BY "PRY2205.user1.semana8"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON USERS;

-- Usuario 2: consultas
CREATE USER PRY2205_USER2
IDENTIFIED BY "PRY2205.user2.semana8"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP;

--Modificaciones de permisos y roles

GRANT CREATE SESSION TO PRY2205_USER1;
GRANT CREATE SESSION TO PRY2205_USER2;

DROP ROLE PRY2205_ROL_D;
DROP ROLE PRY2205_ROL_P;

CREATE ROLE PRY2205_ROL_D;
CREATE ROLE PRY2205_ROL_P;

GRANT CREATE TABLE TO PRY2205_ROL_D;
GRANT CREATE VIEW TO PRY2205_ROL_D;
GRANT CREATE SYNONYM TO PRY2205_ROL_D;
GRANT CREATE PUBLIC SYNONYM TO PRY2205_ROL_D;


GRANT CREATE TABLE TO PRY2205_ROL_P;
GRANT CREATE SEQUENCE TO PRY2205_ROL_P;
GRANT CREATE TRIGGER TO PRY2205_ROL_P;


GRANT PRY2205_ROL_D TO PRY2205_USER1;
GRANT PRY2205_ROL_P TO PRY2205_USER2;


DROP TABLE CLIENTE CASCADE CONSTRAINTS;

CREATE TABLE CLIENTE (
  ID_CLIENTE NUMBER PRIMARY KEY,
  NOMBRE     VARCHAR2(100)
);


GRANT SELECT ON CLIENTE TO PRY2205_USER2;

DROP PUBLIC SYNONYM CLIENTE;

CREATE PUBLIC SYNONYM CLIENTE FOR PRY2205_USER1.CLIENTE;


--Verificación rápida:

--SELECT * FROM CLIENTE;          
--SELECT * FROM PRY2205_USER1.CLIENTE; 


---------CASO 2------------

GRANT CREATE TABLE TO PRY2205_USER2;
GRANT CREATE SEQUENCE TO PRY2205_USER2;

CONNECT PRY2205_USER2/"PRY2205.user2.semana8";

SHOW USER;

DROP SEQUENCE SEQ_CONTROL_STOCK;

CREATE SEQUENCE SEQ_CONTROL_STOCK
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

DROP TABLE CONTROL_STOCK_LIBROS CASCADE CONSTRAINTS;

CREATE TABLE CONTROL_STOCK_LIBROS AS
SELECT
    SEQ_CONTROL_STOCK.NEXTVAL                         AS correlativo,
    TO_CHAR(ADD_MONTHS(SYSDATE, -24), 'MM/YYYY')      AS fecha_proceso,

    l.libroid                                        AS id_libro,
    UPPER(l.nombre_libro)                            AS nombre_libro,

    COUNT(e.ejemplarid)                              AS total_ejemplares,

    NVL(SUM(
        CASE
            WHEN p.fecha_entrega IS NULL THEN 1
            ELSE 0
        END
    ), 0)                                            AS ejemplares_prestamo,

    COUNT(e.ejemplarid)
      - NVL(SUM(
            CASE
                WHEN p.fecha_entrega IS NULL THEN 1
                ELSE 0
            END
        ), 0)                                        AS ejemplares_disponibles,

    ROUND(
        ( NVL(SUM(
            CASE
                WHEN p.fecha_entrega IS NULL THEN 1
                ELSE 0
            END
        ), 0) / NULLIF(COUNT(e.ejemplarid),0) ) * 100
    , 2)                                             AS porc_ejemplares_prestamo,

    CASE
        WHEN ( COUNT(e.ejemplarid)
               - NVL(SUM(
                    CASE
                        WHEN p.fecha_entrega IS NULL THEN 1
                        ELSE 0
                    END
                 ),0)
             ) > 2
        THEN 'S'
        ELSE 'N'
    END                                              AS indicador_stock_critico
FROM libro l
JOIN ejemplar e
  ON l.libroid = e.libroid
LEFT JOIN prestamo p
  ON p.libroid = e.libroid
 AND p.ejemplarid = e.ejemplarid
 AND p.empleadoid IN (190,180,150)
 AND TRUNC(p.fecha_inicio, 'MM') =
     TRUNC(ADD_MONTHS(SYSDATE, -24), 'MM')
WHERE EXISTS (
    SELECT 1
    FROM prestamo px
    WHERE px.libroid = l.libroid
      AND px.empleadoid IN (190,180,150)
      AND TRUNC(px.fecha_inicio, 'MM') =
          TRUNC(ADD_MONTHS(SYSDATE, -24), 'MM')
)
GROUP BY
    l.libroid,
    l.nombre_libro
ORDER BY
    l.libroid;
    

---------------------CASO 3--------------------

---------3.1----------

-- Conexión como usuario dueño
CONNECT PRY2205_USER1/"PRY2205.user1.semana8";

DROP VIEW VW_DETALLE_MULTAS;

CREATE VIEW VW_DETALLE_MULTAS AS
SELECT
    p.prestamoid                                              AS id_prestamo,
    UPPER(a.nombre || ' ' || a.apaterno || ' ' || a.amaterno) AS alumno,
    c.descripcion                                             AS carrera,
    l.libroid                                                 AS codigo_libro,
    l.precio                                                  AS precio_libro,
    p.fecha_termino                                           AS fecha_termino,
    p.fecha_entrega                                           AS fecha_entrega,
    (p.fecha_entrega - p.fecha_termino)                      AS dias_atraso,
    ROUND((l.precio * 0.03) * (p.fecha_entrega - p.fecha_termino), 2) AS multa_sin_rebaja,
    ROUND(
        ((l.precio * 0.03) * (p.fecha_entrega - p.fecha_termino)) *
        (1 - NVL(r.porc_rebaja_multa, 0)/100), 2
    ) AS multa_con_rebaja
FROM PRESTAMO p
JOIN ALUMNO a
  ON p.alumnoid = a.alumnoid
JOIN CARRERA c
  ON a.carreraid = c.carreraid
JOIN LIBRO l
  ON p.libroid = l.libroid
LEFT JOIN REBAJA_MULTA r
  ON a.carreraid = r.carreraid
WHERE TRUNC(p.fecha_termino, 'YYYY') = TRUNC(ADD_MONTHS(SYSDATE, -24), 'YYYY')
  AND p.fecha_entrega > p.fecha_termino
ORDER BY p.fecha_entrega DESC;

-- Verificación rápida de la vista
-- SELECT * FROM VW_DETALLE_MULTAS;


---------3.2----------

-- Conexión como usuario dueño
CONNECT PRY2205_USER1/"PRY2205.user1.semana8";

-- Creación de índices 

-- Índices para mejorar filtros por fecha
CREATE INDEX IDX_PRESTAMO_FECHA_TERMINO ON PRESTAMO(fecha_termino);
CREATE INDEX IDX_PRESTAMO_FECHA_ENTREGA ON PRESTAMO(fecha_entrega);

-- Índices para joins
CREATE INDEX IDX_PRESTAMO_ALUMNOID ON PRESTAMO(alumnoid);
CREATE INDEX IDX_ALUMNO_CARRERAID ON ALUMNO(carreraid);
CREATE INDEX IDX_LIBRO_LIBROID ON LIBRO(libroid);
CREATE INDEX IDX_REBAJA_CARRERAID ON REBAJA_MULTA(carreraid);

-- Verificación rápida
-- EXPLAIN PLAN FOR
-- SELECT * FROM VW_DETALLE_MULTAS;

