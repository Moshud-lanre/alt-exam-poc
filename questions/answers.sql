-- Creation of a temporary table to hold checkedout events for easy re-usability
create temporary table if not exists cart_table(
	event_id bigint,
	customer_id uuid,
	event_data jsonb);

--Question 2a1
--The query seeks to fetch  the most ordered item based on the number of times it appears in an order cart that checked out successfully


with cart_events as (
    -- Select all add & remove from cart events of the customer associated with a successful checkout
    select 
    	*
    from 
    	alt_school.events e1 
    where 
        e1.customer_id in (
            select e2.customer_id 
            from alt_school.events e2
            where e2.event_data @> '{"status": "success"}' 
        )
        and not e1.event_data @> '{"event_type":"visit"}'
        and not e1.event_data @> '{"event_type":"checkout"}'
),
cart_info as (
    -- Groups the events associated to each customer using the item_id,customer_id and the timestamp 
    select 
    	*,
        row_number() 
        over 
           (partition by customer_id, (event_data ->> 'item_id')::int order by event_timestamp) as row_num
    from 
    	cart_events
),

removed_items as (
    -- Extract items removed from the cart
    select 
    	distinct customer_id,
        (event_data ->> 'item_id')::int as item_id
    from 
    	cart_info
    where 
    	row_num = 2   
),
checkedout_cart as (
    -- Extract item that successfuly checked out
    select 
    	event_id,
    	ce.customer_id,
    	event_data
    from 
    	cart_events ce
    left join 
    	removed_items ri 
    on 
    	ce.customer_id = ri.customer_id and (ce.event_data ->> 'item_id')::int = ri.item_id
    where 
    	ri.customer_id is null -- This filter out items removed from cart
)

-- Populate the cart table(temporary table)
insert into cart_table
select 
	event_id,
	customer_id,
	event_data
from 
	checkedout_cart;
-- The query returns the most ordered item
select
    p.id as product_id, 
    p.name as product_name,
    count(*) as num_times_in_successful_orders
from 
    cart_table ct
join 
    alt_school.products p 
on 
	p.id = (ct.event_data ->> 'item_id')::int
group by p.id, p."name" 
order by count(*) desc
limit 1;


--Question 2a2
-- The query seeks to find the top 5 spenders without considering currency, and without using the line_item table.
  

with price_calculation as (
	SELECT 
		customer_id, 
		(event_data ->> 'item_id')::int item_id, 
		(event_data ->> 'quantity')::int quantity,
		(price * (event_data ->> 'quantity')::int) amount
	FROM 
		cart_table ct
	JOIN 
		alt_school.products p 
	ON 
		(ct.event_data ->> 'item_id')::int = p.id
	
	)
	-- Top 5 spenders
	SELECT 
		pc.customer_id,
		location,
		sum(amount) total_spend
	FROM 
		price_calculation pc
	JOIN 
		alt_school.customers c 
	ON 
		pc.customer_id = c.customer_id
	GROUP BY 
		pc.customer_id,
		location
	ORDER BY total_spend DESC 
	LIMIT 5;
	
	
	
--Question 2b1
--  Seeks to determine the most common location (country) where successful checkouts occurred, using the events table.
--Most common location
select 
	location,
	count(*) checkout_count
from 
	alt_school.events e 
join
	alt_school.customers c 
on 
	e.customer_id = c.customer_id 
where 
	e.event_data @> '{"status": "success"}'
group by "location" 
order by count(*) desc
limit 1; 



--Question 2b2
-- Seeks to identify customers that abadoned their cart

select 
	customer_id, 
	count(*) as num_events
from 
	alt_school.events 
-- Filter for only customers who never proceeded to checkout(abandoned cart)
where 
	customer_id not in (
    	select customer_id
    	from alt_school.events 
    	where  
    		 event_data @> '{"event_type" : "checkout"}'
    		 and  event_data @> '{"event_type" : "visit"}'
    	)
group by customer_id
order by num_events desc;


--Question 2bc
-- Seeks to find the averge visit per customer that successfully checked out

with visits_count as (
    
    select 
    	customer_id,
    	count(*)num_visit 
    from 
    	alt_school.events 
    where 
    	event_data @> '{"event_type":"visit"}'
    	and 
	        customer_id in (
	            select e.customer_id 
	            from alt_school.events e
	            where e.event_data @> '{"status": "success"}' 
	        )
	        
    group by 
    	customer_id 
        
)

--Average visit per customer
select 
	round(avg(num_visit),2) average_visits 
from 
	visits_count;