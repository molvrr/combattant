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

let routes =
  List.fold_left
    ~f:(fun acc (v, r) -> R.add_to_list v r acc)
    ~init:R.empty
    [ `GET, (s "clientes" / int / s "extrato" /? nil) @--> Handler.get_balance
    ; `POST, (s "clientes" / int / s "transacoes" /? nil) @--> Handler.create_transaction
    ]
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
