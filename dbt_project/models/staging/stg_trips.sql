with src as (

    select
        cast(VendorID as integer)                as vendor_id,
        tpep_pickup_datetime                     as pickup_ts,
        tpep_dropoff_datetime                    as dropoff_ts,
        cast(passenger_count as integer)         as passenger_count,
        cast(trip_distance as double)            as trip_distance,
        cast(PULocationID as integer)            as pickup_zone_id,
        cast(DOLocationID as integer)            as dropoff_zone_id,
        cast(payment_type as integer)            as payment_type,
        cast(fare_amount as double)              as fare_amount,
        cast(tip_amount as double)               as tip_amount,
        cast(total_amount as double)             as total_amount,
        filename                                 as source_file
    from {{ source('raw', 'yellow_trips') }}

),

valid as (

    select *
    from src
    where pickup_ts is not null
      and dropoff_ts is not null
      and dropoff_ts > pickup_ts
      and trip_distance >= 0
      and total_amount >= 0
      and fare_amount >= 0

),

keyed as (

    select
        *,
        row_number() over (
            partition by vendor_id, pickup_ts, dropoff_ts, pickup_zone_id,
                         dropoff_zone_id, total_amount
            order by source_file
        ) as dup_seq
    from valid

)

select
    md5(concat_ws('|', vendor_id, pickup_ts, dropoff_ts, pickup_zone_id,
                  dropoff_zone_id, total_amount, dup_seq)) as trip_id,
    vendor_id,
    pickup_ts,
    dropoff_ts,
    passenger_count,
    trip_distance,
    pickup_zone_id,
    dropoff_zone_id,
    payment_type,
    fare_amount,
    tip_amount,
    total_amount,
    source_file
from keyed
