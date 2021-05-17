--liquibase formatted sql
--changeset artemov_i:grants dbms:postgresql runAlways:true runOnChange:true splitStatements:false stripComments:false
--гранты на использование

GRANT USAGE ON SCHEMA public TO ${user.update};

--гранты на выполнение
GRANT ALL ON SEQUENCE public.seq_log TO ${user.update};

GRANT SELECT ON TABLE public.dual TO ${user.connect};

SELECT pkg_patcher.p_change_role_connect_user('${user.connect}', '${user.table}');

SELECT pkg_patcher.p_change_role_update_user('${user.update}', '${user.table}');

GRANT SELECT, UPDATE ON TABLE ${user.table}.t_notification TO ${user.connect};
