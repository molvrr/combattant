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

module Handler = struct
  let transaction client_id (db_pool : Query.pool) (request : Request.t) =
    let client_opt =
      Option.join @@ Result.to_option @@ Query.find_client client_id db_pool
    in
    match client_opt with
    | Some client ->
      let insert_result =
        let body = Result.to_option @@ Body.to_string request.body in
        let json = Option.map Yojson.Safe.from_string body in
        let decoded_op = Option.bind json (Utils.Decoder.decode Operation.decoder) in
        match decoded_op with
        | Some op ->
          (match Query.execute_operation ~client_id ~op db_pool with
           | Ok _ as ok -> ok
           | Error e -> Error (`DB e))
        | None -> Error (`Decoder "Invalid operation")
      in
      (match insert_result with
       | Ok () ->
         let json : Yojson.Safe.t =
           `Assoc [ "limite", `Int 100000; "saldo", `Int (-9098) ]
         in
         Response.of_string ~body:(Yojson.Safe.to_string json) `OK
       | Error _ -> Response.create (`Code 422))
    | None -> Response.create `Not_found
  ;;

  let balance client_id (db_pool : Query.pool) (request : Request.t) =
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
  ;;
end

let routes =
  List.fold_left
    ~f:(fun acc (v, r) -> R.add_to_list v r acc)
    ~init:R.empty
    [ `GET, (s "clientes" / int / s "extrato" /? nil) @--> Handler.balance
    ; `POST, (s "clientes" / int / s "transacoes" /? nil) @--> Handler.transaction
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
