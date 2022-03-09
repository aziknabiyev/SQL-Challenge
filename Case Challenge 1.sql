

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');



select * from menu;
select * from sales;
select * from members;

/* 1 What is the total amount each customer spent at the restaurant? */
select sales.customer_id,sum(menu.price) as total from sales 
inner join menu on sales.product_id=menu.product_id GROUP BY customer_id;

/* 2 How many days has each customer visited the restaurant? */
select customer_id,count(distinct(order_date)) as total_days from sales group by customer_id;

/* 3 What was the first item from the menu purchased by each customer? */
select *, 
first_value(product_name) over (partition by customer_id order by customer_id) as prt 
from (
select sales.customer_id,menu.product_name,order_date,
min(order_date) over (partition by customer_id) as begin_date from sales 
inner join menu on sales.product_id=menu.product_id ) x where order_date=begin_date
order by customer_id;


/* 4 What is the most purchased item on the menu and how many times was it purchased by all customers? */
select menu.product_name,count(sales.product_id) as total from sales
inner join menu on menu.product_id=sales.product_id group by menu.product_name
order by total desc;

/* 5 Which item was the most popular for each customer? */
select * from (
select *,
max(total) over (partition by customer_id) as purchase
from (
select sales.customer_id,menu.product_name,
count(sales.product_id) as total 
from sales inner join menu
on sales.product_id=menu.product_id 
group by sales.customer_id,menu.product_name
 ) x   ) y where total=purchase order by customer_id;

 /* 6 Which item was purchased first by the customer after they became a member? */
 select * from (
 select *,
 first_value(product_name) over (partition by customer_id order by customer_id) as prt from (
 select sales.customer_id,menu.product_name,members.join_date,sales.order_date from sales 
 inner join menu on sales.product_id=menu.product_id
 inner join members on sales.customer_id=members.customer_id) x where order_date>=join_date) y
 where product_name=prt;

 /* 7 Which item was purchased just before the customer became a member? */
 select *,
 last_value(product_name) over (partition by customer_id order by customer_id) as prt
 from (
 select sales.customer_id,menu.product_name,sales.order_date,members.join_date from sales
 inner join menu on sales.product_id=menu.product_id 
 inner join members on sales.customer_id=members.customer_id ) x where order_date<join_date;

 /* 8 What is the total items and amount spent for each member before they became a member? */
 select customer_id,
 count(customer_id) as total_product,
 sum(price) as total_price from (
 select sales.customer_id,sales.order_date,members.join_date,menu.product_name,menu.price from sales 
 inner join menu on sales.product_id=menu.product_id
 inner join members on members.customer_id=sales.customer_id) x 
 where order_date<join_date group by customer_id;

 /* 9 If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have? */
 with case1 as (
 select *,
  rank() over (partition by customer_id,member order by product_name) as rnk from (
 select sales.customer_id,sales.order_date,menu.product_name,menu.price,members.join_date,
 case when members.join_date<=sales.order_date then 'Y' else 'N' end as member,
 case when menu.product_name='sushi' then 2 else 1 end as multiply
 from sales
 full outer join menu on sales.product_id=menu.product_id
 full outer join members on sales.customer_id=members.customer_id) x
 )
select customer_id,
sum(price*10*multiply) as total_points,
sum(price) as total_price from case1
group by customer_id;

/* 10 In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January? */
with case1 as (
 select *,
  rank() over (partition by customer_id,member order by product_name) as rnk from (
 select sales.customer_id,menu.product_name,menu.price,members.join_date,sales.order_date,
 case when members.join_date<=sales.order_date then 'Y' else 'N' end as member,
 case when menu.product_name!='sushi' and sales.order_date<DATEADD(week, 1, members.join_date)
 then 2 else 1 end as multiply from sales
 full outer join menu on sales.product_id=menu.product_id
 full outer join members on sales.customer_id=members.customer_id) x
 ) 
 select customer_id,
 sum(price*10*multiply) as total_points 
 from case1 where member='Y' and order_date<'2021-02-01' group by customer_id;
