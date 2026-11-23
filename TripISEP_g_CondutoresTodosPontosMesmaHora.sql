USE TripISEP;
GO

WITH TotalPontos AS (
    SELECT COUNT(*) AS qtd_total
    FROM Ponto_Turistico
),
ViagensCompletasCondutor AS (
    SELECT c.nr_idCivil,
           c.nome,
           v.nr_viagem
    FROM Condutor c
    JOIN Pedido_Viagem p ON p.nr_idCivil_condutor = c.nr_idCivil
    JOIN Viagem v ON v.cod_pedido = p.cod_pedido
    JOIN Viagem_Ponto_Turistico vpt ON vpt.nr_viagem = v.nr_viagem
    CROSS JOIN TotalPontos tp
    GROUP BY c.nr_idCivil, c.nome, v.nr_viagem, tp.qtd_total
    HAVING COUNT(DISTINCT vpt.cod_ponto) = tp.qtd_total
)
SELECT DISTINCT vcc.nr_idCivil,
                vcc.nome,
                vcc.nr_viagem
FROM ViagensCompletasCondutor vcc
WHERE NOT EXISTS (
    SELECT 1
    FROM ViagensCompletasCondutor vc2
    JOIN Viagem_Ponto_Turistico vpt2 ON vpt2.nr_viagem = vc2.nr_viagem
    WHERE vc2.nr_idCivil = vcc.nr_idCivil
    GROUP BY vc2.nr_idCivil, vpt2.cod_ponto
    HAVING MIN(CAST(vpt2.data_hora_passagem AS TIME)) <> MAX(CAST(vpt2.data_hora_passagem AS TIME))
)  
AND (SELECT COUNT(*)
       FROM ViagensCompletasCondutor vc3
       WHERE vc3.nr_idCivil = vcc.nr_idCivil) >= 2
ORDER BY vcc.nome, vcc.nr_viagem;
GO