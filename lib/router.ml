[@@@warning "-26-27-32"]

open StdLabels
open Routes
open Piaf

module R = Map.Make (struct
    type t = Method.t

    let compare a b =
      let a_str = Method.to_string a in
      let b_str = Method.to_string b in
      String.compare a_str b_str
    ;;
  end)

let transactions_route =
  let handler client_id (request : Request.t) =
    let json : Yojson.Safe.t = `Assoc [ "limite", `Int 100000; "saldo", `Int (-9098) ] in
    Response.of_string ~body:(Yojson.Safe.to_string json) `OK
  in
  (s "clientes" / int / s "transacoes" /? nil) @--> handler
;;

let balance_route =
  let handler client_id (request : Request.t) =
    let json : Yojson.Safe.t =
      let balance =
        let total = `Int (-9098) in
        let date = `String "2024-01-17T02:34:41.217753Z" in
        let limit = `Int 100000 in
        `Assoc [ "total", total; "data_extrato", date; "limite", limit ]
      in
      let last_transactions = `List [] in
      `Assoc [ "saldo", balance; "ultimas_transacoes", last_transactions ]
    in
    Response.of_string ~body:(Yojson.Safe.to_string json) `OK
  in
  (s "clientes" / int / s "extrato" /? nil) @--> handler
;;

let routes =
  List.fold_left
    ~f:(fun acc (v, r) -> R.add_to_list v r acc)
    [ `GET, balance_route; `POST, transactions_route; `POST, balance_route ]
    ~init:R.empty
;;

let router = R.map one_of routes

let match_route verb path =
  match R.find_opt verb router with
  | Some router ->
    (match match' router ~target:path with
     | FullMatch r -> Some r
     | MatchWithTrailingSlash r -> Some r
     | NoMatch -> None)
  | None -> None
;;
