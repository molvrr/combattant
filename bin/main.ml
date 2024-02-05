open Eio
open Piaf

let setup_log ?style_renderer level =
  Logs_threaded.enable ();
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level ~all:true level;
  Logs.set_reporter (Logs_fmt.reporter ())
;;

let request_handler ~db_pool Server.{ request; _ } =
  match Rinha.Router.match_route request.meth request.target with
  | Some handler -> Result.get_ok @@ handler db_pool request
  | None ->
    Logs.info (fun d -> d "Não encontrei %S\n" request.target);
    Response.create `Not_found
;;

let () =
  setup_log (Some Logs.Info);
  Eio_main.run
  @@ fun env ->
  Switch.run
  @@ fun sw ->
  let config =
    let interface = Net.Ipaddr.V4.any in
    let port = 8080 in
    `Tcp (interface, port)
  in
  let config = Server.Config.create config in
  let db_uri =
    Uri.make ~scheme:"postgres" ~userinfo:"admin:123" ~host:"db" ~path:"rinha" ()
  in
  let db_pool =
    Result.get_ok
    @@ Caqti_eio_unix.connect_pool ~sw ~stdenv:(env :> Caqti_eio.stdenv) db_uri
  in
  let server = Server.create ~config (request_handler ~db_pool) in
  ignore @@ Server.Command.start ~sw env server
;;
