set serveroutput on;

create table APP_USERS(
    USER_ID number primary key,
    CLIENT_ID number unique not null,
    USERNAME varchar2(100) unique not null,
    PASSWORD_HASH varchar2(256) not null,
    CREATED_AT date default sysdate,
    UPDATED_AT date default sysdate,
    foreign key (CLIENT_ID) references CLIENTS(CLIENT_ID)
);

create table LOGIN_HISTORY (
    LOGIN_ID NUMBER PRIMARY KEY,
    USER_ID NUMBER,
    LOGIN_TIMESTAMP DATE DEFAULT SYSDATE,
    FOREIGN KEY (USER_ID) REFERENCES APP_USERS(USER_ID)
);

create table APP_INACTIVE_USERS(
    USER_ID number primary key,
    CLIENT_ID number,
    USERNAME VARCHAR2(100),
    LAST_LOGIN_DATE date
);

create sequence APP_USERS_SEQ start with 1 increment by 1 nocache;
create sequence LOGIN_HISTORY_SEQ start with 1 increment by 1 nocache;
create sequence CLIENTS_SEQ start with 1 increment by 1 nocache;

create or replace package app_user_management_pkg as
    procedure register_user(p_client_id number, p_username varchar2, p_password varchar2);
    function login_user(p_username varchar2, p_password varchar2) return number;
    function get_user_by_id(p_user_id number) return APP_USERS%rowtype;
    procedure archive_inactive_users;
end app_user_management_pkg;

create or replace package body app_user_management_pkg as

    procedure register_user(p_client_id number, p_username varchar2, p_password varchar2) as
        l_hashed_password varchar2(256);
        l_user_count number;
    begin
        select count(*) into l_user_count from CLIENTS where CLIENT_ID = p_client_id;
        if l_user_count = 0 then
            raise_application_error(-20001, 'Client not found!');
        end if;

        select count(*) into l_user_count from APP_USERS where USERNAME = p_username;
        if l_user_count > 0 then 
            raise_application_error(-20002, 'Username already taken');
        end if;

        l_hashed_password := dbms_crypto.hash(utl_raw.cast_to_raw(p_password), dbms_crypto.hash_sh256);

        insert into APP_USERS (USER_ID, CLIENT_ID, USERNAME, PASSWORD_HASH, CREATED_AT, UPDATED_AT)
        values (APP_USERS_SEQ.nextval, p_client_id, p_username, l_hashed_password, SYSDATE, SYSDATE);
        commit;
    exception
        when others then
            dbms_output.put_line('Error while registering user: ' || sqlerrm);
            rollback;
    end register_user;

    function login_user(p_username varchar2, p_password varchar2) return number as
        l_hashed_password varchar2(256);
        l_stored_password varchar2(256);
        l_user_id number;
    begin
        l_hashed_password := dbms_crypto.hash(utl_raw.cast_to_raw(p_password), dbms_crypto.hash_sh256);

        begin
            select USER_ID, PASSWORD_HASH into l_user_id, l_stored_password
            from APP_USERS where USERNAME = p_username;
        exception
            when NO_DATA_FOUND then
                return -1;
        end;

        if l_stored_password = l_hashed_password then
            insert into LOGIN_HISTORY (LOGIN_ID, USER_ID, LOGIN_TIMESTAMP)
            values (LOGIN_HISTORY_SEQ.nextval, l_user_id, SYSDATE);
            commit;
            return l_user_id;
        else
            return -2;
        end if;
    exception
        when others then
            dbms_output.put_line('Error while logging in: ' || sqlerrm);
            return -3;
    end login_user;

    function get_user_by_id(p_user_id number) return APP_USERS%ROWTYPE as
        l_user APP_USERS%ROWTYPE;
    begin
        select * into l_user from APP_USERS where USER_ID = p_user_id;
        return l_user;
    exception
        when NO_DATA_FOUND then
            raise_application_error(-20003, 'User not found');
    end get_user_by_id;

    procedure archive_inactive_users as
        cursor inactive_users_cursor is
            select 
                au.user_id, 
                au.client_id, 
                au.username, 
                max(lh.login_timestamp) as last_login_date
            from app_users au
            left join login_history lh
            on au.user_id = lh.user_id
            group by au.user_id, au.client_id, au.username
            having max(lh.login_timestamp) < sysdate - interval '3' month;
            
        l_user app_inactive_users%rowtype;
    begin
        for user_rec in inactive_users_cursor loop
            insert into app_inactive_users (USER_ID, CLIENT_ID, USERNAME, LAST_LOGIN_DATE)
            values (user_rec.user_id, user_rec.client_id, user_rec.username, user_rec.last_login_date);
        end loop;
        commit;
    exception
        when others then
            dbms_output.put_line('Error archiving inactive users: ' || sqlerrm);
            rollback;
    end archive_inactive_users;

end app_user_management_pkg;

-- register
begin
    app_user_management_pkg.register_user(1, 'maksim_djolos', 'veryverysecuritypassword007');
end;

-- login
declare
    l_user_id number;
begin
    l_user_id := app_user_management_pkg.login_user('maksim_djolos', 'veryverysecuritypassword007');
    dbms_output.put_line('Logged in user ID: ' || l_user_id);
end;

-- get info about user
declare
    l_user APP_USERS%ROWTYPE;
begin
    l_user := app_user_management_pkg.get_user_by_id(1);
    dbms_output.put_line('User: ' || l_user.USERNAME);
end;
--archive
begin
    app_user_management_pkg.archive_inactive_users;
end;


--job
begin
    dbms_scheduler.create_job (
        job_name        => 'archive_inactive_users_job',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN app_user_management_pkg.archive_inactive_users; END;',
        start_date      => systimestamp,
        repeat_interval => 'FREQ=DAILY; BYHOUR=0; BYMINUTE=0; BYSECOND=0',
        enabled         => true
    );
end;

insert into LOGIN_HISTORY (LOGIN_ID, USER_ID, LOGIN_TIMESTAMP)
values (LOGIN_HISTORY_SEQ.nextval, 1, sysdate - interval '3' month);
commit;

begin
    dbms_scheduler.run_job('archive_inactive_users_job');
end;

select * from APP_INACTIVE_USERS;

--3
create or replace package app_user_management_pkg as
    procedure register_user(p_client_id number, p_username varchar2, p_password varchar2);
    procedure update_user(p_user_id number, p_username varchar2, p_password varchar2);
    procedure delete_user(p_user_id number);
    function get_user_by_id(p_user_id number) return app_users%rowtype;
    procedure archive_inactive_users;
end app_user_management_pkg;

create or replace package body APP_USER_MANAGEMENT_PKG as

    procedure REGISTER_USER(P_CLIENT_ID number, P_USERNAME varchar2, P_PASSWORD varchar2) as
        L_HASHED_PASSWORD varchar2(256);
        L_USER_COUNT number;
    begin

        select count(*) into L_USER_COUNT from CLIENTS where CLIENT_ID = P_CLIENT_ID;
        if L_USER_COUNT = 0 then
            RAISE_APPLICATION_ERROR(-20001, 'Client not found!');
        end if;


        select count(*) into L_USER_COUNT from APP_USERS where USERNAME = P_USERNAME;
        if L_USER_COUNT > 0 then
            RAISE_APPLICATION_ERROR(-20002, 'Username already taken');
        end if;


        L_HASHED_PASSWORD := DBMS_CRYPTO.hash(UTL_RAW.CAST_TO_RAW(P_PASSWORD), DBMS_CRYPTO.HASH_SH256);


        insert into APP_USERS (USER_ID, CLIENT_ID, USERNAME, PASSWORD_HASH, CREATED_AT, UPDATED_AT)
        values (APP_USERS_SEQ.nextval, P_CLIENT_ID, P_USERNAME, L_HASHED_PASSWORD, SYSDATE, SYSDATE);
        commit;
    exception
        when others then
            DBMS_OUTPUT.PUT_LINE('Error while registering user: ' || SQLERRM);
            rollback;
    end REGISTER_USER;

    procedure UPDATE_USER(P_USER_ID number, P_USERNAME varchar2, P_PASSWORD varchar2) as
    L_HASHED_PASSWORD varchar2(256);
begin
    L_HASHED_PASSWORD := DBMS_CRYPTO.hash(UTL_RAW.CAST_TO_RAW(P_PASSWORD), DBMS_CRYPTO.HASH_SH256);

    update APP_USERS
    set USERNAME = P_USERNAME,
        PASSWORD_HASH = L_HASHED_PASSWORD,
        UPDATED_AT = SYSDATE,
        LAST_PASSWORD_CHANGE = SYSDATE
    where USER_ID = P_USER_ID;

    if sql%ROWCOUNT = 0 then
        RAISE_APPLICATION_ERROR(-20003, 'Пользователь не найден!');
    end if;

    commit;
exception
    when others then
        DBMS_OUTPUT.PUT_LINE('Error while updating user: ' || SQLERRM);
        rollback;
end UPDATE_USER;

    procedure DELETE_USER(P_USER_ID number) as
    begin
        delete from APP_USERS where USER_ID = P_USER_ID;
        
        if sql%ROWCOUNT = 0 then
            RAISE_APPLICATION_ERROR(-20004, 'User not found!');
        end if;

        commit;
    exception
        when others then
            DBMS_OUTPUT.PUT_LINE('Error while deleting user: ' || SQLERRM);
            rollback;
    end DELETE_USER;

    function GET_USER_BY_ID(P_USER_ID number) return APP_USERS%ROWTYPE as
        L_USER APP_USERS%ROWTYPE;
    begin
        select * into L_USER from APP_USERS where USER_ID = P_USER_ID;

        return L_USER;
    exception
        when NO_DATA_FOUND then
            RAISE_APPLICATION_ERROR(-20005, 'User not found');
    end GET_USER_BY_ID;

    procedure ARCHIVE_INACTIVE_USERS as
        cursor INACTIVE_USERS_CURSOR is
            select 
                AU.USER_ID, 
                AU.CLIENT_ID, 
                AU.USERNAME, 
                max(LH.LOGIN_TIMESTAMP) as LAST_LOGIN_DATE
            from APP_USERS AU
            left join LOGIN_HISTORY LH on AU.USER_ID = LH.USER_ID
            group by AU.USER_ID, AU.CLIENT_ID, AU.USERNAME
            having max(LH.LOGIN_TIMESTAMP) < SYSDATE - interval '3' month;
            
        L_USER APP_INACTIVE_USERS%ROWTYPE;
    begin
        for USER_REC in INACTIVE_USERS_CURSOR loop
            insert into APP_INACTIVE_USERS (USER_ID, CLIENT_ID, USERNAME, LAST_LOGIN_DATE)
            values (USER_REC.USER_ID, USER_REC.CLIENT_ID, USER_REC.USERNAME, USER_REC.LAST_LOGIN_DATE);
        end loop;
        commit;
    exception
        when others then
            DBMS_OUTPUT.PUT_LINE('Error archiving inactive users: ' || SQLERRM);
            rollback;
    end ARCHIVE_INACTIVE_USERS;

end APP_USER_MANAGEMENT_PKG;

--CRUD:

-- create
begin
    app_user_management_pkg.register_user(1, 'maksim_djolos', 'verysecurepassword1');
end;

-- update
begin
    app_user_management_pkg.update_user(1, 'maksim_djolos_updated', 'newsecurepassword456');
end;

-- delete
begin
    app_user_management_pkg.delete_user(1);
end;

-- get info about user by id
declare
    l_user app_users%rowtype;
begin
    l_user := app_user_management_pkg.get_user_by_id(1);
    dbms_output.put_line('User: ' || l_user.username);
end;

--4
alter table APP_USERS add (LAST_PASSWORD_CHANGE date);

create table PASSWORD_NOTIFICATION (
    NOTIFY_ID number primary key,
    USER_ID number,
    USERNAME varchar2(100),
    NOTIFY_DATE date default SYSDATE,
    foreign key (USER_ID) references APP_USERS(USER_ID)
);

create or replace package APP_PASSWORD_MANAGEMENT_PKG as
    procedure CHECK_PASSWORD_UPDATES;
end APP_PASSWORD_MANAGEMENT_PKG;

create or replace package body app_password_management_pkg as

   procedure check_password_updates as
    cursor users_cursor is
        select user_id, username, last_password_change
        from app_users
        where last_password_change is null 
        or last_password_change < sysdate - interval '3' month;

    l_user_id app_users.user_id%type;
    l_username app_users.username%type;
begin
    for user_rec in users_cursor loop
        l_user_id := user_rec.user_id;
        l_username := user_rec.username;

        insert into password_notification (user_id, username, notify_date)
        values (l_user_id, l_username, sysdate);
    end loop;

    commit;
exception
    when others then
        dbms_output.put_line('Error during password check: ' || sqlerrm);
        rollback;
end check_password_updates;

end app_password_management_pkg;

--job
begin
    dbms_scheduler.create_job(
        job_name        => 'CHECK_PASSWORD_UPDATES_JOB',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN app_password_management_pkg.check_password_updates; END;',
        start_date      => sysdate,
        repeat_interval => 'FREQ=DAILY; BYHOUR=0; BYMINUTE=0; BYSECOND=0',
        enabled         => true
    );
end;

begin
    app_user_management_pkg.update_user(1, 'maksim_djolos', 'newsecurepassword29');
end;

select user_id, username, last_password_change from app_users where user_id = 1;

select * from APP_USERS;

begin
    APP_PASSWORD_MANAGEMENT_PKG.CHECK_PASSWORD_UPDATES;
end;

select * from PASSWORD_NOTIFICATION;

--5
create or replace procedure UPDATE_CLIENT_STATUS as
    cursor CLIENTS_CURSOR is
        select CLIENT_ID, sum(BALANCE) as TOTAL_BALANCE
        from ACCOUNTS
        group by CLIENT_ID;

    L_CLIENT_ID CLIENTS.CLIENT_ID%type;
    L_TOTAL_BALANCE number;
begin
    for CLIENT_REC in CLIENTS_CURSOR loop
        L_CLIENT_ID := CLIENT_REC.CLIENT_ID;
        L_TOTAL_BALANCE := CLIENT_REC.TOTAL_BALANCE;

        if L_TOTAL_BALANCE > 100000 then
            update CLIENTS
            set STATUS = 'VIP client'
            where CLIENT_ID = L_CLIENT_ID;
        else
            update CLIENTS
            set STATUS = 'Client'
            where CLIENT_ID = L_CLIENT_ID;
        end if;
    end loop;

    commit;
exception
    when others then
        DBMS_OUTPUT.PUT_LINE('Error during client status update: ' || SQLERRM);
        rollback;
end UPDATE_CLIENT_STATUS;

--job
begin
    dbms_scheduler.create_job(
        job_name        => 'update_client_status_job',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN update_client_status; END;',
        start_date      => sysdate,
        repeat_interval => 'FREQ=DAILY; BYHOUR=0; BYMINUTE=0; BYSECOND=0',
        enabled         => true
    );
end;

begin
    DBMS_SCHEDULER.RUN_JOB('update_client_status_job');
end;

select CLIENT_ID, STATUS from CLIENTS;