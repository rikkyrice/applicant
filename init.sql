--------------------------------------------------
-- STOCKS
--  在庫情報テーブル
--------------------------------------------------
create table Stocks (
    name varchar(8) not null,
    amount int not null,

    primary key (name)
);

--------------------------------------------------
-- SALES
--  売上情報テーブル
--------------------------------------------------
create table Sales (
    customer_id varchar(15) not null,
    price decimal not null,

    primary key (customer_id)
);