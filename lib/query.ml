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
          SELECT clients.id as @int{id}, @int{mov_limit}, value as @int{balance} FROM clients
          JOIN balances ON balances.client_id = %int{id}
          WHERE clients.id = %int{id}
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

  let transactions =
    let open Operation in
    [%rapper
      get_many
        {sql|
          SELECT @int{id}, @int{client_id}, @int{value}, type as @Operation.TransactionType{transaction_type}, @string{description}, @ptime{created_at} FROM transactions
          WHERE transactions.client_id = %int{client_id}
          ORDER BY created_at DESC
          LIMIT 10
        |sql}
        record_out]
  ;;

  let lock =
    [%rapper
      execute
        {sql|
          SELECT pg_advisory_xact_lock(%int{client_id})
        |sql}]
  ;;
end

let ( let* ) = Result.bind

(* TODO: Separar em duas funções *)
let execute_transaction ~client_id ~(op : Operation.transaction_op) conn =
  match op with
  | `Credit { value; description } ->
    let* () =
      Q.transaction ~client_id ~value ~description conn ~transaction_type:`Credit
    in
    Q.credit ~value ~client_id conn
  | `Debit { value; description } ->
    let* () =
      Q.transaction ~client_id ~value ~description conn ~transaction_type:`Debit
    in
    Q.debit ~value ~client_id conn
;;

let find_client id conn = Q.client ~id conn
let balance client_id conn = Q.balance ~client_id conn
let transactions client_id conn = Q.transactions ~client_id conn
let lock client_id conn = Q.lock ~client_id conn
