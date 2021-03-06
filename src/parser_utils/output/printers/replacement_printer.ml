(**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

module Ast = Flow_ast

type patch = (int * int * string) list

let show_patch p: string =
  ListUtils.to_string ""
    (fun (s, e, p) -> Printf.sprintf "Start: <%d> End: <%d> Patch: <%s>\n" s e p) p

let mk_patch_ast_differ (diff : Flow_ast_differ.node Flow_ast_differ.change list)
  (ast : (Loc.t, Loc.t) Ast.program) (file_path : string) : patch =

   let contents = Sys_utils.cat file_path in
   let offset_table = Offset_utils.make contents in
   let offset loc = Offset_utils.offset offset_table loc in

   let attached_comments = Some (Flow_prettier_comments.attach_comments ast) in
   Ast_diff_printer.edits_of_changes attached_comments diff
   |> Core_list.map ~f:(fun (loc, text) -> Loc.(offset loc.start, offset loc._end, text))

let print (patch : patch) (file_path : string) : string =
  let patch_sorted = List.sort
   (fun (start_one, _, _) (start_two, _, _) -> compare start_one start_two)
   patch
  in
  let file_string = Sys_utils.cat file_path in
  let file_end = String.length file_string in
  (* Apply the spans to the original text *)
  let result_string_minus_end, last_span =
    List.fold_left
      (fun (file, last) (start, _end, text) ->
        let file_curr =
          Printf.sprintf "%s%s%s" file
            (String.sub file_string last (start - last))
            text
        in
        (file_curr, _end) )
      ("", 0) patch_sorted
  in
  let last_span_to_end_size = file_end - last_span in
  let result_string =
    if last_span_to_end_size = 0 then
      Printf.sprintf "%s" result_string_minus_end
    else
      Printf.sprintf "%s%s" result_string_minus_end
        (String.sub file_string last_span last_span_to_end_size)
  in
  result_string
