USE TripISEP;
GO

-- e) Para cada condutor que não seja supervisor: nome, nr_idCivil e as viagens com
--    custo inferior à média do custo das 20% melhores (mais caras) viagens do seu
--    supervisor. As 20% melhores = 1.º quintil (NTILE(5)) das viagens do supervisor.
WITH ViagensCondutor AS (
    SELECT p.nr_idCivil_condutor,
           v.nr_viagem,
           v.custo_total
    FROM Viagem v
    JOIN Pedido_Viagem p ON p.cod_pedido = v.cod_pedido
    WHERE p.nr_idCivil_condutor IS NOT NULL
),
Quintis AS (
    SELECT nr_idCivil_condutor,
           custo_total,
           NTILE(5) OVER (PARTITION BY nr_idCivil_condutor
                          ORDER BY custo_total DESC) AS quintil
    FROM ViagensCondutor
),
MediaTop20 AS (
    SELECT nr_idCivil_condutor,
           AVG(custo_total) AS media_top20
    FROM Quintis
    WHERE quintil = 1
    GROUP BY nr_idCivil_condutor
)
SELECT c.nome,
       c.nr_idCivil,
       vc.nr_viagem,
       vc.custo_total,
       m.media_top20 AS media_top20_supervisor
FROM Condutor c
JOIN ViagensCondutor vc ON vc.nr_idCivil_condutor = c.nr_idCivil
JOIN MediaTop20 m       ON m.nr_idCivil_condutor  = c.nr_idCivil_supervisor
WHERE NOT EXISTS (SELECT 1
                  FROM Condutor s
                  WHERE s.nr_idCivil_supervisor = c.nr_idCivil)   -- não é supervisor
  AND vc.custo_total < m.media_top20
ORDER BY c.nome, vc.nr_viagem;
GO
