/* ========================================================================
   DICIONÁRIO DE DADOS - SQL SERVER 2022
   ========================================================================

   OBJETIVO:
       Extrair a estrutura do banco de dados sem alterar nenhum objeto.

   SEGURANÇA:
       - SOMENTE SELECT
       - Não executa INSERT
       - Não executa UPDATE
       - Não executa DELETE
       - Não executa CREATE / ALTER / DROP
       - Não utiliza sp_rename, sp_executesql ou comandos dinâmicos

   EXECUTAR:
       No banco que deseja documentar.

   ======================================================================== */


USE [SEU_BANCO];
GO


/* ========================================================================
   01. RESUMO DO BANCO
   ======================================================================== */

SELECT
    DB_NAME() AS database_name,
    SERVERPROPERTY('ServerName') AS server_name,
    SERVERPROPERTY('ProductVersion') AS sql_server_version,
    SERVERPROPERTY('ProductLevel') AS product_level,
    SERVERPROPERTY('Edition') AS edition,
    GETDATE() AS generated_at;


/* ========================================================================
   02. SCHEMAS
   ======================================================================== */

SELECT
    s.schema_id,
    s.name AS schema_name,
    USER_NAME(s.principal_id) AS owner_name
FROM sys.schemas s
ORDER BY
    s.name;


/* ========================================================================
   03. TABELAS
   ======================================================================== */

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    t.object_id,
    t.create_date,
    t.modify_date,
    t.temporal_type_desc,
    t.is_memory_optimized,
    t.is_filetable
FROM sys.tables t
INNER JOIN sys.schemas s
    ON s.schema_id = t.schema_id
ORDER BY
    s.name,
    t.name;


/* ========================================================================
   04. TABELAS + QUANTIDADE DE REGISTROS
   ======================================================================== */

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    SUM(p.rows) AS row_count
FROM sys.tables t
INNER JOIN sys.schemas s
    ON s.schema_id = t.schema_id
INNER JOIN sys.partitions p
    ON p.object_id = t.object_id
WHERE
    p.index_id IN (0, 1)
GROUP BY
    s.name,
    t.name
ORDER BY
    s.name,
    t.name;


/* ========================================================================
   05. COLUNAS
   ======================================================================== */

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    c.column_id,
    c.name AS column_name,

    ty.name AS data_type,

    CASE
        WHEN ty.name IN
        (
            'varchar',
            'char',
            'varbinary',
            'binary'
        )
        THEN
            CASE
                WHEN c.max_length = -1
                    THEN 'MAX'
                ELSE
                    CAST(c.max_length AS VARCHAR(10))
            END

        WHEN ty.name IN
        (
            'nvarchar',
            'nchar'
        )
        THEN
            CASE
                WHEN c.max_length = -1
                    THEN 'MAX'
                ELSE
                    CAST(c.max_length / 2 AS VARCHAR(10))
            END

        ELSE NULL
    END AS max_length,

    c.precision,
    c.scale,

    CASE
        WHEN c.is_nullable = 1
            THEN 'SIM'
        ELSE 'NÃO'
    END AS nullable,

    CASE
        WHEN c.is_identity = 1
            THEN 'SIM'
        ELSE 'NÃO'
    END AS is_identity,

    CASE
        WHEN c.is_computed = 1
            THEN 'SIM'
        ELSE 'NÃO'
    END AS is_computed,

    dc.definition AS default_definition,

    cc.definition AS computed_definition,

    c.collation_name

FROM sys.columns c

INNER JOIN sys.tables t
    ON t.object_id = c.object_id

INNER JOIN sys.schemas s
    ON s.schema_id = t.schema_id

INNER JOIN sys.types ty
    ON ty.user_type_id = c.user_type_id

LEFT JOIN sys.default_constraints dc
    ON dc.object_id = c.default_object_id

LEFT JOIN sys.computed_columns cc
    ON cc.object_id = c.object_id
    AND cc.column_id = c.column_id

ORDER BY
    s.name,
    t.name,
    c.column_id;


/* ========================================================================
   06. PRIMARY KEYS
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    tab.name AS table_name,
    kc.name AS primary_key_name,
    col.name AS column_name,
    ic.key_ordinal,
    ic.is_descending_key
FROM sys.key_constraints kc

INNER JOIN sys.tables tab
    ON tab.object_id = kc.parent_object_id

INNER JOIN sys.schemas sch
    ON sch.schema_id = tab.schema_id

INNER JOIN sys.index_columns ic
    ON ic.object_id = kc.parent_object_id
    AND ic.index_id = kc.unique_index_id

INNER JOIN sys.columns col
    ON col.object_id = ic.object_id
    AND col.column_id = ic.column_id

WHERE
    kc.type = 'PK'

ORDER BY
    sch.name,
    tab.name,
    kc.name,
    ic.key_ordinal;


/* ========================================================================
   07. FOREIGN KEYS / RELACIONAMENTOS
   ======================================================================== */

SELECT
    fk.name AS foreign_key_name,

    sch_parent.name AS parent_schema,
    tab_parent.name AS parent_table,
    col_parent.name AS parent_column,

    sch_ref.name AS referenced_schema,
    tab_ref.name AS referenced_table,
    col_ref.name AS referenced_column,

    fkc.constraint_column_id AS column_ordinal,

    fk.delete_referential_action_desc AS on_delete,
    fk.update_referential_action_desc AS on_update,

    CASE
        WHEN fk.is_disabled = 1
            THEN 'DESABILITADA'
        ELSE 'ATIVA'
    END AS status

FROM sys.foreign_keys fk

INNER JOIN sys.foreign_key_columns fkc
    ON fkc.constraint_object_id = fk.object_id

INNER JOIN sys.tables tab_parent
    ON tab_parent.object_id = fk.parent_object_id

INNER JOIN sys.schemas sch_parent
    ON sch_parent.schema_id = tab_parent.schema_id

INNER JOIN sys.columns col_parent
    ON col_parent.object_id = fkc.parent_object_id
    AND col_parent.column_id = fkc.parent_column_id

INNER JOIN sys.tables tab_ref
    ON tab_ref.object_id = fk.referenced_object_id

INNER JOIN sys.schemas sch_ref
    ON sch_ref.schema_id = tab_ref.schema_id

INNER JOIN sys.columns col_ref
    ON col_ref.object_id = fkc.referenced_object_id
    AND col_ref.column_id = fkc.referenced_column_id

ORDER BY
    sch_parent.name,
    tab_parent.name,
    fk.name,
    fkc.constraint_column_id;


/* ========================================================================
   08. UNIQUE CONSTRAINTS
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    tab.name AS table_name,
    kc.name AS constraint_name,
    col.name AS column_name,
    ic.key_ordinal
FROM sys.key_constraints kc

INNER JOIN sys.tables tab
    ON tab.object_id = kc.parent_object_id

INNER JOIN sys.schemas sch
    ON sch.schema_id = tab.schema_id

INNER JOIN sys.index_columns ic
    ON ic.object_id = kc.parent_object_id
    AND ic.index_id = kc.unique_index_id

INNER JOIN sys.columns col
    ON col.object_id = ic.object_id
    AND col.column_id = ic.column_id

WHERE
    kc.type = 'UQ'

ORDER BY
    sch.name,
    tab.name,
    kc.name,
    ic.key_ordinal;


/* ========================================================================
   09. CHECK CONSTRAINTS
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    tab.name AS table_name,
    cc.name AS constraint_name,
    col.name AS column_name,
    cc.definition,
    cc.is_disabled,
    cc.is_not_trusted
FROM sys.check_constraints cc

INNER JOIN sys.tables tab
    ON tab.object_id = cc.parent_object_id

INNER JOIN sys.schemas sch
    ON sch.schema_id = tab.schema_id

LEFT JOIN sys.columns col
    ON col.object_id = cc.parent_object_id
    AND col.column_id = cc.parent_column_id

ORDER BY
    sch.name,
    tab.name,
    cc.name;


/* ========================================================================
   10. DEFAULT CONSTRAINTS
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    tab.name AS table_name,
    col.name AS column_name,
    dc.name AS constraint_name,
    dc.definition
FROM sys.default_constraints dc

INNER JOIN sys.tables tab
    ON tab.object_id = dc.parent_object_id

INNER JOIN sys.schemas sch
    ON sch.schema_id = tab.schema_id

INNER JOIN sys.columns col
    ON col.object_id = dc.parent_object_id
    AND col.column_id = dc.parent_column_id

ORDER BY
    sch.name,
    tab.name,
    col.column_id;


/* ========================================================================
   11. ÍNDICES
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    tab.name AS table_name,

    i.name AS index_name,
    i.index_id,

    i.type_desc AS index_type,

    CASE
        WHEN i.is_unique = 1
            THEN 'SIM'
        ELSE 'NÃO'
    END AS is_unique,

    CASE
        WHEN i.is_primary_key = 1
            THEN 'SIM'
        ELSE 'NÃO'
    END AS is_primary_key,

    CASE
        WHEN i.is_unique_constraint = 1
            THEN 'SIM'
        ELSE 'NÃO'
    END AS is_unique_constraint,

    CASE
        WHEN i.is_disabled = 1
            THEN 'SIM'
        ELSE 'NÃO'
    END AS is_disabled,

    i.filter_definition,

    ic.key_ordinal,

    col.name AS column_name,

    CASE
        WHEN ic.is_descending_key = 1
            THEN 'DESC'
        ELSE 'ASC'
    END AS sort_order,

    CASE
        WHEN ic.is_included_column = 1
            THEN 'SIM'
        ELSE 'NÃO'
    END AS included_column

FROM sys.indexes i

INNER JOIN sys.tables tab
    ON tab.object_id = i.object_id

INNER JOIN sys.schemas sch
    ON sch.schema_id = tab.schema_id

INNER JOIN sys.index_columns ic
    ON ic.object_id = i.object_id
    AND ic.index_id = i.index_id

INNER JOIN sys.columns col
    ON col.object_id = ic.object_id
    AND col.column_id = ic.column_id

WHERE
    i.index_id > 0

ORDER BY
    sch.name,
    tab.name,
    i.name,
    ic.key_ordinal;


/* ========================================================================
   12. VIEWS
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    v.name AS view_name,
    v.object_id,
    v.create_date,
    v.modify_date,
    m.definition
FROM sys.views v

INNER JOIN sys.schemas sch
    ON sch.schema_id = v.schema_id

LEFT JOIN sys.sql_modules m
    ON m.object_id = v.object_id

ORDER BY
    sch.name,
    v.name;


/* ========================================================================
   13. STORED PROCEDURES
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    p.name AS procedure_name,
    p.object_id,
    p.create_date,
    p.modify_date,
    m.definition
FROM sys.procedures p

INNER JOIN sys.schemas sch
    ON sch.schema_id = p.schema_id

LEFT JOIN sys.sql_modules m
    ON m.object_id = p.object_id

ORDER BY
    sch.name,
    p.name;


/* ========================================================================
   14. FUNCTIONS
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    o.name AS function_name,
    o.type_desc,
    o.object_id,
    o.create_date,
    o.modify_date,
    m.definition
FROM sys.objects o

INNER JOIN sys.schemas sch
    ON sch.schema_id = o.schema_id

LEFT JOIN sys.sql_modules m
    ON m.object_id = o.object_id

WHERE
    o.type IN
    (
        'FN',
        'IF',
        'TF',
        'FS',
        'FT'
    )

ORDER BY
    sch.name,
    o.name;


/* ========================================================================
   15. TRIGGERS DE TABELAS
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    tab.name AS table_name,
    tr.name AS trigger_name,
    tr.is_disabled,
    tr.is_instead_of_trigger,
    tr.create_date,
    tr.modify_date,
    m.definition
FROM sys.triggers tr

INNER JOIN sys.tables tab
    ON tab.object_id = tr.parent_id

INNER JOIN sys.schemas sch
    ON sch.schema_id = tab.schema_id

LEFT JOIN sys.sql_modules m
    ON m.object_id = tr.object_id

WHERE
    tr.parent_class = 1

ORDER BY
    sch.name,
    tab.name,
    tr.name;


/* ========================================================================
   16. TRIGGERS DE DATABASE
   ======================================================================== */

SELECT
    tr.name AS trigger_name,
    tr.is_disabled,
    tr.create_date,
    tr.modify_date,
    m.definition
FROM sys.triggers tr

LEFT JOIN sys.sql_modules m
    ON m.object_id = tr.object_id

WHERE
    tr.parent_class = 0

ORDER BY
    tr.name;


/* ========================================================================
   17. SEQUENCES
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    seq.name AS sequence_name,
    typ.name AS data_type,
    seq.start_value,
    seq.increment,
    seq.minimum_value,
    seq.maximum_value,
    seq.current_value,
    seq.is_cycling,
    seq.is_cached,
    seq.cache_size
FROM sys.sequences seq

INNER JOIN sys.schemas sch
    ON sch.schema_id = seq.schema_id

INNER JOIN sys.types typ
    ON typ.user_type_id = seq.user_type_id

ORDER BY
    sch.name,
    seq.name;


/* ========================================================================
   18. SINÔNIMOS
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    sn.name AS synonym_name,
    sn.base_object_name
FROM sys.synonyms sn

INNER JOIN sys.schemas sch
    ON sch.schema_id = sn.schema_id

ORDER BY
    sch.name,
    sn.name;


/* ========================================================================
   19. OBJETOS DO BANCO
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    o.name AS object_name,
    o.type,
    o.type_desc,
    o.create_date,
    o.modify_date
FROM sys.objects o

INNER JOIN sys.schemas sch
    ON sch.schema_id = o.schema_id

ORDER BY
    sch.name,
    o.type_desc,
    o.name;


/* ========================================================================
   20. DEPENDÊNCIAS ENTRE OBJETOS
   ======================================================================== */

SELECT
    sch_ref.name AS referencing_schema,
    obj_ref.name AS referencing_object,
    obj_ref.type_desc AS referencing_type,

    sch_target.name AS referenced_schema,
    obj_target.name AS referenced_object,
    obj_target.type_desc AS referenced_type,

    sed.referenced_entity_name,
    sed.referenced_minor_name

FROM sys.sql_expression_dependencies sed

INNER JOIN sys.objects obj_ref
    ON obj_ref.object_id = sed.referencing_id

INNER JOIN sys.schemas sch_ref
    ON sch_ref.schema_id = obj_ref.schema_id

LEFT JOIN sys.objects obj_target
    ON obj_target.object_id = sed.referenced_id

LEFT JOIN sys.schemas sch_target
    ON sch_target.schema_id = obj_target.schema_id

ORDER BY
    sch_ref.name,
    obj_ref.name;


/* ========================================================================
   21. COMENTÁRIOS DAS TABELAS
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    tab.name AS table_name,
    ep.value AS table_description
FROM sys.tables tab

INNER JOIN sys.schemas sch
    ON sch.schema_id = tab.schema_id

LEFT JOIN sys.extended_properties ep
    ON ep.major_id = tab.object_id
    AND ep.minor_id = 0
    AND ep.name = 'MS_Description'

ORDER BY
    sch.name,
    tab.name;


/* ========================================================================
   22. COMENTÁRIOS DAS COLUNAS
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    tab.name AS table_name,
    col.name AS column_name,
    ep.value AS column_description
FROM sys.columns col

INNER JOIN sys.tables tab
    ON tab.object_id = col.object_id

INNER JOIN sys.schemas sch
    ON sch.schema_id = tab.schema_id

LEFT JOIN sys.extended_properties ep
    ON ep.major_id = col.object_id
    AND ep.minor_id = col.column_id
    AND ep.name = 'MS_Description'

ORDER BY
    sch.name,
    tab.name,
    col.column_id;


/* ========================================================================
   23. ESTATÍSTICAS DE TABELAS
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    tab.name AS table_name,

    SUM(ps.row_count) AS row_count,

    SUM(ps.reserved_page_count) * 8 AS reserved_kb,

    SUM(ps.used_page_count) * 8 AS used_kb,

    SUM(ps.in_row_data_page_count) * 8 AS data_kb

FROM sys.dm_db_partition_stats ps

INNER JOIN sys.tables tab
    ON tab.object_id = ps.object_id

INNER JOIN sys.schemas sch
    ON sch.schema_id = tab.schema_id

GROUP BY
    sch.name,
    tab.name

ORDER BY
    SUM(ps.reserved_page_count) DESC;


/* ========================================================================
   24. TABELAS SEM PRIMARY KEY
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    tab.name AS table_name
FROM sys.tables tab

INNER JOIN sys.schemas sch
    ON sch.schema_id = tab.schema_id

LEFT JOIN sys.key_constraints kc
    ON kc.parent_object_id = tab.object_id
    AND kc.type = 'PK'

WHERE
    kc.object_id IS NULL

ORDER BY
    sch.name,
    tab.name;


/* ========================================================================
   25. COLUNAS QUE PARTICIPAM DE FOREIGN KEY
   ======================================================================== */

SELECT
    sch.name AS schema_name,
    tab.name AS table_name,
    col.name AS column_name,

    fk.name AS foreign_key_name,

    sch_ref.name AS referenced_schema,
    tab_ref.name AS referenced_table,
    col_ref.name AS referenced_column

FROM sys.foreign_key_columns fkc

INNER JOIN sys.foreign_keys fk
    ON fk.object_id = fkc.constraint_object_id

INNER JOIN sys.tables tab
    ON tab.object_id = fkc.parent_object_id

INNER JOIN sys.schemas sch
    ON sch.schema_id = tab.schema_id

INNER JOIN sys.columns col
    ON col.object_id = fkc.parent_object_id
    AND col.column_id = fkc.parent_column_id

INNER JOIN sys.tables tab_ref
    ON tab_ref.object_id = fkc.referenced_object_id

INNER JOIN sys.schemas sch_ref
    ON sch_ref.schema_id = tab_ref.schema_id

INNER JOIN sys.columns col_ref
    ON col_ref.object_id = fkc.referenced_object_id
    AND col_ref.column_id = fkc.referenced_column_id

ORDER BY
    sch.name,
    tab.name,
    col.column_id;


/* ========================================================================
   FIM
   ======================================================================== */