SELECT r.cod_ponto,
       r.nome,
       r.tipo_ponto_turistico,
       r.nr_viagens_luxo,
       ROUND(100.0 * r.nr_viagens_luxo / r.total_viagens_luxo, 2) AS perc_das_viagens_luxo,
       r.nr_viagens_total,
       ROUND(100.0 * r.nr_viagens_luxo / r.nr_viagens_total, 2)   AS perc_visitas_em_luxo,
       ROUND(r.custo_medio_viagem_luxo, 2)                        AS custo_medio_viagem_luxo
FROM (SELECT pt.cod_ponto,
             pt.nome,
             pt.tipo_ponto_turistico,
             COUNT(DISTINCT v.nr_viagem) AS nr_viagens_luxo,
             (SELECT COUNT(*)
              FROM Viagem v3
              JOIN Pedido_Viagem p3 ON p3.cod_pedido = v3.cod_pedido
              JOIN Tipo_Servico ts3 ON ts3.cod_servico = p3.cod_servico
              WHERE ts3.descricao = 'Luxo') AS total_viagens_luxo,
             (SELECT COUNT(DISTINCT vpt4.nr_viagem)
              FROM Viagem_Ponto_Turistico vpt4
              WHERE vpt4.cod_ponto = pt.cod_ponto) AS nr_viagens_total,
             (SELECT AVG(v5.custo_total)
              FROM Viagem v5
              JOIN Pedido_Viagem p5 ON p5.cod_pedido = v5.cod_pedido
              JOIN Tipo_Servico ts5 ON ts5.cod_servico = p5.cod_servico
              WHERE ts5.descricao = 'Luxo'
                AND v5.nr_viagem IN (SELECT vpt5.nr_viagem
                                     FROM Viagem_Ponto_Turistico vpt5
                                     WHERE vpt5.cod_ponto = pt.cod_ponto)) AS custo_medio_viagem_luxo
      FROM Ponto_Turistico pt
      JOIN Viagem_Ponto_Turistico vpt ON vpt.cod_ponto = pt.cod_ponto
      JOIN Viagem v                   ON v.nr_viagem   = vpt.nr_viagem
      JOIN Pedido_Viagem p            ON p.cod_pedido  = v.cod_pedido
      JOIN Tipo_Servico ts            ON ts.cod_servico = p.cod_servico
      WHERE ts.descricao = 'Luxo'
        AND p.data_hora_cancelamento IS NULL
      GROUP BY pt.cod_ponto, pt.nome, pt.tipo_ponto_turistico
      HAVING COUNT(DISTINCT v.nr_viagem) =
             (SELECT MAX(t.nr_viagens)
              FROM (SELECT COUNT(DISTINCT v2.nr_viagem) AS nr_viagens
                    FROM Viagem_Ponto_Turistico vpt2
                    JOIN Viagem v2        ON v2.nr_viagem   = vpt2.nr_viagem
                    JOIN Pedido_Viagem p2 ON p2.cod_pedido  = v2.cod_pedido
                    JOIN Tipo_Servico ts2 ON ts2.cod_servico = p2.cod_servico
                    WHERE ts2.descricao = 'Luxo'
                      AND p2.data_hora_cancelamento IS NULL
                    GROUP BY vpt2.cod_ponto) t)) r
ORDER BY r.nome;
