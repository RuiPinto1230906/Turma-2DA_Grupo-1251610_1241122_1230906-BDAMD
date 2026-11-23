USE TripISEP;
GO

-- d) Por serviço: código, custo total de viagens global, % do custo do ano atual
--    face ao custo global do serviço e nº de pedidos de viagem com custo 80% acima
--    da média dos custos (de todas as viagens).
SELECT ts.cod_servico,
       ts.descricao,
       SUM(v.custo_total) AS custo_total_global,
       ROUND(100.0 * SUM(CASE WHEN YEAR(p.data_hora_recolha_passageiro) = YEAR(GETDATE())
                              THEN v.custo_total ELSE 0 END)
                   / NULLIF(SUM(v.custo_total), 0), 2) AS perc_custo_ano_atual,
       SUM(CASE WHEN v.custo_total > 1.8 * m.media_global THEN 1 ELSE 0 END) AS nr_pedidos_custo_80_acima_media
FROM Tipo_Servico ts
JOIN Pedido_Viagem p ON p.cod_servico = ts.cod_servico
JOIN Viagem v        ON v.cod_pedido  = p.cod_pedido
CROSS JOIN (SELECT AVG(custo_total) AS media_global FROM Viagem) m
GROUP BY ts.cod_servico, ts.descricao, m.media_global
ORDER BY ts.cod_servico;
GO
