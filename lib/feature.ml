type t = Pipe_operators

let all = [ Pipe_operators ]
let to_string = function Pipe_operators -> "pipe-operators"
let of_string s = List.find_opt (fun t -> to_string t = s) all
