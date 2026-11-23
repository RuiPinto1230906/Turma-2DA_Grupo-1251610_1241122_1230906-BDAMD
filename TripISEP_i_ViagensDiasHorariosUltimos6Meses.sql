USE TripISEP;
GO

WITH ViagensElegiveis AS (
    SELECT p.nr_idCivil_condutor,
           c.nome,
           p.matricula,
           p.data_hora_recolha_passageiro,
           v.custo_total,
           ((DATEPART(weekday, p.data_hora_recolha_passageiro) + @@DATEFIRST - 2) % 7) + 1 AS dia_semana_iso
    FROM Viagem v
    JOIN Pedido_Viagem p ON p.cod_pedido = v.cod_pedido
    JOIN Condutor c ON c.nr_idCivil = p.nr_idCivil_condutor
    WHERE p.nr_idCivil_condutor IS NOT NULL
      AND p.data_hora_recolha_passageiro >= DATEADD(MONTH, -6, GETDATE())
      AND CAST(p.data_hora_recolha_passageiro AS TIME) >= CAST('10:00:00' AS TIME)
      AND CAST(p.data_hora_recolha_passageiro AS TIME) <= CAST('15:00:00' AS TIME)
      AND ((DATEPART(weekday, p.data_hora_recolha_passageiro) + @@DATEFIRST - 2) % 7) + 1 IN (2, 4, 6, 7)
),
TotaisFimSemana AS (
    SELECT nr_idCivil_condutor,
           COUNT(*) AS qtd_fds,
           SUM(custo_total) AS soma_fds
    FROM ViagensElegiveis
    WHERE dia_semana_iso IN (6, 7)
    GROUP BY nr_idCivil_condutor
)
SELECT CAST(ve.data_hora_recolha_passageiro AS DATE) AS [data],
       CAST(ve.data_hora_recolha_passageiro AS TIME(0)) AS hora,
       ve.matricula,
       ve.nome,
       CASE
           WHEN COALESCE(tfs.qtd_fds, 0) > 3 THEN tfs.soma_fds
           ELSE NULL
       END AS Custo_Total_Viagens
FROM ViagensElegiveis ve
LEFT JOIN TotaisFimSemana tfs ON tfs.nr_idCivil_condutor = ve.nr_idCivil_condutor
WHERE NOT EXISTS (
    SELECT 1
    FROM Pedido_Viagem p2
    WHERE p2.nr_idCivil_condutor = ve.nr_idCivil_condutor
      AND p2.data_hora_recolha_passageiro >= DATEADD(MONTH, -6, GETDATE())
      AND ((DATEPART(weekday, p2.data_hora_recolha_passageiro) + @@DATEFIRST - 2) % 7) + 1 NOT IN (2, 4, 6, 7)
)
ORDER BY ve.nome ASC, ve.data_hora_recolha_passageiro DESC;
GO