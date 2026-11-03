-- SPDX-License-Identifier: Apache-2.0
-- RAFAELIA Omega LOG999: source-bound DERIVED mathematical projection ONLY.
-- NOT A MIGRATION. No DDL, DML, GRANTS or provider data changes.
-- Source: RafPolimata/docs/COGNITIVE_SPIRAL_CUBE_10X10X10_V1.md
-- Original: ln(ln(999/936)), three 120-degree arms, bounded 10x10x10.
-- NEW composition: r_n=999*(2/sqrt(3))^n; phase=n*pi()/6+2*pi()*arm/3.
-- NOT proof of 42 period, of biological dynamics, or of storage growth.
BEGIN TRANSACTION READ ONLY;
WITH spiral_steps AS (
  SELECT n, 999.0 * power(2.0 / sqrt(3.0), n) AS radius
  FROM generate_series(0, 42) AS step(n)
), arms AS (
  SELECT a, CASE a
    WHEN 0 THEN sqrt(pi()) / 5.0
    WHEN 1 THEN sqrt(pi()) / 12.0
    ELSE sqrt(5.0) / 9.0
  END AS arm_weight
  FROM generate_series(0, 2) AS arm(a)
), projection AS (
  SELECT s.n, a.a AS arm, s.radius,
    s.radius / 936.0 AS source_ratio_extension,
    ln(ln(s.radius / 936.0)) AS loglog_ratio,
    (s.n * pi() / 6.0 + 2.0 * pi() * a.a / 3.0) AS angle_rad,
    a.arm_weight
  FROM spiral_steps s CROSS JOIN arms a
)
SELECT n, arm, radius, source_ratio_extension, loglog_ratio,
       angle_rad,
       radius * cos(angle_rad) AS x,
       radius * sin(angle_rad) AS y,
       arm_weight * radius * cos(angle_rad) AS weighted_x,
       arm_weight * radius * sin(angle_rad) AS weighted_y
FROM projection
ORDER BY n, arm;
ROLLBACK;
-- Expected 43*3=129 synthetic rows, zero persistent changes.
-- Existing (draft, NOT deployed) logical layers:
-- arm 0 -> raf_private.source_registry; arm 1 -> raf_private.lineage_edges;
-- arm 2 -> raf_private.evidence_events. This script never reads those tables.
