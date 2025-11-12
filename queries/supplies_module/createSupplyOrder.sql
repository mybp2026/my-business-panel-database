create or replace function create_supply_order(
    supplier_id uuid,
    warehouse_id uuid,
    expected_delivery_date date
) returns uuid language plpgsql
as $$
declare
    new_supply_order_id uuid;
begin
    insert into supplies_module.supply_order(
        supplier_id,
        warehouse_id,
        supply_order_date,
        expected_delivery_date,
        supply_order_status_id
    ) values (
        $1,
        $2,
        current_date,
        $3,
        1
    ) returning supply_order_id into new_supply_order_id;

    return new_supply_order_id;
end;
$$;