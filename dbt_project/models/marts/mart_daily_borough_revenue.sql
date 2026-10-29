select
    f.pickup_date,
    coalesce(z.borough, 'Unknown')                         as pickup_borough,
    count(*)                                               as trips,
    round(sum(f.total_amount), 2)                          as total_revenue,
    round(avg(f.fare_amount), 2)                           as avg_fare,
    round(avg(f.trip_duration_minutes), 1)                 as avg_duration_minutes,
    round(sum(f.tip_amount)
          / nullif(sum(case when f.payment_type_name = 'credit_card'
                            then f.fare_amount end), 0), 4) as tip_rate_credit_card
from {{ ref('fct_trips') }} f
left join {{ ref('dim_zone') }} z
    on f.pickup_zone_id = z.zone_id
group by 1, 2
