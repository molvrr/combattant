module Decoder : sig
  type 'a decoder

  val decode : 'a decoder -> Yojson.Safe.t -> 'a option
  val return : 'a -> 'a decoder
  val fail : 'a decoder
  val bind : 'a decoder -> ('a -> 'b decoder) -> 'b decoder
  val map : ('a -> 'b) -> 'a decoder -> 'b decoder
  val string : string decoder
  val literal : string -> string decoder
  val int : int decoder
  val field : string -> 'a decoder -> 'a decoder
  val list : 'a decoder -> 'a list decoder
  val one_of : 'a decoder list -> 'a decoder

  module Syntax : sig
    val ( *> ) : 'a decoder -> 'b decoder -> 'b decoder
    val ( <* ) : 'a decoder -> 'b decoder -> 'a decoder
    val ( >>= ) : 'a decoder -> ('a -> 'b decoder) -> 'b decoder
    val ( >>| ) : 'a decoder -> ('a -> 'b) -> 'b decoder
    val ( <*> ) : ('a -> 'b) decoder -> 'a decoder -> 'b decoder
    val ( <$> ) : ('a -> 'b) -> 'a decoder -> 'b decoder
    val ( <: ) : string -> 'a decoder -> 'a decoder
    val ( <|> ) : 'a decoder -> 'a decoder -> 'a decoder
  end
end = struct
  type 'a decoder = Yojson.Safe.t -> 'a option

  let decode decoder json = decoder json
  let return v _ = Some v
  let fail _ = None

  let map f decoder json =
    match decoder json with
    | Some d -> Some (f d)
    | None -> None
  ;;

  let bind decoder f json =
    match decoder json with
    | Some x -> f x `Null
    | None -> None
  ;;

  let rec one_of decoders json =
    match decoders with
    | [] -> None
    | decoder :: tl ->
      (match decoder json with
       | Some _ as x -> x
       | None -> one_of tl json)
  ;;

  let string = function
    | `String str -> Some str
    | _ -> None
  ;;

  let literal str = function
    | `String s when String.equal s str -> Some s
    | _ -> None
  ;;

  let int = function
    | `Int int -> Some int
    | _ -> None
  ;;

  let field key decoder json =
    try decoder @@ Yojson.Safe.Util.member key json with
    | _ -> None
  ;;

  let list decoder json =
    let rec helper acc = function
      | [] -> Some []
      | hd :: tl ->
        (match decoder hd with
         | Some _ as x -> helper (x :: acc) tl
         | None -> None)
    in
    match json with
    | `List list -> Option.map List.rev (helper [] list)
    | _ -> None
  ;;

  module Syntax = struct
    let ( *> ) decoder_a decoder_b yojson =
      match decoder_a yojson with
      | Some _ -> decoder_b yojson
      | None -> None
    ;;

    let ( <* ) decoder_a decoder_b yojson =
      match decoder_a yojson with
      | Some value -> Option.map (fun _ -> value) (decoder_b yojson)
      | None -> None
    ;;

    let ( >>= ) = bind
    let ( >>| ) decoder f yojson = map f decoder yojson

    let ( <*> ) decoder_a decoder_b input =
      match decoder_a input with
      | Some f ->
        (match decoder_b input with
         | Some x -> Some (f x)
         | None -> None)
      | None -> None
    ;;

    let ( <$> ) f decoder = decoder >>| f
    let ( <: ) = field

    let ( <|> ) decoder_a decoder_b input =
      match decoder_a input with
      | Some _ as value -> value
      | None -> decoder_b input
    ;;
  end
end
