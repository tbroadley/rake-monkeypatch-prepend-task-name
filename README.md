# rake-monkeypatch-prepend-task-name

A monkeypatch for Rake that prepends to each line of output the name of the task that printed it.

I originally wrote this as an intern at Datadog in summer 2018.

It's probably the most densely commented piece of code I've ever written. Honestly I find myself wishing I'd written more comments. Some parts of the code, like defaulting to `create_shell_runner(old_cmd)` if `block` isn't defined when calling `old_sh`, don't make sense to me anymore.

It's been a while, so I don't remember what version of Rake this was for. TODO figure it out.
