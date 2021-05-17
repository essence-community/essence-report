--liquibase formatted sql
--changeset artemov_i:init_schema_default dbms:postgresql splitStatements:false stripComments:false
CREATE SCHEMA ${user.table};

CREATE TABLE ${user.table}.t_log
(
    ck_id varchar(32) NOT NULL,
    cv_session varchar(100),
    cc_json text,
    cv_table varchar(4000),
    cv_id varchar(4000),
    cv_action varchar(30),
    cv_error varchar(4000),
    ck_user varchar(150) NOT NULL,
    ct_change timestamp with time zone NOT NULL,
    CONSTRAINT cin_p_log PRIMARY KEY (ck_id)
);
COMMENT ON TABLE ${user.table}.t_log IS 'Лог';
COMMENT ON COLUMN ${user.table}.t_log.ck_id IS 'ИД записи лога';
COMMENT ON COLUMN ${user.table}.t_log.cv_session IS 'ИД сессии';
COMMENT ON COLUMN ${user.table}.t_log.cc_json IS 'JSON';
COMMENT ON COLUMN ${user.table}.t_log.cv_table IS 'Имя таблицы';
COMMENT ON COLUMN ${user.table}.t_log.cv_id IS 'ИД записи в таблице';
COMMENT ON COLUMN ${user.table}.t_log.cv_action IS 'ИД действия';
COMMENT ON COLUMN ${user.table}.t_log.cv_error IS 'Код ошибки';
COMMENT ON COLUMN ${user.table}.t_log.ck_user IS 'ИД пользователя';
COMMENT ON COLUMN ${user.table}.t_log.ct_change IS 'Дата последнего изменения';

CREATE TABLE ${user.table}.t_create_patch (
	ck_id uuid NOT NULL,
	cv_file_name varchar(200) NOT NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	сj_param jsonb NOT NULL,
	cd_create date NOT NULL,
	cn_size bigint NULL,
	CONSTRAINT cin_p_create_patch PRIMARY KEY (ck_id)
);
COMMENT ON COLUMN ${user.table}.t_create_patch.ck_id IS 'Идентификатор';
COMMENT ON COLUMN ${user.table}.t_create_patch.cv_file_name IS 'Наименование файла';
COMMENT ON COLUMN ${user.table}.t_create_patch.ck_user IS 'Аудит идентификатор пользователя';
COMMENT ON COLUMN ${user.table}.t_create_patch.ct_change IS 'Аудит время модификации';
COMMENT ON COLUMN ${user.table}.t_create_patch.сj_param IS 'Параметры запуска';
COMMENT ON COLUMN ${user.table}.t_create_patch.cd_create IS 'Дата сборки';
COMMENT ON COLUMN ${user.table}.t_create_patch.cn_size IS 'Размер сборки';

CREATE TABLE ${user.table}.t_notification (
	ck_id varchar(32) NOT NULL,
	cd_st timestamp NOT NULL,
	cd_en timestamp,
	ck_user varchar(100) NOT NULL,
	cl_sent smallint NOT NULL,
	cv_message text,
	CONSTRAINT cin_p_notification PRIMARY KEY (ck_id)
);
COMMENT ON TABLE ${user.table}.t_notification IS 'Т_Оповещение';
COMMENT ON COLUMN ${user.table}.t_notification.ck_id IS 'ИД оповещения';
COMMENT ON COLUMN ${user.table}.t_notification.cd_en IS 'Дата окончания';
COMMENT ON COLUMN ${user.table}.t_notification.cd_st IS 'Дата начала';
COMMENT ON COLUMN ${user.table}.t_notification.cv_message IS 'Сообщение';
COMMENT ON COLUMN ${user.table}.t_notification.ck_user IS 'ИД пользователя';
COMMENT ON COLUMN ${user.table}.t_notification.cl_sent IS 'Признак отправки';

--changeset artemov_i:init_schema_essence_report dbms:postgresql splitStatements:false stripComments:false

-- ${user.table}.t_authorization definition

-- Drop table

-- DROP TABLE ${user.table}.t_authorization;

CREATE TABLE ${user.table}.t_authorization (
	ck_id uuid NOT NULL DEFAULT uuid_generate_v4(),
	cv_name varchar(30) NOT NULL,
	cv_plugin varchar(300) NOT NULL,
	cct_parameter jsonb NOT NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	CONSTRAINT cin_c_authorization CHECK ((jsonb_typeof(cct_parameter) = 'object'::text)),
	CONSTRAINT cin_p_authorization PRIMARY KEY (ck_id)
);
CREATE UNIQUE INDEX cin_i_authorization ON ${user.table}.t_authorization USING btree (ck_id);
COMMENT ON TABLE ${user.table}.t_authorization IS 'Список систем авторизации';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_authorization.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_authorization.cv_name IS 'Наименование';

-- ${user.table}.t_d_engine definition

-- Drop table

-- DROP TABLE ${user.table}.t_d_engine;

CREATE TABLE ${user.table}.t_d_engine (
	ck_id varchar(30) NOT NULL,
	cv_name varchar(2000) NOT NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	CONSTRAINT cin_p_d_engine PRIMARY KEY (ck_id)
);
CREATE UNIQUE INDEX cin_i_d_engine ON ${user.table}.t_d_engine USING btree (ck_id);
COMMENT ON TABLE ${user.table}.t_d_engine IS 'Список шаблонизаторов';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_d_engine.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_d_engine.cv_name IS 'Наименование';
COMMENT ON COLUMN ${user.table}.t_d_engine.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_d_engine.ct_change IS 'Время модификации';


-- ${user.table}.t_d_error definition

-- Drop table

-- DROP TABLE ${user.table}.t_d_error;

CREATE TABLE ${user.table}.t_d_error (
	ck_id varchar(30) NOT NULL,
	cv_name varchar(300) NOT NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	CONSTRAINT cin_c_d_error CHECK (((ck_id)::text = lower((ck_id)::text))),
	CONSTRAINT cin_p_d_error PRIMARY KEY (ck_id)
);
CREATE UNIQUE INDEX cin_i_d_error ON ${user.table}.t_d_error USING btree (lower((ck_id)::text));
COMMENT ON TABLE ${user.table}.t_d_error IS 'Список типов ошибок';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_d_error.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_d_error.cv_name IS 'Наименование ошибки';
COMMENT ON COLUMN ${user.table}.t_d_error.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_d_error.ct_change IS 'Время модификации';


-- ${user.table}.t_d_format definition

-- Drop table

-- DROP TABLE ${user.table}.t_d_format;

CREATE TABLE ${user.table}.t_d_format (
	ck_id varchar(30) NOT NULL,
	cv_name varchar(300) NOT NULL,
	cv_extension varchar(10) NOT NULL,
	cv_name_lib varchar(30) NOT NULL,
	cv_recipe varchar(100) NOT NULL,
	cct_parameter jsonb NULL,
	cv_content_type varchar(100) NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	CONSTRAINT cin_c_d_format_1 CHECK ((jsonb_typeof(cct_parameter) = 'object'::text)),
	CONSTRAINT cin_c_d_format_2 CHECK (((cv_extension)::text ~~ '.%'::text)),
	CONSTRAINT cin_c_d_format_3 CHECK (((ck_id)::text = lower((ck_id)::text))),
	CONSTRAINT cin_p_d_format PRIMARY KEY (ck_id)
);
CREATE UNIQUE INDEX cin_i_d_format ON ${user.table}.t_d_format USING btree (lower((ck_id)::text));
COMMENT ON TABLE ${user.table}.t_d_format IS 'Форматы печати';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_d_format.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_d_format.cv_name IS 'Наименование';
COMMENT ON COLUMN ${user.table}.t_d_format.cv_extension IS 'Расширение файла';
COMMENT ON COLUMN ${user.table}.t_d_format.cv_name_lib IS 'Наименование библиотеки jsreports';
COMMENT ON COLUMN ${user.table}.t_d_format.cv_recipe IS 'Наименование настроек в jsreports';
COMMENT ON COLUMN ${user.table}.t_d_format.cct_parameter IS 'Настройка формата';
COMMENT ON COLUMN ${user.table}.t_d_format.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_d_format.ct_change IS 'Время модификации';
COMMENT ON COLUMN ${user.table}.t_d_format.cv_content_type IS 'Mime type';

-- ${user.table}.t_d_global_setting definition

-- Drop table

-- DROP TABLE ${user.table}.t_d_global_setting;

CREATE TABLE ${user.table}.t_d_global_setting (
	ck_id varchar(30) NOT NULL,
	cv_value text NULL,
	cv_description text NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	CONSTRAINT cin_c_d_global_setting_1 CHECK (((ck_id)::text = upper((ck_id)::text))),
	CONSTRAINT cin_p_d_global_setting PRIMARY KEY (ck_id)
);
CREATE UNIQUE INDEX cin_i_d_global_setting_1 ON ${user.table}.t_d_global_setting USING btree (ck_id);
CREATE UNIQUE INDEX cin_i_d_global_setting_2 ON ${user.table}.t_d_global_setting USING btree (upper((ck_id)::text));
COMMENT ON TABLE ${user.table}.t_d_global_setting IS 'Основные настройки';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_d_global_setting.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_d_global_setting.cv_value IS 'Значение';
COMMENT ON COLUMN ${user.table}.t_d_global_setting.cv_description IS 'Описание';
COMMENT ON COLUMN ${user.table}.t_d_global_setting.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_d_global_setting.ct_change IS 'Время модификации';

-- ${user.table}.t_d_source_type definition

-- Drop table

-- DROP TABLE ${user.table}.t_d_source_type;

CREATE TABLE ${user.table}.t_d_source_type (
	ck_id varchar(30) NOT NULL,
	cv_name varchar(300) NOT NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	CONSTRAINT cin_c_source_type_1 CHECK (((ck_id)::text = lower((ck_id)::text))),
	CONSTRAINT cin_p_d_source_type PRIMARY KEY (ck_id)
);
CREATE UNIQUE INDEX cin_i_d_source_type ON ${user.table}.t_d_source_type USING btree (lower((ck_id)::text));
COMMENT ON TABLE ${user.table}.t_d_source_type IS 'Список типов источников данных';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_d_source_type.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_d_source_type.cv_name IS 'Описаниние';
COMMENT ON COLUMN ${user.table}.t_d_source_type.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_d_source_type.ct_change IS 'Время модификации';

-- ${user.table}.t_d_status definition

-- Drop table

-- DROP TABLE ${user.table}.t_d_status;

CREATE TABLE ${user.table}.t_d_status (
	ck_id varchar(30) NOT NULL,
	cv_name varchar(300) NOT NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	CONSTRAINT cin_c_d_status_1 CHECK (((ck_id)::text = lower((ck_id)::text))),
	CONSTRAINT cin_p_d_status PRIMARY KEY (ck_id)
);
CREATE UNIQUE INDEX cin_i_d_status ON ${user.table}.t_d_status USING btree (lower((ck_id)::text));
COMMENT ON TABLE ${user.table}.t_d_status IS 'Список статусов';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_d_status.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_d_status.cv_name IS 'Наименование';
COMMENT ON COLUMN ${user.table}.t_d_status.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_d_status.ct_change IS 'Время модификации';

-- ${user.table}.t_asset definition

-- Drop table

-- DROP TABLE ${user.table}.t_asset;

CREATE TABLE ${user.table}.t_asset (
	ck_id uuid NOT NULL DEFAULT uuid_generate_v4(),
	cv_name text NOT NULL,
	cv_template text NULL,
	ck_engine varchar(30) NULL,
	cb_asset bytea NULL,
	cct_parameter jsonb NULL,
	cv_helpers text NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	CONSTRAINT cin_c_asset CHECK ((jsonb_typeof(cct_parameter) = 'object'::text)),
	CONSTRAINT cin_p_asset PRIMARY KEY (ck_id),
	CONSTRAINT cin_r_asset_1 FOREIGN KEY (ck_engine) REFERENCES ${user.table}.t_d_engine(ck_id)
);
CREATE UNIQUE INDEX cin_i_asset_1 ON ${user.table}.t_asset USING btree (ck_id);
COMMENT ON TABLE ${user.table}.t_asset IS 'Список ресурсов';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_asset.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_asset.cv_name IS 'Наименование';
COMMENT ON COLUMN ${user.table}.t_asset.cv_template IS 'Шаблон';
COMMENT ON COLUMN ${user.table}.t_asset.ck_engine IS 'Индетификатор шаблонизатора';
COMMENT ON COLUMN ${user.table}.t_asset.cb_asset IS 'Файл';
COMMENT ON COLUMN ${user.table}.t_asset.cct_parameter IS 'Настройки';
COMMENT ON COLUMN ${user.table}.t_asset.cv_helpers IS 'Дополнительные функции';
COMMENT ON COLUMN ${user.table}.t_asset.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_asset.ct_change IS 'Время модификации';

-- ${user.table}.t_d_queue definition

-- Drop table

-- DROP TABLE ${user.table}.t_d_queue;

CREATE TABLE ${user.table}.t_d_queue (
	ck_id varchar(30) NOT NULL,
	cv_runner_url varchar(2000) NULL,
	ck_parent varchar(30) NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	CONSTRAINT cin_c_d_queue_1 CHECK (((ck_id)::text = lower((ck_id)::text))),
	CONSTRAINT cin_p_d_queue PRIMARY KEY (ck_id),
	CONSTRAINT cin_r_d_queue_1 FOREIGN KEY (ck_parent) REFERENCES ${user.table}.t_d_queue(ck_id)
);
CREATE UNIQUE INDEX cin_i_d_queue ON ${user.table}.t_d_queue USING btree (lower((ck_id)::text));
COMMENT ON TABLE ${user.table}.t_d_queue IS 'Список очередей';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_d_queue.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_d_queue.cv_runner_url IS 'Ссылка на контекст запуска. Например http://localhost:8020/runner';
COMMENT ON COLUMN ${user.table}.t_d_queue.ck_parent IS 'Ссылка на родительский индетификатор';
COMMENT ON COLUMN ${user.table}.t_d_queue.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_d_queue.ct_change IS 'Время модификации';

-- ${user.table}.t_report definition

-- Drop table

-- DROP TABLE ${user.table}.t_report;

CREATE TABLE ${user.table}.t_report (
	ck_id uuid NOT NULL DEFAULT uuid_generate_v4(),
	cv_name varchar(300) NOT NULL,
	ck_d_default_queue varchar(30) NULL,
	ck_authorization uuid NOT NULL,
	cn_day_expire_storage int2 NOT NULL DEFAULT 365,
	cct_parameter jsonb NULL,
	cn_priority int4 NOT NULL DEFAULT 100,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	CONSTRAINT cin_c_report_1 CHECK ((jsonb_typeof(cct_parameter) = 'object'::text)),
	CONSTRAINT cin_p_report PRIMARY KEY (ck_id),
	CONSTRAINT cin_u_report UNIQUE (cv_name),
	CONSTRAINT cin_r_report_1 FOREIGN KEY (ck_d_default_queue) REFERENCES ${user.table}.t_d_queue(ck_id),
	CONSTRAINT cin_r_report_2 FOREIGN KEY (ck_authorization) REFERENCES ${user.table}.t_authorization(ck_id)
);
CREATE UNIQUE INDEX cin_i_report_1 ON ${user.table}.t_report USING btree (ck_id);
CREATE UNIQUE INDEX cin_i_report_2 ON ${user.table}.t_report USING btree (upper((cv_name)::text));
COMMENT ON TABLE ${user.table}.t_report IS 'Список отчетов';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_report.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_report.cv_name IS 'Наименование';
COMMENT ON COLUMN ${user.table}.t_report.ck_d_default_queue IS 'Индетификатор типа череди по умолчанию';
COMMENT ON COLUMN ${user.table}.t_report.ck_authorization IS 'Индетификатор авторизации';
COMMENT ON COLUMN ${user.table}.t_report.cn_day_expire_storage IS 'Время хранения готового отчета';
COMMENT ON COLUMN ${user.table}.t_report.cct_parameter IS 'Настройки отчета';
COMMENT ON COLUMN ${user.table}.t_report.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_report.ct_change IS 'Время модификации';
COMMENT ON COLUMN ${user.table}.t_report.cn_priority IS 'Приоритет';

-- ${user.table}.t_report_asset definition

-- Drop table

-- DROP TABLE ${user.table}.t_report_asset;

CREATE TABLE ${user.table}.t_report_asset (
	ck_id uuid NOT NULL DEFAULT uuid_generate_v4(),
	cv_name varchar(30) NOT NULL,
	ck_asset uuid NOT NULL,
	ck_report uuid NOT NULL,
	cct_parameter jsonb NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	CONSTRAINT cin_c_report_template_1 CHECK (((cv_name)::text = lower((cv_name)::text))),
	CONSTRAINT cin_c_report_template_2 CHECK ((jsonb_typeof(cct_parameter) = 'object'::text)),
	CONSTRAINT cin_p_report_template PRIMARY KEY (ck_id),
	CONSTRAINT cin_u_report_template UNIQUE (ck_report, cv_name),
	CONSTRAINT cin_r_report_template_1 FOREIGN KEY (ck_report) REFERENCES ${user.table}.t_report(ck_id),
	CONSTRAINT cin_r_report_template_2 FOREIGN KEY (ck_asset) REFERENCES ${user.table}.t_asset(ck_id)
);
CREATE UNIQUE INDEX cin_i_report_template_1 ON ${user.table}.t_report_asset USING btree (ck_id);
CREATE UNIQUE INDEX cin_i_report_template_2 ON ${user.table}.t_report_asset USING btree (ck_report, lower((cv_name)::text));
CREATE INDEX cin_i_report_template_3 ON ${user.table}.t_report_asset USING btree (ck_asset);
CREATE INDEX cin_i_report_template_4 ON ${user.table}.t_report_asset USING btree (ck_report);
COMMENT ON TABLE ${user.table}.t_report_asset IS 'Список дополнительных ресурсов';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_report_asset.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_report_asset.cv_name IS 'Наименование';
COMMENT ON COLUMN ${user.table}.t_report_asset.ck_asset IS 'Индетифкатор ресурса';
COMMENT ON COLUMN ${user.table}.t_report_asset.ck_report IS 'Индетификатор отчета';
COMMENT ON COLUMN ${user.table}.t_report_asset.cct_parameter IS 'Настройки';
COMMENT ON COLUMN ${user.table}.t_report_asset.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_report_asset.ct_change IS 'Время модификации';


-- ${user.table}.t_report_format definition

-- Drop table

-- DROP TABLE ${user.table}.t_report_format;

CREATE TABLE ${user.table}.t_report_format (
	ck_id uuid NOT NULL DEFAULT uuid_generate_v4(),
	ck_report uuid NOT NULL,
	ck_d_format varchar(30) NOT NULL,
	cct_parameter jsonb NULL,
	ck_asset uuid NOT NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	CONSTRAINT cin_c_report_format CHECK ((jsonb_typeof(cct_parameter) = 'object'::text)),
	CONSTRAINT cin_p_report_format PRIMARY KEY (ck_id),
	CONSTRAINT cin_u_report_format UNIQUE (ck_report, ck_d_format),
	CONSTRAINT cin_r_report_format_1 FOREIGN KEY (ck_report) REFERENCES ${user.table}.t_report(ck_id),
	CONSTRAINT cin_r_report_format_2 FOREIGN KEY (ck_d_format) REFERENCES ${user.table}.t_d_format(ck_id),
	CONSTRAINT cin_r_report_format_3 FOREIGN KEY (ck_asset) REFERENCES ${user.table}.t_asset(ck_id)
);
CREATE UNIQUE INDEX cin_i_report_format_1 ON ${user.table}.t_report_format USING btree (ck_report, ck_d_format);
CREATE INDEX cin_i_report_format_2 ON ${user.table}.t_report_format USING btree (ck_report);
CREATE INDEX cin_i_report_format_3 ON ${user.table}.t_report_format USING btree (ck_d_format);
CREATE UNIQUE INDEX cin_i_report_format_4 ON ${user.table}.t_report_format USING btree (ck_id);
COMMENT ON TABLE ${user.table}.t_report_format IS 'Список формата отчета';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_report_format.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_report_format.ck_report IS 'Индетификатор отчета';
COMMENT ON COLUMN ${user.table}.t_report_format.ck_d_format IS 'Индетификатор формата';
COMMENT ON COLUMN ${user.table}.t_report_format.cct_parameter IS 'Настройки формата';
COMMENT ON COLUMN ${user.table}.t_report_format.ck_asset IS 'Индетификатор ресурса';
COMMENT ON COLUMN ${user.table}.t_report_format.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_report_format.ct_change IS 'Время модификации';

-- ${user.table}.t_scheduler definition

-- Drop table

-- DROP TABLE ${user.table}.t_scheduler;

CREATE TABLE ${user.table}.t_scheduler (
	ck_id uuid NOT NULL DEFAULT uuid_generate_v4(),
	cct_parameter jsonb NULL,
	cn_priority int4 NOT NULL DEFAULT 100,
	cv_unix_cron varchar(100) NOT NULL,
	ct_next_run_cron timestamptz NULL,
	ck_d_format varchar(30) NOT NULL,
	ck_report uuid NOT NULL,
	cv_report_name varchar(50) NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	ct_start_run_cron timestamptz(0) NOT NULL,
	cl_enable int2 NOT NULL DEFAULT 0,
	CONSTRAINT cin_c_scheduler_1 CHECK ((jsonb_typeof(cct_parameter) = 'object'::text)),
	CONSTRAINT cin_p_scheduler PRIMARY KEY (ck_id),
	CONSTRAINT cin_r_scheduler_2 FOREIGN KEY (ck_d_format) REFERENCES ${user.table}.t_d_format(ck_id),
	CONSTRAINT cin_r_scheduler_3 FOREIGN KEY (ck_report) REFERENCES ${user.table}.t_report(ck_id)
);
CREATE INDEX cin_i_scheduler_2 ON ${user.table}.t_scheduler USING btree (ck_d_format);
CREATE INDEX cin_i_scheduler_3 ON ${user.table}.t_scheduler USING btree (ck_report);
CREATE UNIQUE INDEX cin_i_scheduler_4 ON ${user.table}.t_scheduler USING btree (ck_id);
COMMENT ON TABLE ${user.table}.t_scheduler IS 'Список плановых печатей отчета';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_scheduler.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_scheduler.cct_parameter IS 'Настройки';
COMMENT ON COLUMN ${user.table}.t_scheduler.cn_priority IS 'Приоритет запуска';
COMMENT ON COLUMN ${user.table}.t_scheduler.cv_unix_cron IS 'Настройка времени запуска в формате unix. * * * * *';
COMMENT ON COLUMN ${user.table}.t_scheduler.ct_next_run_cron IS 'Время следующего запуска';
COMMENT ON COLUMN ${user.table}.t_scheduler.ck_d_format IS 'Индетификатор формата отчета';
COMMENT ON COLUMN ${user.table}.t_scheduler.ck_report IS 'Индетификатор отчета';
COMMENT ON COLUMN ${user.table}.t_scheduler.cv_report_name IS 'Наименование файла результата';
COMMENT ON COLUMN ${user.table}.t_scheduler.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_scheduler.ct_change IS 'Время модификации';
COMMENT ON COLUMN ${user.table}.t_scheduler.ct_start_run_cron IS 'Время начала работы планировщика';
COMMENT ON COLUMN ${user.table}.t_scheduler.cl_enable IS 'Признак активности планировщика';

-- ${user.table}.t_source definition

-- Drop table

-- DROP TABLE ${user.table}.t_source;

CREATE TABLE ${user.table}.t_source (
	ck_id varchar(30) NOT NULL,
	cct_parameter jsonb NULL,
	cv_plugin varchar(300) NULL,
	ck_d_source varchar(30) NOT NULL,
	cl_enable smallint NOT NULL DEFAULT 0::smallint,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	CONSTRAINT cin_c_source CHECK ((jsonb_typeof(cct_parameter) = 'object'::text)),
	CONSTRAINT cin_p_source PRIMARY KEY (ck_id),
	CONSTRAINT cin_r_source_1 FOREIGN KEY (ck_d_source) REFERENCES ${user.table}.t_d_source_type(ck_id)
);
CREATE INDEX cin_i_source_1 ON ${user.table}.t_source USING btree (ck_d_source);
CREATE UNIQUE INDEX cin_i_source_2 ON ${user.table}.t_source USING btree (ck_id);
CREATE UNIQUE INDEX cin_i_source_3 ON ${user.table}.t_source USING btree (upper((ck_id)::text));
COMMENT ON TABLE ${user.table}.t_source IS 'Список источников данных';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_source.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_source.cct_parameter IS 'Настройки';
COMMENT ON COLUMN ${user.table}.t_source.cv_plugin IS 'Наименование плагина';
COMMENT ON COLUMN ${user.table}.t_source.ck_d_source IS 'Индетификатор типа источника данных';
COMMENT ON COLUMN ${user.table}.t_source.cl_enable IS 'Признак активности источника';
COMMENT ON COLUMN ${user.table}.t_source.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_source.ct_change IS 'Время модификации';

-- ${user.table}.t_queue definition

-- Drop table

-- DROP TABLE ${user.table}.t_queue;

CREATE TABLE ${user.table}.t_queue (
	ck_id uuid NOT NULL DEFAULT uuid_generate_v4(),
	ck_d_status varchar(30) NOT NULL,
	cct_parameter jsonb NULL,
	ck_d_format varchar(30) NOT NULL,
	ck_d_queue varchar(30) NOT NULL,
	ct_create timestamptz NOT NULL DEFAULT LOCALTIMESTAMP,
	ct_st timestamptz NULL,
	ct_en timestamptz NULL,
	ck_report uuid NOT NULL,
	ck_scheduler uuid NULL,
	ct_cleaning timestamptz NOT NULL DEFAULT 'infinity'::timestamp without time zone,
	cv_report_name varchar(50) NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	cn_priority int4 NOT NULL DEFAULT 100,
	CONSTRAINT cin_c_queue_1 CHECK ((jsonb_typeof(cct_parameter) = 'object'::text)),
	CONSTRAINT cin_p_queue PRIMARY KEY (ck_id),
	CONSTRAINT cin_r_queue_1 FOREIGN KEY (ck_d_format) REFERENCES ${user.table}.t_d_format(ck_id),
	CONSTRAINT cin_r_queue_2 FOREIGN KEY (ck_d_queue) REFERENCES ${user.table}.t_d_queue(ck_id),
	CONSTRAINT cin_r_queue_3 FOREIGN KEY (ck_d_status) REFERENCES ${user.table}.t_d_status(ck_id),
	CONSTRAINT cin_r_queue_4 FOREIGN KEY (ck_report) REFERENCES ${user.table}.t_report(ck_id),
	CONSTRAINT cin_r_queue_5 FOREIGN KEY (ck_scheduler) REFERENCES ${user.table}.t_scheduler(ck_id)
);
CREATE INDEX cin_i_queue_1 ON ${user.table}.t_queue USING btree (ck_d_status);
CREATE INDEX cin_i_queue_2 ON ${user.table}.t_queue USING btree (ck_d_format);
CREATE INDEX cin_i_queue_3 ON ${user.table}.t_queue USING btree (ck_report);
CREATE INDEX cin_i_queue_4 ON ${user.table}.t_queue USING btree (ck_scheduler);
CREATE UNIQUE INDEX cin_i_queue_5 ON ${user.table}.t_queue USING btree (ck_id);
COMMENT ON TABLE ${user.table}.t_queue IS 'Очередь отчетов';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_queue.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_queue.ck_d_status IS 'Индетификатор статуса';
COMMENT ON COLUMN ${user.table}.t_queue.cct_parameter IS 'Настройки отчета';
COMMENT ON COLUMN ${user.table}.t_queue.ck_d_format IS 'Индетификатор формата отчета';
COMMENT ON COLUMN ${user.table}.t_queue.ck_d_queue IS 'Индетификатор очереди';
COMMENT ON COLUMN ${user.table}.t_queue.ct_create IS 'Время создания';
COMMENT ON COLUMN ${user.table}.t_queue.ct_st IS 'Время начала формирования';
COMMENT ON COLUMN ${user.table}.t_queue.ct_en IS 'Время окончания формирования';
COMMENT ON COLUMN ${user.table}.t_queue.ck_report IS 'Индетификатор отчета';
COMMENT ON COLUMN ${user.table}.t_queue.ck_scheduler IS 'Индетификатор планировщика если по плану';
COMMENT ON COLUMN ${user.table}.t_queue.ct_cleaning IS 'Дата удаления отчета';
COMMENT ON COLUMN ${user.table}.t_queue.cv_report_name IS 'Наименования файла отчета';
COMMENT ON COLUMN ${user.table}.t_queue.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_queue.ct_change IS 'Время модификации';
COMMENT ON COLUMN ${user.table}.t_queue.cn_priority IS 'Приоритет';

-- ${user.table}.t_queue_log definition

-- Drop table

-- DROP TABLE ${user.table}.t_queue_log;

CREATE TABLE ${user.table}.t_queue_log (
	ck_id uuid NOT NULL DEFAULT uuid_generate_v4(),
	ck_queue uuid NOT NULL,
	cv_error text NULL,
	cv_error_stacktrace text NULL,
	ck_d_error varchar(30) NOT NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	CONSTRAINT cin_p_queue_log PRIMARY KEY (ck_id),
	CONSTRAINT cin_r_queue_log_1 FOREIGN KEY (ck_queue) REFERENCES ${user.table}.t_queue(ck_id),
	CONSTRAINT cin_r_queue_log_2 FOREIGN KEY (ck_d_error) REFERENCES ${user.table}.t_d_error(ck_id)
);
CREATE INDEX cin_i_queue_log_2 ON ${user.table}.t_queue_log USING btree (ck_d_error);
CREATE UNIQUE INDEX cin_i_queue_log_3 ON ${user.table}.t_queue_log USING btree (ck_id);
COMMENT ON TABLE ${user.table}.t_queue_log IS 'Список ошибок';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_queue_log.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_queue_log.ck_queue IS 'Индетификатор очереди';
COMMENT ON COLUMN ${user.table}.t_queue_log.cv_error IS 'Наименование ошибки';
COMMENT ON COLUMN ${user.table}.t_queue_log.cv_error_stacktrace IS 'Полное описание ошибки';
COMMENT ON COLUMN ${user.table}.t_queue_log.ck_d_error IS 'Индетификатор ошибки';
COMMENT ON COLUMN ${user.table}.t_queue_log.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_queue_log.ct_change IS 'Время модификации';

-- ${user.table}.t_queue_storage definition

-- Drop table

-- DROP TABLE ${user.table}.t_queue_storage;

CREATE TABLE ${user.table}.t_queue_storage (
	ck_id uuid NOT NULL,
	cv_content_type varchar(250) NOT NULL,
	cb_result bytea NOT NULL,
	cct_meta_data jsonb NOT NULL,
	CONSTRAINT cin_r_queue_storage_log_1 FOREIGN KEY (ck_id) REFERENCES ${user.table}.t_queue(ck_id)
);
COMMENT ON TABLE ${user.table}.t_queue_storage IS 'Список файлов';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_queue_storage.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_queue_storage.cv_content_type IS 'Mime type';
COMMENT ON COLUMN ${user.table}.t_queue_storage.cb_result IS 'File';
COMMENT ON COLUMN ${user.table}.t_queue_storage.cct_meta_data IS 'Дополнительные данные';

-- ${user.table}.t_report_query definition

-- Drop table

-- DROP TABLE ${user.table}.t_report_query;

CREATE TABLE ${user.table}.t_report_query (
	ck_id uuid NOT NULL DEFAULT uuid_generate_v4(),
	cv_name varchar(30) NOT NULL,
	cv_body text NULL,
	ck_source varchar(30) NOT NULL,
	ck_report uuid NOT NULL,
	cct_parameter jsonb NULL,
	cct_source_parameter jsonb NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
	CONSTRAINT cin_c_report_query_1 CHECK (((cv_name)::text = lower((cv_name)::text))),
	CONSTRAINT cin_c_report_query_2 CHECK ((jsonb_typeof(cct_parameter) = 'object'::text)),
	CONSTRAINT cin_c_report_query_3 CHECK ((jsonb_typeof(cct_source_parameter) = 'object'::text)),
	CONSTRAINT cin_p_report_query PRIMARY KEY (ck_id),
	CONSTRAINT cin_u_report_query UNIQUE (ck_report, cv_name),
	CONSTRAINT cin_r_report_query_1 FOREIGN KEY (ck_report) REFERENCES ${user.table}.t_report(ck_id),
	CONSTRAINT cin_r_report_query_2 FOREIGN KEY (ck_source) REFERENCES ${user.table}.t_source(ck_id)
);
CREATE UNIQUE INDEX cin_i_report_query_1 ON ${user.table}.t_report_query USING btree (ck_id);
CREATE UNIQUE INDEX cin_i_report_query_2 ON ${user.table}.t_report_query USING btree (ck_report, lower((cv_name)::text));
CREATE INDEX cin_i_report_query_3 ON ${user.table}.t_report_query USING btree (ck_source);
CREATE INDEX cin_i_report_query_4 ON ${user.table}.t_report_query USING btree (ck_report);
COMMENT ON TABLE ${user.table}.t_report_query IS 'Список вызовов данных';

-- Column comments

COMMENT ON COLUMN ${user.table}.t_report_query.ck_id IS 'Индетификатор';
COMMENT ON COLUMN ${user.table}.t_report_query.cv_name IS 'Наименование';
COMMENT ON COLUMN ${user.table}.t_report_query.cv_body IS 'Содеражание запроса например SQL ЗАПРОС';
COMMENT ON COLUMN ${user.table}.t_report_query.ck_source IS 'Индетификатор источника данных';
COMMENT ON COLUMN ${user.table}.t_report_query.ck_report IS 'Индетификатор отчета';
COMMENT ON COLUMN ${user.table}.t_report_query.cct_parameter IS 'Настройки запроса';
COMMENT ON COLUMN ${user.table}.t_report_query.cct_source_parameter IS 'Дополнительные настройки источника данных';
COMMENT ON COLUMN ${user.table}.t_report_query.ck_user IS 'Индетификатор пользователя изменившего/создавшего запись';
COMMENT ON COLUMN ${user.table}.t_report_query.ct_change IS 'Время модификации';
