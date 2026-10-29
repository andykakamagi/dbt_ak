select
    trip_id,
    pickup_ts,
    dropoff_ts,
    cast(pickup_ts as date)                          as pickup_date,
    pickup_zone_id,
    dropoff_zone_id,
    passenger_count,
    trip_distance,
    date_diff('minute', pickup_ts, dropoff_ts)       as trip_duration_minutes,
    case payment_type
        when 1 then 'credit_card'
        when 2 then 'cash'
        when 3 then 'no_charge'
        when 4 then 'dispute'
        when 6 then 'voided'
        else 'unknown'
    end                                              as payment_type_name,
    fare_amount,
    tip_amount,
    total_amount
from {{ ref('stg_trips') }}
