USE TripISEP;
GO

SELECT r.cod_servico,
       r.descricao,
       r.posicao,
       r.nr_idCivil,
       r.nome,
       r.custo_total_viagens
FROM (
        SELECT ts.cod_servico,
               ts.descricao,
               c.nr_idCivil,
               c.nome,
               SUM(v.custo_total) AS custo_total_viagens,
               RANK() OVER (PARTITION BY ts.cod_servico
                            ORDER BY SUM(v.custo_total) DESC) AS posicao
        FROM Viagem v
        JOIN Pedido_Viagem p ON p.cod_pedido   = v.cod_pedido
        JOIN Condutor c      ON c.nr_idCivil   = p.nr_idCivil_condutor
        JOIN Tipo_Servico ts ON ts.cod_servico = p.cod_servico
        GROUP BY ts.cod_servico, ts.descricao, c.nr_idCivil, c.nome
     ) r
WHERE r.posicao <= 3
ORDER BY r.cod_servico, r.posicao;