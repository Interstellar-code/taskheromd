# Table Dependencies Analysis Template

This document analyzes the dependencies between database tables to determine the correct order for creating tables in migrations. This analysis is crucial for maintaining referential integrity and avoiding foreign key constraint errors during database setup.

## Tables with No Dependencies (Base Tables)

These tables can be created first as they don't depend on other tables:

1. `[table_name_1]` - [Reason for no dependencies]
2. `[table_name_2]` - [Reason for no dependencies]
3. `[table_name_3]` - [Reason for no dependencies]
4. `[table_name_4]` - [Reason for no dependencies]
5. `[table_name_5]` - [Reason for no dependencies]
6. `[table_name_6]` - [Reason for no dependencies]
7. `[table_name_7]` - [Reason for no dependencies]
8. `[table_name_8]` - [Reason for no dependencies]
9. `[table_name_9]` - [Reason for no dependencies]
10. `[table_name_10]` - [Reason for no dependencies]
11. `[table_name_11]` - [Reason for no dependencies]
12. `[table_name_12]` - [Reason for no dependencies]

## Tables with Dependencies (Level 1)

These tables depend on base tables:

1. `[table_name_1]` - Depends on `[base_table_1]`
2. `[table_name_2]` - Depends on `[base_table_1]`, `[base_table_2]`, `[base_table_3]`
3. `[table_name_3]` - Depends on `[base_table_4]`
4. `[table_name_4]` - Depends on `[base_table_4]` (nullable)
5. `[table_name_5]` - Depends on `[base_table_4]`
6. `[table_name_6]` - Depends on `[base_table_4]`
7. `[table_name_7]` - Depends on `[base_table_4]`
8. `[table_name_8]` - Depends on `[base_table_4]` (multiple nullable references)

## Tables with Dependencies (Level 2)

These tables depend on Level 1 tables:

1. `[table_name_1]` - Depends on `[level1_table_2]`
2. `[table_name_2]` - Depends on `[level1_table_1]`, `[base_table_10]` (nullable)
3. `[table_name_3]` - Depends on `[base_table_4]`, `[base_table_6]` (nullable), `[level1_table_2]` (nullable), `[level1_table_3]` (nullable), `[level1_table_4]` (nullable), `[level1_table_5]` (nullable), `[level1_table_6]` (nullable)
4. `[table_name_4]` - Depends on `[base_table_4]`, `[base_table_10]`

## Tables with Dependencies (Level 3)

These tables depend on Level 2 tables:

1. `[table_name_1]` - Depends on `[level2_table_2]`
2. `[table_name_2]` - Depends on `[level1_table_6]`, `[level2_table_3]`
3. `[table_name_3]` - Depends on `[level2_table_3]`
4. `[table_name_4]` - Depends on `[base_table_4]`, `[level1_table_6]`, `[level2_table_3]`
5. `[table_name_5]` - Depends on `[base_table_4]`, `[level2_table_3]`

## Complete Dependency Order

Based on the analysis, here's the recommended order for creating tables in the migration:

1. `[base_table_1]`
2. `[base_table_2]`
3. `[base_table_3]`
4. `[base_table_4]`
5. `[base_table_5]`
6. `[base_table_6]`
7. `[base_table_7]`
8. `[base_table_8]`
9. `[base_table_9]`
10. `[base_table_10]`
11. `[base_table_11]`
12. `[base_table_12]`
13. `[level1_table_1]`
14. `[level1_table_2]`
15. `[level1_table_3]`
16. `[level1_table_4]`
17. `[level1_table_5]`
18. `[level1_table_6]`
19. `[level1_table_7]`
20. `[level1_table_8]`
21. `[level2_table_1]`
22. `[level2_table_2]`
23. `[level2_table_3]`
24. `[level2_table_4]`
25. `[level3_table_1]`
26. `[level3_table_2]`
27. `[level3_table_3]`
28. `[level3_table_4]`
29. `[level3_table_5]`

## Foreign Key Constraints

After creating all tables, we need to add foreign key constraints in the reverse order of the dependencies:

1. Add foreign keys for Level 3 tables
2. Add foreign keys for Level 2 tables
3. Add foreign keys for Level 1 tables

This ensures that all referenced tables exist before adding the constraints.

## Notes on Circular Dependencies

There are some potential circular dependencies in the schema:
- `[table_name_1]` references `[table_name_2]` and `[table_name_3]`
- `[table_name_4]` references `[table_name_3]` and `[table_name_1]`

To handle these, we'll:
1. Create all tables first without foreign key constraints
2. Add the foreign key constraints after all tables are created
3. Make sure to use the correct constraint options (CASCADE, SET NULL, etc.) based on the SQL schema

## Migration Implementation Strategy

When implementing migrations based on this analysis:

1. Create separate migration files for each dependency level
2. Use nullable foreign keys for circular dependencies
3. Consider using deferred constraints if your database supports them
4. Test the migration process in a development environment before deploying

## Notes for AI Agent

When populating this template:
1. Replace all placeholder table names with actual table names from the project
2. Accurately identify dependencies between tables based on foreign key relationships
3. Note any nullable foreign keys as they affect the creation order
4. Identify and document any circular dependencies
5. Verify the complete dependency order is correct and comprehensive
6. Consider adding a visual representation of dependencies if helpful
7. Update the migration implementation strategy with project-specific details
