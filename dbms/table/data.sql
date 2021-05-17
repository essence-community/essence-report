--liquibase formatted sql
--changeset artemov_i:init_schema_data_essence_report dbms:postgresql splitStatements:false stripComments:false
INSERT INTO ${user.table}.t_d_error (ck_id,cv_name,ck_user,ct_change)
	VALUES ('system_error','Другая ошибка системы','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.723');
INSERT INTO ${user.table}.t_d_error (ck_id,cv_name,ck_user,ct_change)
	VALUES ('db_error','Внутреняя ошибка в бд','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.723');
INSERT INTO ${user.table}.t_d_error (ck_id,cv_name,ck_user,ct_change)
	VALUES ('network','Ошибка вызова шлюза','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.723');

INSERT INTO ${user.table}.t_d_source_type (ck_id,cv_name,ck_user,ct_change)
	VALUES ('plugin','Плагин','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.723');
INSERT INTO ${user.table}.t_d_source_type (ck_id,cv_name,ck_user,ct_change)
	VALUES ('postgres','PostgreSQL','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.723');
INSERT INTO ${user.table}.t_d_source_type (ck_id,cv_name,ck_user,ct_change)
	VALUES ('oracle','Oracle','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.723');

INSERT INTO ${user.table}.t_d_queue (ck_id,ck_user,ct_change)
	VALUES ('default','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.723');

INSERT INTO ${user.table}.t_d_status (ck_id,cv_name,ck_user,ct_change)
	VALUES ('add','Добавлен в очередь','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
INSERT INTO ${user.table}.t_d_status (ck_id,cv_name,ck_user,ct_change)
	VALUES ('success','Отчет готов','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
INSERT INTO ${user.table}.t_d_status (ck_id,cv_name,ck_user,ct_change)
	VALUES ('fault','Ошибка формирования','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
INSERT INTO ${user.table}.t_d_status (ck_id,cv_name,ck_user,ct_change)
	VALUES ('processing','Отчет на формировании','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
INSERT INTO ${user.table}.t_d_status (ck_id,cv_name,ck_user,ct_change)
	VALUES ('delete','Отчет удален с хранения','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');

INSERT INTO ${user.table}.t_authorization (ck_id, cv_name, cv_plugin, cct_parameter, ck_user, ct_change)
    VALUES ('f4548def-7373-48bc-bc1f-8cb19c25aec9'::uuid, 'Без авторизации', 'no_auth', '{}'::jsonb,'4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
INSERT INTO ${user.table}.t_authorization (ck_id, cv_name, cv_plugin, cct_parameter, ck_user, ct_change)
    VALUES ('7691352f-764f-42c9-800a-ef7afb8b0fed'::uuid, 'Авторизация проекта CORE', 'core', '{"cv_url":"http://localhost:8080/api"}'::jsonb,'4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');

INSERT INTO ${user.table}.t_d_global_setting (ck_id,cv_value,cv_description,ck_user,ct_change)
	VALUES ('JSREPORT_SETTING','{}','Настройки JSReports','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
INSERT INTO ${user.table}.t_d_global_setting (ck_id,cv_value,cv_description,ck_user,ct_change)
	VALUES ('TYPE_STORAGE','dir','Место хранение готовых отчетов.
local - в данную бд
riak - хранилище riak cs
aws - Amazon
dir - локальная папка','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
INSERT INTO ${user.table}.t_d_global_setting (ck_id,cv_value,cv_description,ck_user,ct_change)
	VALUES ('DIR_STORAGE_PATH','/tmp','Папка хранение готовых отчетов, если выбран тип dir','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
INSERT INTO ${user.table}.t_d_global_setting (ck_id,cv_value,cv_description,ck_user,ct_change)
	VALUES ('S3_PARAMETER','{}','Настройки S3','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
INSERT INTO ${user.table}.t_d_global_setting (ck_id,cv_value,cv_description,ck_user,ct_change)
	VALUES ('S3_KEY_ID','','Ключ ID S3','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
INSERT INTO ${user.table}.t_d_global_setting (ck_id,cv_value,cv_description,ck_user,ct_change)
	VALUES ('S3_SECRET_KEY','','Ключ S3','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
INSERT INTO ${user.table}.t_d_global_setting (ck_id,cv_value,cv_description,ck_user,ct_change)
	VALUES ('S3_ENDPOINT','http://s3.amazonaws.com','Урл S3','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
INSERT INTO ${user.table}.t_d_global_setting (ck_id,cv_value,cv_description,ck_user,ct_change)
	VALUES ('RIAK_PROXY','http://localhost:10010','Урл Riak CS в режиме прокси ','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
INSERT INTO ${user.table}.t_d_global_setting (ck_id,cv_value,cv_description,ck_user,ct_change)
	VALUES ('S3_BUCKET','reports','Наименование корзины в S3','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
INSERT INTO ${user.table}.t_d_global_setting (ck_id,cv_value,cv_description,ck_user,ct_change)
	VALUES ('S3_READ_PUBLIC','false','Разрешаем доступ файлов в S3','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');

INSERT INTO ${user.table}.t_source (ck_id,cct_parameter,ck_d_source,cl_enable,ck_user,ct_change)
	VALUES ('meta','{"user": "s_mc", "poolMax": 100, "poolMin": 0, "password": "s_mc", "connectString": "postgres://localhost:5432/core"}'::jsonb,'postgres',0,'4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
INSERT INTO ${user.table}.t_source (ck_id,cct_parameter,ck_d_source,cl_enable,ck_user,ct_change)
	VALUES ('bfl','{"user": "s_bc", "poolMax": 100, "poolMin": 0, "password": "s_bc", "connectString": "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=BFL))"}'::jsonb,'oracle',0,'4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');


INSERT INTO ${user.table}.t_d_engine (ck_id,cv_name,ck_user,ct_change)
	VALUES ('handlebars','Шаблон построитель https://handlebarsjs.com/','4fd05ca9-3a9e-4d66-82df-886dfa082113','2020-10-23 10:05:51.000');
