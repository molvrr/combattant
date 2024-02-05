type pool = ((module Rapper_helper.CONNECTION), Caqti_error.t) Caqti_eio.Pool.t

module Q = struct
  let transaction =
    [%rapper
      execute
        {sql|
        INSERT INTO transactions (client_id, value, type, description)
        VALUES (%int{client_id}, %int{value}, %Operation.TransactionType{transaction_type}, %string{description})
      |sql}]
  ;;

  let debit =
    [%rapper
      execute
        {sql|
        UPDATE balances SET value = value - %int{value} WHERE client_id = %int{client_id}
      |sql}]
  ;;

  let credit =
    [%rapper
      execute
        {sql|
          UPDATE balances SET value = value + %int{value} WHERE client_id = %int{client_id}
        |sql}]
  ;;

  let client =
    let open Client in
    [%rapper
      get_opt
        {sql|
          SELECT @int{id}, @int{mov_limit} FROM clients WHERE id = %int{id}
        |sql}
        record_out]
  ;;

  let balance =
    [%rapper
      get_opt
        {sql|
          SELECT @int{value}, @ptime{now()} as time FROM balances WHERE client_id = %int{client_id}
        |sql}]
  ;;
end

let ( let* ) = Result.bind

let execute_operation ~client_id ~(op : Operation.t) conn =
  match op with
  | Transaction { value; description; transaction_type } ->
    let* () = Q.transaction ~client_id ~value ~description conn ~transaction_type in
    (match transaction_type with
     | Credit -> Q.credit ~value ~client_id conn
     | Debit -> Q.debit ~value ~client_id conn)
  | _ -> failwith "TODO"
;;

let find_client id conn = Q.client ~id conn
let balance client_id conn = Q.balance ~client_id conn
