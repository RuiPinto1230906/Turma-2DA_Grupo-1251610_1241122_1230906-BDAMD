USE TripISEP;
GO

WITH RoteiroViagem AS (
    SELECT v.nr_viagem,
           p.nr_idCivil_condutor,
           COUNT(DISTINCT vpt.cod_ponto) AS qtd_pontos,
           STRING_AGG(CAST(vpt.cod_ponto AS VARCHAR(10)), ',')
               WITHIN GROUP (ORDER BY vpt.cod_ponto) AS assinatura_pontos
    FROM Viagem v
    JOIN Pedido_Viagem p ON p.cod_pedido = v.cod_pedido
    JOIN Viagem_Ponto_Turistico vpt ON vpt.nr_viagem = v.nr_viagem
    WHERE p.nr_idCivil_condutor IS NOT NULL
    GROUP BY v.nr_viagem, p.nr_idCivil_condutor
)
SELECT DISTINCT c.nr_idCivil,
                c.nome
FROM Condutor c
JOIN RoteiroViagem rv1 ON rv1.nr_idCivil_condutor = c.nr_idCivil
WHERE (
    SELECT COUNT(DISTINCT rv2.nr_idCivil_condutor)
    FROM RoteiroViagem rv2
    WHERE rv2.nr_idCivil_condutor <> rv1.nr_idCivil_condutor
      AND rv2.qtd_pontos = rv1.qtd_pontos
      AND rv2.assinatura_pontos = rv1.assinatura_pontos
) >= 5
ORDER BY c.nome, c.nr_idCivil;
GO