-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- The orientation switch is the trigger for 2-in-1 tablet mode; the watcher
-- exits on a machine that has no switch.
hl.exec_cmd(o.launch("omarchy-2in1-watch"))
