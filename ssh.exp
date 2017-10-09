#!/usr/bin/expect
set host [lindex $argv 0]
set user [lindex $argv 1]
set pass [lindex $argv 2]
spawn ssh $host -l $user ls
expect -re "^Password:"
send "$pass\r"
interact
