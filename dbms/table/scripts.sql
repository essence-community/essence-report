--liquibase formatted sql
--changeset artemov_i:init_schema_trigger_essence_report dbms:postgresql splitStatements:false stripComments:false
CREATE TRIGGER notify_notification_event
AFTER INSERT ON ${user.table}.t_notification
  FOR EACH ROW EXECUTE PROCEDURE notify_event();

CREATE TRIGGER notify_queue_event
AFTER INSERT ON ${user.table}.t_queue
  FOR EACH ROW EXECUTE PROCEDURE notify_event();

--changeset artemov_i:CORE-1454 dbms:postgresql splitStatements:false stripComments:false
ALTER TABLE ${user.table}.t_asset ADD cl_archive smallint NOT NULL DEFAULT 0::smallint;
COMMENT ON COLUMN ${user.table}.t_asset.cl_archive IS 'Признак того что cb_asset zip архив';

--changeset artemov_i:CORE-1466 dbms:postgresql splitStatements:false stripComments:false
ALTER TABLE ${user.table}.t_report_query ADD ck_parent uuid NULL;
COMMENT ON COLUMN ${user.table}.t_report_query.ck_parent IS 'Родительский запрос';
ALTER TABLE ${user.table}.t_report_query ADD CONSTRAINT cin_r_report_query_3 FOREIGN KEY (ck_parent) REFERENCES ${user.table}.t_report_query(ck_id);
ALTER TABLE ${user.table}.t_report_query ADD CONSTRAINT cin_c_report_query_4 CHECK (ck_id <> ck_parent);
ALTER TABLE ${user.table}.t_d_queue ADD CONSTRAINT cin_c_d_queue_2 CHECK (ck_id <> ck_parent);

	