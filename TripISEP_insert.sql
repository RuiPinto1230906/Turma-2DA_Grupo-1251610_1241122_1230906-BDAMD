/* =====================================================================
   TripISEP - Povoamento da base de dados (SQL Server)
   Executar DEPOIS de TripISEP_create.sql e TripISEP_regras_complexas.sql.
   Para repovoar: executar primeiro TripISEP_delete.sql.

   3.1 PLANO DE DADOS (conjunto mínimo para validar as alíneas a) a i))
   ---------------------------------------------------------------------
   Data de referência: 21-11-2026 ("ano atual" = 2026; "últimos 6 meses" =
   desde 21-05-2026). As consultas usam GETDATE(): se forem executadas
   noutra data, as alíneas d) e i) podem devolver resultados diferentes.

   Volumes: 4 serviços, 30 custos de serviço, 30 clientes, 30 condutores,
   30 veículos, 30 associações condutor-veículo, 30 pontos turísticos, 30 pedidos,
   30 viagens, 30 faturas, 144 passagens por pontos, 35 recibos, 30 detalhes.
   Tipo_Servico tem 4 tuplos (os 4 serviços do enunciado). Cada pedido tem
   uma viagem (30 viagens = mínimo para Viagem, Fatura_Recibo e Detalhe).
   Viagem_Ponto_Turistico tem mais de 30 porque a alínea g) exige viagens por
   todos os 30 pontos (4 visitas x 30). Recibo_Comissao tem 35: um por
   condutor e mês com viagens, mais os dos supervisores.
   O condutor Dk conduz o veículo Vk; cada cliente faz 1 pedido.

   Supervisão (R6/R7: índice menor = mais velho e carta mais antiga)
     D01 -> D08, D09, D11..D17          D02 -> D18..D21  (D02 nunca conduz)

   a) Cada serviço tem 5 a 8 condutores com viagens, sem empates no top 3.
   b) 12 viagens com pontos; 6 qualificam (passagens depois da média dos
      museus, ~10:27) e 6 não (as visitas guiadas e 2 viagens da manhã).
   c) Veículos com várias viagens (D08, D09, D18, D19, D20...): as viagens
      anteriores à última qualificam; D20 tem 2 viagens com 80 min de intervalo.
   d) Viagens em 2025 e 2026 em todos os serviços; viagens caras (visitas e
      uma de 120 km) acima de 1,8 x a média nos serviços Luxo e Grupo.
   e) D01 tem 5 viagens (1 muito cara); os seus supervisionados têm viagens
      mais baratas que a média das 20% melhores de D01.
   f) D02 nunca conduz e recebe comissão de supervisão: aparece em 2025 e
      2026. D01 só conduz em 2026, por isso aparece só em 2025.
   g) D08 faz 2 visitas por todos os 30 pontos com as mesmas horas
      (qualifica); D09 faz 2 visitas com horas diferentes (não qualifica).
   h) Roteiro {1,3,5} feito por 6 condutores (D11..D16 -> cada um tem 5
      outros, qualificam); roteiro {10,18,24} só por 2 (D23, D24 -> não).
   i) Últimos 6 meses: D18 (4 viagens ao fim de semana -> mostra
      Custo_Total_Viagens) e D19 (1 ao fim de semana -> coluna NULL)
      qualificam; D20 (2 viagens a uma quarta-feira) não qualifica.

   Ordem de inserção: respeita as FK e os triggers de TripISEP_regras_complexas.sql.
   Os totais de Recibo_Comissao são recalculados pelo trigger R26.
   ===================================================================== */

USE TripISEP;
GO

-- Tipo_Servico: 4 tuplos
INSERT INTO Tipo_Servico (cod_servico, descricao) VALUES
    (1, 'Casual'),
    (2, 'Eco'),
    (3, 'Luxo'),
    (4, 'Grupo');
GO

-- Historico_Custo_Servico: 30 tuplos
INSERT INTO Historico_Custo_Servico (cod_servico, data_inicio_custo, data_fim_custo, preco_base, custo_minuto, custo_km, taxa_iva, tempo_max_espera, custo_minuto_espera, custo_cancelamento, perc_acrescimo_cancelamento, perc_comissao_condutor, perc_comissao_supervisor) VALUES
    (1, '2024-01-01', '2024-06-30', 2.50, 0.20, 0.90, 23.00, 10, 0.15, 3.00, 20, 20, 5),
    (1, '2024-07-01', '2024-12-31', 2.60, 0.21, 0.92, 23.00, 10, 0.15, 3.00, 20, 20, 5),
    (1, '2025-01-01', '2025-06-30', 2.70, 0.22, 0.94, 23.00, 10, 0.15, 3.00, 20, 20, 5),
    (1, '2025-07-01', '2025-12-31', 2.80, 0.23, 0.96, 23.00, 10, 0.15, 3.00, 20, 20, 5),
    (1, '2026-01-01', '2026-03-31', 2.90, 0.24, 0.98, 23.00, 10, 0.15, 3.00, 20, 20, 5),
    (1, '2026-04-01', '2026-06-30', 3.00, 0.25, 1.00, 23.00, 10, 0.15, 3.00, 20, 20, 5),
    (1, '2026-07-01', '2026-09-30', 3.10, 0.26, 1.02, 23.00, 10, 0.15, 3.00, 20, 20, 5),
    (1, '2026-10-01', NULL, 3.20, 0.27, 1.04, 23.00, 10, 0.15, 3.00, 20, 20, 5),
    (2, '2024-01-01', '2024-06-30', 2.80, 0.22, 0.95, 23.00, 10, 0.15, 3.00, 15, 18, 4),
    (2, '2024-07-01', '2024-12-31', 2.90, 0.23, 0.97, 23.00, 10, 0.15, 3.00, 15, 18, 4),
    (2, '2025-01-01', '2025-06-30', 3.00, 0.24, 0.99, 23.00, 10, 0.15, 3.00, 15, 18, 4),
    (2, '2025-07-01', '2025-12-31', 3.10, 0.25, 1.01, 23.00, 10, 0.15, 3.00, 15, 18, 4),
    (2, '2026-01-01', '2026-03-31', 3.20, 0.26, 1.03, 23.00, 10, 0.15, 3.00, 15, 18, 4),
    (2, '2026-04-01', '2026-06-30', 3.30, 0.27, 1.05, 23.00, 10, 0.15, 3.00, 15, 18, 4),
    (2, '2026-07-01', '2026-09-30', 3.40, 0.28, 1.07, 23.00, 10, 0.15, 3.00, 15, 18, 4),
    (2, '2026-10-01', NULL, 3.50, 0.29, 1.09, 23.00, 10, 0.15, 3.00, 15, 18, 4),
    (3, '2024-07-01', '2024-12-31', 5.10, 0.41, 1.52, 23.00, 15, 0.30, 6.00, 30, 25, 6),
    (3, '2025-01-01', '2025-06-30', 5.20, 0.42, 1.54, 23.00, 15, 0.30, 6.00, 30, 25, 6),
    (3, '2025-07-01', '2025-12-31', 5.30, 0.43, 1.56, 23.00, 15, 0.30, 6.00, 30, 25, 6),
    (3, '2026-01-01', '2026-03-31', 5.40, 0.44, 1.58, 23.00, 15, 0.30, 6.00, 30, 25, 6),
    (3, '2026-04-01', '2026-06-30', 5.50, 0.45, 1.60, 23.00, 15, 0.30, 6.00, 30, 25, 6),
    (3, '2026-07-01', '2026-09-30', 5.60, 0.46, 1.62, 23.00, 15, 0.30, 6.00, 30, 25, 6),
    (3, '2026-10-01', NULL, 5.70, 0.47, 1.64, 23.00, 15, 0.30, 6.00, 30, 25, 6),
    (4, '2024-07-01', '2024-12-31', 4.10, 0.31, 1.22, 23.00, 20, 0.25, 5.00, 25, 22, 5),
    (4, '2025-01-01', '2025-06-30', 4.20, 0.32, 1.24, 23.00, 20, 0.25, 5.00, 25, 22, 5),
    (4, '2025-07-01', '2025-12-31', 4.30, 0.33, 1.26, 23.00, 20, 0.25, 5.00, 25, 22, 5),
    (4, '2026-01-01', '2026-03-31', 4.40, 0.34, 1.28, 23.00, 20, 0.25, 5.00, 25, 22, 5),
    (4, '2026-04-01', '2026-06-30', 4.50, 0.35, 1.30, 23.00, 20, 0.25, 5.00, 25, 22, 5),
    (4, '2026-07-01', '2026-09-30', 4.60, 0.36, 1.32, 23.00, 20, 0.25, 5.00, 25, 22, 5),
    (4, '2026-10-01', NULL, 4.70, 0.37, 1.34, 23.00, 20, 0.25, 5.00, 25, 22, 5);
GO

-- password = SHA-256 (hash) de palavras-passe de teste
-- Cliente: 30 tuplos
INSERT INTO Cliente (nr_idCivil, nome, nif, data_nascimento, login, password) VALUES
    ('58709585', 'Miguel Santos Martins', '290440569', '1968-07-03', 'msantos1', '8316ad00aebd455110fe3f1dce778727919bef11a22a115a419c56e38e31b9f0'),
    ('77262352', 'Rita Rodrigues Moreira', '173301824', '1977-07-30', 'rrodrigues2', 'c592df4a86933b92addc9842402ddf198c638ea9be58916ee6e3734e1e3152f8'),
    ('49578460', 'Andre Gomes Pereira', '248878003', '1980-03-19', 'agomes3', '93915a0a4bf8f634cb1856494dd4304472ad46b9827f541f76b6761c49cc55b0'),
    ('64404922', 'Beatriz Ribeiro Ribeiro', '529779047', '2002-07-18', 'bribeiro4', '072aa9e9fb9d5162e465d3321530463caecd59b156676fe3071997cdc1017816'),
    ('21815439', 'Carlos Correia Neves', '288634438', '1998-04-19', 'ccorreia5', '0c2e7ac34c9a4f2c9058223947a466a6a21159e2e9d9e2c6597e8b7d334ae907'),
    ('64907779', 'Daniela Monteiro Lopes', '699956612', '1982-12-05', 'dmonteiro6', '96e8866d1b7224b560bdc487ba6df5c240d8b27b4d9878504e9bcc270f9025dc'),
    ('29377915', 'Eduardo Santos Vieira', '989695030', '1996-08-16', 'esantos7', '414e473c518c7b56659e6f048c44c972788b31f3d88744c448b1e314dfc67afc'),
    ('84849218', 'Fernanda Rodrigues Sousa', '408952339', '1995-04-05', 'frodrigues8', '63de0166a3a7896d6e8f2b9e2cf05495efdf060cbc00da22288839d6ff9d9596'),
    ('59153450', 'Gustavo Gomes Correia', '843068297', '1992-02-18', 'ggomes9', 'b03032a6093b3d8640cde7a26439ebedfa9aa7f0eefa2a1036516df83058e323'),
    ('41970943', 'Helena Ribeiro Oliveira', '272050095', '1965-06-12', 'hribeiro10', '084cb59677d000b20f80d646913c35a2d97902bf8351f2456105a95ec3c7da2e'),
    ('34651543', 'Ivo Correia Pinto', '272455407', '1978-10-23', 'icorreia11', '1c5fc56db289c512b035cc0d9c4ba0555f14eb7911cae104c1d515f7dc9d1060'),
    ('99384612', 'Joana Monteiro Silva', '360542714', '1959-01-31', 'jmonteiro12', '6f54a6cb1544d58dceccdf48d32c3d04ac07a0fef0fc89374e1684028539faff'),
    ('76090595', 'Kevin Santos Marques', '742566551', '1974-05-12', 'ksantos13', '9376ec45800be1ee43cff530c0cdc8f2bef91090634b4f8319fa38442b97c1d4'),
    ('46265254', 'Laura Rodrigues Monteiro', '412720815', '1958-05-15', 'lrodrigues14', '4d3c8cc2ec628976af6750df0499ca09023c851b34b3158828ce6f1330d062ba'),
    ('30552354', 'Mario Gomes Fernandes', '559840379', '1991-02-16', 'mgomes15', '04e237f4d9cef3973e40742d11ae98c9472494aa97a492406548a7e231f945bb'),
    ('92847639', 'Natalia Ribeiro Mendes', '718104260', '1986-08-02', 'nribeiro16', '5a274cfd42ccde36d22f05c17b1aaec66d226699b0063d6274da34949cc0e501'),
    ('27843185', 'Orlando Correia Costa', '851411915', '2004-03-31', 'ocorreia17', '3596e323428f7c2463df469ac44f463beb4063c8dbbf0feab41a83fbffbf2aeb'),
    ('93891895', 'Paula Monteiro Carvalho', '813264880', '1962-11-05', 'pmonteiro18', '9f82ec3e57a982e540efabe88c9d2988bea1768763333741e0c5b400667a2dc3'),
    ('72289682', 'Ricardo Santos Santos', '947485860', '1993-03-15', 'rsantos19', 'f57a5229c907498efa79b0a826d03a8b207537cd558c8cb3237c7121cf804a4e'),
    ('64428001', 'Sofia Rodrigues Alves', '538400257', '1993-05-11', 'srodrigues20', 'cc1731972ea5e14b37d80a3f8699dc79c6a1f63eeb684a851bd2110293ed7ee6'),
    ('24896513', 'Telmo Gomes Cardoso', '627031191', '1993-12-04', 'tgomes21', 'c9eecf48b2c5a7bad42fea20434035690368cc6bad1e0415f1040cdb90bf3f93'),
    ('19354761', 'Vera Ribeiro Gonçalves', '314665439', '1964-01-16', 'vribeiro22', 'ab319f9b916f524fdf363736e01318056b86156367c1e6ee9efe3e98c118a212'),
    ('39019720', 'Wilson Correia Nunes', '583119500', '1972-07-24', 'wcorreia23', 'd32f485e593c5f3eb908219dda303f4feec8578ca71dda3502d8e7ace985f799'),
    ('25754327', 'Ximena Monteiro Rodrigues', '475129829', '1962-09-19', 'xmonteiro24', 'c9ccbed493dc9a7724acc704a7d756f40b28ea539c54ffb432a70e232153d2db'),
    ('24741157', 'Yolanda Santos Teixeira', '110250482', '1971-07-28', 'ysantos25', 'c2dad9bc0ab5690e8613cd738f523fabdb45a8be9c057ed6be393e8aed47c514'),
    ('83023741', 'Zeca Rodrigues Ferreira', '218946535', '1990-08-15', 'zrodrigues26', 'b58ce90f5ad4b85bf4f3b5121cfaf0aeef95ca7a726c81707e3937dc29c40622'),
    ('93374421', 'Alexandre Gomes Almeida', '137381374', '1964-04-23', 'agomes27', 'a9917d99e6c10151a09a1b9bb60b876883fbee1decd2df5bfc312ebdcaa388ba'),
    ('38910936', 'Barbara Ribeiro Rocha', '769351559', '1991-10-03', 'bribeiro28', '028d4a56a63dc0bfd3028d78163c8e7ec7ce97d913afdc9b004014ebe2205edd'),
    ('30938108', 'Claudio Correia Gomes', '791192097', '1980-08-18', 'ccorreia29', '99590172a4a0c936a02b4af28c9666cf0fecdb73e8f09d8bdf1254c68f6c65bc'),
    ('57625835', 'Debora Monteiro Soares', '756692355', '1990-09-02', 'dmonteiro30', '971cc4923460d8feb0ed07046ef02c4b5bc2c47225f92e76a13b6c72ad1cdcd0');
GO

-- D01..D36 por ordem de idade (supervisores primeiro)
-- Condutor: 30 tuplos
INSERT INTO Condutor (nr_idCivil, nome, morada, nif, data_nascimento, nr_carta_conducao, data_emissao_carta, data_validade_carta, nr_idCivil_supervisor) VALUES
    ('54464097', 'Ana Silva Pereira', 'Avenida dos Aliados, 203, Porto', '808935572', '1968-01-10', 'P-100000 A', '1987-02-24', '2029-06-30', NULL),
    ('17480894', 'Bruno Martins Alves', 'Rua das Flores, 275, Porto', '211071364', '1968-12-05', 'P-109173 B', '1988-01-20', '2029-07-20', NULL),
    ('60081935', 'Carla Alves Vieira', 'Rua de Faria Guimarães, 30, Porto', '654854973', '1969-10-31', 'P-118346 C', '1988-12-15', '2029-08-09', NULL),
    ('39816302', 'Diogo Correia Rodrigues', 'Rua de Santa Catarina, 45, Porto', '575623510', '1970-09-26', 'P-127519 D', '1989-11-10', '2029-08-29', NULL),
    ('67126116', 'Eva Rocha Pinto', 'Rua das Flores, 124, Porto', '207402358', '1971-08-22', 'P-136692 E', '1990-10-06', '2029-09-18', NULL),
    ('84960310', 'Filipe Costa Rocha', 'Avenida da Boavista, 31, Porto', '997825707', '1972-07-17', 'P-145865 F', '1991-09-01', '2029-10-08', NULL),
    ('86893910', 'Gabriela Lopes Fernandes', 'Rua das Flores, 115, Porto', '787129422', '1973-06-12', 'P-155038 G', '1992-07-27', '2029-10-28', NULL),
    ('95212661', 'Hugo Teixeira Moreira', 'Rua de Faria Guimarães, 32, Porto', '729659571', '1974-05-08', 'P-164211 H', '1993-06-22', '2029-11-17', '54464097'),
    ('89590039', 'Inês Monteiro Santos', 'Avenida da Boavista, 26, Porto', '347384804', '1975-04-03', 'P-173384 J', '1994-05-18', '2029-12-07', '54464097'),
    ('17252221', 'João Pereira Lopes', 'Rua do Campo Alegre, 69, Porto', '420965605', '1976-02-27', 'P-182557 K', '1995-04-13', '2029-12-27', NULL),
    ('67255890', 'Karina Gonçalves Nunes', 'Avenida dos Aliados, 277, Porto', '236478448', '1977-01-22', 'P-191730 L', '1996-03-08', '2030-01-16', '54464097'),
    ('87626738', 'Luís Pinto Oliveira', 'Rua do Bonjardim, 287, Porto', '986309003', '1977-12-18', 'P-200903 M', '1997-02-01', '2030-02-05', '54464097'),
    ('35256684', 'Marta Soares Almeida', 'Rua das Flores, 298, Porto', '723326042', '1978-11-13', 'P-210076 N', '1997-12-28', '2030-02-25', '54464097'),
    ('96753514', 'Nuno Santos Monteiro', 'Rua de Cedofeita, 191, Porto', '214615284', '1979-10-09', 'P-219249 P', '1998-11-23', '2030-03-17', '54464097'),
    ('84517017', 'Olga Sousa Martins', 'Rua das Flores, 289, Porto', '173996269', '1980-09-03', 'P-228422 R', '1999-10-19', '2030-04-06', '54464097'),
    ('94082061', 'Pedro Almeida Carvalho', 'Rua de Cedofeita, 255, Porto', '840573909', '1981-07-30', 'P-237595 S', '2000-09-13', '2030-04-26', '54464097'),
    ('82366283', 'Quitéria Mendes Neves', 'Avenida da Boavista, 161, Porto', '609936196', '1982-06-25', 'P-246768 T', '2001-08-09', '2030-05-16', '54464097'),
    ('89592782', 'Rui Neves Gonçalves', 'Rua de Costa Cabral, 186, Porto', '431872363', '1983-05-21', 'P-255941 U', '2002-07-05', '2030-06-05', '17480894'),
    ('44343251', 'Sara Rodrigues Correia', 'Avenida dos Aliados, 125, Porto', '197891151', '1984-04-15', 'P-265114 V', '2003-05-31', '2030-06-25', '17480894'),
    ('88097845', 'Tiago Marques Ferreira', 'Rua do Bonjardim, 269, Porto', '641627137', '1985-03-11', 'P-274287 W', '2004-04-25', '2030-07-15', '17480894'),
    ('57100526', 'Úrsula Moreira Marques', 'Rua de Costa Cabral, 148, Porto', '763864767', '1986-02-04', 'P-283460 X', '2005-03-21', '2030-08-04', '17480894'),
    ('20824854', 'Vasco Cardoso Soares', 'Rua das Flores, 263, Porto', '558955962', '1986-12-31', 'P-292633 Y', '2006-02-14', '2030-08-24', NULL),
    ('33140838', 'Wanda Oliveira Costa', 'Rua da Boavista, 78, Porto', '635020128', '1987-11-26', 'P-301806 Z', '2007-01-10', '2030-09-13', NULL),
    ('67599395', 'Xavier Gomes Ribeiro', 'Rua de Santa Catarina, 40, Porto', '930951719', '1988-10-21', 'P-310979 A', '2007-12-06', '2030-10-03', NULL),
    ('85903659', 'Yara Carvalho Cardoso', 'Rua de Faria Guimarães, 161, Porto', '475203600', '1989-09-16', 'P-320152 B', '2008-10-31', '2030-10-23', NULL),
    ('58000147', 'Zé Vieira Sousa', 'Rua de Faria Guimarães, 255, Porto', '732657734', '1990-08-12', 'P-329325 C', '2009-09-26', '2030-11-12', NULL),
    ('72230843', 'Alice Ferreira Teixeira', 'Rua das Flores, 48, Porto', '399845088', '1991-07-08', 'P-338498 D', '2010-08-22', '2030-12-02', NULL),
    ('74632401', 'Bernardo Fernandes Silva', 'Rua das Flores, 32, Porto', '895076355', '1992-06-02', 'P-347671 E', '2011-07-18', '2030-12-22', NULL),
    ('52554798', 'Catarina Ribeiro Gomes', 'Rua de Faria Guimarães, 229, Porto', '415582123', '1993-04-28', 'P-356844 F', '2012-06-12', '2031-01-11', NULL),
    ('62780050', 'Duarte Nunes Mendes', 'Rua da Boavista, 12, Porto', '605741540', '1994-03-24', 'P-366017 G', '2013-05-08', '2031-01-31', NULL);
GO

-- Veiculo: 30 tuplos
INSERT INTO Veiculo (matricula, marca, modelo, nr_chassis, data_matricula, limite_km_semanal) VALUES
    ('SD-24-SR', 'Toyota', 'Prius', 'VF77WFKGYT7LBP0KB', '2023-04-02', 1000),
    ('TK-92-CJ', 'Tesla', 'Model 3', 'VF0LZR9YRNS2RN8ZB', '2019-02-27', 1000),
    ('JS-43-GX', 'Mercedes-Benz', 'Classe E', 'VFZ5Z0FRGR7NYP7A7', '2024-02-06', 1000),
    ('ZM-92-CD', 'BMW', 'Série 5', 'VF1N7M4YF262FLLJB', '2019-11-06', 1000),
    ('VR-93-EX', 'Renault', 'Zoe', 'VF7ZKJBAGJ4NPBTPV', '2021-10-23', 1000),
    ('HV-51-JU', 'Volkswagen', 'ID.4', 'VF3JDZ639JK9B5MAK', '2019-12-19', 1000),
    ('ES-89-DU', 'Skoda', 'Octavia', 'VFDX7GDSNUCG95BE5', '2020-10-28', 1000),
    ('XT-87-TG', 'Peugeot', '508', 'VFU5979STN5J3H25X', '2019-05-29', 1000),
    ('HP-19-GK', 'Hyundai', 'Ioniq', 'VFHK0KTJ6RG28LRL4', '2021-11-21', 1000),
    ('NL-63-GM', 'Kia', 'EV6', 'VFXF0BY65B1YV9EHR', '2024-06-13', 1000),
    ('DC-43-JB', 'Audi', 'A6', 'VFMUJ4T2K98XFUDM4', '2024-01-08', 1000),
    ('CJ-12-ZC', 'Volvo', 'S90', 'VFTFRETH6AY3UJCSH', '2024-06-07', 1000),
    ('FJ-16-FG', 'Toyota', 'Prius', 'VFWWPV59MUZBTCAB9', '2022-02-02', 1000),
    ('GT-70-HR', 'Tesla', 'Model 3', 'VFG4829WPRYNJ2ZDJ', '2019-01-30', 1000),
    ('CZ-42-PF', 'Mercedes-Benz', 'Classe E', 'VFDF19VSVC6MLU5AT', '2021-01-15', 1000),
    ('LU-51-HB', 'BMW', 'Série 5', 'VFWPZMAY1F7U9NS9A', '2019-07-06', 1000),
    ('JC-28-NV', 'Renault', 'Zoe', 'VFC2BWWRFK1X8KVKC', '2023-08-17', 1000),
    ('TZ-64-TE', 'Volkswagen', 'ID.4', 'VF9BRFBCJ0G15DBS8', '2020-06-24', 1000),
    ('AR-18-TU', 'Skoda', 'Octavia', 'VFFE7TETSPR681E7V', '2023-04-20', 1000),
    ('BX-90-ZG', 'Peugeot', '508', 'VFEKYTWJA7D8UGP8V', '2022-12-22', 1000),
    ('TK-69-RR', 'Hyundai', 'Ioniq', 'VFHNWF7BV6E95U1PP', '2019-06-02', 1000),
    ('VC-28-TJ', 'Kia', 'EV6', 'VF0J9UH0R882BLA85', '2021-04-10', 1000),
    ('KE-63-MN', 'Audi', 'A6', 'VFXHYAXY2HNAVT0E2', '2021-03-10', 1000),
    ('VC-56-PJ', 'Volvo', 'S90', 'VFDUGDVKSU49XN04B', '2023-07-21', 1000),
    ('ZN-80-UG', 'Toyota', 'Prius', 'VFFD35JV8DJL73YVW', '2020-06-07', 1000),
    ('ZJ-61-ZH', 'Tesla', 'Model 3', 'VFW72HLLEP98R5Y54', '2019-10-13', 1000),
    ('UG-41-CF', 'Mercedes-Benz', 'Classe E', 'VFYFXS0TNB313P1UY', '2023-03-21', 1000),
    ('BS-45-VM', 'BMW', 'Série 5', 'VFJ9PFUS1254WBJC4', '2022-12-24', 1000),
    ('SV-72-AC', 'Renault', 'Zoe', 'VF265SGRKKG6FCAJR', '2022-03-12', 1000),
    ('BZ-48-EZ', 'Volkswagen', 'ID.4', 'VFT4HGEWN1TRAAW6U', '2024-05-17', 1000);
GO

-- Condutor_Veiculo: 30 tuplos
INSERT INTO Condutor_Veiculo (matricula, data_hora_inicio, nr_idCivil_condutor, data_hora_fim) VALUES
    ('SD-24-SR', '2025-01-01 00:00:00', '54464097', NULL),
    ('TK-92-CJ', '2025-01-01 00:00:00', '17480894', NULL),
    ('JS-43-GX', '2025-01-01 00:00:00', '60081935', NULL),
    ('ZM-92-CD', '2025-01-01 00:00:00', '39816302', NULL),
    ('VR-93-EX', '2025-01-01 00:00:00', '67126116', NULL),
    ('HV-51-JU', '2025-01-01 00:00:00', '84960310', NULL),
    ('ES-89-DU', '2025-01-01 00:00:00', '86893910', NULL),
    ('XT-87-TG', '2025-01-01 00:00:00', '95212661', NULL),
    ('HP-19-GK', '2025-01-01 00:00:00', '89590039', NULL),
    ('NL-63-GM', '2025-01-01 00:00:00', '17252221', NULL),
    ('DC-43-JB', '2025-01-01 00:00:00', '67255890', NULL),
    ('CJ-12-ZC', '2025-01-01 00:00:00', '87626738', NULL),
    ('FJ-16-FG', '2025-01-01 00:00:00', '35256684', NULL),
    ('GT-70-HR', '2025-01-01 00:00:00', '96753514', NULL),
    ('CZ-42-PF', '2025-01-01 00:00:00', '84517017', NULL),
    ('LU-51-HB', '2025-01-01 00:00:00', '94082061', NULL),
    ('JC-28-NV', '2025-01-01 00:00:00', '82366283', NULL),
    ('TZ-64-TE', '2025-01-01 00:00:00', '89592782', NULL),
    ('AR-18-TU', '2025-01-01 00:00:00', '44343251', NULL),
    ('BX-90-ZG', '2025-01-01 00:00:00', '88097845', NULL),
    ('TK-69-RR', '2025-01-01 00:00:00', '57100526', NULL),
    ('VC-28-TJ', '2025-01-01 00:00:00', '20824854', NULL),
    ('KE-63-MN', '2025-01-01 00:00:00', '33140838', NULL),
    ('VC-56-PJ', '2025-01-01 00:00:00', '67599395', NULL),
    ('ZN-80-UG', '2025-01-01 00:00:00', '85903659', NULL),
    ('ZJ-61-ZH', '2025-01-01 00:00:00', '58000147', NULL),
    ('UG-41-CF', '2025-01-01 00:00:00', '72230843', NULL),
    ('BS-45-VM', '2025-01-01 00:00:00', '74632401', NULL),
    ('SV-72-AC', '2025-01-01 00:00:00', '52554798', NULL),
    ('BZ-48-EZ', '2025-01-01 00:00:00', '62780050', NULL);
GO

-- Ponto_Turistico: 30 tuplos
INSERT INTO Ponto_Turistico (cod_ponto, nome, tipo_ponto_turistico) VALUES
    (1, 'Torre dos Clérigos', 'M'),
    (2, 'Sé do Porto', 'M'),
    (3, 'Palácio da Bolsa', 'M'),
    (4, 'Estação de São Bento', 'M'),
    (5, 'Ponte Luís I', 'M'),
    (6, 'Igreja de São Francisco', 'M'),
    (7, 'Igreja do Carmo', 'M'),
    (8, 'Casa da Música', 'M'),
    (9, 'Mosteiro da Serra do Pilar', 'M'),
    (10, 'Museu de Serralves', 'MU'),
    (11, 'Museu Nacional Soares dos Reis', 'MU'),
    (12, 'Museu do Carro Elétrico', 'MU'),
    (13, 'Museu da Misericórdia do Porto', 'MU'),
    (14, 'Casa-Museu Guerra Junqueiro', 'MU'),
    (15, 'Museu do Vinho do Porto', 'MU'),
    (16, 'Museu Nacional da Imprensa', 'MU'),
    (17, 'Museu Romântico da Quinta da Macieirinha', 'MU'),
    (18, 'Parque da Cidade do Porto', 'PN'),
    (19, 'Jardins do Palácio de Cristal', 'PN'),
    (20, 'Jardim Botânico do Porto', 'PN'),
    (21, 'Parque Biológico de Gaia', 'PN'),
    (22, 'Parque de Serralves', 'PN'),
    (23, 'Parque de São Roque', 'PN'),
    (24, 'Miradouro da Vitória', 'MI'),
    (25, 'Jardim do Morro', 'MI'),
    (26, 'Miradouro da Sé', 'MI'),
    (27, 'Miradouro das Fontaínhas', 'MI'),
    (28, 'Miradouro da Foz', 'MI'),
    (29, 'Miradouro de Gaia', 'MI'),
    (30, 'Miradouro do Palácio de Cristal', 'MI');
GO

-- Pedido_Viagem: 30 tuplos
INSERT INTO Pedido_Viagem (cod_pedido, nr_idCivil_cliente, cod_servico, matricula, nr_idCivil_condutor, data_hora_pedido, data_hora_recolha_passageiro, local_inicio, distancia_km, data_hora_cancelamento, valor_cancelamento) VALUES
    (1, '58709585', 1, 'JC-28-NV', '82366283', '2025-03-11 07:57:00', '2025-03-12 10:20:00', 'Rua do Campo Alegre, 229, Porto', 8, NULL, NULL),
    (2, '77262352', 2, 'TK-69-RR', '57100526', '2025-05-19 12:40:00', '2025-05-20 15:00:00', 'Rua da Boavista, 243, Porto', 10, NULL, NULL),
    (3, '49578460', 3, 'ZN-80-UG', '85903659', '2025-08-06 12:50:00', '2025-08-07 09:30:00', 'Avenida da Boavista, 127, Porto', 12, NULL, NULL),
    (4, '64404922', 4, 'ZJ-61-ZH', '58000147', '2025-10-14 01:21:00', '2025-10-15 18:10:00', 'Avenida da Boavista, 21, Porto', 7, NULL, NULL),
    (5, '21815439', 1, 'UG-41-CF', '72230843', '2025-12-02 05:43:00', '2025-12-03 13:45:00', 'Rua de Costa Cabral, 33, Porto', 9, NULL, NULL),
    (6, '64907779', 1, 'SD-24-SR', '54464097', '2026-01-07 16:04:00', '2026-01-08 14:20:00', 'Rua de Cedofeita, 218, Porto', 9, NULL, NULL),
    (7, '29377915', 1, 'DC-43-JB', '67255890', '2026-01-13 06:11:00', '2026-01-14 08:30:00', 'Rua de Cedofeita, 119, Porto', 14, NULL, NULL),
    (8, '84849218', 2, 'CJ-12-ZC', '87626738', '2026-02-10 05:01:00', '2026-02-11 15:15:00', 'Rua do Bonjardim, 152, Porto', 14, NULL, NULL),
    (9, '59153450', 3, 'SD-24-SR', '54464097', '2026-02-11 08:56:00', '2026-02-12 16:10:00', 'Rua de Costa Cabral, 18, Porto', 120, NULL, NULL),
    (10, '41970943', 1, 'KE-63-MN', '33140838', '2026-02-18 03:57:00', '2026-02-19 13:00:00', 'Rua de Santa Catarina, 95, Porto', 11, NULL, NULL),
    (11, '34651543', 3, 'FJ-16-FG', '35256684', '2026-03-03 17:01:00', '2026-03-04 16:40:00', 'Rua de Costa Cabral, 96, Porto', 14, NULL, NULL),
    (12, '99384612', 4, 'XT-87-TG', '95212661', '2026-03-09 02:19:00', '2026-03-10 09:00:00', 'Rua de Cedofeita, 244, Porto', 60, NULL, NULL),
    (13, '76090595', 3, 'HP-19-GK', '89590039', '2026-03-16 12:34:00', '2026-03-17 09:00:00', 'Rua do Bonjardim, 29, Porto', 60, NULL, NULL),
    (14, '46265254', 2, 'SD-24-SR', '54464097', '2026-03-18 02:55:00', '2026-03-19 09:40:00', 'Avenida da Boavista, 186, Porto', 12, NULL, NULL),
    (15, '30552354', 2, 'VC-56-PJ', '67599395', '2026-04-01 05:32:00', '2026-04-02 14:00:00', 'Rua da Boavista, 58, Porto', 11, NULL, NULL),
    (16, '92847639', 4, 'GT-70-HR', '96753514', '2026-04-07 05:29:00', '2026-04-08 09:00:00', 'Avenida da Boavista, 29, Porto', 14, NULL, NULL),
    (17, '27843185', 4, 'XT-87-TG', '95212661', '2026-04-12 20:45:00', '2026-04-14 09:00:00', 'Rua do Campo Alegre, 127, Porto', 60, NULL, NULL),
    (18, '93891895', 3, 'HP-19-GK', '89590039', '2026-04-20 13:18:00', '2026-04-21 09:30:00', 'Rua de Costa Cabral, 216, Porto', 60, NULL, NULL),
    (19, '72289682', 4, 'SD-24-SR', '54464097', '2026-04-22 08:53:00', '2026-04-23 17:05:00', 'Rua de Santa Catarina, 150, Porto', 7, NULL, NULL),
    (20, '64428001', 1, 'CZ-42-PF', '84517017', '2026-05-04 23:01:00', '2026-05-06 14:10:00', 'Avenida da Boavista, 28, Porto', 14, NULL, NULL),
    (21, '24896513', 1, 'SD-24-SR', '54464097', '2026-05-05 23:26:00', '2026-05-07 11:30:00', 'Rua de Cedofeita, 254, Porto', 11, NULL, NULL),
    (22, '19354761', 2, 'LU-51-HB', '94082061', '2026-05-12 10:19:00', '2026-05-13 12:20:00', 'Rua de Faria Guimarães, 73, Porto', 14, NULL, NULL),
    (23, '39019720', 1, 'TZ-64-TE', '89592782', '2026-06-05 11:31:00', '2026-06-06 10:30:00', 'Avenida dos Aliados, 169, Porto', 8, NULL, NULL),
    (24, '25754327', 1, 'AR-18-TU', '44343251', '2026-06-24 15:25:00', '2026-06-25 11:30:00', 'Rua do Bonjardim, 42, Porto', 11, NULL, NULL),
    (25, '24741157', 2, 'AR-18-TU', '44343251', '2026-07-10 04:34:00', '2026-07-11 12:00:00', 'Rua das Flores, 288, Porto', 9, NULL, NULL),
    (26, '83023741', 2, 'TZ-64-TE', '89592782', '2026-07-11 08:49:00', '2026-07-12 11:00:00', 'Rua do Campo Alegre, 240, Porto', 12, NULL, NULL),
    (27, '93374421', 3, 'TZ-64-TE', '89592782', '2026-08-14 14:56:00', '2026-08-15 12:15:00', 'Avenida da Boavista, 192, Porto', 6, NULL, NULL),
    (28, '38910936', 3, 'BX-90-ZG', '88097845', '2026-09-08 03:40:00', '2026-09-09 12:45:00', 'Rua de Santa Catarina, 243, Porto', 10, NULL, NULL),
    (29, '30938108', 2, 'BX-90-ZG', '88097845', '2026-09-08 08:36:00', '2026-09-09 11:00:00', 'Rua da Boavista, 159, Porto', 8, NULL, NULL),
    (30, '57625835', 4, 'TZ-64-TE', '89592782', '2026-09-19 06:32:00', '2026-09-20 13:00:00', 'Avenida dos Aliados, 56, Porto', 9, NULL, NULL);
GO

-- Viagem: 30 tuplos
INSERT INTO Viagem (nr_viagem, cod_pedido, duracao_minutos, atraso_passageiro_minutos, custo_preco_base, custo_duracao, custo_distancia, custo_espera, valor_iva, custo_total) VALUES
    (1, 1, 20, NULL, 2.70, 4.40, 7.52, 0.00, 3.36, 17.98),
    (2, 2, 26, 2, 3.00, 6.24, 9.90, 0.30, 4.47, 23.91),
    (3, 3, 30, NULL, 5.30, 12.90, 18.72, 0.00, 8.49, 45.41),
    (4, 4, 19, NULL, 4.30, 6.27, 8.82, 0.00, 4.46, 23.85),
    (5, 5, 22, NULL, 2.80, 5.06, 8.64, 0.00, 3.80, 20.30),
    (6, 6, 22, NULL, 2.90, 5.28, 8.82, 0.00, 3.91, 20.91),
    (7, 7, 40, 3, 2.90, 9.60, 13.72, 0.45, 6.13, 32.80),
    (8, 8, 40, NULL, 3.20, 10.40, 14.42, 0.00, 6.44, 34.46),
    (9, 9, 150, NULL, 5.40, 66.00, 189.60, 0.00, 60.03, 321.03),
    (10, 10, 35, 3, 2.90, 8.40, 10.78, 0.45, 5.18, 27.71),
    (11, 11, 40, 3, 5.40, 17.60, 22.12, 0.90, 10.58, 56.60),
    (12, 12, 180, NULL, 4.40, 61.20, 76.80, 0.00, 32.75, 175.15),
    (13, 13, 180, NULL, 5.40, 79.20, 94.80, 0.00, 41.26, 220.66),
    (14, 14, 30, NULL, 3.20, 7.80, 12.36, 0.00, 5.37, 28.73),
    (15, 15, 35, NULL, 3.30, 9.45, 11.55, 0.00, 5.59, 29.89),
    (16, 16, 40, NULL, 4.50, 14.00, 18.20, 0.00, 8.44, 45.14),
    (17, 17, 180, NULL, 4.50, 63.00, 78.00, 0.00, 33.47, 178.97),
    (18, 18, 180, NULL, 5.50, 81.00, 96.00, 0.00, 41.98, 224.48),
    (19, 19, 19, NULL, 4.50, 6.65, 9.10, 0.00, 4.66, 24.91),
    (20, 20, 40, NULL, 3.00, 10.00, 14.00, 0.00, 6.21, 33.21),
    (21, 21, 26, NULL, 3.00, 6.50, 11.00, 0.00, 4.72, 25.22),
    (22, 22, 40, NULL, 3.30, 10.80, 14.70, 0.00, 6.62, 35.42),
    (23, 23, 22, 3, 3.00, 5.50, 8.00, 0.45, 3.90, 20.85),
    (24, 24, 28, NULL, 3.00, 7.00, 11.00, 0.00, 4.83, 25.83),
    (25, 25, 24, NULL, 3.40, 6.72, 9.63, 0.00, 4.54, 24.29),
    (26, 26, 30, 3, 3.40, 8.40, 12.84, 0.45, 5.77, 30.86),
    (27, 27, 18, 3, 5.60, 8.28, 9.72, 0.90, 5.64, 30.14),
    (28, 29, 25, NULL, 3.40, 7.00, 8.56, 0.00, 4.36, 23.32),
    (29, 28, 26, NULL, 5.60, 11.96, 16.20, 0.00, 7.76, 41.52),
    (30, 30, 25, 3, 4.60, 9.00, 11.88, 0.75, 6.03, 32.26);
GO

-- Fatura_Recibo: 30 tuplos
INSERT INTO Fatura_Recibo (nr_fatura, nr_viagem, data_emissao) VALUES
    (1, 1, '2025-03-12'),
    (2, 2, '2025-05-20'),
    (3, 3, '2025-08-07'),
    (4, 4, '2025-10-15'),
    (5, 5, '2025-12-03'),
    (6, 6, '2026-01-08'),
    (7, 7, '2026-01-14'),
    (8, 8, '2026-02-11'),
    (9, 9, '2026-02-12'),
    (10, 10, '2026-02-19'),
    (11, 11, '2026-03-04'),
    (12, 12, '2026-03-10'),
    (13, 13, '2026-03-17'),
    (14, 14, '2026-03-19'),
    (15, 15, '2026-04-02'),
    (16, 16, '2026-04-08'),
    (17, 17, '2026-04-14'),
    (18, 18, '2026-04-21'),
    (19, 19, '2026-04-23'),
    (20, 20, '2026-05-06'),
    (21, 21, '2026-05-07'),
    (22, 22, '2026-05-13'),
    (23, 23, '2026-06-06'),
    (24, 24, '2026-06-25'),
    (25, 25, '2026-07-11'),
    (26, 26, '2026-07-12'),
    (27, 27, '2026-08-15'),
    (28, 28, '2026-09-09'),
    (29, 29, '2026-09-09'),
    (30, 30, '2026-09-20');
GO

-- Viagem_Ponto_Turistico: 144 tuplos
INSERT INTO Viagem_Ponto_Turistico (nr_viagem, cod_ponto, data_hora_passagem) VALUES
    (7, 1, '2026-01-14 08:38:00'),
    (7, 3, '2026-01-14 08:50:00'),
    (7, 5, '2026-01-14 09:02:00'),
    (8, 1, '2026-02-11 15:23:00'),
    (8, 3, '2026-02-11 15:35:00'),
    (8, 5, '2026-02-11 15:47:00'),
    (10, 10, '2026-02-19 13:07:00'),
    (10, 18, '2026-02-19 13:17:00'),
    (10, 24, '2026-02-19 13:29:00'),
    (11, 1, '2026-03-04 16:48:00'),
    (11, 3, '2026-03-04 17:00:00'),
    (11, 5, '2026-03-04 17:12:00'),
    (12, 1, '2026-03-10 09:05:00'),
    (12, 2, '2026-03-10 09:10:00'),
    (12, 3, '2026-03-10 09:15:00'),
    (12, 4, '2026-03-10 09:20:00'),
    (12, 5, '2026-03-10 09:25:00'),
    (12, 6, '2026-03-10 09:30:00'),
    (12, 7, '2026-03-10 09:35:00'),
    (12, 8, '2026-03-10 09:40:00'),
    (12, 9, '2026-03-10 09:45:00'),
    (12, 10, '2026-03-10 09:50:00'),
    (12, 11, '2026-03-10 09:55:00'),
    (12, 12, '2026-03-10 10:00:00'),
    (12, 13, '2026-03-10 10:05:00'),
    (12, 14, '2026-03-10 10:10:00'),
    (12, 15, '2026-03-10 10:15:00'),
    (12, 16, '2026-03-10 10:20:00'),
    (12, 17, '2026-03-10 10:25:00'),
    (12, 18, '2026-03-10 10:30:00'),
    (12, 19, '2026-03-10 10:35:00'),
    (12, 20, '2026-03-10 10:40:00'),
    (12, 21, '2026-03-10 10:45:00'),
    (12, 22, '2026-03-10 10:50:00'),
    (12, 23, '2026-03-10 10:55:00'),
    (12, 24, '2026-03-10 11:00:00'),
    (12, 25, '2026-03-10 11:05:00'),
    (12, 26, '2026-03-10 11:10:00'),
    (12, 27, '2026-03-10 11:15:00'),
    (12, 28, '2026-03-10 11:20:00'),
    (12, 29, '2026-03-10 11:25:00'),
    (12, 30, '2026-03-10 11:30:00'),
    (13, 1, '2026-03-17 09:05:00'),
    (13, 2, '2026-03-17 09:10:00'),
    (13, 3, '2026-03-17 09:15:00'),
    (13, 4, '2026-03-17 09:20:00'),
    (13, 5, '2026-03-17 09:25:00'),
    (13, 6, '2026-03-17 09:30:00'),
    (13, 7, '2026-03-17 09:35:00'),
    (13, 8, '2026-03-17 09:40:00'),
    (13, 9, '2026-03-17 09:45:00'),
    (13, 10, '2026-03-17 09:50:00'),
    (13, 11, '2026-03-17 09:55:00'),
    (13, 12, '2026-03-17 10:00:00'),
    (13, 13, '2026-03-17 10:05:00'),
    (13, 14, '2026-03-17 10:10:00'),
    (13, 15, '2026-03-17 10:15:00'),
    (13, 16, '2026-03-17 10:20:00'),
    (13, 17, '2026-03-17 10:25:00'),
    (13, 18, '2026-03-17 10:30:00'),
    (13, 19, '2026-03-17 10:35:00'),
    (13, 20, '2026-03-17 10:40:00'),
    (13, 21, '2026-03-17 10:45:00'),
    (13, 22, '2026-03-17 10:50:00'),
    (13, 23, '2026-03-17 10:55:00'),
    (13, 24, '2026-03-17 11:00:00'),
    (13, 25, '2026-03-17 11:05:00'),
    (13, 26, '2026-03-17 11:10:00'),
    (13, 27, '2026-03-17 11:15:00'),
    (13, 28, '2026-03-17 11:20:00'),
    (13, 29, '2026-03-17 11:25:00'),
    (13, 30, '2026-03-17 11:30:00'),
    (15, 10, '2026-04-02 14:07:00'),
    (15, 18, '2026-04-02 14:17:00'),
    (15, 24, '2026-04-02 14:29:00'),
    (16, 1, '2026-04-08 09:08:00'),
    (16, 3, '2026-04-08 09:20:00'),
    (16, 5, '2026-04-08 09:32:00'),
    (17, 1, '2026-04-14 09:05:00'),
    (17, 2, '2026-04-14 09:10:00'),
    (17, 3, '2026-04-14 09:15:00'),
    (17, 4, '2026-04-14 09:20:00'),
    (17, 5, '2026-04-14 09:25:00'),
    (17, 6, '2026-04-14 09:30:00'),
    (17, 7, '2026-04-14 09:35:00'),
    (17, 8, '2026-04-14 09:40:00'),
    (17, 9, '2026-04-14 09:45:00'),
    (17, 10, '2026-04-14 09:50:00'),
    (17, 11, '2026-04-14 09:55:00'),
    (17, 12, '2026-04-14 10:00:00'),
    (17, 13, '2026-04-14 10:05:00'),
    (17, 14, '2026-04-14 10:10:00'),
    (17, 15, '2026-04-14 10:15:00'),
    (17, 16, '2026-04-14 10:20:00'),
    (17, 17, '2026-04-14 10:25:00'),
    (17, 18, '2026-04-14 10:30:00'),
    (17, 19, '2026-04-14 10:35:00'),
    (17, 20, '2026-04-14 10:40:00'),
    (17, 21, '2026-04-14 10:45:00'),
    (17, 22, '2026-04-14 10:50:00');
GO

INSERT INTO Viagem_Ponto_Turistico (nr_viagem, cod_ponto, data_hora_passagem) VALUES
    (17, 23, '2026-04-14 10:55:00'),
    (17, 24, '2026-04-14 11:00:00'),
    (17, 25, '2026-04-14 11:05:00'),
    (17, 26, '2026-04-14 11:10:00'),
    (17, 27, '2026-04-14 11:15:00'),
    (17, 28, '2026-04-14 11:20:00'),
    (17, 29, '2026-04-14 11:25:00'),
    (17, 30, '2026-04-14 11:30:00'),
    (18, 1, '2026-04-21 09:35:00'),
    (18, 2, '2026-04-21 09:40:00'),
    (18, 3, '2026-04-21 09:45:00'),
    (18, 4, '2026-04-21 09:50:00'),
    (18, 5, '2026-04-21 09:55:00'),
    (18, 6, '2026-04-21 10:00:00'),
    (18, 7, '2026-04-21 10:05:00'),
    (18, 8, '2026-04-21 10:10:00'),
    (18, 9, '2026-04-21 10:15:00'),
    (18, 10, '2026-04-21 10:20:00'),
    (18, 11, '2026-04-21 10:25:00'),
    (18, 12, '2026-04-21 10:30:00'),
    (18, 13, '2026-04-21 10:35:00'),
    (18, 14, '2026-04-21 10:40:00'),
    (18, 15, '2026-04-21 10:45:00'),
    (18, 16, '2026-04-21 10:50:00'),
    (18, 17, '2026-04-21 10:55:00'),
    (18, 18, '2026-04-21 11:00:00'),
    (18, 19, '2026-04-21 11:05:00'),
    (18, 20, '2026-04-21 11:10:00'),
    (18, 21, '2026-04-21 11:15:00'),
    (18, 22, '2026-04-21 11:20:00'),
    (18, 23, '2026-04-21 11:25:00'),
    (18, 24, '2026-04-21 11:30:00'),
    (18, 25, '2026-04-21 11:35:00'),
    (18, 26, '2026-04-21 11:40:00'),
    (18, 27, '2026-04-21 11:45:00'),
    (18, 28, '2026-04-21 11:50:00'),
    (18, 29, '2026-04-21 11:55:00'),
    (18, 30, '2026-04-21 12:00:00'),
    (20, 1, '2026-05-06 14:18:00'),
    (20, 3, '2026-05-06 14:30:00'),
    (20, 5, '2026-05-06 14:42:00'),
    (22, 1, '2026-05-13 12:28:00'),
    (22, 3, '2026-05-13 12:40:00'),
    (22, 5, '2026-05-13 12:52:00');
GO

-- Recibo_Comissao: 35 tuplos
INSERT INTO Recibo_Comissao (nr_recibo, nr_idCivil_condutor, data_emissao, mes_referencia, ano_referencia, valor_comissoes_viagens, valor_comissoes_supervisao, valor_total_comissoes) VALUES
    (1, '54464097', '2025-04-05', 3, 2025, 0, 0.18, 0.18),
    (2, '82366283', '2025-04-05', 3, 2025, 3.60, 0, 3.60),
    (3, '17480894', '2025-06-05', 5, 2025, 0, 0.17, 0.17),
    (4, '57100526', '2025-06-05', 5, 2025, 4.30, 0, 4.30),
    (5, '85903659', '2025-09-05', 8, 2025, 11.35, 0, 11.35),
    (6, '58000147', '2025-11-05', 10, 2025, 5.25, 0, 5.25),
    (7, '72230843', '2026-01-05', 12, 2025, 4.06, 0, 4.06),
    (8, '54464097', '2026-02-05', 1, 2026, 4.18, 0.33, 4.51),
    (9, '67255890', '2026-02-05', 1, 2026, 6.56, 0, 6.56),
    (10, '54464097', '2026-03-05', 2, 2026, 80.26, 0.25, 80.51),
    (11, '87626738', '2026-03-05', 2, 2026, 6.20, 0, 6.20),
    (12, '33140838', '2026-03-05', 2, 2026, 5.54, 0, 5.54),
    (13, '54464097', '2026-04-05', 3, 2026, 5.17, 6.09, 11.26),
    (14, '95212661', '2026-04-05', 3, 2026, 38.53, 0, 38.53),
    (15, '89590039', '2026-04-05', 3, 2026, 55.17, 0, 55.17),
    (16, '35256684', '2026-04-05', 3, 2026, 14.15, 0, 14.15),
    (17, '54464097', '2026-05-05', 4, 2026, 5.48, 5.84, 11.32),
    (18, '95212661', '2026-05-05', 4, 2026, 39.37, 0, 39.37),
    (19, '89590039', '2026-05-05', 4, 2026, 56.12, 0, 56.12),
    (20, '96753514', '2026-05-05', 4, 2026, 9.93, 0, 9.93),
    (21, '67599395', '2026-05-05', 4, 2026, 5.38, 0, 5.38),
    (22, '54464097', '2026-06-05', 5, 2026, 5.04, 0.59, 5.63),
    (23, '84517017', '2026-06-05', 5, 2026, 6.64, 0, 6.64),
    (24, '94082061', '2026-06-05', 5, 2026, 6.38, 0, 6.38),
    (25, '17480894', '2026-07-05', 6, 2026, 0, 0.47, 0.47),
    (26, '89592782', '2026-07-05', 6, 2026, 4.17, 0, 4.17),
    (27, '44343251', '2026-07-05', 6, 2026, 5.17, 0, 5.17),
    (28, '17480894', '2026-08-05', 7, 2026, 0, 0.39, 0.39),
    (29, '89592782', '2026-08-05', 7, 2026, 5.55, 0, 5.55),
    (30, '44343251', '2026-08-05', 7, 2026, 4.37, 0, 4.37),
    (31, '17480894', '2026-09-05', 8, 2026, 0, 0.45, 0.45),
    (32, '89592782', '2026-09-05', 8, 2026, 7.54, 0, 7.54),
    (33, '17480894', '2026-10-05', 9, 2026, 0, 1.15, 1.15),
    (34, '89592782', '2026-10-05', 9, 2026, 7.10, 0, 7.10),
    (35, '88097845', '2026-10-05', 9, 2026, 14.58, 0, 14.58);
GO

-- Detalhe_Recibo_Viagem: 30 tuplos
INSERT INTO Detalhe_Recibo_Viagem (nr_viagem, nr_recibo, cod_servico, custo_total_viagem, percentagem_aplicada, valor_comissao) VALUES
    (1, 2, 1, 17.98, 20, 3.60),
    (2, 4, 2, 23.91, 18, 4.30),
    (3, 5, 3, 45.41, 25, 11.35),
    (4, 6, 4, 23.85, 22, 5.25),
    (5, 7, 1, 20.30, 20, 4.06),
    (6, 8, 1, 20.91, 20, 4.18),
    (7, 9, 1, 32.80, 20, 6.56),
    (9, 10, 3, 321.03, 25, 80.26),
    (8, 11, 2, 34.46, 18, 6.20),
    (10, 12, 1, 27.71, 20, 5.54),
    (14, 13, 2, 28.73, 18, 5.17),
    (12, 14, 4, 175.15, 22, 38.53),
    (13, 15, 3, 220.66, 25, 55.17),
    (11, 16, 3, 56.60, 25, 14.15),
    (19, 17, 4, 24.91, 22, 5.48),
    (17, 18, 4, 178.97, 22, 39.37),
    (18, 19, 3, 224.48, 25, 56.12),
    (16, 20, 4, 45.14, 22, 9.93),
    (15, 21, 2, 29.89, 18, 5.38),
    (21, 22, 1, 25.22, 20, 5.04),
    (20, 23, 1, 33.21, 20, 6.64),
    (22, 24, 2, 35.42, 18, 6.38),
    (23, 26, 1, 20.85, 20, 4.17),
    (24, 27, 1, 25.83, 20, 5.17),
    (26, 29, 2, 30.86, 18, 5.55),
    (25, 30, 2, 24.29, 18, 4.37),
    (27, 32, 3, 30.14, 25, 7.54),
    (30, 34, 4, 32.26, 22, 7.10),
    (28, 35, 2, 23.32, 18, 4.20),
    (29, 35, 3, 41.52, 25, 10.38);
GO

-- Verificação rápida das contagens
SELECT 'Tipo_Servico' AS tabela, COUNT(*) AS tuplos FROM Tipo_Servico
UNION ALL SELECT 'Historico_Custo_Servico', COUNT(*) FROM Historico_Custo_Servico
UNION ALL SELECT 'Cliente', COUNT(*) FROM Cliente
UNION ALL SELECT 'Condutor', COUNT(*) FROM Condutor
UNION ALL SELECT 'Veiculo', COUNT(*) FROM Veiculo
UNION ALL SELECT 'Condutor_Veiculo', COUNT(*) FROM Condutor_Veiculo
UNION ALL SELECT 'Ponto_Turistico', COUNT(*) FROM Ponto_Turistico
UNION ALL SELECT 'Pedido_Viagem', COUNT(*) FROM Pedido_Viagem
UNION ALL SELECT 'Viagem', COUNT(*) FROM Viagem
UNION ALL SELECT 'Fatura_Recibo', COUNT(*) FROM Fatura_Recibo
UNION ALL SELECT 'Viagem_Ponto_Turistico', COUNT(*) FROM Viagem_Ponto_Turistico
UNION ALL SELECT 'Recibo_Comissao', COUNT(*) FROM Recibo_Comissao
UNION ALL SELECT 'Detalhe_Recibo_Viagem', COUNT(*) FROM Detalhe_Recibo_Viagem;
GO