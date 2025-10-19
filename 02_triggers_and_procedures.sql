set serveroutput on;
--1
alter table CLIENTS
add STATUS varchar2(100) default('Client') not null;

select * from clients;

create table TEMP_CLIENTS (
    CLIENT_ID number primary key
);

create or replace trigger save_client_id_trg
before insert or update on ACCOUNTS
for each row
begin
    begin
        insert into TEMP_CLIENTS (CLIENT_ID) values (:NEW.CLIENT_ID);
    exception
        when DUP_VAL_ON_INDEX then
        null;
    end;
end;

create or replace trigger update_client_status_trg
after insert or update on ACCOUNTS
begin
    for rec in (select CLIENT_ID from TEMP_CLIENTS) loop
        declare
            total_balance number;
        begin
            select SUM(BALANCE) into total_balance
            from ACCOUNTS
            where CLIENT_ID = rec.CLIENT_ID;

            if total_balance > 100000 then
                update CLIENTS
                set STATUS = 'VIP client'
                where CLIENT_ID = rec.CLIENT_ID;
            else
                update CLIENTS
                set STATUS = 'Client'
                where CLIENT_ID = rec.CLIENT_ID;
            end if;
        end;
    end loop;

    delete from TEMP_CLIENTS;
end;

select * from ACCOUNTS;

update ACCOUNTS
set BALANCE = 250000
where CLIENT_ID = 23;

select * from clients;

--2
create or replace trigger employee_department_move_trg
after update of DEPARTMENT_ID
on EMPLOYEES
for each row
begin
    if :OLD.DEPARTMENT_ID != :NEW.DEPARTMENT_ID then
    insert into EMPLOYEE_MOVES (EMPLOYEE_ID, OLD_DEPARTMENT_ID, NEW_DEPARTMENT_ID, MOVE_DATE)
    values (:OLD.EMPLOYEE_ID, :OLD.DEPARTMENT_ID, :NEW.DEPARTMENT_ID, SYSDATE);
    end if;
end;

update EMPLOYEES
set DEPARTMENT_ID = 2
where EMPLOYEE_ID = 9;

select * from EMPLOYEES;
select * from EMPLOYEE_MOVES;

--3
create or replace procedure add_account(
    p_client_id in NUMBER,
    p_account_number VARCHAR2,
    p_balance in number,
    p_currency in VARCHAR2
) as
    l_client_name VARCHAR2(200);
begin
    begin
        select first_name || ' ' || last_name || ' сметка ' || p_currency
        into l_client_name
        from clients
        where client_id = p_client_id;
    exception
        when no_data_found then
            dbms_output.put_line('Error: invalid client!');
            return;
        when others then
            dbms_output.put_line('Error while fetching client name: ' || SQLERRM);
            return;
    end;
    begin
        insert into accounts (client_id, account_number, balance, currency, account_name)
        values (p_client_id, p_account_number, p_balance, p_currency, l_client_name);
        commit;
    exception
        when others then
            dbms_output.put_line('Error while adding account: ' || SQLERRM);
    end;
end;

exec add_account (26, 'BG1234567889', 1000, 'USD');

select * from accounts;

create or replace procedure get_account_details(
    p_account_id in number,
    p_account_details out VARCHAR2
) as
begin
    begin
        select account_name || ' - ' || balance || ' ' || currency
        into p_account_details
        from accounts
        where account_id = p_account_id;
    exception
        when others then
            dbms_output.put_line('Error while retrieving account details: ' || SQLERRM);
    end;
end;

declare
    l_account_details VARCHAR2(200);
begin
    get_account_details(20, l_account_details);
    dbms_output.put_line('Account details: ' || l_account_details);
end;

create or replace procedure update_account(
    p_account_id in number,
    p_new_balance in number,
    p_new_currency in varchar2
) as
    l_client_name varchar2(200);
begin   
    begin
        select first_name || ' ' || last_name
        into l_client_name
        from clients c
        join accounts a on c.client_id = a.client_id
        where a.account_id = p_account_id;
        
        update accounts
        set balance = p_new_balance,
            currency = p_new_currency,
            account_name = l_client_name || ' сметка ' || p_new_currency
        where account_id = p_account_id;
        commit;
    exception
        when no_data_found then
            dbms_output.put_line('Error: Account not found!');
        when others then
            dbms_output.put_line('Error while updating account info: ' || SQLERRM);
    end;
end;

exec update_account(1, 1200, 'EUR');
select * from accounts;

create or replace procedure delete_account(
    p_account_id in NUMBER
) as
begin
    begin
        delete from accounts where account_id = p_account_id;
        commit;
    exception
        when others then
            dbms_output.put_line('Error while deleting account: ' || SQLERRM);
    end;
end;

exec delete_account(22);
select * from accounts;

--4
create or replace procedure add_new_client(
    p_first_name in varchar2,
    p_middle_name in varchar2,
    p_last_name in varchar2,
    p_address in varchar2,
    p_phone in varchar2,
    p_email in varchar2
) as
begin
    begin
        insert into clients(first_name, middle_name, last_name, address, phone, email)
        values (p_first_name, p_middle_name, p_last_name, p_address, p_phone, p_email);
        commit;
    exception
        when others then
            dbms_output.put_line('Error while adding client: ' || SQLERRM);
    end;
end;

exec add_new_client('Роман', 'Виталиевич', 'Пеев', 'Бул. Никола Вапцаров 99, Пловдив','88005553535','romanpeev6@gmail.com');
select * from clients;

create or replace procedure update_client(
    p_client_id in number,
    p_new_first_name in varchar2,
    p_new_middle_name in varchar2,
    p_new_last_name in varchar2,
    p_new_address in varchar2,
    p_new_phone in varchar2,
    p_new_email in varchar2
) as
begin
    begin
        update clients 
        set first_name = p_new_first_name,
            middle_name = p_new_middle_name,
            last_name = p_new_last_name,
            address = p_new_address,
            phone = p_new_phone,
            email = p_new_email
        where client_id = p_client_id;
        commit;
    exception
        when no_data_found then
            dbms_output.put_line('Error: client not found!');
        when others then
            dbms_output.put_line('Error while updating client: ' || SQLERRM);
    end;
end;

exec update_client(41, 'Roman', 'Vitaliyevich', 'Peev', 'Bul Nikola Vaptsarov 99, Plovdiv', '0879874537', 'romanpeev1@gmail.com');
select * from clients;

create or replace procedure get_client_details(
    p_client_id in number,
    p_client_details out varchar2
) as 
begin
    begin
        select first_name || ' ' || middle_name || ' ' || last_name || ', ' || address || ', ' || phone || ', ' || email || '.'
        into p_client_details
        from clients
        where client_id = p_client_id;
    exception
        when others then
            dbms_output.put_line('Error while retrieving account details: ' || SQLERRM);
    end;
end;

declare
    l_client_details VARCHAR2(600);
begin
    get_client_details(24, l_client_details);
    dbms_output.put_line('Client info: ' || l_client_details);
end;

create or replace procedure delete_client(
    p_client_id in NUMBER
) as
begin
    begin
        delete from clients where client_id = p_client_id;
        commit;
    exception
        when others then
            dbms_output.put_line('Error while deleting client: ' || SQLERRM);
    end;
end;

exec delete_client(41);
select * from clients;

--5
create or replace procedure money_transfer(
    p_from_account_id in number,
    p_to_account_id in number,
    p_amount in number
) as 
    l_from_balance number;
    l_to_balance number;
    l_currency_from varchar2(20);
    l_currency_to varchar2(20);
begin
    begin
        select balance, currency into l_from_balance, l_currency_from
        from accounts
        where account_id = p_from_account_id;
        
        select balance, currency into l_to_balance, l_currency_to
        from accounts
        where account_id = p_to_account_id;
    exception
        when no_data_found then
            dbms_output.put_line('Error: one or both accounts not found!');
            return;
        when others then
            dbms_output.put_line('Error while fetching account details: ' || SQLERRM);
            return;
    end;
    
    if l_currency_from != l_currency_to then
        dbms_output.put_line('Error: currency mistach between accounts.');
        return;
    end if;
    
    if l_from_balance < p_amount then
        dbms_output.put_line('Error: Insufficient funds.');
        return;
    end if;
    
    begin
        update accounts
        set balance = balance - p_amount
        where account_id = p_from_account_id;
        
        update accounts 
        set balance= balance + p_amount
        where account_id = p_to_account_id;
        
        commit;
        dbms_output.put_line('Transfer successful: ' || p_amount || ' ' || l_currency_from);
    exception
        when others then
            rollback;
            dbms_output.put_line('Error while processing transfer: ' || SQLERRM);
    end;
end;

select * from accounts;
exec money_transfer(21, 20, 500);

--6
create table exchange_rates(
    from_currency varchar2(10),
    to_currency varchar2(10),
    rate number,
    primary key (from_currency, to_currency)
);

--chatgpt :), but without John Doe meme(((( :
INSERT INTO exchange_rates VALUES ('BGN', 'USD', 0.55);
INSERT INTO exchange_rates VALUES ('USD', 'BGN', 1.82);
INSERT INTO exchange_rates VALUES ('BGN', 'EUR', 0.51);
INSERT INTO exchange_rates VALUES ('EUR', 'BGN', 1.95);
INSERT INTO exchange_rates VALUES ('USD', 'EUR', 0.93);
INSERT INTO exchange_rates VALUES ('EUR', 'USD', 1.08);
COMMIT;
--end of chat gpt(((

create or replace procedure transfer_money_conversion(
    p_from_account_id in number,
    p_to_account_id in number,
    p_amount in NUMBER
) as
    l_from_balance number;
    l_to_balance number;
    l_currency_from varchar2(10);
    l_currency_to varchar2(10);
    l_conversion_rate number := 1;
    l_converted_amount number;
begin
    begin
        select balance, currency into l_from_balance, l_currency_from
        from accounts
        where account_id = p_from_account_id;
        
        select balance, currency into l_to_balance, l_currency_to
        from accounts
        where account_id = p_to_account_id;
    exception
        when no_data_found then
            dbms_output.put_line('Error: one or both accounts not found.');
            return;
        when others then
            dbms_output.put_line('Error while fetching account details: ' || SQLERRM);
            return;
    end;
    
    if l_currency_from != l_currency_to then
        begin
            select rate into l_conversion_rate
            from exchange_rates
            where from_currency = l_currency_from and to_currency = l_currency_to;
        exception
            when no_data_found then
                dbms_output.put_line('Error: no exchange rate available.');
                return;
            when others then
                dbms_output.put_line('Error while fetching exchange rate: ' || SQLERRM);
                return;
        end;
        
        l_converted_amount := p_amount * l_conversion_rate;
    else
        l_converted_amount := p_amount;
    end if;
    
    if l_from_balance < p_amount then
        dbms_output.put_line('Error: insufficient funds.');
        return;
    end if;
    
    begin
        update accounts
        set balance = balance - p_amount
        where account_id = p_from_account_id;
        
        update accounts 
        set balance = balance + l_converted_amount
        where account_id = p_to_account_id;
        
        commit;
        dbms_output.put_line('Transfer successful: ' || p_amount || ' ' || l_currency_from || 
                             ' converted to ' || l_converted_amount || ' ' || l_currency_to);
    EXCEPTION
        when others then
            rollback;
            dbms_output.put_line('Error while processing transfer: ' || SQLERRM);
    end;
end;

select * from accounts;
exec transfer_money_conversion(14, 42, 100000);
select * from clients;